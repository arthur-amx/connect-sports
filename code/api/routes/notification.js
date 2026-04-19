const express = require("express");
const router = express.Router();
const amqp = require("amqplib");
const axios = require("axios");

const RABBITMQ_URL = process.env.RABBITMQ_URL || "amqp://rabbitmq";
const QUEUE = process.env.QUEUE || "notificacao";
const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_API_KEY = process.env.ONESIGNAL_API_KEY;

// --- Funções Auxiliares ---

async function sendPushToUser(userId, title, message) {
  try {
    await axios.post(
      "https://onesignal.com/api/v1/notifications",
      {
        app_id: ONESIGNAL_APP_ID,
        include_external_user_ids: [String(userId)],
        headings: { en: title },
        contents: { en: message },
      },
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${ONESIGNAL_API_KEY}`,
        },
      }
    );
    console.log("Notificação OneSignal enviada para:", userId);
  } catch (err) {
    console.error("Erro ao enviar notificação OneSignal:", err.response?.data || err.message);
  }
}

async function consumeNotification() {
  let conn;
  try {
    conn = await amqp.connect(RABBITMQ_URL);
    const channel = await conn.createChannel();
    await channel.assertQueue(QUEUE, { durable: true });
    
    console.log("Aguardando mensagens na fila:", QUEUE);
    channel.consume(QUEUE, async (msg) => {
      if (msg !== null) {
        try {
          const data = JSON.parse(msg.content.toString());
          await sendPushToUser(data.userId, data.title, data.message);
        } finally {
          channel.ack(msg);
        }
      }
    });
  } catch (error) {
    console.error("Erro no consumidor RabbitMQ:", error.message);
    if (conn) await conn.close(); // Fecha a conexão em caso de erro na inicialização
  }
}

async function publishNotification(userId, title, message) {
  let conn;
  try {
    conn = await amqp.connect(RABBITMQ_URL);
    const channel = await conn.createChannel();
    await channel.assertQueue(QUEUE, { durable: true });
    const payload = { userId, title, message };
    channel.sendToQueue(QUEUE, Buffer.from(JSON.stringify(payload)), { persistent: true });
    await channel.close();
  } catch (error) {
    console.error("Erro ao publicar no RabbitMQ:", error.message);
    throw error; // Re-lança o erro para ser tratado pela rota
  } finally {
    if (conn) await conn.close(); // Garante que a conexão seja sempre fechada
  }
}

// --- Rota ---

router.post("/enviar", async (req, res) => {
  const { userId, title, message } = req.body;
  if (!userId || !title || !message) {
    return res.status(400).json({ message: "userId, title, e message são obrigatórios." });
  }
  try {
    await publishNotification(userId, title, message);
    // Em um app real, o consumidor rodaria de forma independente.
    // Para o teste, iniciamos ele aqui para verificar o fluxo completo.
    consumeNotification();
    res.status(200).json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message || "Falha ao publicar notificação." });
  }
});

// Exporta o router e a função para ser usada em outros locais, como `fichas.js`
module.exports = { router, publishNotification };