const request = require('supertest');
const express = require('express');
const feedbackRouter = require('../routes/feedbacks');
const db = require('../db');

jest.mock('../middleware/auth', () => jest.fn((req, res, next) => {
    req.user = { id: 'defaultAthleteId', tipo_usuario: 0, nome: 'Atleta Padrão' };
    next();
}));

jest.mock('../db');

const app = express();
app.use(express.json());
app.use('/api', feedbackRouter);

const normalizeSQL = (sql) => sql.replace(/\s\s+/g, ' ').replace(/\n/g, ' ').trim();

describe('Feedback Routes', () => {
  const mockAthleteUser = { id: 'athleteId123', tipo_usuario: 0, nome: 'Atleta Teste' };
  const mockTrainerUser = { id: 'trainerId456', tipo_usuario: 1, nome: 'Treinador Teste' };
  let consoleErrorSpy;
  let consoleLogSpy;

  beforeEach(() => {
    db.query.mockReset();
    db.query.mockResolvedValue({ rows: [], rowCount: 0 });

    require('../middleware/auth').mockImplementation((req, res, next) => {
        req.user = { ...mockAthleteUser }; 
        next();
    });
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    consoleLogSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
    consoleLogSpy.mockRestore();
  });

  describe('POST /api/feedbacks', () => {
    const validFeedbackData = {
      tipo_feedback: 1,
      texto_feedback: 'Great training session!',
    };
    const postFeedbackQueryRaw = `INSERT INTO feedbacks (id_atleta, id_treinador, tipo_feedback, texto_feedback)
        VALUES ($1, $2, $3, $4) RETURNING id, id_treinador`;

    it('should allow an athlete to send feedback successfully', async () => {
      db.query
        .mockResolvedValueOnce({ rows: [{ id_treinador: 'trainerIdAssociated' }], rowCount: 1 }) 
        .mockResolvedValueOnce({ rows: [{ id: 'feedbackIdNew', id_treinador: 'trainerIdAssociated' }], rowCount: 1 }); 

      const response = await request(app)
        .post('/api/feedbacks')
        .send(validFeedbackData);

      expect(response.status).toBe(201);
      expect(response.body.message).toBe('Feedback enviado com sucesso!');
      expect(response.body.feedbackId).toBe('feedbackIdNew');
      expect(response.body.id_treinador).toBe('trainerIdAssociated');
      
      expect(db.query).toHaveBeenNthCalledWith(1,
        'SELECT id_treinador FROM atleta_treinador WHERE id_atleta = $1',
        [mockAthleteUser.id]
      );
      expect(db.query).toHaveBeenNthCalledWith(2,
        normalizeSQL(postFeedbackQueryRaw),
        [mockAthleteUser.id, 'trainerIdAssociated', validFeedbackData.tipo_feedback, validFeedbackData.texto_feedback.trim()]
      );
    });
    
    it('should return 400 if tipo_feedback is missing', async () => {
      const { tipo_feedback, ...data } = validFeedbackData;
      const response = await request(app).post('/api/feedbacks').send(data);
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Tipo e texto do feedback são obrigatórios.');
    });
    
    it('should return 400 if texto_feedback is missing', async () => {
      const { texto_feedback, ...data } = validFeedbackData;
      const response = await request(app).post('/api/feedbacks').send({ ...data, tipo_feedback: 1});
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Tipo e texto do feedback são obrigatórios.');
    });

    it('should return 400 if texto_feedback is only whitespace', async () => {
        const response = await request(app)
            .post('/api/feedbacks')
            .send({ tipo_feedback: 1, texto_feedback: '   ' });
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('Tipo e texto do feedback são obrigatórios.');
    });

    it('should return 400 for invalid tipo_feedback (not 1 or 2)', async () => {
        const response = await request(app)
            .post('/api/feedbacks')
            .send({ tipo_feedback: 3, texto_feedback: "test" });
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('Tipo de feedback inválido.');
    });
    
    it('should return 400 for non-numeric tipo_feedback', async () => {
        const response = await request(app)
            .post('/api/feedbacks')
            .send({ tipo_feedback: "abc", texto_feedback: "test" });
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('Tipo de feedback inválido.');
    });

    it('should return 404 if athlete is not linked to a trainer', async () => {
      db.query.mockResolvedValueOnce({ rows: [], rowCount: 0 }); 

      const response = await request(app)
        .post('/api/feedbacks')
        .send(validFeedbackData);

      expect(response.status).toBe(404);
      expect(response.body.message).toBe('Atleta não vinculado a um treinador.');
    });

    it('should handle server error when saving feedback (trainer lookup fails)', async () => {
      db.query.mockRejectedValueOnce(new Error('DB error looking up trainer'));

      const response = await request(app)
        .post('/api/feedbacks')
        .send(validFeedbackData);

      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno do servidor ao salvar feedback.');
    });

    it('should handle server error when saving feedback (insert feedback fails)', async () => {
      db.query
        .mockResolvedValueOnce({ rows: [{ id_treinador: 'trainerIdAssociated' }], rowCount: 1 })
        .mockRejectedValueOnce(new Error('DB error inserting feedback'));

      const response = await request(app)
        .post('/api/feedbacks')
        .send(validFeedbackData);

      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno do servidor ao salvar feedback.');
    });
  });


  describe('GET /api/feedbacks', () => {
    const getFeedbacksQueryRaw = `SELECT
            f.id,
            f.id_atleta,
            u.nome AS nome_atleta, 
            f.tipo_feedback,
            f.texto_feedback,
            f.data_envio,
            f.status_feedback
        FROM
            feedbacks f
        JOIN
            usuarios u ON f.id_atleta = u.id
        WHERE
            f.id_treinador = $1
        ORDER BY
            f.data_envio DESC`;

    beforeEach(() => { 
        require('../middleware/auth').mockImplementation((req, res, next) => {
            req.user = { ...mockTrainerUser };
            next();
        });
    });

    it('should allow a trainer to retrieve their feedbacks', async () => {
      const mockFeedbacks = [
        { id: 'fb1', id_atleta: 'atl1', nome_atleta: 'Atleta Um', texto_feedback: 'Bom', tipo_feedback: 1, status_feedback: 0, data_envio: new Date().toISOString() },
        { id: 'fb2', id_atleta: 'atl2', nome_atleta: 'Atleta Dois', texto_feedback: 'Ruim', tipo_feedback: 2, status_feedback: 1, data_envio: new Date().toISOString() },
      ];
      db.query.mockResolvedValueOnce({ rows: mockFeedbacks, rowCount: mockFeedbacks.length });

      const response = await request(app).get('/api/feedbacks');

      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockFeedbacks);
      expect(db.query).toHaveBeenCalledWith(
        normalizeSQL(getFeedbacksQueryRaw),
        [mockTrainerUser.id]
      );
    });

     it('should return an empty array if trainer has no feedbacks', async () => {
      db.query.mockResolvedValueOnce({ rows: [], rowCount: 0 });
      const response = await request(app).get('/api/feedbacks');
      expect(response.status).toBe(200);
      expect(response.body).toEqual([]);
    });

    it('should handle server error when fetching feedbacks', async () => {
      db.query.mockRejectedValueOnce(new Error('DB error fetching feedbacks'));
      const response = await request(app).get('/api/feedbacks');
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno do servidor ao buscar feedbacks.');
    });
  });

  describe('PATCH /api/feedbacks/:id/status', () => {
    const feedbackIdToUpdate = 123;
    const validStatusUpdate = { status: 1 };
    const patchFeedbackStatusQueryRaw = `UPDATE feedbacks
             SET status_feedback = $1
             WHERE id = $2 AND id_treinador = $3 RETURNING id`;

    beforeEach(() => { 
        require('../middleware/auth').mockImplementation((req, res, next) => {
            req.user = { ...mockTrainerUser };
            next();
        });
    });

    it('should allow a trainer to update feedback status', async () => {
      db.query.mockResolvedValueOnce({ rows: [{id: feedbackIdToUpdate}], rowCount: 1 }); 

      const response = await request(app)
        .patch(`/api/feedbacks/${feedbackIdToUpdate}/status`)
        .send(validStatusUpdate);

      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Status do feedback atualizado com sucesso.');
      expect(response.body.feedback).toEqual({id: feedbackIdToUpdate});
      expect(db.query).toHaveBeenCalledWith(
        normalizeSQL(patchFeedbackStatusQueryRaw),
        [validStatusUpdate.status, feedbackIdToUpdate, mockTrainerUser.id]
      );
    });
    
     it('should return 400 for invalid feedback ID format (non-numeric)', async () => {
        const response = await request(app)
            .patch('/api/feedbacks/invalidID/status')
            .send(validStatusUpdate);
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('ID de feedback inválido.');
    });

    it('should return 400 if status is missing in body', async () => {
      const response = await request(app)
        .patch(`/api/feedbacks/${feedbackIdToUpdate}/status`)
        .send({});
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Status inválido. Use 0 (não lido) ou 1 (lido).');
    });
    
    it('should return 400 if status is invalid (not 0 or 1)', async () => {
      const response = await request(app)
        .patch(`/api/feedbacks/${feedbackIdToUpdate}/status`)
        .send({ status: 3 });
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Status inválido. Use 0 (não lido) ou 1 (lido).');
    });

     it('should return 400 if status is not a number', async () => {
      const response = await request(app)
        .patch(`/api/feedbacks/${feedbackIdToUpdate}/status`)
        .send({ status: "abc" }); 
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Status inválido. Use 0 (não lido) ou 1 (lido).');
    });

    it('should return 404 if feedback not found or not owned by trainer', async () => {
      db.query.mockResolvedValueOnce({ rows:[], rowCount: 0 });
      const response = await request(app)
        .patch(`/api/feedbacks/${feedbackIdToUpdate}/status`)
        .send(validStatusUpdate);
      expect(response.status).toBe(404);
      expect(response.body.message).toBe('Feedback não encontrado ou não pertence a este treinador.');
    });

    it('should handle server error when updating feedback status', async () => {
      db.query.mockRejectedValueOnce(new Error('DB error updating status'));
      const response = await request(app)
        .patch(`/api/feedbacks/${feedbackIdToUpdate}/status`)
        .send(validStatusUpdate);
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno do servidor ao atualizar status.');
    });
  });
});