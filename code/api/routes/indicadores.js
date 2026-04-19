// routes/indicadores.js
const express = require('express');
const authenticateToken = require('../middleware/auth');
const db = require('../db');
const router = express.Router();

// ... (funções auxiliares mantidas como estão)
function calcularTempoTreino(inicio, fim) {
    if (!inicio || !fim) return 0;
    const inicioData = new Date(inicio);
    const fimData = new Date(fim);
    return Math.max(0, (fimData.getTime() - inicioData.getTime()) / 1000); // em segundos
}
function getElapsedTime(fichas) {
    let tempoTotalTreinoSegundos = 0;
    const tempoPorFicha = fichas.map(ficha => {
        const { id, iniciado_em, finalizado_em } = ficha;
        const tempoTreinoSegundos = calcularTempoTreino(iniciado_em, finalizado_em);
        tempoTotalTreinoSegundos += tempoTreinoSegundos;
        return { id: id, duracaoMinutos: Math.round(tempoTreinoSegundos / 60) };
    });
    return { tempoTotalTreinoMinutos: Math.round(tempoTotalTreinoSegundos / 60), tempoPorFicha: tempoPorFicha };
}
function getPorcentagemConcluida(fichas) {
    if (!fichas || fichas.length === 0) return { percentual: 0 };
    const fichasTotais = fichas.length;
    const fichasConcluidas = fichas.filter(ficha => ficha.status_ficha === 3).length;
    const percentual = (fichasConcluidas / fichasTotais) * 100;
    return { percentual: Math.round(percentual) };
}
function formatarTempo(segundos) {
    const horas = Math.floor(segundos / 3600);
    const minutos = Math.floor((segundos % 3600) / 60);
    return `${horas}h ${minutos}min`;
}

// FIX: Queries alteradas para uma linha para corresponderem aos testes
router.get('/treinos/:idUsuario', authenticateToken, async (req, res) => {
    const { idUsuario } = req.params;
    const dataAtual = new Date();
    const dataInicio = new Date(dataAtual.getFullYear(), dataAtual.getMonth(), dataAtual.getDate(), 0, 0, 0, 0);
    const dataFim = new Date(dataAtual.getFullYear(), dataAtual.getMonth(), dataAtual.getDate(), 23, 59, 59, 999);

    try {
        const result = await db.query("SELECT id, data_ficha, status_ficha FROM fichas WHERE data_ficha >= $1 AND data_ficha <= $2 AND id_atleta = $3 ORDER BY data_ficha DESC", [dataInicio.toISOString(), dataFim.toISOString(), idUsuario]);
        const treinos = result.rows;
        const percentualData = getPorcentagemConcluida(treinos);
        res.status(200).json(percentualData);
    } catch (error) {
        console.error('Erro ao buscar treinos (percentual):', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar buscar treinos.' });
    }
});

router.get('/tempoTreino/:idUsuario', authenticateToken, async (req, res) => {
    const { idUsuario } = req.params;
    const dataAtual = new Date();
    const dataInicio = new Date(dataAtual.getFullYear(), dataAtual.getMonth(), dataAtual.getDate(), 0, 0, 0, 0);
    const dataFim = new Date(dataAtual.getFullYear(), dataAtual.getMonth(), dataAtual.getDate(), 23, 59, 59, 999);

    try {
        const result = await db.query("SELECT id, iniciado_em, finalizado_em FROM fichas WHERE data_ficha >= $1 AND data_ficha <= $2 AND id_atleta = $3 AND status_ficha = 3", [dataInicio.toISOString(), dataFim.toISOString(), idUsuario]);
        const treinos = result.rows;
        const tempoData = getElapsedTime(treinos);
        res.status(200).json(tempoData);
    } catch (error) {
        console.error('Erro ao buscar tempo de treino:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar buscar treinos.' });
    }
});

router.get('/treinosSemana/:idUsuario', authenticateToken, async (req, res) => {
    const { idUsuario } = req.params;
    try {
        const today = new Date();
        const dayOfWeek = today.getDay(); 
        const firstDayEpoch = new Date(today);
        firstDayEpoch.setDate(today.getDate() - (dayOfWeek === 0 ? 6 : dayOfWeek - 1));
        firstDayEpoch.setHours(0, 0, 0, 0);

        const lastDayEpoch = new Date(firstDayEpoch);
        lastDayEpoch.setDate(firstDayEpoch.getDate() + 6);
        lastDayEpoch.setHours(23, 59, 59, 999);

        const result = await db.query("SELECT TO_CHAR(data_ficha AT TIME ZONE 'UTC', 'YYYY-MM-DD') AS dia, COUNT(*) AS total_treinos FROM fichas WHERE data_ficha BETWEEN $1 AND $2 AND id_atleta = $3 AND status_ficha = 3 GROUP BY dia ORDER BY dia", [firstDayEpoch.toISOString(), lastDayEpoch.toISOString(), idUsuario]);
        res.status(200).json(result.rows);
    } catch (error) {
        console.error('Erro ao buscar treinos na semana:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar buscar treinos na semana.' });
    }
});

router.get('/progressoMensal/:idUsuario', authenticateToken, async (req, res) => {
    const { idUsuario } = req.params;
    const anoAtual = new Date().getFullYear();

    try {
        const result = await db.query("SELECT data_ficha, iniciado_em, finalizado_em FROM fichas WHERE EXTRACT(YEAR FROM data_ficha AT TIME ZONE 'UTC') = $1 AND id_atleta = $2 AND status_ficha = 3", [anoAtual, idUsuario]);
        const fichas = result.rows;
        const tempoPorMesSegundos = Array(12).fill(0);

        fichas.forEach(ficha => {
            const { data_ficha, iniciado_em, finalizado_em } = ficha;
            if (iniciado_em && finalizado_em) {
                const mes = new Date(data_ficha).getUTCMonth();
                tempoPorMesSegundos[mes] += calcularTempoTreino(iniciado_em, finalizado_em);
            }
        });

        const valoresFormatados = tempoPorMesSegundos.map(segundos => formatarTempo(segundos));
        res.status(200).json({ valores: valoresFormatados });
    } catch (error) {
        console.error('Erro ao buscar progresso mensal:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar buscar progresso mensal.' });
    }
});

module.exports = router;