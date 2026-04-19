const express = require('express');
const authenticateToken = require('../middleware/auth');

// Importa nosso módulo de banco de dados
const db = require('../db');

const router = express.Router();

//Rota para retornar todos os esportes
router.get('/esportes', authenticateToken, async (req, res) => {
    try {
        // Busca todos os eventos do banco de dados
        const result = await db.query('SELECT * FROM esportes ORDER BY id ASC');
        const esportes = result.rows;

        res.status(200).json(esportes);
    } catch (error) {
        console.error('Erro ao buscar esportes:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar buscar esportes.' });
    }
})

router.post('/vincular', authenticateToken, async (req, res) => {
    const { id_usuario, convite } = req.body; // Obtém o id_usuario da query string

    try {
        const result = await db.query('SELECT id_treinador FROM treinador_convite WHERE convite = $1', [convite]);
        const conviteResult = result.rows[0];

        if (!conviteResult) {
            return res.status(404).json({ message: 'Convite não encontrado.' });
        }

        const checkExising = await db.query('SELECT * FROM atleta_treinador WHERE id_atleta = $1 AND id_treinador = $2', [id_usuario, conviteResult.id_treinador]);

        if (checkExising.rowCount > 0) {
            return res.status(400).json({ message: 'Vínculo com o treinador já realizado' });
        }

        const insertQuery = `INSERT INTO atleta_treinador 
        (id_atleta, id_treinador)
        VALUES ($1, $2)`;

        const values = [id_usuario, conviteResult.id_treinador];
        await db.query(insertQuery, values);

        const queryTreinador = 'SELECT nome, telefone FROM usuarios where id = $1';
        const valuesTreinador = [conviteResult.id_treinador];
        const resultTreinador = await db.query(queryTreinador, valuesTreinador);
        const treinador = resultTreinador.rows[0];

        res.status(200).json({
            message: 'Vinculo criado com sucesso!',
            id_atleta: id_usuario,
            id_treinador: conviteResult.id_treinador, // Retorna o id do treinador vinculado
            treinador: {
                id_treinador: conviteResult.id_treinador,
                nome: treinador.nome,
                telefone: treinador.telefone
            }
        });
    } catch (error) {
        console.error('Erro ao tentar vincular:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar vincular treinador e atleta.' });
    }
})

router.post('/convite', authenticateToken, async (req, res) => {
    const { id_usuario } = req.body; // Obtém o id_usuario da query string
    const convite = await gerarCodigoUnico(); // Gera um código único para o convite

    try {
        const insertQuery = `INSERT INTO treinador_convite 
        (id_treinador, convite)
        VALUES ($1, $2)`;

        const values = [id_usuario, convite];
        const result = await db.query(insertQuery, values);

        if (result.rowCount === 0) {
            return res.status(500).json({ message: 'Erro ao criar convite' });
        }

        res.status(200).json({
            message: 'Convite criado com sucesso!',
            convite: convite // Retorna o código do convite gerado
        });
    } catch (error) {
        console.error('Erro ao tentar vincular:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar vincular treinador e atleta.' });
    }
})

router.get('/treinador/atletas/:idTreinador', authenticateToken, async (req, res) => {

    const id = req.params.idTreinador;
    const query = 'SELECT u.id, u.nome, u.email, u.telefone, u.cpf, u.data_nascimento FROM usuarios AS u INNER JOIN atleta_treinador AS at ON u.id = at.id_atleta WHERE at.id_treinador = $1'
    const values = [id];

    try {
        // Busca todos os eventos do banco de dados
        const result = await db.query(query, values);
        const atletas = result.rows;

        res.status(200).json(atletas);
    } catch (error) {
        console.error('Erro ao buscar atletas:', error);
        res.status(500).json({ message: 'Erro interno no servidor ao tentar buscar atletas.' });
    }

})  

function gerarCodigoUnico() {
    const agora = Date.now().toString(); // Timestamp atual em milissegundos
    let hash = 0;
  
    for (let i = 0; i < agora.length; i++) {
      const char = agora.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash |= 0; // Converte pra inteiro 32-bit
    }
  
    // Transforma o hash em hexadecimal e garante que seja positivo
    const codigo = Math.abs(hash).toString(16).padStart(8, '0');
  
    return codigo;
}

module.exports = router;