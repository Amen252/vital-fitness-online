const Article = require('../models/Article');

async function getArticles(req, res) {
  const articles = await Article.find({ isPublished: true }).sort({ createdAt: -1 });
  return res.json(articles);
}

module.exports = { getArticles };
