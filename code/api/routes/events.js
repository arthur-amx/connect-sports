// routes/events.js

const express = require('express');
const db = require('../db');
const router = express.Router();
const authenticateToken = require('../middleware/auth');

// POST /cadastro/:id_usuario
router.post('/cadastro/:id_usuario', authenticateToken, async (req, res) => {
    let { nome_evento, tipo_evento, data_evento, descricao, status_evento } = req.body;
    const { id_usuario } = req.params;

    if (!nome_evento) return res.status(400).json({ message: 'nome_evento é obrigatório.' });
    if (!tipo_evento) return res.status(400).json({ message: 'tipo_evento é obrigatório.' });
    if (!descricao) return res.status(400).json({ message: 'descricao é obrigatória.' });
    
    if (status_evento === undefined || status_evento === null) {
        status_evento = 1;
    }

    try {
        let query, params;
        if (data_evento) {
            query = `INSERT INTO eventos (nome_evento, tipo_evento, data_evento, descricao, status_evento, criado_por) VALUES ($1, $2, to_timestamp($3, 'DD/MM/YYYY HH24:MI:SS'), $4, $5, $6) RETURNING *`;
            const dateTime = data_evento.includes(' ') ? data_evento : `${data_evento} 00:00:00`;
            params = [nome_evento, tipo_evento, dateTime, descricao, status_evento, id_usuario];
        } else {
            query = `INSERT INTO eventos (nome_evento, tipo_evento, descricao, status_evento, criado_por) VALUES ($1, $2, $3, $4, $5) RETURNING *`;
            params = [nome_evento, tipo_evento, descricao, status_evento, id_usuario];
        }
        const result = await db.query(query, params);
        return res.status(201).json({ message: 'Evento criado com sucesso!', evento: result.rows[0] });
    } catch (error) {
        console.error('Erro ao criar evento:', error);
        return res.status(500).json({ message: 'Erro interno no servidor ao tentar criar evento.' });
    }
});

// GET /:id_usuario
router.get('/:id_usuario', authenticateToken, async (req, res) => {
    const { id_usuario } = req.params;
    try {
        const result = await db.query(`SELECT e.id, e.nome_evento, e.tipo_evento, e.data_evento, e.descricao, e.criado_por, es.nome_esporte AS tipo_evento_nome, CASE WHEN ae.id_atleta IS NOT NULL THEN 1 ELSE 0 END AS atleta_vinculado FROM eventos e JOIN esportes es ON e.tipo_evento = es.id LEFT JOIN atleta_evento ae ON e.id = ae.id_evento AND ae.id_atleta = $1 WHERE e.status_evento = 1 ORDER BY e.data_evento DESC NULLS LAST`, [id_usuario]);
        res.status(200).json(result.rows);
    } catch (error) {
        console.error('Erro ao buscar eventos:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar buscar eventos.' });
    }
});

// GET /retornar/:id
router.get('/retornar/:id', authenticateToken, async (req, res) => {
    const eventoId = req.params.id;
    try {
        const result = await db.query('SELECT * FROM eventos WHERE id = $1', [eventoId]);
        if (result.rows.length === 0) return res.status(404).json({ message: 'Evento não encontrado.' });
        res.status(200).json(result.rows[0]);
    } catch (error) {
        console.error('Erro ao buscar evento:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar buscar evento.' });
    }
});

// GET /retornar/usuario/:id_usuario
router.get('/retornar/usuario/:id_usuario', authenticateToken, async (req, res) => {
    const { id_usuario } = req.params;
    try {
        // FIX: Removido o comentário SQL que quebrava o teste
        const query = `SELECT e.id, e.nome_evento, e.tipo_evento, e.data_evento, e.descricao, es.nome_esporte AS tipo_evento_nome, 1 AS atleta_vinculado FROM eventos e JOIN esportes es ON e.tipo_evento = es.id JOIN atleta_evento ae ON e.id = ae.id_evento WHERE ae.id_atleta = $1 AND e.status_evento = 1 ORDER BY e.data_evento DESC NULLS LAST`;
        const result = await db.query(query, [id_usuario]);
        res.status(200).json(result.rows);
    } catch (error) {
        console.error('Erro ao buscar eventos do usuário:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar buscar eventos.' });
    }
});

