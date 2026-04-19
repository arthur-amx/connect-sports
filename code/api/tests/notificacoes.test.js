jest.mock('amqplib');
jest.mock('axios');

const request = require('supertest');
const express = require('express');
const amqp = require('amqplib');
const axios = require('axios');

const { router: notificacoesRouter } = require('../routes/notification');

describe('Notificacoes Routes', () => {
  let app;
  let mockChannel;
  let mockConnection;
  let consoleErrorSpy;
  let consoleLogSpy; // Adicionado spy para o console.log

  beforeEach(() => {
    jest.clearAllMocks();

    // Silencia o console.error e console.log durante os testes
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    consoleLogSpy = jest.spyOn(console, 'log').mockImplementation(() => {});

    mockChannel = {
      assertQueue: jest.fn().mockResolvedValue(undefined),
      sendToQueue: jest.fn(),
      consume: jest.fn(),
      ack: jest.fn(),
      close: jest.fn().mockResolvedValue(undefined),
    };
    mockConnection = {
      createChannel: jest.fn().mockResolvedValue(mockChannel),
      close: jest.fn().mockResolvedValue(undefined),
    };
    amqp.connect.mockResolvedValue(mockConnection);
    axios.post.mockResolvedValue({ data: {} });

    app = express();
    app.use(express.json());
    app.use('/notificacoes', notificacoesRouter);
  });

  afterEach(() => {
    // Restaura as funções originais do console após cada teste
    consoleErrorSpy.mockRestore();
    consoleLogSpy.mockRestore();
  });

  describe('POST /notificacoes/enviar', () => {
    const notificationPayload = {
      userId: 'user123',
      title: 'Test Title',
      message: 'Test Message',
    };

    it('should handle successful notification publishing', async () => {
      const response = await request(app)
        .post('/notificacoes/enviar')
        .send(notificationPayload);

      expect(response.status).toBe(200);
      expect(response.body).toEqual({ ok: true });
      expect(amqp.connect).toHaveBeenCalled();
      expect(mockChannel.sendToQueue).toHaveBeenCalledTimes(1);
    });

    it('should return 500 if RabbitMQ connection fails', async () => {
      const connectionError = new Error('RabbitMQ connection failed');
      amqp.connect.mockRejectedValueOnce(connectionError);

      const response = await request(app)
        .post('/notificacoes/enviar')
        .send(notificationPayload);
        
      expect(response.status).toBe(500);
      expect(response.body.message).toBe('RabbitMQ connection failed');
    });

    it('should consume a message and call OneSignal', async () => {
      const testMsg = { content: Buffer.from(JSON.stringify(notificationPayload)) };
      mockChannel.consume.mockImplementation((queue, callback) => {
        callback(testMsg);
      });
      
      await request(app).post('/notificacoes/enviar').send(notificationPayload);

      expect(amqp.connect).toHaveBeenCalledTimes(2);
      expect(mockChannel.consume).toHaveBeenCalled();
      expect(axios.post).toHaveBeenCalled();
      expect(mockChannel.ack).toHaveBeenCalledWith(testMsg);
    });
  });
});