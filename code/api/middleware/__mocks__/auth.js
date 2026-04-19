module.exports = jest.fn((req, res, next) => {
  req.user = { id: 'mockUserId', nome: 'Mock User', email: 'mock@example.com', tipo_usuario: 0 }; // 0 para atleta
  next();
});