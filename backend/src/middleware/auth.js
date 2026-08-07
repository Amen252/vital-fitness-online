const jwt = require('jsonwebtoken');
const User = require('../models/User');

async function auth(req, res, next) {
  const header = req.headers.authorization;
  let token = header?.startsWith('Bearer ') ? header.split(' ')[1] : null;

  if (!token && req.cookies) {
    token = req.cookies.token;
  }

  if (!token) {
    return res.status(401).json({ message: 'Authentication required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'dev-secret');
    req.user = await User.findById(decoded.id);

    if (!req.user) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    if (req.user.status === 'suspended' || req.user.status === 'deleted') {
      return res.status(403).json({
        message: req.user.status === 'deleted'
          ? 'This account has been deleted.'
          : 'This account has been suspended. Please contact support.',
      });
    }

    // Force password change check — match path segments, not substrings
    // (avoids '/me' matching '/api/admin/meals').
    if (req.user.must_change_password) {
      const pathname = String(req.originalUrl || req.url || '').split('?')[0];
      const allowedExact = new Set([
        '/api/auth/me',
        '/api/auth/logout',
        '/api/auth/change-password',
        '/api/admin/me',
        '/api/admin/logout',
        '/api/admin/change-password',
        '/api/user/profile',
      ]);
      const allowedSuffixes = ['/change-password', '/logout', '/auth/me', '/auth/logout', '/auth/change-password'];
      const isAllowed =
        allowedExact.has(pathname)
        || allowedSuffixes.some((suffix) => pathname === suffix || pathname.endsWith(suffix));
      if (!isAllowed) {
        return res.status(403).json({
          message: 'Password change required on first login',
          code: 'PASSWORD_CHANGE_REQUIRED',
        });
      }
    }

    return next();
  } catch (error) {
    return res.status(401).json({ message: 'Authentication required' });
  }
}

module.exports = auth;
