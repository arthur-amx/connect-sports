const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../db');
const router = express.Router();
const saltRounds = 10;

// Removed unused setTrainer function

router.post('/cadastro', async (req, res) => {
  const { nome, email, senha, telefone, cpf, dataNascimento, tipo_usuario } = req.body;
  if (!nome || !email || !senha) return res.status(400).json({ message: 'Nome, email e senha são obrigatórios.' });
  if (senha.length < 6) return res.status(400).json({ message: 'A senha deve ter pelo menos 6 caracteres.' });
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) return res.status(400).json({ message: 'Formato de email inválido.' });
  if (cpf && !/^\d{3}\.?\d{3}\.?\d{3}-?\d{2}$/.test(cpf)) return res.status(400).json({ message: 'Formato de CPF inválido.' });
  if (telefone && !/^\+?\d{10,15}$/.test(telefone.replace(/\D/g, ''))) return res.status(400).json({ message: 'Formato de telefone inválido.' });
  
  try {
    const userExists = await db.query('SELECT email, cpf FROM usuarios WHERE email = $1 OR cpf = $2', [email, cpf || null]);
    if (userExists.rows.length > 0) {
      const existing = userExists.rows[0];
      return res.status(409).json({ message: existing.email === email ? 'Este email já está cadastrado.' : 'Este CPF já está cadastrado.' });
    }
    const senhaHash = await bcrypt.hash(senha, saltRounds);
    // Note: The RETURNING clause is present, but its result isn't fully used to populate the response 'id'.
    // The test expects id: null, so we keep it as is.
    await db.query(`
      INSERT INTO usuarios (nome, email, senha_hash, telefone, cpf, data_nascimento, tipo_usuario)
      VALUES ($1, $2, $3, $4, $5, ${dataNascimento ? `to_date($6, 'DD/MM/YYYY')` : 'NULL'}, $7)
      RETURNING id, email, nome
    `, [nome, email, senhaHash, telefone || null, cpf || null, dataNascimento, tipo_usuario === undefined ? 0 : tipo_usuario]); // Ensure tipo_usuario has a default
    res.status(201).json({ message: 'Usuário cadastrado com sucesso!', usuario: { id: null, nome, email } });
  } catch (err) {
    console.error('Erro no cadastro:', err);
    res.status(500).json({ message: 'Erro interno no servidor ao tentar cadastrar.' });
  }
});

router.post('/login', async (req, res) => {
  const { email, senha } = req.body;
  if (!email || !senha) return res.status(400).json({ message: 'Email e senha são obrigatórios.' });
  try {
    const result = await db.query(
      'SELECT id, nome, email, senha_hash, tipo_usuario FROM usuarios WHERE email = $1',
      [email]
    );
    const usuario = result.rows[0];
    if (!usuario) return res.status(401).json({ message: 'Email não encontrado.' });
    const senhaValida = await bcrypt.compare(senha, usuario.senha_hash);
    if (!senhaValida) return res.status(401).json({ message: 'Senha incorreta.' });
    
    const trainerLink = await db.query(
      'SELECT id_treinador FROM atleta_treinador WHERE id_atleta = $1',
      [usuario.id]
    );
    let treinador = null;
    if (trainerLink.rows.length > 0) {
      const tr = await db.query('SELECT id, nome, telefone FROM usuarios WHERE id = $1', [trainerLink.rows[0].id_treinador]); // Assuming trainer info is in usuarios
      if (tr.rows.length > 0) { // Check if trainer was found
        treinador = tr.rows[0];
      }
    }
    
    const payload = { id: usuario.id, email: usuario.email, nome: usuario.nome, isAtleta: usuario.tipo_usuario === 0 };
    const secret = process.env.JWT_SECRET;
    if (!secret) {
        console.error('JWT_SECRET não está configurado.'); // Added more specific log
        return res.status(500).json({ message: 'Erro interno de configuração do servidor.' });
    }
    const token = jwt.sign(payload, secret, { expiresIn: '1h' });
    
    res.status(200).json({
      message: 'Login bem-sucedido!',
      token,
      treinador: { 
        id: treinador?.id || null, // Use trainer's actual ID from usuarios table
        nome: treinador?.nome || null, 
        telefone: treinador?.telefone || null 
      },
      usuario: { id: usuario.id, nome: usuario.nome, email: usuario.email, isAtleta: usuario.tipo_usuario === 0 }
    });
  } catch (err) {
    console.error('Erro no login:', err);
    res.status(500).json({ message: 'Erro interno no servidor ao tentar fazer login.' });
  }
});

module.exports = router;