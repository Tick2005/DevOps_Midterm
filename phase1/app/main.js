require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const os = require('os');
const productRoutes = require('./routes/productRoutes');
const dataSource = require('./services/dataSource');
const uiRoutes = require('./routes/uiRoutes');
const path = require('path');
const fs = require('fs'); 

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// view engine and static
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');
app.use(express.static(path.join(__dirname, 'public')));

app.use('/', uiRoutes);
app.use('/products', productRoutes);

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

async function start() {
  // Đảm bảo thư mục uploads tồn tại
  const uploadsDir = path.join(__dirname, 'public', 'uploads');
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
    console.log(`Created uploads directory at ${uploadsDir}`);
  }

  // Try to connect to MongoDB Atlas with extended timeout (30 seconds)
  const mongoUri = process.env.MONGODB_URI || process.env.MONGO_URI || 'mongodb://localhost:27017/products_db';
  let usingMongo = false;
  
  console.log('Attempting to connect to MongoDB Atlas...');
  console.log('Using URI:', mongoUri.replace(/:[^:@]+@/, ':***@')); // Hide password in log
  
  try {
    await mongoose.connect(mongoUri, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      serverSelectionTimeoutMS: 30000,  // 30 seconds for Atlas cloud connection
      connectTimeoutMS: 30000,           // 30 seconds to establish connection
      socketTimeoutMS: 45000,            // 45 seconds for socket operations
      family: 4                          // Force IPv4 (sometimes IPv6 causes issues)
    });
    usingMongo = true;
    console.log('✓ Successfully connected to MongoDB Atlas — using mongodb as data source.');
  } catch (err) {
    usingMongo = false;
    console.log('✗ Failed to connect to MongoDB Atlas — falling back to in-memory database.');
    console.log('Connection error:', err.message);
    console.log('Reason:', err.reason?.message || 'Unknown');
  }

  await dataSource.init(usingMongo);

  app.listen(PORT, HOST, () => {
    console.log(`✓ Server running on http://${HOST}:${PORT} — hostname: ${os.hostname()}`);
    console.log(`✓ Data source in use: ${dataSource.isMongo ? 'mongodb' : 'in-memory'}`);
    console.log(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
  });
}

start();

module.exports = app;