// DELETE /deletar/:id
router.delete('/deletar/:id', authenticateToken, async (req, res) => {
    const eventoId = req.params.id;
    try {
        const result = await db.query('UPDATE eventos SET status_evento = 0 WHERE id = $1 RETURNING *', [eventoId]);
        if (result.rowCount === 0) return res.status(404).json({ message: 'Evento não encontrado.' });
        res.status(200).json({ message: 'Evento desativado com sucesso!', eventoDeletado: result.rows[0] });
    } catch (error) {
        console.error('Erro ao desativar evento:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar desativar evento.' });
    }
});

// POST /vincular/:id
router.post('/vincular/:id', authenticateToken, async (req, res) => {
    const eventoId = req.params.id;
    const { id_usuario } = req.body;
    if (!id_usuario) {
        return res.status(400).json({ message: 'id_usuario (do atleta) é obrigatório no corpo da requisição.' });
    }
    try {
        const result = await db.query('INSERT INTO atleta_evento (id_atleta, id_evento) VALUES ($1, $2) RETURNING *', [id_usuario, eventoId]);
        res.status(201).json({ message: 'Vínculo criado com sucesso!', vinculo: result.rows[0] });
    } catch (error) {
        console.error('Erro ao criar vínculo:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar criar vínculo.' });
    }
});

// PUT /desvincular/:id
router.put('/desvincular/:id', authenticateToken, async (req, res) => {
    const eventoId = req.params.id;
    const { id_usuario } = req.body;
    if (!id_usuario) {
        return res.status(400).json({ message: 'id_usuario (do atleta) é obrigatório no corpo da requisição.' });
    }
    try {
        const result = await db.query('DELETE FROM atleta_evento WHERE id_atleta = $1 AND id_evento = $2 RETURNING *', [id_usuario, eventoId]);
        if (result.rowCount === 0) return res.status(404).json({ message: 'Vínculo não encontrado para este usuário e evento.' });
        res.status(200).json({ message: 'Vínculo deletado com sucesso!', vinculoDeletado: result.rows[0] });
    } catch (error) {
        console.error('Erro ao deletar vínculo:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar deletar vínculo.' });
    }
});

// PUT /alterar/:id
router.put('/alterar/:id', authenticateToken, async (req, res) => {
    const eventoId = req.params.id;
    const { nome_evento, tipo_evento, data_evento, descricao, status_evento } = req.body;

    // Apenas valida se o nome não é uma string vazia, permitindo que outros campos sejam nulos para atualização parcial
    if (nome_evento === '') return res.status(400).json({ message: 'Nome do evento não pode ser vazio.'});

    // FIX: Removida a validação estrita dos outros campos para permitir COALESCE
    
    try {
        let dateTime = data_evento;
        if (data_evento && !data_evento.includes(' ')) {
            dateTime = `${data_evento} 00:00:00`;
        }

        const query = `UPDATE eventos SET nome_evento = COALESCE($1, nome_evento), tipo_evento = COALESCE($2, tipo_evento), data_evento = COALESCE(to_timestamp($3, 'DD/MM/YYYY HH24:MI:SS'), data_evento), descricao = COALESCE($4, descricao), status_evento = COALESCE($5, status_evento) WHERE id = $6 RETURNING *`;
        const params = [nome_evento, tipo_evento, dateTime, descricao, status_evento, eventoId];
        
        const result = await db.query(query, params);
        
        if (result.rowCount === 0) return res.status(404).json({ message: 'Evento não encontrado.' });

        res.status(200).json({ message: 'Evento atualizado com sucesso!', eventoAtualizado: result.rows[0] });
    } catch (error) {
        console.error('Erro ao atualizar evento:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar atualizar evento.' });
    }
});

module.exports = router;