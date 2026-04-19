const request = require('supertest');
const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../db');
const authRouter = require('../routes/auth');

jest.mock('../db');
jest.mock('bcrypt', () => ({
  hash: jest.fn(),
  compare: jest.fn(),
}));
jest.mock('jsonwebtoken', () => ({
  sign: jest.fn(),
  verify: jest.fn(),
}));


const app = express();
app.use(express.json());
app.use('/', authRouter);

describe('Auth Routes', () => {
  let originalJwtSecret;
  let consoleErrorSpy;

  beforeAll(() => {
    originalJwtSecret = process.env.JWT_SECRET;
    process.env.JWT_SECRET = 'testsecret';
  });

  afterAll(() => {
    process.env.JWT_SECRET = originalJwtSecret;
  });

  beforeEach(() => {
    db.query.mockReset();
    db.query.mockResolvedValue({ rows: [], rowCount: 0 });

    bcrypt.hash.mockClear();
    bcrypt.compare.mockClear();
    jwt.sign.mockClear();
    
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    if (consoleErrorSpy) {
      consoleErrorSpy.mockRestore();
    }
  });

  describe('POST /cadastro', () => {
    const validUserData = {
      nome: 'Test User',
      email: 'test@example.com',
      senha: 'password123',
      telefone: '+5531999998888',
      cpf: '123.456.789-00',
      dataNascimento: '01/01/1990',
      tipo_usuario: 0,
    };

    it('should register a new user successfully', async () => {
      db.query
        .mockResolvedValueOnce({ rows: [] }) // Check userExists
        .mockResolvedValueOnce({ rows: [{ id: 'newUserId', nome: 'Test User', email: 'test@example.com' }], rowCount: 1 }); // Insert
      bcrypt.hash.mockResolvedValue('hashedPassword');

      const response = await request(app)
        .post('/cadastro')
        .send(validUserData);

      expect(response.status).toBe(201);
      expect(response.body.message).toBe('Usuário cadastrado com sucesso!');
      expect(response.body.usuario).toEqual({ id: null, nome: 'Test User', email: 'test@example.com' });
      expect(db.query).toHaveBeenCalledTimes(2);
      expect(bcrypt.hash).toHaveBeenCalledWith('password123', 10);
      expect(db.query).toHaveBeenNthCalledWith(2,
        expect.stringContaining("to_date($6, 'DD/MM/YYYY')"),
        ['Test User', 'test@example.com', 'hashedPassword', '+5531999998888', '123.456.789-00', '01/01/1990', 0]
      );
    });

    it('should register a user successfully without optional fields (telefone, cpf, dataNascimento) and default tipo_usuario', async () => {
        const minimalUserData = {
            nome: 'Minimal User',
            email: 'minimal@example.com',
            senha: 'passwordSecure'
        };
        db.query
          .mockResolvedValueOnce({ rows: [] })
          .mockResolvedValueOnce({ rows: [{ id: 'minimalUserId', ...minimalUserData }], rowCount: 1 });
        bcrypt.hash.mockResolvedValue('hashedMinimalPassword');

        const response = await request(app)
            .post('/cadastro')
            .send(minimalUserData);

        expect(response.status).toBe(201);
        expect(response.body.message).toBe('Usuário cadastrado com sucesso!');
        expect(response.body.usuario).toEqual({ id: null, nome: minimalUserData.nome, email: minimalUserData.email });
        expect(db.query).toHaveBeenCalledTimes(2);
        expect(db.query).toHaveBeenNthCalledWith(2,
            expect.stringContaining("NULL"),
            [minimalUserData.nome, minimalUserData.email, 'hashedMinimalPassword', null, null, undefined, 0]
        );
    });


    it('should return 400 if nome, email, or senha are missing', async () => {
      let response = await request(app).post('/cadastro').send({ email: 'test@example.com', senha: 'password123' });
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Nome, email e senha são obrigatórios.');

      response = await request(app).post('/cadastro').send({ nome: 'Test', senha: 'password123' });
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Nome, email e senha são obrigatórios.');

      response = await request(app).post('/cadastro').send({ nome: 'Test', email: 'test@example.com' });
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Nome, email e senha são obrigatórios.');
    });

    it('should return 400 if password is too short', async () => {
      const response = await request(app)
        .post('/cadastro')
        .send({ ...validUserData, senha: '123' });
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('A senha deve ter pelo menos 6 caracteres.');
    });

    it('should return 400 for invalid email format', async () => {
        const response = await request(app)
            .post('/cadastro')
            .send({ ...validUserData, email: 'invalidemail' });
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('Formato de email inválido.');
    });

    it('should return 400 for invalid CPF format', async () => {
        const response = await request(app)
            .post('/cadastro')
            .send({ ...validUserData, cpf: '12345' });
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('Formato de CPF inválido.');
    });

    it('should return 400 for invalid telefone format', async () => {
        const response = await request(app)
            .post('/cadastro')
            .send({ ...validUserData, telefone: '123' });
        expect(response.status).toBe(400);
        expect(response.body.message).toBe('Formato de telefone inválido.');
    });


    it('should return 409 if email already exists', async () => {
      db.query.mockResolvedValueOnce({ rows: [{ email: 'test@example.com', cpf: 'somecpf' }], rowCount: 1 });

      const response = await request(app)
        .post('/cadastro')
        .send(validUserData);

      expect(response.status).toBe(409);
      expect(response.body.message).toBe('Este email já está cadastrado.');
    });

     it('should return 409 if CPF already exists', async () => {
      db.query.mockResolvedValueOnce({ rows: [{ email: 'other@example.com', cpf: '123.456.789-00' }], rowCount: 1 });

      const response = await request(app)
        .post('/cadastro')
        .send(validUserData);

      expect(response.status).toBe(409);
      expect(response.body.message).toBe('Este CPF já está cadastrado.');
    });

    it('should handle database error during registration (userExists check)', async () => {
      db.query.mockRejectedValueOnce(new Error('DB error on userExists'));
      bcrypt.hash.mockResolvedValue('hashedPassword'); // bcrypt pode ser chamado antes do erro ocorrer, dependendo da rota.

      const response = await request(app)
        .post('/cadastro')
        .send(validUserData);

      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar cadastrar.');
    });

    it('should handle database error during registration (insert user)', async () => {
      db.query
        .mockResolvedValueOnce({ rows: [] }) // userExists is fine
        .mockRejectedValueOnce(new Error('DB error on insert')); // Error on second query (insert)
      bcrypt.hash.mockResolvedValue('hashedPassword');

      const response = await request(app)
        .post('/cadastro')
        .send(validUserData);

      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar cadastrar.');
    });
  });

  describe('POST /login', () => {
    const loginCredentials = {
      email: 'test@example.com',
      senha: 'password123',
    };

    it('should login successfully and return a token for an athlete with a trainer', async () => {
      const mockUser = {
        id: 'userId1',
        nome: 'Test User',
        email: 'test@example.com',
        senha_hash: 'hashedPassword', // A rota irá comparar 'password123' com isso
        tipo_usuario: 0, // Atleta
      };
      const mockTrainerLink = { id_treinador: 'trainerId1' };
      const mockTrainerDetails = { id: 'trainerId1', nome: 'Arthur Treinador', telefone: '+5531975004496' };

      db.query
        .mockResolvedValueOnce({ rows: [mockUser], rowCount: 1 })      // Find user by email
        .mockResolvedValueOnce({ rows: [mockTrainerLink], rowCount: 1 }) // Find trainer link for athlete
        .mockResolvedValueOnce({ rows: [mockTrainerDetails], rowCount: 1 }); // Find trainer details

      bcrypt.compare.mockResolvedValue(true); // Senha correta
      jwt.sign.mockReturnValue('mockAuthToken');

      const response = await request(app)
        .post('/login')
        .send(loginCredentials);

      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Login bem-sucedido!');
      expect(response.body.token).toBe('mockAuthToken');
      expect(response.body.usuario).toEqual({ id: 'userId1', nome: 'Test User', email: 'test@example.com', isAtleta: true });
      expect(response.body.treinador).toEqual({ id: 'trainerId1', nome: 'Arthur Treinador', telefone: '+5531975004496' });
      expect(jwt.sign).toHaveBeenCalledWith(
        { id: 'userId1', email: 'test@example.com', nome: 'Test User', isAtleta: true },
        'testsecret',
        { expiresIn: '1h' }
      );
    });

    it('should login successfully for an athlete whose linked trainer is not found in usuarios table', async () => {
        const mockUser = {
            id: 'userId1',
            nome: 'Test User',
            email: 'test@example.com',
            senha_hash: 'hashedPassword',
            tipo_usuario: 0,
        };
        const mockTrainerLink = { id_treinador: 'nonExistentTrainerId' };

        db.query
            .mockResolvedValueOnce({ rows: [mockUser], rowCount: 1 })          // Find user
            .mockResolvedValueOnce({ rows: [mockTrainerLink], rowCount: 1 })  // Find trainer link
            .mockResolvedValueOnce({ rows: [], rowCount: 0 });                 // Trainer details not found in usuarios table

        bcrypt.compare.mockResolvedValue(true);
        jwt.sign.mockReturnValue('mockAuthToken');

        const response = await request(app)
            .post('/login')
            .send(loginCredentials);

        expect(response.status).toBe(200);
        expect(response.body.treinador).toEqual({ id: null, nome: null, telefone: null });
    });

    it('should login successfully for an athlete without a linked trainer', async () => {
      const mockUser = {
        id: 'userId2',
        nome: 'Athlete NoTrainer',
        email: 'athlete_nt@example.com',
        senha_hash: 'hashedPassword',
        tipo_usuario: 0, // Atleta
      };

      db.query
        .mockResolvedValueOnce({ rows: [mockUser], rowCount: 1 }) // Find user by email
        .mockResolvedValueOnce({ rows: [], rowCount: 0 });       // No trainer link found in atleta_treinador

      bcrypt.compare.mockResolvedValue(true);
      jwt.sign.mockReturnValue('mockAuthTokenNoTrainer');

      const response = await request(app)
        .post('/login')
        .send({ email: 'athlete_nt@example.com', senha: 'password123' });

      expect(response.status).toBe(200);
      expect(response.body.token).toBe('mockAuthTokenNoTrainer');
      expect(response.body.usuario.isAtleta).toBe(true);
      expect(response.body.treinador).toEqual({ id: null, nome: null, telefone: null });
    });


    it('should return 400 if email or senha are missing', async () => {
      let response = await request(app).post('/login').send({ email: 'test@example.com' });
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Email e senha são obrigatórios.');
      
      response = await request(app).post('/login').send({ senha: 'password123' });
      expect(response.status).toBe(400);
      expect(response.body.message).toBe('Email e senha são obrigatórios.');
    });

    it('should return 401 if email not found', async () => {
      db.query.mockResolvedValueOnce({ rows: [], rowCount: 0 }); // No user found

      const response = await request(app)
        .post('/login')
        .send(loginCredentials);

      expect(response.status).toBe(401);
      expect(response.body.message).toBe('Email não encontrado.');
    });

    it('should return 401 for incorrect password', async () => {
      const mockUser = { id: 'userId1', email: 'test@example.com', senha_hash: 'hashedPassword' };
      db.query.mockResolvedValueOnce({ rows: [mockUser], rowCount: 1 });
      bcrypt.compare.mockResolvedValue(false); // Password doesn't match

      const response = await request(app)
        .post('/login')
        .send(loginCredentials);

      expect(response.status).toBe(401);
      expect(response.body.message).toBe('Senha incorreta.');
    });

    it('should return 500 if JWT_SECRET is not configured', async () => {
        const originalSecret = process.env.JWT_SECRET; // Salva o original
        process.env.JWT_SECRET = ''; // Simula ausência
        
        const mockUser = { id: 'userId1', email: 'test@example.com', senha_hash: 'hashedPassword', tipo_usuario: 0 };
        db.query
          .mockResolvedValueOnce({ rows: [mockUser], rowCount: 1 })  // Find user
          .mockResolvedValueOnce({ rows: [], rowCount: 0 });        // No trainer link (assumindo atleta)
        bcrypt.compare.mockResolvedValue(true);         // Password match

        const response = await request(app)
            .post('/login')
            .send(loginCredentials);

        expect(response.status).toBe(500);
        expect(response.body.message).toBe('Erro interno de configuração do servidor.');
        
        process.env.JWT_SECRET = originalSecret; // Restaura para outros testes
    });

    it('should handle database error during login (fetching user)', async () => {
      db.query.mockRejectedValueOnce(new Error('DB login error - fetch user'));

      const response = await request(app)
        .post('/login')
        .send(loginCredentials);

      expect(response.status).toBe(500);
      expect(response.body.message).toBe('Erro interno no servidor ao tentar fazer login.');
    });

    it('should handle database error during login (fetching trainer link)', async () => {
        const mockUser = { id: 'userId1', email: 'test@example.com', senha_hash: 'hashedPassword', tipo_usuario: 0 };
        db.query
            .mockResolvedValueOnce({ rows: [mockUser], rowCount: 1 }) // User fetch OK
            .mockRejectedValueOnce(new Error('DB login error - fetch trainer link')); // Error na busca do link do treinador
        bcrypt.compare.mockResolvedValue(true);

        const response = await request(app)
            .post('/login')
            .send(loginCredentials);

        expect(response.status).toBe(500);
        expect(response.body.message).toBe('Erro interno no servidor ao tentar fazer login.');
    });

    it('should handle database error during login (fetching trainer details)', async () => {
        const mockUser = { id: 'userId1', nome: 'Test User', email: 'test@example.com', senha_hash: 'hashedPassword', tipo_usuario: 0 };
        const mockTrainerLink = { id_treinador: 'trainerId1' };
        db.query
            .mockResolvedValueOnce({ rows: [mockUser], rowCount: 1 })          // User fetch OK
            .mockResolvedValueOnce({ rows: [mockTrainerLink], rowCount: 1 }) // Trainer link OK
            .mockRejectedValueOnce(new Error('DB login error - fetch trainer details')); // Error na busca dos detalhes do treinador
        bcrypt.compare.mockResolvedValue(true);

        const response = await request(app)
            .post('/login')
            .send(loginCredentials);

        expect(response.status).toBe(500);
        expect(response.body.message).toBe('Erro interno no servidor ao tentar fazer login.');
    });
  });
});