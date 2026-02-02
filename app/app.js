const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Root health check (for ALB target group)
app.get('/', (req, res) => {
  res.status(200).json({
    status: 'ok',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});
// Health check
app.get('/v2/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Versioned API endpoint
app.get('/v2/hello', (req, res) => {
  res.json({
    message: 'Hello from v2 API 👋'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
