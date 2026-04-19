const request = require('supertest');
const express = require('express');
const eventosRouter = require('../routes/events');
const db = require('../db');

const mockUserIdFromToken = 'userFromToken123';

jest.mock('../middleware/auth', () => jest.fn((req, res, next) => {
  req.user = { id: mockUserIdFromToken, tipo_usuario: 0, nome: 'Usuário Teste Logado' }; // Default mock
  next();
}));

jest.mock('../db');

const app = express();
app.use(express.json());
app.use('/api/eventos', eventosRouter);

// Helper para remover múltiplos espaços e quebras de linha, e trimmar
const normalizeSQL = (sql) => {
  if (typeof sql !== 'string') return '';
  return sql.replace(/\s\s+/g, ' ').replace(/\n/g, ' ').trim();
}

describe('Eventos Routes', () => {
  const mockCreatorUserId = 'eventCreator456'; // Used as req.user.id for creation routes
  let consoleErrorSpy;
  let consoleLogSpy;

  beforeEach(() => {
    db.query.mockReset(); // Clear call history and reset implementations
    db.query.mockResolvedValue({ rows: [], rowCount: 0 }); // Default mock resolution

    // Setup specific auth mock for event creator scenarios
    require('../middleware/auth').mockImplementation((req, res, next) => {
      req.user = { id: mockCreatorUserId, tipo_usuario: 1, nome: 'Treinador Criador' };
      next();
    });
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    consoleLogSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
    consoleLogSpy.mockRestore();
  });

  describe('POST /api/eventos/cadastro/:id_usuario', () => {
    const baseEventData = {
      nome_evento: 'Evento Teste Principal',
      tipo_evento: 1,
      descricao: 'Descrição detalhada do evento.',
    };

    const insertQueryWithDateRaw = `
          INSERT INTO eventos
            (nome_evento, tipo_evento, data_evento, descricao, status_evento, criado_por)
          VALUES
            ($1, $2, to_timestamp($3, 'DD/MM/YYYY HH24:MI:SS'), $4, $5, $6)
          RETURNING *`;
    
    const insertQueryWithoutDateRaw = `
          INSERT INTO eventos
            (nome_evento, tipo_evento, descricao, status_evento, criado_por)
          VALUES
            ($1, $2, $3, $4, $5)
          RETURNING *`;

    it('should create an event successfully with data_evento', async () => {
      const eventDataWithDate = {
        ...baseEventData,
        data_evento: '25/12/2025', // data_evento_tela
        status_evento: 1,
      };
      const expectedDateTimeForDB = '25/12/2025 00:00:00';
      const mockCreatedEvent = { 
        id: 'newEventId1', 
        ...eventDataWithDate, 
        data_evento: new Date('2025-12-25T00:00:00.000Z').toISOString(), // Example, DB might store timezone differently
        criado_por: mockCreatorUserId 
      };
      db.query.mockResolvedValueOnce({ rows: [mockCreatedEvent], rowCount: 1 });

      const response = await request(app)
        .post(`/api/eventos/cadastro/${mockCreatorUserId}`) // param id_usuario is creator
        .send(eventDataWithDate);

      expect(response.status).toBe(201);
      expect(response.body.message).toBe('Evento criado com sucesso!');
      expect(response.body.evento).toEqual(mockCreatedEvent);
      
      expect(db.query).toHaveBeenCalledTimes(1);
      const [actualQuery, actualParams] = db.query.mock.calls[0];
      expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(insertQueryWithDateRaw));
      expect(actualParams).toEqual([
          eventDataWithDate.nome_evento, 
          eventDataWithDate.tipo_evento, 
          expectedDateTimeForDB, 
          eventDataWithDate.descricao, 
          eventDataWithDate.status_evento, 
          mockCreatorUserId // criado_por should be from req.user.id
      ]);
    });

    it('should create an event successfully without data_evento (defaulting status_evento to 1)', async () => {
      const eventDataNoDate = { ...baseEventData };
      const mockCreatedEvent = { 
        id: 'newEventId2', 
        ...eventDataNoDate, 
        status_evento: 1, 
        data_evento: null, 
        criado_por: mockCreatorUserId 
      };
      db.query.mockResolvedValueOnce({ rows: [mockCreatedEvent], rowCount: 1 });

      const response = await request(app)
        .post(`/api/eventos/cadastro/${mockCreatorUserId}`)
        .send(eventDataNoDate);

      expect(response.status).toBe(201);
      expect(response.body.message).toBe('Evento criado com sucesso!');
      expect(response.body.evento).toEqual(mockCreatedEvent);

      expect(db.query).toHaveBeenCalledTimes(1);
      const [actualQuery, actualParams] = db.query.mock.calls[0];
      expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(insertQueryWithoutDateRaw));
      expect(actualParams).toEqual([
          eventDataNoDate.nome_evento, 
          eventDataNoDate.tipo_evento, 
          eventDataNoDate.descricao, 
          1, // Default status_evento
          mockCreatorUserId // criado_por
      ]);
    });

    it('should return 400 if nome_evento is missing', async () => {
      const { nome_evento, ...incompleteData } = baseEventData;
      const response = await request(app)
        .post(`/api/eventos/cadastro/${mockCreatorUserId}`)
        .send(incompleteData);
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('nome_evento é obrigatório.'); // Assuming route validates this
    });

    it('should return 400 if tipo_evento is missing', async () => {
      const { tipo_evento, ...incompleteData } = baseEventData;
      const response = await request(app)
        .post(`/api/eventos/cadastro/${mockCreatorUserId}`)
        .send({ ...incompleteData, nome_evento: 'Test Name Only' });
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('tipo_evento é obrigatório.'); // Assuming route validates this
    });
    
    it('should return 400 if descricao is missing', async () => {
      const { descricao, ...incompleteData } = baseEventData;
      const response = await request(app)
        .post(`/api/eventos/cadastro/${mockCreatorUserId}`)
        .send({ ...incompleteData, nome_evento: 'Test Name', tipo_evento: 1 });
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('descricao é obrigatória.'); // Assuming route validates this
    });

    it('should handle server error during event creation', async () => {
      db.query.mockRejectedValueOnce(new Error('DB creation error'));
      const response = await request(app)
        .post(`/api/eventos/cadastro/${mockCreatorUserId}`)
        .send({ ...baseEventData, data_evento: '01/01/2025', status_evento: 1 });
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar criar evento.');
    });
  });

  describe('GET /api/eventos/:id_usuario', () => {
    const targetUserIdForListing = 'athlete123ToList'; // User whose perspective we are viewing from
    const getEventsForUserQueryRaw = `SELECT e.id, e.nome_evento, e.tipo_evento, e.data_evento, e.descricao, e.criado_por,
              es.nome_esporte AS tipo_evento_nome,
              CASE
                WHEN ae.id_atleta IS NOT NULL THEN 1
                ELSE 0
              END AS atleta_vinculado
       FROM eventos e
       JOIN esportes es ON e.tipo_evento = es.id
       LEFT JOIN atleta_evento ae ON e.id = ae.id_evento AND ae.id_atleta = $1
       WHERE e.status_evento = 1
       ORDER BY e.data_evento DESC NULLS LAST`;

    beforeEach(() => {
        // Mock auth for an athlete viewing the events list
        require('../middleware/auth').mockImplementation((req, res, next) => {
          req.user = { id: targetUserIdForListing, tipo_usuario: 0, nome: 'Atleta Listando Eventos' };
          next();
        });
    });

    it('should retrieve events for a given user ID, indicating which ones they are linked to', async () => {
      const mockEvents = [
        { id: 'event1', nome_evento: 'Evento A', tipo_evento:1, data_evento: null, descricao: 'd1', criado_por: 'c1', tipo_evento_nome: 'Futebol', atleta_vinculado: 1 },
        { id: 'event2', nome_evento: 'Evento B', tipo_evento:2, data_evento: null, descricao: 'd2', criado_por: 'c2', tipo_evento_nome: 'Basquete', atleta_vinculado: 0 },
      ];
      db.query.mockResolvedValueOnce({ rows: mockEvents });

      // The :id_usuario in the route is the user for whom events are listed (same as logged-in user here)
      const response = await request(app).get(`/api/eventos/${targetUserIdForListing}`);

      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockEvents);

      expect(db.query).toHaveBeenCalledTimes(1);
      const [actualQuery, actualParams] = db.query.mock.calls[0];
      expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(getEventsForUserQueryRaw));
      expect(actualParams).toEqual([targetUserIdForListing]);
    });

    it('should return an empty array if no events found', async () => {
      db.query.mockResolvedValueOnce({ rows: [] });
      const response = await request(app).get(`/api/eventos/${targetUserIdForListing}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual([]);
    });

    it('should handle server error when fetching events by user ID', async () => {
      db.query.mockRejectedValueOnce(new Error('DB fetch error'));
      const response = await request(app).get(`/api/eventos/${targetUserIdForListing}`);
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar buscar eventos.');
    });
  });

  describe('GET /api/eventos/retornar/:id (specific event)', () => {
    const eventId = 'eventAbc';
    const getSpecificEventQueryRaw = 'SELECT * FROM eventos WHERE id = $1';

    it('should retrieve a specific event by its ID', async () => {
      const mockEvent = { id: eventId, nome_evento: 'Evento Específico' };
      db.query.mockResolvedValueOnce({ rows: [mockEvent], rowCount: 1 });

      const response = await request(app).get(`/api/eventos/retornar/${eventId}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockEvent);

      expect(db.query).toHaveBeenCalledTimes(1);
      const [actualQuery, actualParams] = db.query.mock.calls[0];
      expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(getSpecificEventQueryRaw));
      expect(actualParams).toEqual([eventId]);
    });

    it('should return 404 if event not found by ID', async () => {
      db.query.mockResolvedValueOnce({ rows: [], rowCount: 0 });
      const response = await request(app).get(`/api/eventos/retornar/${eventId}`);
      expect(response.status).toBe(404);
      expect(response.body.message).toBe('Evento não encontrado.');
    });

    it('should handle server error when fetching a specific event', async () => {
      db.query.mockRejectedValueOnce(new Error('DB fetch specific error'));
      const response = await request(app).get(`/api/eventos/retornar/${eventId}`);
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar buscar evento.');
    });
  });

  describe('GET /api/eventos/retornar/usuario/:id_usuario (user specific linked events)', () => {
    const athleteUserIdForLinkedEvents = 'athleteXyzLinked';
    const getLinkedEventsQueryRaw = `SELECT e.id, e.nome_evento, e.tipo_evento, e.data_evento, e.descricao,
              es.nome_esporte AS tipo_evento_nome,
              1 AS atleta_vinculado
       FROM eventos e
       JOIN esportes es ON e.tipo_evento = es.id
       JOIN atleta_evento ae ON e.id = ae.id_evento
       WHERE ae.id_atleta = $1 AND e.status_evento = 1
       ORDER BY e.data_evento DESC NULLS LAST`;
    
     beforeEach(() => { 
        // Auth as the athlete whose linked events are being requested
        require('../middleware/auth').mockImplementation((req, res, next) => {
          req.user = { id: athleteUserIdForLinkedEvents, tipo_usuario: 0, nome: 'Atleta Vinculado' };
          next();
        });
    });

    it('should retrieve events an athlete is specifically linked to', async () => {
      const mockLinkedEvents = [
        { id: 'eventLinked1', nome_evento: 'Evento Vinculado 1', tipo_evento:1, data_evento: null, descricao:'d', tipo_evento_nome: 'Corrida', atleta_vinculado: 1 },
      ];
      db.query.mockResolvedValueOnce({ rows: mockLinkedEvents });

      const response = await request(app).get(`/api/eventos/retornar/usuario/${athleteUserIdForLinkedEvents}`);
      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockLinkedEvents);
      
      expect(db.query).toHaveBeenCalledTimes(1);
      const [actualQuery, actualParams] = db.query.mock.calls[0];
      expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(getLinkedEventsQueryRaw));
      expect(actualParams).toEqual([athleteUserIdForLinkedEvents]);
    });

     it('should handle server error for user specific linked events', async () => {
        db.query.mockRejectedValueOnce(new Error('DB error'));
        const response = await request(app).get(`/api/eventos/retornar/usuario/${athleteUserIdForLinkedEvents}`);
        expect(response.status).toBe(500);
        expect(response.body.message).toBe('Erro interno no servidor ao tentar buscar eventos.');
     });
  });

  describe('DELETE /api/eventos/deletar/:id', () => {
    const eventIdToDelete = 'eventToDelete789';
    const deleteEventQueryRaw = 'UPDATE eventos SET status_evento = 0 WHERE id = $1 RETURNING *';

    beforeEach(() => {
        // Auth as a trainer/admin who can delete events
        require('../middleware/auth').mockImplementation((req, res, next) => {
          req.user = { id: 'someAdminOrTrainerId', tipo_usuario: 1, nome: 'Admin Deletador' };
          next();
        });
    });

    it('should deactivate an event successfully', async () => {
      const mockDeactivatedEvent = { id: eventIdToDelete, nome_evento: 'Evento Deletado', status_evento: 0 };
      db.query.mockResolvedValueOnce({ rows: [mockDeactivatedEvent], rowCount: 1 });

      const response = await request(app).delete(`/api/eventos/deletar/${eventIdToDelete}`);
      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Evento desativado com sucesso!');
      expect(response.body.eventoDeletado).toEqual(mockDeactivatedEvent);

      expect(db.query).toHaveBeenCalledTimes(1);
      const [actualQuery, actualParams] = db.query.mock.calls[0];
      expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(deleteEventQueryRaw));
      expect(actualParams).toEqual([eventIdToDelete]);
    });
    
    it('should return 404 if event to delete not found', async () => {
        db.query.mockResolvedValueOnce({ rows: [], rowCount: 0 });
        const response = await request(app).delete(`/api/eventos/deletar/${eventIdToDelete}`);
        expect(response.status).toBe(404);
        expect(response.body.message).toBe('Evento não encontrado.'); 
    });

     it('should handle server error for deleting event', async () => {
        db.query.mockRejectedValueOnce(new Error('DB error'));
        const response = await request(app).delete(`/api/eventos/deletar/${eventIdToDelete}`);
        expect(response.status).toBe(500);
        expect(response.body.message).toBe('Erro interno no servidor ao tentar desativar evento.');
     });
  });

  describe('POST /api/eventos/vincular/:id', () => {
    const eventIdToLink = 'eventLink123'; // Event ID from URL param
    const userIdLinking = 'userLinkingAction456'; // User performing the action (from auth middleware)
    const userIdToLinkInBody = 'userToLinkBody789'; // User ID provided in request body
    const vincularQueryRaw = 'INSERT INTO atleta_evento (id_atleta, id_evento) VALUES ($1, $2) RETURNING *';
    
    beforeEach(() => {
        // Auth as the user who is trying to link (could be self or a trainer linking an athlete)
        require('../middleware/auth').mockImplementation((req, res, next) => {
          req.user = { id: userIdLinking, tipo_usuario: 0, nome: 'Atleta se Vinculando' };
          next();
        });
    });

    it('should link a user (from body) to an event successfully', async () => {
      const mockInsertedLink = { id_atleta_evento: 'newLinkId', id_atleta: userIdToLinkInBody, id_evento: eventIdToLink };
      db.query.mockResolvedValueOnce({ rows: [mockInsertedLink], rowCount: 1 });

      const response = await request(app)
        .post(`/api/eventos/vincular/${eventIdToLink}`)
        .send({ id_usuario: userIdToLinkInBody }); // Athlete to be linked is in the body

      expect(response.status).toBe(201);
      expect(response.body.message).toBe('Vínculo criado com sucesso!');
      expect(response.body.vinculo).toEqual(mockInsertedLink);

      expect(db.query).toHaveBeenCalledTimes(1);
      const [actualQuery, actualParams] = db.query.mock.calls[0];
      expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(vincularQueryRaw));
      expect(actualParams).toEqual([userIdToLinkInBody, eventIdToLink]);
    });
    
    it('should return 400 if id_usuario is missing in body for vincular', async () => {
        const response = await request(app).post(`/api/eventos/vincular/${eventIdToLink}`).send({});
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('id_usuario (do atleta) é obrigatório no corpo da requisição.');
    });

    // Test for FK violation (event or user not found)
    it('should return 500 if event or user to link does not exist (FK violation)', async () => {
        db.query.mockRejectedValueOnce({ code: '23503', message: 'DB specific FK error' }); 
        const response = await request(app)
            .post(`/api/eventos/vincular/${eventIdToLink}`)
            .send({ id_usuario: userIdToLinkInBody });
        expect(response.status).toBe(500); // Or 404 if your route handles '23503' specifically
        expect(response.body.message).toBe('Erro interno no servidor ao tentar criar vínculo.');
    });
    
    // Test for unique constraint violation (already linked)
    it('should return 500 if user already linked to event (UNIQUE constraint violation)', async () => {
        db.query.mockRejectedValueOnce({ code: '23505', message: 'DB specific unique error' }); 
        const response = await request(app)
            .post(`/api/eventos/vincular/${eventIdToLink}`)
            .send({ id_usuario: userIdToLinkInBody });
        expect(response.status).toBe(500); // Or 409 if your route handles '23505' specifically
        expect(response.body.message).toBe('Erro interno no servidor ao tentar criar vínculo.');
    });
  });

  describe('PUT /api/eventos/desvincular/:id', () => {
    const eventIdToUnlink = 'eventUnlink789';
    const userIdUnlinkingAction = 'userUnlinkingAction012'; // User performing action (from auth)
    const userIdToUnlinkInBody = 'userToUnlinkInBody345'; // User ID in request body
    const desvincularQueryRaw = 'DELETE FROM atleta_evento WHERE id_atleta = $1 AND id_evento = $2 RETURNING *';

    beforeEach(() => { 
        require('../middleware/auth').mockImplementation((req, res, next) => {
          req.user = { id: userIdUnlinkingAction, tipo_usuario: 0, nome: 'Atleta se Desvinculando' };
          next();
        });
    });

    it('should unlink a user (from body) from an event successfully', async () => {
      const mockDeletedLink = { id_atleta: userIdToUnlinkInBody, id_evento: eventIdToUnlink };
      // Assuming DELETE RETURNING * returns the deleted row, or affected row count.
      db.query.mockResolvedValueOnce({ rows: [mockDeletedLink], rowCount: 1 }); 
      const response = await request(app)
        .put(`/api/eventos/desvincular/${eventIdToUnlink}`)
        .send({ id_usuario: userIdToUnlinkInBody });
      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Vínculo deletado com sucesso!');
      
      expect(db.query).toHaveBeenCalledTimes(1);
      const [actualQuery, actualParams] = db.query.mock.calls[0];
      expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(desvincularQueryRaw));
      expect(actualParams).toEqual([userIdToUnlinkInBody, eventIdToUnlink]);
    });

    it('should return 400 if id_usuario missing for desvincular', async () => {
        const response = await request(app).put(`/api/eventos/desvincular/${eventIdToUnlink}`).send({});
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('id_usuario (do atleta) é obrigatório no corpo da requisição.');
    });
    
    it('should return 404 if link to delete not found for desvincular', async () => {
        db.query.mockResolvedValueOnce({ rows: [], rowCount: 0 }); // No link found to delete
        const response = await request(app)
            .put(`/api/eventos/desvincular/${eventIdToUnlink}`)
            .send({ id_usuario: userIdToUnlinkInBody });
        expect(response.status).toBe(404);
        expect(response.body.message).toBe('Vínculo não encontrado para este usuário e evento.');
    });

    it('should handle server error for desvincular', async () => {
        db.query.mockRejectedValueOnce(new Error('DB error'));
        const response = await request(app)
            .put(`/api/eventos/desvincular/${eventIdToUnlink}`)
            .send({ id_usuario: userIdToUnlinkInBody });
        expect(response.status).toBe(500);
        expect(response.body.message).toBe('Erro interno no servidor ao tentar deletar vínculo.');
    });
  });

  describe('PUT /api/eventos/alterar/:id', () => {
    const eventIdToUpdate = 'eventUpdateAbc';
    const fullUpdateData = {
      nome_evento: 'Evento Atualizado X',
      tipo_evento: 2,
      data_evento: '15/08/2026', 
      descricao: 'Descrição nova e melhorada.',
      status_evento: 1,
    };
    const expectedDateTimeUpdate = '15/08/2026 00:00:00';

    const updateQueryRaw = `UPDATE eventos
             SET nome_evento = COALESCE($1, nome_evento),
                 tipo_evento = COALESCE($2, tipo_evento),
                 data_evento = COALESCE(to_timestamp($3, 'DD/MM/YYYY HH24:MI:SS'), data_evento),
                 descricao = COALESCE($4, descricao),
                 status_evento = COALESCE($5, status_evento)
             WHERE id = $6
             RETURNING *`;

    beforeEach(() => {
        // Auth as a trainer/admin
        require('../middleware/auth').mockImplementation((req, res, next) => {
          req.user = { id: 'someAdminOrTrainerId', tipo_usuario: 1, nome: 'Admin Alterador' };
          next();
        });
    });

    it('should update an event successfully with all fields', async () => {
      const mockUpdatedEvent = { 
        id: eventIdToUpdate, 
        ...fullUpdateData, 
        data_evento: new Date('2026-08-15T00:00:00.000Z').toISOString()
      };
      db.query.mockResolvedValueOnce({ rows: [mockUpdatedEvent], rowCount: 1 });

      const response = await request(app)
        .put(`/api/eventos/alterar/${eventIdToUpdate}`)
        .send(fullUpdateData);

      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Evento atualizado com sucesso!');
      expect(response.body.eventoAtualizado).toEqual(mockUpdatedEvent);

      expect(db.query).toHaveBeenCalledTimes(1);
      const [actualQuery, actualParams] = db.query.mock.calls[0];
      expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(updateQueryRaw));
      expect(actualParams).toEqual([
          fullUpdateData.nome_evento, 
          fullUpdateData.tipo_evento, 
          expectedDateTimeUpdate, 
          fullUpdateData.descricao, 
          fullUpdateData.status_evento, 
          eventIdToUpdate
      ]);
    });

    it('should update an event with only some fields (NEEDS ROUTE CHECK FOR 400)', async () => {
        const partialUpdateData = { nome_evento: 'Partial Update Name' }; 
        const mockUpdatedEventAfterPartial = { 
            id: eventIdToUpdate, 
            nome_evento: 'Partial Update Name', 
            // other fields would retain their old values from DB, or be null if new
            tipo_evento: 1, // Example old value
            data_evento: new Date('2025-01-01T00:00:00.000Z').toISOString(), // Example old value
            descricao: 'Old Description', // Example old value
            status_evento: 1 // Example old value
        }; 
        // The mock response should reflect what COALESCE would return if DB had prior values
        db.query.mockResolvedValueOnce({ rows: [{
            ...mockUpdatedEventAfterPartial, // Simulate the DB returning the complete, updated row
            nome_evento: partialUpdateData.nome_evento // ensure this field is from the update
        }], rowCount: 1 });
        
        const response = await request(app)
            .put(`/api/eventos/alterar/${eventIdToUpdate}`)
            .send(partialUpdateData);
            
        // This test was failing: Expected 200, Received 400.
        // This implies the route has validation that prevents partial updates as intended by COALESCE.
        // If the route is fixed to allow true partial updates, this test should pass.
        expect(response.status).toBe(200); 
        expect(response.body.eventoAtualizado.nome_evento).toBe(partialUpdateData.nome_evento);
        // You might want to check other fields in response.body.eventoAtualizado if they should remain unchanged
        
        expect(db.query).toHaveBeenCalledTimes(1);
        const [actualQuery, actualParams] = db.query.mock.calls[0];
        expect(normalizeSQL(actualQuery)).toEqual(normalizeSQL(updateQueryRaw));
        expect(actualParams).toEqual([
            partialUpdateData.nome_evento, 
            undefined, // tipo_evento not sent
            undefined, // data_evento not sent
            undefined, // descricao not sent
            undefined, // status_evento not sent
            eventIdToUpdate
        ]);
    });

    it('should return 400 if nome_evento is empty string when provided', async () => {
        const response = await request(app)
            .put(`/api/eventos/alterar/${eventIdToUpdate}`)
            .send({ nome_evento: ''}); 
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('Nome do evento não pode ser vazio.');
    });
    
    it('should return 404 if event to update not found', async () => {
        db.query.mockResolvedValueOnce({ rows: [], rowCount: 0 }); // Event not found
        const response = await request(app)
            .put(`/api/eventos/alterar/${eventIdToUpdate}`)
            .send(fullUpdateData); // Send valid data to pass initial checks
        expect(response.status).toBe(404);
        expect(response.body.message).toBe('Evento não encontrado.');
    });

    it('should handle server error (e.g. invalid data type for a field not directly validated by route) for alterar', async () => {
        // This simulates an error from the DB due to data type mismatch,
        // assuming the route doesn't catch this specific validation before hitting DB.
        db.query.mockRejectedValueOnce(new Error('database error: invalid input syntax for type integer'));
        const response = await request(app)
            .put(`/api/eventos/alterar/${eventIdToUpdate}`)
            .send({ nome_evento: "Nome Valido", tipo_evento: "texto_invalido" }); // Invalid tipo_evento
        expect(response.status).toBe(500);
        expect(response.body.message).toBe('Erro interno no servidor ao tentar atualizar evento.');
    });
  });
});