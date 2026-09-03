const { query } = require('../src/config/db');

module.exports = async (req, res) => {
  try {
    const cleared = await query('DELETE FROM login_failures');
    const students = await query(
      'SELECT id, full_name, email, college_id, roll_no, board_roll_no, dob, is_active, must_change_credentials FROM users WHERE role = $1',
      ['student']
    );
    res.json({
      status: 'ok',
      message: 'Lockouts cleared',
      studentsCount: students.length,
      students
    });
  } catch (err) {
    res.status(500).json({ error: err.message, stack: err.stack });
  }
};
