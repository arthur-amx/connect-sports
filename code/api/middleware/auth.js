const jwt = require('jsonwebtoken');

// Obtém a chave secreta do ambiente
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error('⚠️ JWT_SECRET não configurado em process.env');
  // Caso queira, lance aqui um erro para interromper o server
}

function authenticateToken(req, res, next) {
  // 1) Captura o header Authorization ("Bearer <token>")
  const authHeader = req.headers['authorization'] || req.headers['Authorization'];
  if (!authHeader) {
    return res.status(401).json({ message: 'Token não fornecido.' });
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(400).json({ message: 'Formato de token inválido. Use "Bearer <token>".' });
  }

  const token = parts[1];

  // 2) Verifica/decodifica o token
  jwt.verify(token, JWT_SECRET, (err, payload) => {
    if (err) {
      // Token expirado ou inválido
      return res.status(403).json({ message: 'Token inválido ou expirado.' });
    }

    // 3) Popula req.user com o payload que você incluiu no login
    //    Por exemplo: { id, email, nome, isAtleta }
    req.user = {
      id: payload.id,
      email: payload.email,
      nome: payload.nome,
      isAtleta: payload.isAtleta,
    };

    // 4) Avança para o próximo handler
    next();
  });
}

module.exports = authenticateToken;
