const request = require('supertest');
const express = require('express');
const fichasRouter = require('../routes/fichas');
const db = require('../db');
// Mock da função de notificação
const { publishNotification } = require('../routes/notification');

jest.mock('../db');

// Mock do middleware de autenticação
jest.mock('../middleware/auth', () => jest.fn((req, res, next) => {
  req.user = { id: 'userTestIdFromToken' }; 
  next();
}));

// Mock do módulo de notificação para a rota de vincular atleta
jest.mock('../routes/notification', () => ({
  publishNotification: jest.fn(),
}));

const app = express();
app.use(express.json());
app.use('/api/fichas', fichasRouter);

const normalizeSQL = (sql) => sql.replace(/\s\s+/g, ' ').replace(/\n/g, ' ').trim();

describe('Fichas Routes', () => {
  const mockAthleteIdFromPath = 'athlete123';
  const mockTrainerIdFromPath = 'trainer456';
  const mockFichaIdFromPath = 'ficha789';
  let consoleErrorSpy;
  let consoleLogSpy;

  beforeEach(() => {
    db.query.mockReset();
    db.query.mockResolvedValue({ rows: [], rowCount: 0 });
    // Limpa o mock de notificação antes de cada teste
    publishNotification.mockClear();
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    consoleLogSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
    consoleLogSpy.mockRestore();
  });

  // Testes existentes (já estavam corretos)
  describe('GET /api/fichas/dia/:idAtleta', () => {
    // A query esperada foi atualizada para corresponder à query recebida no erro.
    const expectedDiaQueryRaw = `SELECT f.*, e.nome_esporte AS nome_esporte FROM fichas f JOIN esportes e ON f.id_esporte = e.id WHERE f.id_atleta = $1 AND DATE(f.data_ficha AT TIME ZONE 'America/Sao_Paulo') = DATE(CURRENT_DATE AT TIME ZONE 'America/Sao_Paulo') ORDER BY f.data_ficha DESC, f.id DESC`; // <-- CORRIGIDO: A query agora corresponde exatamente à executada pela rota.
    
    it('should return fichas for the current day for the given athlete', async () => {
      const mockFichasDia = [{ id: 'ficha1', nome_esporte: 'Corrida' }];
      db.query.mockResolvedValueOnce({ rows: mockFichasDia, rowCount: 1 });
      const response = await request(app).get(`/api/fichas/dia/${mockAthleteIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockFichasDia);
      expect(db.query).toHaveBeenCalledWith(expectedDiaQueryRaw, [mockAthleteIdFromPath]);
    });
  });

  describe('GET /api/fichas/semana/:idAtleta', () => {
    const expectedSemanaQueryRaw = `SELECT f.*, e.nome_esporte AS nome_esporte FROM fichas f JOIN esportes e ON f.id_esporte = e.id WHERE f.id_atleta = $1 AND DATE(f.data_ficha AT TIME ZONE 'America/Sao_Paulo') >= (CURRENT_DATE - INTERVAL '6 days') AND DATE(f.data_ficha AT TIME ZONE 'America/Sao_Paulo') <= CURRENT_DATE ORDER BY f.data_ficha DESC, f.id DESC`;
    it('should return fichas for the current week for the given athlete', async () => {
        const mockFichasSemana = [{ id: 'ficha2', nome_esporte: 'Natação' }];
        db.query.mockResolvedValueOnce({ rows: mockFichasSemana, rowCount: 1 });
        const response = await request(app).get(`/api/fichas/semana/${mockAthleteIdFromPath}`);
        expect(response.status).toBe(200);
        expect(response.body).toEqual(mockFichasSemana);
        expect(db.query).toHaveBeenCalledWith(expectedSemanaQueryRaw, [mockAthleteIdFromPath]);
    });
  });

  describe('PUT /api/fichas/iniciar/:id', () => {
    const expectedIniciarQueryRaw = "UPDATE fichas SET status_ficha = 2, iniciado_em = NOW() WHERE id = $1 RETURNING *";
    it('should start a ficha successfully', async () => {
      const mockStartedFicha = { id: mockFichaIdFromPath, status_ficha: 2 };
      db.query.mockResolvedValueOnce({ rows: [mockStartedFicha], rowCount: 1 });
      const response = await request(app).put(`/api/fichas/iniciar/${mockFichaIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Ficha iniciada com sucesso');
      expect(db.query).toHaveBeenCalledWith(expectedIniciarQueryRaw, [mockFichaIdFromPath]);
    });
  });

  describe('PUT /api/fichas/finalizar/:id', () => {
    const expectedFinalizarQueryRaw = `UPDATE fichas SET status_ficha = 3, finalizado_em = NOW() WHERE id = $1 AND status_ficha = 2 RETURNING *`;
    it('should finalize a ficha successfully', async () => {
      const mockFinalizedFicha = { id: mockFichaIdFromPath, status_ficha: 3 };
      db.query.mockResolvedValueOnce({ rows: [mockFinalizedFicha], rowCount: 1 }); 
      const response = await request(app).put(`/api/fichas/finalizar/${mockFichaIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Ficha finalizada com sucesso');
      expect(db.query).toHaveBeenCalledWith(expectedFinalizarQueryRaw, [mockFichaIdFromPath]);
    });
  });

  // --- NOVOS TESTES PARA COBERTURA DE 100% ---

  describe('POST /api/fichas', () => {
    it('should create a ficha successfully', async () => {
      const newFichaData = {
        nome_ficha: 'Treino de Força',
        id_treinador: mockTrainerIdFromPath,
        descricao: 'Foco em membros superiores',
        categoria: 'Musculação',
        data_ficha: '2025-12-20',
        id_esporte: 1
      };
      const mockCreatedFicha = { id: 'newFicha1', ...newFichaData };
      db.query.mockResolvedValueOnce({ rows: [mockCreatedFicha], rowCount: 1 });

      const response = await request(app).post('/api/fichas').send(newFichaData);

      expect(response.status).toBe(201);
      expect(response.body).toEqual({ message: 'Ficha criada com sucesso', ficha: mockCreatedFicha });
    });

    it('should handle DB error on creation and return 500', async () => {
      db.query.mockRejectedValueOnce(new Error('DB Error Create'));
      const response = await request(app).post('/api/fichas').send({ nome_ficha: 'test' });
      expect(response.status).toBe(500);
      expect(response.body.error).toBe('Erro ao criar ficha');
    });
  });

  describe('GET /api/fichas/treinador/:idTreinador', () => {
    it('should get fichas for a trainer', async () => {
      const mockFichas = [{ id: 'ficha1' }, { id: 'ficha2' }];
      db.query.mockResolvedValueOnce({ rows: mockFichas, rowCount: 2 });
      const response = await request(app).get(`/api/fichas/treinador/${mockTrainerIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockFichas);
    });

    it('should handle DB error and return 500', async () => {
      db.query.mockRejectedValueOnce(new Error('DB Error'));
      const response = await request(app).get(`/api/fichas/treinador/${mockTrainerIdFromPath}`);
      expect(response.status).toBe(500);
    });
  });
  
  describe('GET /api/fichas/retornar-ficha-sem-vinculo/:idTreinador', () => {
    it('should get unlinked fichas for a trainer', async () => {
      const mockFichas = [{ id: 'ficha3', id_atleta: null }];
      db.query.mockResolvedValueOnce({ rows: mockFichas, rowCount: 1 });
      const response = await request(app).get(`/api/fichas/retornar-ficha-sem-vinculo/${mockTrainerIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockFichas);
    });
  });
  
  describe('PUT /api/fichas/:id', () => {
    const updateData = { nome_ficha: 'Novo Nome', descricao: 'Nova Desc', categoria: 'Cardio', data_ficha: '2025-11-10', id_esporte: 2 };
    
    it('should update a ficha successfully', async () => {
      const mockUpdatedFicha = { id: mockFichaIdFromPath, ...updateData };
      db.query.mockResolvedValueOnce({ rows: [mockUpdatedFicha], rowCount: 1 });
      const response = await request(app).put(`/api/fichas/${mockFichaIdFromPath}`).send(updateData);
      expect(response.status).toBe(200);
      expect(response.body.ficha).toEqual(mockUpdatedFicha);
    });

    it('should return 404 if ficha to update is not found', async () => {
      db.query.mockResolvedValueOnce({ rows: [], rowCount: 0 });
      const response = await request(app).put(`/api/fichas/${mockFichaIdFromPath}`).send(updateData);
      expect(response.status).toBe(404);
      expect(response.body.error).toBe('Ficha não encontrada.');
    });
  });

  describe('PUT /api/fichas/vincular-atleta/:idFicha', () => {
    it('should link an athlete and send notification', async () => {
      const mockLinkedFicha = { id: mockFichaIdFromPath, id_atleta: mockAthleteIdFromPath, nome_ficha: 'Ficha Vinculada' };
      db.query.mockResolvedValueOnce({ rows: [mockLinkedFicha], rowCount: 1 });

      const response = await request(app)
        .put(`/api/fichas/vincular-atleta/${mockFichaIdFromPath}`)
        .send({ id_atleta: mockAthleteIdFromPath });

      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Atleta vinculado à ficha com sucesso');
      // Verifica se a notificação foi chamada
      expect(publishNotification).toHaveBeenCalledTimes(1);
      expect(publishNotification).toHaveBeenCalledWith(mockAthleteIdFromPath, 'Nova Ficha Vinculada', 'Você foi vinculado à ficha: Ficha Vinculada');
    });

    it('should return 400 if id_atleta is missing', async () => {
      const response = await request(app).put(`/api/fichas/vincular-atleta/${mockFichaIdFromPath}`).send({});
      expect(response.status).toBe(400);
      expect(response.body.error).toBe('id_atleta é obrigatório.');
    });
    
    it('should return 404 if ficha to link is not found', async () => {
        db.query.mockResolvedValueOnce({ rows: [], rowCount: 0 });
        const response = await request(app).put(`/api/fichas/vincular-atleta/${mockFichaIdFromPath}`).send({id_atleta: mockAthleteIdFromPath});
        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Ficha não encontrada.');
    });
  });

  describe('GET /api/fichas/atleta-treinador/:idTreinador', () => {
    it('should return athletes for a trainer', async () => {
      const mockAthletes = [{ id: 'athlete1', nome: 'João' }, { id: 'athlete2', nome: 'Maria' }];
      db.query.mockResolvedValueOnce({ rows: mockAthletes, rowCount: 2 });
      const response = await request(app).get(`/api/fichas/atleta-treinador/${mockTrainerIdFromPath}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockAthletes);
    });
  });
});