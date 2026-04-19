require('dotenv').config();;                     // Carrega variáveis de ambiente

const { Pool } = require('pg');

const pool = new Pool({                          // Cria pool de conexão com o DB PostgreSQL
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_DATABASE,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

pool.on('connect', () => {
  console.log('Cliente conectado ao pool do PostgreSQL!');
});

// Encerra a aplicação em caso de erro no pool
pool.on('error', (err, client) => {
  console.error('Erro inesperado no cliente do pool ocioso', err);
  process.exit(-1);
});

// Exporta uma função query para usar o pool facilmente
module.exports = {
  query: (text, params) => pool.query(text, params),
  pool: pool
};

console.log(`Tentando conectar ao DB: ${process.env.DB_USER}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_DATABASE}`);
