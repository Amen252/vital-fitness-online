const express = require('express');
const { getArticles } = require('../controllers/contentController');

const router = express.Router();

router.get('/articles', getArticles);

module.exports = router;
