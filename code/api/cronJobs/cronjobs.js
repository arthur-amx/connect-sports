const cron = require('node-cron');
const axios = require('axios');
const db = require('../db');
require('dotenv').config(); 

// Função para buscar eventos do dia e notificar usuários
async function notificarEventosDoDia() {
  const hoje = new Date();
  const dataHoje = hoje.toISOString().slice(0, 10); // 'YYYY-MM-DD'

  // 1. Buscar eventos do dia
  const eventos = await db.query(
    `SELECT e.id, e.nome_evento
     FROM eventos e
     WHERE DATE(e.data_evento) = $1`, [dataHoje]
  );

  // 2. Buscar usuários registrados no evento
  for (const evento of eventos.rows) {
    const usuarios = await db.query(
      `SELECT u.id
       FROM atleta_evento ue
       JOIN usuarios u ON u.id = ue.id_atleta
       WHERE ue.id_evento = $1`, [evento.id]
    );
    const userIds = usuarios.rows.map(u => u.id).filter(Boolean);

    if (userIds.length > 0) {
      // 3. Enviar notificação para todos
      try{
        await axios.post('https://onesignal.com/api/v1/notifications', {
            app_id: process.env.ONESIGNAL_APP_ID,
            include_external_user_ids: userIds.map(String), // IDs dos usuários
            headings: { en: "Evento do dia!" },
            contents: { en: `Hoje você tem o evento: ${evento.nome_evento}` },
            small_icon: "ic_stat_notification",
        }, {
            headers: {
            'Content-Type': 'application/json',
            'Authorization': `${process.env.ONESIGNAL_API_KEY}`,
            }
        });

      } catch (error) {
        console.error('Erro ao enviar notificação:', error.response?.data || error.message);
      }
      
    }
  }
}

// Agenda para rodar todo dia às 05:00
cron.schedule('0 6 * * *', notificarEventosDoDia);