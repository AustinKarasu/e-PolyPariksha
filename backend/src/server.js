const app = require('./app');
const { env } = require('./config/env');
const { processTestNotifications } = require('./services/notification.service');

if (require.main === module) {
  app.listen(env.port, () => {
    console.log(`e-PolyPariksha HP API listening on port ${env.port}`);
  });
  processTestNotifications().catch((error) => console.error('Test notification sweep failed', error.message));
  setInterval(() => {
    processTestNotifications().catch((error) => console.error('Test notification sweep failed', error.message));
  }, 30 * 1000).unref();
}

// Export for Vercel serverless
module.exports = app;
