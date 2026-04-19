const express = require('express');
const router = express.Router();
const pool = require('../db');
const authenticateToken = require('../middleware/auth');

router.post('/feedbacks', authenticateToken, async (req, res) => {
    const id_atleta = req.user.id;
    const { tipo_feedback, texto_feedback } = req.body;

    if (!tipo_feedback || !texto_feedback || texto_feedback.trim() === '') {
        return res.status(400).json({ message: 'Tipo e texto do feedback são obrigatórios.' });
    }
    const parsedTipoFeedback = parseInt(tipo_feedback, 10);
    if (isNaN(parsedTipoFeedback) || ![1, 2].includes(parsedTipoFeedback)) {
        return res.status(400).json({ message: 'Tipo de feedback inválido.' });
    }

    try {
        const treinadorResult = await pool.query('SELECT id_treinador FROM atleta_treinador WHERE id_atleta = $1', [id_atleta]);
        if (treinadorResult.rows.length === 0) {
            return res.status(404).json({ message: 'Atleta não vinculado a um treinador.' });
        }
        const id_treinador = treinadorResult.rows[0].id_treinador;

        const insertResult = await pool.query("INSERT INTO feedbacks (id_atleta, id_treinador, tipo_feedback, texto_feedback) VALUES ($1, $2, $3, $4) RETURNING id, id_treinador", [id_atleta, id_treinador, parsedTipoFeedback, texto_feedback.trim()]);
        res.status(201).json({
            message: 'Feedback enviado com sucesso!',
            feedbackId: insertResult.rows[0].id,
            id_treinador: insertResult.rows[0].id_treinador,
        });
    } catch (error) {
        console.error('Erro ao salvar feedback:', error);
        res.status(500).json({ message: 'Erro interno do servidor ao salvar feedback.' });
    }
});

router.get('/feedbacks', authenticateToken, async (req, res) => {
    const id_treinador = req.user.id;
    try {
        const feedbackResult = await pool.query("SELECT f.id, f.id_atleta, u.nome AS nome_atleta, f.tipo_feedback, f.texto_feedback, f.data_envio, f.status_feedback FROM feedbacks f JOIN usuarios u ON f.id_atleta = u.id WHERE f.id_treinador = $1 ORDER BY f.data_envio DESC", [id_treinador]);
        res.status(200).json(feedbackResult.rows);
    } catch (error) {
        console.error('Erro ao buscar feedbacks:', error);
        res.status(500).json({ message: 'Erro interno do servidor ao buscar feedbacks.' });
    }
});

router.patch('/feedbacks/:id/status', authenticateToken, async (req, res) => {
    const id_treinador = req.user.id;
    const feedbackId = parseInt(req.params.id, 10);
    const { status } = req.body;

    if (isNaN(feedbackId)) {
        return res.status(400).json({ message: 'ID de feedback inválido.' });
    }
    const parsedStatus = parseInt(status, 10);
    if (isNaN(parsedStatus) || ![0, 1].includes(parsedStatus)) {
        return res.status(400).json({ message: 'Status inválido. Use 0 (não lido) ou 1 (lido).' });
    }

    try {
        const updateResult = await pool.query("UPDATE feedbacks SET status_feedback = $1 WHERE id = $2 AND id_treinador = $3 RETURNING id", [parsedStatus, feedbackId, id_treinador]);
        if (updateResult.rowCount === 0) {
            return res.status(404).json({ message: 'Feedback não encontrado ou não pertence a este treinador.' });
        }
        res.status(200).json({ message: 'Status do feedback atualizado com sucesso.', feedback: updateResult.rows[0] });
    } catch (error) {
        console.error('Erro ao atualizar status do feedback:', error);
        res.status(500).json({ message: 'Erro interno do servidor ao atualizar status.' });
    }
});

module.exports = router;