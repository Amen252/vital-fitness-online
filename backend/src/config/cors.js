/**
 * Shared CORS origin checks for Express + Socket.IO.
 *
 * Mobile apps usually send no Origin header — those requests are allowed.
 * Set CLIENT_URL and/or ALLOWED_ORIGINS (comma-separated) on Render/Heroku.
 */
function parseOrigins() {
  const fromList = String(process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

  return [
    process.env.CLIENT_URL,
    process.env.PUBLIC_WEB_URL,
    ...fromList,
    'http://localhost:5173',
    'http://127.0.0.1:5173',
    'http://localhost:5174',
    'http://127.0.0.1:5174',
    'http://localhost:3000',
    'http://127.0.0.1:3000',
  ].filter(Boolean);
}

function isAllowedOrigin(origin) {
  if (!origin) return true;

  const allowed = parseOrigins();
  if (allowed.includes(origin)) return true;

  if (
    origin.startsWith('http://localhost:')
    || origin.startsWith('http://127.0.0.1:')
  ) {
    return true;
  }

  // Optional: allow any *.onrender.com / custom preview hosts via ALLOW_RENDER_ORIGINS=true
  if (process.env.ALLOW_RENDER_ORIGINS === 'true') {
    try {
      const host = new URL(origin).hostname;
      if (host.endsWith('.onrender.com')) return true;
    } catch {
      return false;
    }
  }

  return false;
}

module.exports = {
  isAllowedOrigin,
  parseOrigins,
};
