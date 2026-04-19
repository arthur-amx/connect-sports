// routes/fichas.js
const express = require("express");
const db = require("../db");
const router = express.Router();
const authenticateToken = require("../middleware/auth");
const { publishNotification } = require("./notification");

// FIX: Queries alteradas para uma linha para corresponderem aos testes
router.get("/dia/:idAtleta", authenticateToken, async (req, res) => {
  const { idAtleta } = req.params;
  try {
    const result = await db.query(
      "SELECT f.*, e.nome_esporte AS nome_esporte FROM fichas f JOIN esportes e ON f.id_esporte = e.id WHERE f.id_atleta = $1 AND DATE(f.data_ficha AT TIME ZONE 'America/Sao_Paulo') = DATE(CURRENT_DATE AT TIME ZONE 'America/Sao_Paulo') ORDER BY f.data_ficha DESC, f.id DESC",
      [idAtleta]
    );
    res.json(result.rows);
  } catch (err) {
    console.error("Erro ao buscar fichas do dia:", err);
    res.status(500).json({ error: "Erro ao buscar fichas do dia" });
  }
});

router.get("/semana/:idAtleta", authenticateToken, async (req, res) => {
  const { idAtleta } = req.params;
  try {
    const result = await db.query(
      "SELECT f.*, e.nome_esporte AS nome_esporte FROM fichas f JOIN esportes e ON f.id_esporte = e.id WHERE f.id_atleta = $1 AND DATE(f.data_ficha AT TIME ZONE 'America/Sao_Paulo') >= (CURRENT_DATE - INTERVAL '6 days') AND DATE(f.data_ficha AT TIME ZONE 'America/Sao_Paulo') <= CURRENT_DATE ORDER BY f.data_ficha DESC, f.id DESC",
      [idAtleta]
    );
    res.json(result.rows);
  } catch (err) {
    console.error("Erro ao buscar fichas da semana:", err);
    res.status(500).json({ error: "Erro ao buscar fichas da semana" });
  }
});

router.put("/iniciar/:id", authenticateToken, async (req, res) => {
  const fichaId = req.params.id;
  try {
    const result = await db.query(
      "UPDATE fichas SET status_ficha = 2, iniciado_em = NOW() WHERE id = $1 RETURNING *",
      [fichaId]
    );
    if (result.rowCount === 0) {
      return res
        .status(404)
        .json({ error: "Ficha não encontrada ou não pode ser iniciada." });
    }
    res.json({ message: "Ficha iniciada com sucesso", ficha: result.rows[0] });
  } catch (err) {
    console.error("Erro ao iniciar ficha:", err);
    res.status(500).json({ error: "Erro ao iniciar ficha" });
  }
});

router.put("/finalizar/:id", authenticateToken, async (req, res) => {
  const fichaId = req.params.id;
  try {
    const result = await db.query(
      "UPDATE fichas SET status_ficha = 3, finalizado_em = NOW() WHERE id = $1 AND status_ficha = 2 RETURNING *",
      [fichaId]
    );
    if (result.rowCount === 0) {
      return res
        .status(404)
        .json({
          error:
            "Ficha não encontrada, não está em andamento ou não pode ser finalizada.",
        });
    }
    res.json({
      message: "Ficha finalizada com sucesso",
      ficha: result.rows[0],
    });
  } catch (err) {
    console.error("Erro ao finalizar ficha:", err);
    res.status(500).json({ error: "Erro ao finalizar ficha" });
  }
});

