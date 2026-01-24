const express = require('express');
const router = express.Router();
const dataSource = require('../services/dataSource');

router.get('/', async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = 5;
    const skip = (page - 1) * limit;
    
    const allProducts = await dataSource.getAll();
    const total = allProducts.length;
    const products = allProducts.slice(skip, skip + limit);
    const totalPages = Math.ceil(total / limit);
    
    res.render('index', { 
      products, 
      pagination: {
        page,
        limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1
      },
      hostname: require('os').hostname(), 
      source: dataSource.isMongo ? 'mongodb' : 'in-memory' 
    });
  } catch (err) { next(err); }
});

module.exports = router;
