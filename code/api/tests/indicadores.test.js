const request = require('supertest');
const express = require('express');
const indicadoresRouter = require('../routes/indicadores');
const db = require('../db');

jest.mock('../db');
jest.mock('../middleware/auth', () => jest.fn((req, res, next) => {
  req.user = { id: 'testUserIdFromToken' }; 
  next();
}));

const app = express();
app.use(express.json());
app.use('/api/dashboard', indicadoresRouter);

const normalizeSQL = (sql) => sql.replace(/\s\s+/g, ' ').replace(/\n/g, ' ').trim();

describe('Indicadores Routes', () => {
  const mockUserIdFromPath = 'user123';
  let consoleErrorSpy;
  let consoleLogSpy;

  beforeEach(() => {
    db.query.mockReset();
    db.query.mockResolvedValue({ rows: [], rowCount: 0 });
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    consoleLogSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2025-06-08T12:00:00.000Z'));
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
    consoleLogSpy.mockRestore();
    jest.useRealTimers();
  });

  describe('GET /api/dashboard/treinos/:idUsuario (Percentual Concluído Hoje)', () => {
    const treinosPercentualQueryRaw = `
            SELECT id, data_ficha, status_ficha
            FROM fichas
            WHERE data_ficha >= $1 AND data_ficha <= $2
              AND id_atleta = $3
            ORDER BY data_ficha DESC
        `;
    it('should calculate 0% if no trainings today', async () => {
      db.query.mockResolvedValueOnce({ rows: [] }); 
      const response = await request(app).get(`/api/dashboard/treinos/${mockUserIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual({ percentual: 0 });
      expect(db.query).toHaveBeenCalledWith(normalizeSQL(treinosPercentualQueryRaw), [expect.any(String), expect.any(String), mockUserIdFromPath]);
    });
    
    it('should calculate 50% if 1 of 2 trainings completed today', async () => {
      const mockFichasHoje = [
        { id: 1, data_ficha: new Date().toISOString(), status_ficha: 3 },
        { id: 2, data_ficha: new Date().toISOString(), status_ficha: 1 },
      ];
      db.query.mockResolvedValueOnce({ rows: mockFichasHoje });
      const response = await request(app).get(`/api/dashboard/treinos/${mockUserIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual({ percentual: 50 });
    });

    it('should calculate 100% if all trainings completed today', async () => {
      const mockFichasHoje = [
        { id: 1, data_ficha: new Date().toISOString(), status_ficha: 3 },
        { id: 2, data_ficha: new Date().toISOString(), status_ficha: 3 },
      ];
      db.query.mockResolvedValueOnce({ rows: mockFichasHoje });
      const response = await request(app).get(`/api/dashboard/treinos/${mockUserIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual({ percentual: 100 });
    });
    
    it('should handle DB error gracefully for /treinos (percentual)', async () => {
      db.query.mockRejectedValueOnce(new Error('DB Error Percentual'));
      const response = await request(app).get(`/api/dashboard/treinos/${mockUserIdFromPath}`);
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar buscar treinos.');
    });
  });

  describe('GET /api/dashboard/tempoTreino/:idUsuario (Tempo Treino Hoje)', () => {
    const tempoTreinoQueryRaw = `
            SELECT id, iniciado_em, finalizado_em 
            FROM fichas 
            WHERE data_ficha >= $1 AND data_ficha <= $2 
              AND id_atleta = $3 
              AND status_ficha = 3
        `;
    it('should calculate 0 total time if no completed trainings today', async () => {
      db.query.mockResolvedValueOnce({ rows: [] }); 
      const response = await request(app).get(`/api/dashboard/tempoTreino/${mockUserIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual({ tempoTotalTreinoMinutos: 0, tempoPorFicha: [] });
      expect(db.query).toHaveBeenCalledWith(normalizeSQL(tempoTreinoQueryRaw), [expect.any(String), expect.any(String), mockUserIdFromPath]);
    });
    
    it('should calculate total time for completed trainings today', async () => {
      const now = new Date();
      const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
      const thirtyMinAgoFromStartOfHour = new Date(oneHourAgo.getTime() + 30 * 60 * 1000); 
      
      const mockFichasConcluidasHoje = [
        { id: 1, iniciado_em: oneHourAgo.toISOString(), finalizado_em: now.toISOString(), status_ficha: 3 }, 
        { id: 2, iniciado_em: thirtyMinAgoFromStartOfHour.toISOString(), finalizado_em: now.toISOString(), status_ficha: 3 }, 
      ];
      db.query.mockResolvedValueOnce({ rows: mockFichasConcluidasHoje });
      const response = await request(app).get(`/api/dashboard/tempoTreino/${mockUserIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body.tempoTotalTreinoMinutos).toBe(90); 
      expect(response.body.tempoPorFicha).toEqual([
        { id: 1, duracaoMinutos: 60 },
        { id: 2, duracaoMinutos: 30 },
      ]);
    });

    it('should handle ficha with no start/end time resulting in 0 duration for that ficha', async () => {
        const now = new Date();
        const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
        const mockFichas = [
            { id: 1, iniciado_em: oneHourAgo.toISOString(), finalizado_em: now.toISOString(), status_ficha: 3 },
            { id: 2, iniciado_em: null, finalizado_em: null, status_ficha: 3 },
            { id: 3, iniciado_em: now.toISOString(), finalizado_em: null, status_ficha: 3 },
        ];
        db.query.mockResolvedValueOnce({ rows: mockFichas });
        const response = await request(app).get(`/api/dashboard/tempoTreino/${mockUserIdFromPath}`);
        expect(response.status).toBe(200);
        expect(response.body.tempoTotalTreinoMinutos).toBe(60);
        expect(response.body.tempoPorFicha).toContainEqual({ id: 1, duracaoMinutos: 60 });
        expect(response.body.tempoPorFicha).toContainEqual({ id: 2, duracaoMinutos: 0 });
        expect(response.body.tempoPorFicha).toContainEqual({ id: 3, duracaoMinutos: 0 });
    });

    it('should handle DB error gracefully for /tempoTreino', async () => {
      db.query.mockRejectedValueOnce(new Error('DB Error Tempo'));
      const response = await request(app).get(`/api/dashboard/tempoTreino/${mockUserIdFromPath}`);
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar buscar treinos.');
    });
  });


  describe('GET /api/dashboard/treinosSemana/:idUsuario', () => {
    const expectedTreinosSemanaQueryRaw = `SELECT 
                TO_CHAR(data_ficha AT TIME ZONE 'UTC', 'YYYY-MM-DD') AS dia, 
                COUNT(*) AS total_treinos 
             FROM fichas 
             WHERE data_ficha BETWEEN $1 AND $2 
               AND id_atleta = $3 
               AND status_ficha = 3 
             GROUP BY dia
             ORDER BY dia`;
    
    it('should return empty array if no trainings in the week (as per rota atual)', async () => {
      db.query.mockResolvedValueOnce({ rows: [] });
      const response = await request(app).get(`/api/dashboard/treinosSemana/${mockUserIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual([]); 
      expect(db.query).toHaveBeenCalledWith(normalizeSQL(expectedTreinosSemanaQueryRaw), [expect.any(String), expect.any(String), mockUserIdFromPath]);
    });

    it('should return aggregated trainings per day for the week (as per rota atual)', async () => {
      const expectedFirstDayISO = "2025-06-02T00:00:00.000Z"; 
      const expectedLastDayISO = "2025-06-08T23:59:59.999Z";

      const mockDbData = [
        { dia: '2025-06-02', total_treinos: 2 },
        { dia: '2025-06-04', total_treinos: 1 },
      ];
      db.query.mockResolvedValueOnce({ rows: mockDbData }); 
      
      const response = await request(app).get(`/api/dashboard/treinosSemana/${mockUserIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockDbData); 

      expect(db.query).toHaveBeenCalledWith(
        normalizeSQL(expectedTreinosSemanaQueryRaw),
        [expectedFirstDayISO, expectedLastDayISO, mockUserIdFromPath]
      );
    });

    it('should handle DB error gracefully for /treinosSemana', async () => {
      db.query.mockRejectedValueOnce(new Error('DB Error Semana'));
      const response = await request(app).get(`/api/dashboard/treinosSemana/${mockUserIdFromPath}`);
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar buscar treinos na semana.');
    });
  });

  describe('GET /api/dashboard/progressoMensal/:idUsuario', () => {
    const progressoMensalQueryRaw = `SELECT data_ficha, iniciado_em, finalizado_em
       FROM fichas 
       WHERE EXTRACT(YEAR FROM data_ficha AT TIME ZONE 'UTC') = $1 
         AND id_atleta = $2 
         AND status_ficha = 3`;

    it('should return 0h 0min for all months if no trainings in the year', async () => {
      db.query.mockResolvedValueOnce({ rows: [] });
      const response = await request(app).get(`/api/dashboard/progressoMensal/${mockUserIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body.valores).toHaveLength(12);
      response.body.valores.forEach(val => expect(val).toBe('0h 0min'));
      expect(db.query).toHaveBeenCalledWith(normalizeSQL(progressoMensalQueryRaw), [2025, mockUserIdFromPath]);
    });
    
    it('should calculate monthly progress correctly', async () => {
      const currentYear = 2025;
      const janStart = new Date(`${currentYear}-01-15T10:00:00.000Z`);
      const janEnd = new Date(janStart.getTime() + (60 + 30) * 60 * 1000);
      const marStart = new Date(`${currentYear}-03-10T14:00:00.000Z`);
      const marEnd = new Date(marStart.getTime() + 120 * 60 * 1000);

      const mockFichasAno = [
        { data_ficha: janStart.toISOString(), iniciado_em: janStart.toISOString(), finalizado_em: janEnd.toISOString() },
        { data_ficha: marStart.toISOString(), iniciado_em: marStart.toISOString(), finalizado_em: marEnd.toISOString() },
      ];
      db.query.mockResolvedValueOnce({ rows: mockFichasAno });
      const response = await request(app).get(`/api/dashboard/progressoMensal/${mockUserIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body.valores).toHaveLength(12);
      expect(response.body.valores[0]).toBe('1h 30min');
      expect(response.body.valores[1]).toBe('0h 0min');  
      expect(response.body.valores[2]).toBe('2h 0min');  
    });

    it('should handle fichas with missing start/end times for progressoMensal', async () => {
        const currentYear = 2025;
        const janStart = new Date(`${currentYear}-01-15T10:00:00.000Z`);
        const mockFichas = [
            { data_ficha: janStart.toISOString(), iniciado_em: null, finalizado_em: janStart.toISOString() }, 
            { data_ficha: janStart.toISOString(), iniciado_em: janStart.toISOString(), finalizado_em: null }, 
        ];
        db.query.mockResolvedValueOnce({ rows: mockFichas });
        const response = await request(app).get(`/api/dashboard/progressoMensal/${mockUserIdFromPath}`);
        expect(response.status).toBe(200);
        expect(response.body.valores[0]).toBe('0h 0min');
    });

    it('should handle DB error gracefully for /progressoMensal', async () => {
      db.query.mockRejectedValueOnce(new Error('DB Error Mensal'));
      const response = await request(app).get(`/api/dashboard/progressoMensal/${mockUserIdFromPath}`);
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar buscar progresso mensal.');
    });
  });
});