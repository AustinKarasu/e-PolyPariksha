const fs = require('fs/promises');
const path = require('path');
const nodemailer = require('nodemailer');
const { env } = require('../config/env');
const { query } = require('../config/db');

const logoPath = path.resolve(__dirname, '../../assets/polyht_logo.png');

function mailer() {
  if (!env.smtp.host || !env.smtp.user || !env.smtp.pass || !env.smtp.from) return null;
  return nodemailer.createTransport({
    host: env.smtp.host,
    port: env.smtp.port,
    secure: env.smtp.secure,
    auth: { user: env.smtp.user, pass: env.smtp.pass }
  });
}

function escape(value) {
  return String(value || '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
}

function formatDate(value) {
  return new Intl.DateTimeFormat('en-IN', { dateStyle: 'full', timeStyle: 'short', timeZone: 'Asia/Kolkata' }).format(new Date(value));
}

function emailHtml({ heading, intro, test, action, footer = 'Please keep this email for your records.' }) {
  const details = test ? `
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;background:#f5f8fc;border:1px solid #dce5f0">
      <tr><td style="padding:14px 16px;color:#334155;font-size:14px"><strong>Exam</strong><br>${escape(test.title)}</td></tr>
      <tr><td style="padding:0 16px 14px;color:#334155;font-size:14px"><strong>Branch and semester</strong><br>${escape(test.branch_name)} | Semester ${escape(test.semester)}</td></tr>
      <tr><td style="padding:0 16px 14px;color:#334155;font-size:14px"><strong>Start</strong><br>${formatDate(test.scheduled_start)}</td></tr>
      <tr><td style="padding:0 16px 14px;color:#334155;font-size:14px"><strong>End</strong><br>${formatDate(test.scheduled_end)}</td></tr>
      <tr><td style="padding:0 16px 14px;color:#334155;font-size:14px"><strong>Duration</strong><br>${escape(test.time_limit_minutes)} minutes</td></tr>
    </table>` : '';
  return `<!doctype html><html><body style="margin:0;background:#eef3f8;font-family:Arial,sans-serif;color:#1e293b">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td align="center" style="padding:28px 12px">
      <table role="presentation" width="620" cellspacing="0" cellpadding="0" style="max-width:620px;background:#fff;border:1px solid #dce5f0">
        <tr><td style="padding:22px 28px;background:#103b72;color:#fff"><strong style="font-size:20px">e-PolyPariksha HP</strong><br><span style="font-size:13px">Examination notification</span></td></tr>
        <tr><td style="padding:28px"><h1 style="margin:0 0 14px;font-size:22px">${escape(heading)}</h1><p style="margin:0 0 20px;line-height:1.55">${escape(intro)}</p>${details}${action ? `<p style="margin:22px 0 0;line-height:1.55">${escape(action)}</p>` : ''}<p style="margin:22px 0 0;color:#64748b;font-size:13px;line-height:1.5">${escape(footer)}</p></td></tr>
        <tr><td align="center" style="padding:18px;border-top:1px solid #e2e8f0"><img src="cid:epolypariksha-logo" width="54" height="54" alt="e-PolyPariksha HP"><div style="margin-top:7px;color:#64748b;font-size:12px">e-PolyPariksha HP</div></td></tr>
      </table>
    </td></tr></table></body></html>`;
}

async function attachments(pdf) {
  const files = [];
  try { files.push({ filename: 'e-polypariksha-hp-logo.png', path: logoPath, cid: 'epolypariksha-logo' }); } catch (_) {}
  if (pdf?.pdf_data) {
    files.push({ filename: pdf.pdf_original_name || `exam-${pdf.id}.pdf`, content: Buffer.from(pdf.pdf_data), contentType: pdf.pdf_mime_type || 'application/pdf' });
  } else if (pdf?.pdf_path) {
    try { files.push({ filename: pdf.pdf_original_name || `exam-${pdf.id}.pdf`, content: await fs.readFile(pdf.pdf_path), contentType: pdf.pdf_mime_type || 'application/pdf' }); } catch (_) {}
  }
  return files;
}

async function recipientsForTest(test) {
  const students = await query(
    `SELECT email FROM users WHERE role = 'student' AND is_active = TRUE AND email IS NOT NULL
     AND branch_id = $1 AND semester = $2 AND (created_by_admin_id IS NULL OR created_by_admin_id = $3)`,
    [test.branch_id, test.semester, test.created_by]
  );
  const admins = await query(`SELECT email FROM users WHERE role = 'admin' AND is_active = TRUE AND email IS NOT NULL`);
  return { students: students.map((row) => row.email), admins: admins.map((row) => row.email) };
}

async function markAndSend({ eventType, test, email, subject, html, includePdf = false }) {
  const key = `${eventType}:${test?.id || 'app'}:${String(email).toLowerCase()}`;
  const marked = await query(
    `INSERT INTO email_notifications (event_key, event_type, test_id, recipient_email)
     VALUES ($1, $2, $3, $4) ON CONFLICT (event_key) DO NOTHING RETURNING id`,
    [key, eventType, test?.id || null, email]
  );
  if (!marked[0]) return false;
  const transport = mailer();
  if (!transport) return false;
  try {
    await transport.sendMail({ from: env.smtp.from, to: email, subject, html, attachments: await attachments(includePdf ? test : null) });
    return true;
  } catch (error) {
    await query('DELETE FROM email_notifications WHERE event_key = $1', [key]);
    console.error('Notification email failed', error.message);
    return false;
  }
}

async function notifyTest(test, eventType) {
  const { students, admins } = await recipientsForTest(test);
  const copy = {
    scheduled: ['Test scheduled', 'A new examination has been scheduled for your branch and semester.', 'Please review the date, time, and duration below and be ready before the start time.'],
    started: ['Test has started', 'Your scheduled examination is now live.', 'Open e-PolyPariksha HP to begin the examination before the end time.'],
    ended: ['Test has ended', 'The examination window has now closed.', 'The question paper is attached for your records.'],
    cancelled: ['Test cancelled', 'This examination has been cancelled and will not take place.', 'You do not need to take any action. We will notify you when a new relevant test is scheduled or starts.']
  }[eventType];
  if (!copy) return;
  const [heading, intro, action] = copy;
  const studentHtml = emailHtml({ heading, intro, test, action });
  const adminHtml = emailHtml({ heading: `${heading}: ${test.title}`, intro: `A ${eventType} notification was sent to eligible students in ${test.branch_name}, Semester ${test.semester}.`, test, action: eventType === 'ended' ? 'The question paper is attached for your records.' : eventType === 'cancelled' ? 'Eligible students have been told that the test is cancelled and that future relevant test updates will be sent.' : 'This notification applies only to eligible students.' });
  await Promise.allSettled([
    ...students.map((email) => markAndSend({ eventType: `student_${eventType}`, test, email, subject: `e-PolyPariksha HP: ${heading}`, html: studentHtml, includePdf: eventType === 'ended' })),
    ...admins.map((email) => markAndSend({ eventType: `admin_${eventType}`, test, email, subject: `e-PolyPariksha HP: ${heading}`, html: adminHtml, includePdf: eventType === 'ended' }))
  ]);
}

async function notifyAppUpdate(version, actingAdminId) {
  const admins = await query(`SELECT email FROM users WHERE role = 'admin' AND is_active = TRUE AND email IS NOT NULL`);
  const students = await query(`SELECT email FROM users WHERE role = 'student' AND is_active = TRUE AND email IS NOT NULL`);
  const html = emailHtml({ heading: 'App update available', intro: `e-PolyPariksha HP version ${version} is now available.`, action: 'Open the app and use the update option when prompted.' });
  await Promise.allSettled(admins.map((row) => markAndSend({ eventType: `app_update_${version}`, email: row.email, subject: 'e-PolyPariksha HP: App update available', html })));
  await Promise.allSettled(students.map((row) => markAndSend({ eventType: `student_app_update_${version}`, email: row.email, subject: 'e-PolyPariksha HP: App update available', html })));
  return { notifiedBy: actingAdminId, version };
}

async function notifySecurityEvent(user, event, detail) {
  if (!user?.email) return;
  const labels = {
    password_changed: 'Password changed',
    two_factor_enabled: 'Two-factor authentication enabled',
    two_factor_disabled: 'Two-factor authentication disabled',
    biometric_enabled: 'Biometric sign-in enabled',
    biometric_disabled: 'Biometric sign-in disabled'
  };
  const heading = labels[event] || 'Account security updated';
  const html = emailHtml({ heading, intro: `A security setting was changed for your e-PolyPariksha HP account${detail ? `: ${detail}` : '.'}`, action: 'If you did not make this change, change your password and contact your institution immediately.' });
  await markAndSend({ eventType: `${event}_${Date.now()}`, email: user.email, subject: `e-PolyPariksha HP: ${heading}`, html });
}

async function processTestNotifications() {
  const scheduled = await query(`SELECT t.*, b.name AS branch_name FROM tests t JOIN branches b ON b.id = t.branch_id WHERE t.deleted_at IS NULL AND t.is_active = TRUE AND t.created_at > CURRENT_TIMESTAMP - INTERVAL '30 days'`);
  for (const test of scheduled) {
    if (new Date(test.scheduled_end) <= new Date()) await notifyTest(test, 'ended');
    else if (new Date(test.scheduled_start) <= new Date()) await notifyTest(test, 'started');
  }
}

module.exports = { notifyTest, notifyAppUpdate, notifySecurityEvent, processTestNotifications };
