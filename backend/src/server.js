const app = require('./app');
const { env } = require('./config/env');

if (require.main === module) {
  app.listen(env.port, () => {
    console.log(`e-PolyPariksha HP API listening on port ${env.port}`);
  });
}

// Export for Vercel serverless
module.exports = app;
