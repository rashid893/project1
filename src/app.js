const express = require('express');
const { createLogger, format, transports } = require('winston');

const app = express();
app.use(express.json());

// --- Logger ---
const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: format.combine(
    format.timestamp(),
    format.json()
  ),
  transports: [new transports.Console()],
});

// --- Health check ---
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    version: process.env.APP_VERSION || 'unknown',
    environment: process.env.NODE_ENV || 'development',
    uptime: process.uptime(),
  });
});

// --- API routes ---
app.get('/api/items', (req, res) => {
  logger.info('GET /api/items');
  res.json([
    { id: 1, name: 'Widget A', price: 9.99 },
    { id: 2, name: 'Widget B', price: 19.99 },
    { id: 3, name: 'Widget C', price: 29.99 },
  ]);
});

app.get('/api/items/:id', (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (isNaN(id) || id < 1) {
    return res.status(400).json({ error: 'Invalid item ID' });
  }
  const items = {
    1: { id: 1, name: 'Widget A', price: 9.99 },
    2: { id: 2, name: 'Widget B', price: 19.99 },
    3: { id: 3, name: 'Widget C', price: 29.99 },
  };
  const item = items[id];
  if (!item) {
    return res.status(404).json({ error: 'Item not found' });
  }
  res.json(item);
});

app.post('/api/items', (req, res) => {
  const { name, price } = req.body;
  if (!name || typeof price !== 'number') {
    return res.status(400).json({ error: 'name (string) and price (number) required' });
  }
  logger.info('POST /api/items', { name, price });
  res.status(201).json({ id: Date.now(), name, price });
});

// --- 404 fallback ---
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// --- Error handler ---
app.use((err, req, res, _next) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;
