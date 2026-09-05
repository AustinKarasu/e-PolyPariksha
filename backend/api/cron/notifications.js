const { processTestNotifications } = require('../../src/services/notification.service');

module.exports = async (req, res) => {
  const isVercelCron = req.headers['x-vercel-cron'] === '1';
  if (!isVercelCron && req.headers['authorization'] !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  try {
    await processTestNotifications();
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  } catch (error) {
    console.error('Cron notification sweep failed:', error.message);
    res.status(500).json({ error: 'Notification sweep failed', message: error.message });
  }
};
