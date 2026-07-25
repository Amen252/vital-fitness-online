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

    if (req.user.status === 'suspended') {
      return res.status(403).json({ message: 'This account has been suspended. Please contact support.' });
    }

    // Force password change check
    if (req.user.must_change_password) {
      const allowedPaths = ['/change-password', '/logout', '/me', '/auth/change-password', '/auth/logout', '/auth/me'];
      const isAllowed = allowedPaths.some(path => req.originalUrl.includes(path));
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
