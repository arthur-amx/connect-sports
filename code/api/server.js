require('dotenv').config();                     // Carrega variáveis de ambiente

const express = require("express");
const cors = require("cors");
const db = require('./db');                     // Importa o módulo db (para garantir que o pool conecte)
const authRoutes = require("./routes/auth"); 
const eventRoutes = require("./routes/events")   // Importa as rotas de autenticação
const utilsRoutes = require("./routes/utils")   // Importa as rotas de autenticação
const feedbackRoutes = require('./routes/feedbacks');
const indicadoresRoute = require('./routes/indicadores')
const fichasRoute = require('./routes/fichas')
const notificationRoute = require('./routes/notification') // Importa as rotas de notificação

const app = express();

// Middleware para permitir CORS (Ajustar as opções se precisar de mais controle - 
// TODO: Verificar itens de segurança inclusos no projeto - semana do dia 23/03)
app.use(cors());

// Middleware para interpretar JSON
app.use(express.json());

// Montar as rotas de autenticação sob o prefixo /api/auth
app.use("/api/auth", authRoutes);
app.use("/api/eventos", eventRoutes); // Monta as rotas de eventos sob o prefixo /api/eventos
app.use("/api/utils", utilsRoutes); // Monta as rotas de utils sob o prefixo /api/utils
app.use("/api/indicadores", indicadoresRoute)
app.use('/api', feedbackRoutes);
app.use('/api/fichas', fichasRoute);
app.use('/api/notification', notificationRoute.router); // Monta as rotas de notificação sob o prefixo /api/notification


// Rota raiz para verificar se a API está online (opcional)
app.get("/", (req, res) => {
    res.send("API Connect Sports está no ar! Use /api/auth para login/cadastro.");
});

// Middleware para tratar rotas não encontradas (404) - Opcional, mas bom ter
app.use((req, res, next) => {
    res.status(404).json({ message: "Rota não encontrada." });
});

// Middleware de tratamento de erros genérico (Opcional, mas bom ter)
app.use((err, req, res, next) => {
    console.error("Erro não tratado:", err.stack);
    res.status(500).json({ message: "Ocorreu um erro interno no servidor." });
});


// Iniciar o servidor
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => { // Escuta em 0.0.0.0 para ser acessível fora do container
    console.log(`Servidor rodando em http://35.175.176.59:${PORT} (dentro do host)`);
    console.log(`Servidor escutando na porta ${PORT} dentro do container`);
    db.query('SELECT NOW()', (err, res) => {
        if (err) {
            console.error("!!! Falha ao conectar ao banco de dados no início:", err);
        } else {
            console.log(">>> Conexão com banco de dados verificada com sucesso:", res.rows[0].now);
        }
    });
});