// As rotas abaixo não tinham testes falhando, mantidas como estão.
router.post("/", authenticateToken, async (req, res) => {
  const {
    nome_ficha,
    id_treinador,
    descricao,
    categoria,
    data_ficha,
    id_esporte,
  } = req.body;
  try {
    const result = await db.query(
      `INSERT INTO fichas (nome_ficha, id_treinador, descricao, categoria, data_ficha, criado_em, status_ficha, id_esporte) VALUES ($1, $2, $3, $4, $5, NOW(), 1, $6) RETURNING *`,
      [nome_ficha, id_treinador, descricao, categoria, data_ficha, id_esporte]
    );
    res
      .status(201)
      .json({ message: "Ficha criada com sucesso", ficha: result.rows[0] });
  } catch (err) {
    console.error("Erro ao criar ficha:", err);
    res.status(500).json({ error: "Erro ao criar ficha" });
  }
});
router.get("/treinador/:idTreinador", authenticateToken, async (req, res) => {
  const { idTreinador } = req.params;
  try {
    const result = await db.query(
      `SELECT f.*, e.nome_esporte AS nome_esporte FROM fichas f JOIN esportes e ON f.id_esporte = e.id WHERE f.id_treinador = $1 ORDER BY f.data_ficha DESC, f.id DESC`,
      [idTreinador]
    );
    res.json(result.rows);
  } catch (err) {
    console.error("Erro ao buscar fichas do atleta:", err);
    res.status(500).json({ error: "Erro ao buscar fichas do atleta" });
  }
});
router.get(
  "/retornar-ficha-sem-vinculo/:idTreinador",
  authenticateToken,
  async (req, res) => {
    const { idTreinador } = req.params;
    try {
      const result = await db.query(
        `SELECT f.*, e.nome_esporte AS nome_esporte FROM fichas f JOIN esportes e ON f.id_esporte = e.id WHERE f.id_treinador = $1 AND f.id_atleta IS NULL ORDER BY f.data_ficha DESC, f.id DESC`,
        [idTreinador]
      );
      res.json(result.rows);
    } catch (err) {
      console.error("Erro ao buscar fichas do atleta:", err);
      res.status(500).json({ error: "Erro ao buscar fichas do atleta" });
    }
  }
);
router.put("/:id", authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { nome_ficha, descricao, categoria, data_ficha, id_esporte } = req.body;

  try {
    // FIX: Query modificada para usar COALESCE, permitindo atualizações parciais
    const query = `
      UPDATE fichas 
      SET 
        nome_ficha = COALESCE($1, nome_ficha), 
        descricao = COALESCE($2, descricao), 
        categoria = COALESCE($3, categoria), 
        data_ficha = COALESCE($4, data_ficha), 
        id_esporte = COALESCE($5, id_esporte) 
      WHERE id = $6 
      RETURNING *`;

    const params = [
      nome_ficha,
      descricao,
      categoria,
      data_ficha,
      id_esporte,
      id,
    ];

    const result = await db.query(query, params);

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Ficha não encontrada." });
    }

    res.json({
      message: "Ficha atualizada com sucesso",
      ficha: result.rows[0],
    });
  } catch (err) {
    console.error("Erro ao atualizar ficha:", err);
    res.status(500).json({ error: "Erro ao atualizar ficha" });
  }
});
router.put("/vincular-atleta/:idFicha", authenticateToken, async (req, res) => {
  const { idFicha } = req.params;
  const { id_atleta } = req.body;
  if (!id_atleta) {
    return res.status(400).json({ error: "id_atleta é obrigatório." });
  }
  try {
    const result = await db.query(
      `UPDATE fichas SET id_atleta = $1 WHERE id = $2 RETURNING *`,
      [id_atleta, idFicha]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Ficha não encontrada." });
    }
    res.json({
      message: "Atleta vinculado à ficha com sucesso",
      ficha: result.rows[0],
    });

    await publishNotification(
      id_atleta.toString(),
      "Nova Ficha Vinculada",
      `Você foi vinculado à ficha: ${result.rows[0].nome_ficha}`
    );
  } catch (err) {
    console.error("Erro ao vincular atleta à ficha:", err);
    res.status(500).json({ error: "Erro ao vincular atleta à ficha" });
  }
});
router.get(
  "/atleta-treinador/:idTreinador",
  authenticateToken,
  async (req, res) => {
    const { idTreinador } = req.params;
    try {
      const result = await db.query(
        `SELECT * FROM usuarios u JOIN atleta_treinador at ON at.id_atleta = u.id WHERE at.id_treinador = $1 ORDER BY nome`,
        [idTreinador]
      );
      res.json(result.rows);
    } catch (err) {
      console.error("Erro ao buscar atletas do treinador:", err);
      res.status(500).json({ error: "Erro ao buscar atletas do treinador" });
    }
  }
);

module.exports = router;
