const mockQuery = jest.fn();

module.exports = {
  query: mockQuery,
  pool: {
    query: mockQuery
  }
};