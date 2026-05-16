const request = require('supertest');
const app = require('../src/app');

describe('Health Check', () => {
  it('GET /health returns 200 with status healthy', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body).toHaveProperty('uptime');
  });
});

describe('GET /api/items', () => {
  it('returns array of items', async () => {
    const res = await request(app).get('/api/items');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(3);
    expect(res.body[0]).toHaveProperty('id');
    expect(res.body[0]).toHaveProperty('name');
    expect(res.body[0]).toHaveProperty('price');
  });
});

describe('GET /api/items/:id', () => {
  it('returns a single item by id', async () => {
    const res = await request(app).get('/api/items/1');
    expect(res.status).toBe(200);
    expect(res.body.name).toBe('Widget A');
  });

  it('returns 404 for non-existent item', async () => {
    const res = await request(app).get('/api/items/999');
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Item not found');
  });

  it('returns 400 for invalid id', async () => {
    const res = await request(app).get('/api/items/abc');
    expect(res.status).toBe(400);
  });
});

describe('POST /api/items', () => {
  it('creates a new item', async () => {
    const res = await request(app)
      .post('/api/items')
      .send({ name: 'Widget D', price: 39.99 });
    expect(res.status).toBe(201);
    expect(res.body.name).toBe('Widget D');
    expect(res.body).toHaveProperty('id');
  });

  it('rejects missing name', async () => {
    const res = await request(app)
      .post('/api/items')
      .send({ price: 10 });
    expect(res.status).toBe(400);
  });

  it('rejects missing price', async () => {
    const res = await request(app)
      .post('/api/items')
      .send({ name: 'Foo' });
    expect(res.status).toBe(400);
  });
});

describe('404 fallback', () => {
  it('returns 404 for unknown routes', async () => {
    const res = await request(app).get('/nonexistent');
    expect(res.status).toBe(404);
  });
});
