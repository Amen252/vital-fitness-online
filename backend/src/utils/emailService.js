const nodemailer = require('nodemailer');

let transporter;

function isEmailConfigured() {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
}

function getTransporter() {
  if (transporter) return transporter;

  if (!isEmailConfigured()) {
    return null;
  }

  const port = Number(process.env.SMTP_PORT || 587);
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  return transporter;
}

function getFromAddress() {
  return process.env.EMAIL_FROM || process.env.SMTP_USER || 'noreply@vitalfitness.app';
}

async function sendEmail({ to, subject, text, html }) {
  const transport = getTransporter();

  if (!transport) {
    console.log(`[EMAIL] (simulated)\nTo: ${to}\nSubject: ${subject}\n${text}`);
    return { simulated: true };
  }

  return transport.sendMail({
    from: getFromAddress(),
    to,
    subject,
    text,
    html,
  });
}

async function sendCoachApplicationApprovedEmail(user) {
  const appName = 'VitalFitness';
  const displayName = user.full_name || user.name || user.username || 'there';
  const recipient = user.username || user.email;
  if (!recipient) {
    return { skipped: true };
  }
  const subject = `${appName} — Coach Application Approved`;
  const text = [
    `Hi ${displayName},`,
    '',
    'Great news! Your coach application has been approved.',
    '',
    'Please sign out and sign back in to access your coach dashboard.',
    '',
    'Welcome to the VitalFitness coaching team!',
    '',
    `— ${appName}`,
  ].join('\n');

  const html = `
    <p>Hi <strong>${displayName}</strong>,</p>
    <p>Great news! Your coach application has been <strong>approved</strong>.</p>
    <p>Please <strong>sign out and sign back in</strong> to access your coach dashboard.</p>
    <p>Welcome to the VitalFitness coaching team!</p>
    <p>— ${appName}</p>
  `;

  return sendEmail({ to: recipient, subject, text, html });
}

async function sendCoachApplicationRejectedEmail(user) {
  const appName = 'VitalFitness';
  const displayName = user.full_name || user.name || user.username || 'there';
  const recipient = user.username || user.email;
  if (!recipient) {
    return { skipped: true };
  }
  const subject = `${appName} — Coach Application Update`;
  const text = [
    `Hi ${displayName},`,
    '',
    'Thank you for applying to become a coach at VitalFitness.',
    '',
    'After reviewing your application, we are unable to approve it at this time.',
    '',
    'You can update your information and reapply from the app, or continue using VitalFitness as a member.',
    '',
    `— ${appName}`,
  ].join('\n');

  const html = `
    <p>Hi <strong>${displayName}</strong>,</p>
    <p>Thank you for applying to become a coach at VitalFitness.</p>
    <p>After reviewing your application, we are unable to approve it <strong>at this time</strong>.</p>
    <p>You can update your information and <strong>reapply from the app</strong>, or continue using VitalFitness as a member.</p>
    <p>— ${appName}</p>
  `;

  return sendEmail({ to: recipient, subject, text, html });
}

module.exports = {
  sendEmail,
  sendCoachApplicationApprovedEmail,
  sendCoachApplicationRejectedEmail,
  isEmailConfigured,
};
