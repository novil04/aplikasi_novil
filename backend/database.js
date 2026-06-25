const mysql = require('mysql2/promise');
require('dotenv').config();

// =====================================================
// DATABASE CONFIGURATION
// =====================================================
// Railway provides different variable names, support multiple formats:
// 1. Railway MySQL Plugin: MYSQL_URL, MYSQLHOST, MYSQLPORT, MYSQLUSER, MYSQLPASSWORD, MYSQLDATABASE
// 2. Custom variables: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
// 3. Standard: DATABASE_URL

// Parse DATABASE_URL if provided (format: mysql://user:password@host:port/database)
let dbConfig = {};

if (process.env.DATABASE_URL) {
  try {
    const url = new URL(process.env.DATABASE_URL);
    dbConfig = {
      host: url.hostname,
      port: parseInt(url.port) || 3306,
      user: url.username,
      password: url.password,
      database: url.pathname.slice(1), // Remove leading '/'
    };
    console.log('📦 Using DATABASE_URL for connection');
  } catch (error) {
    console.error('❌ Error parsing DATABASE_URL:', error.message);
  }
} else if (process.env.MYSQL_URL) {
  try {
    const url = new URL(process.env.MYSQL_URL);
    dbConfig = {
      host: url.hostname,
      port: parseInt(url.port) || 3306,
      user: url.username,
      password: url.password,
      database: url.pathname.slice(1),
    };
    console.log('📦 Using MYSQL_URL for connection');
  } catch (error) {
    console.error('❌ Error parsing MYSQL_URL:', error.message);
  }
} else {
  // Use individual environment variables
  dbConfig = {
    host: process.env.MYSQLHOST || process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.MYSQLPORT || process.env.DB_PORT || '3306'),
    user: process.env.MYSQLUSER || process.env.DB_USER || 'root',
    password: process.env.MYSQLPASSWORD || process.env.DB_PASSWORD || '',
    database: process.env.MYSQLDATABASE || process.env.DB_NAME || 'pengering_ikan',
  };
  console.log('📦 Using individual environment variables for connection');
}

// Add connection pool settings
dbConfig.waitForConnections = true;
dbConfig.connectionLimit = 10;
dbConfig.queueLimit = 0;

// Log configuration (hide password)
console.log('🔧 Database Config:', {
  host: dbConfig.host,
  port: dbConfig.port,
  user: dbConfig.user,
  database: dbConfig.database,
  password: dbConfig.password ? '***' : '(empty)'
});

// Create connection pool
const pool = mysql.createPool(dbConfig);

// Test connection
async function testConnection() {
  try {
    const connection = await pool.getConnection();
    console.log('✅ Database connected successfully');
    connection.release();
    return true;
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    return false;
  }
}

// Initialize database tables
async function initDatabase() {
  try {
    const connection = await pool.getConnection();
    
    // Create sensor_data table
    await connection.query(`
      CREATE TABLE IF NOT EXISTS sensor_data (
        id INT AUTO_INCREMENT PRIMARY KEY,
        suhu FLOAT NOT NULL,
        berat FLOAT NOT NULL,
        target FLOAT NOT NULL,
        relay1 BOOLEAN DEFAULT FALSE,
        relay2 BOOLEAN DEFAULT FALSE,
        relay3 BOOLEAN DEFAULT FALSE,
        relay4 BOOLEAN DEFAULT FALSE,
        status VARCHAR(50) DEFAULT 'DISCONNECTED',
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_timestamp (timestamp)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);
    
    // Create status_history table
    await connection.query(`
      CREATE TABLE IF NOT EXISTS status_history (
        id INT AUTO_INCREMENT PRIMARY KEY,
        message TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_timestamp (timestamp)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);
    
    // Create control_commands table
    await connection.query(`
      CREATE TABLE IF NOT EXISTS control_commands (
        id INT AUTO_INCREMENT PRIMARY KEY,
        command VARCHAR(50) NOT NULL,
        source VARCHAR(50) DEFAULT 'API',
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_timestamp (timestamp)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);
    
    console.log('✅ Database tables initialized');
    connection.release();
    return true;
  } catch (error) {
    console.error('❌ Database initialization failed:', error.message);
    return false;
  }
}

// Insert sensor data
async function insertSensorData(data) {
  try {
    // Convert ISO timestamp to MySQL DATETIME format
    let mysqlTimestamp;
    if (data.timestamp) {
      const date = new Date(data.timestamp);
      mysqlTimestamp = date.toISOString().slice(0, 19).replace('T', ' ');
    } else {
      const date = new Date();
      mysqlTimestamp = date.toISOString().slice(0, 19).replace('T', ' ');
    }
    
    // Convert boolean to integer (1 or 0) for MySQL
    const relay1 = data.relay1 ? 1 : 0;
    const relay2 = data.relay2 ? 1 : 0;
    const relay3 = data.relay3 ? 1 : 0;
    const relay4 = data.relay4 ? 1 : 0;
    
    const [result] = await pool.query(
      `INSERT INTO sensor_data (suhu, berat, target, relay1, relay2, relay3, relay4, status, timestamp) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        data.suhu || 0,
        data.berat || 0,
        data.target || 0,
        relay1,
        relay2,
        relay3,
        relay4,
        data.status || 'DISCONNECTED',
        mysqlTimestamp
      ]
    );
    return result.insertId;
  } catch (error) {
    console.error('❌ Error inserting sensor data:', error.message);
    throw error;
  }
}

// Get latest sensor data
async function getLatestSensorData() {
  try {
    const [rows] = await pool.query(
      `SELECT 
        id, suhu, berat, target, relay1, relay2, relay3, relay4, status,
        CONVERT_TZ(timestamp, '+00:00', '+07:00') as timestamp
       FROM sensor_data 
       ORDER BY timestamp DESC 
       LIMIT 1`
    );
    return rows[0] || null;
  } catch (error) {
    console.error('❌ Error getting latest sensor data:', error.message);
    throw error;
  }
}

// Get sensor data history
async function getSensorDataHistory(limit = 50) {
  try {
    const [rows] = await pool.query(
      `SELECT 
        id, suhu, berat, target, relay1, relay2, relay3, relay4, status,
        CONVERT_TZ(timestamp, '+00:00', '+07:00') as timestamp
       FROM sensor_data 
       ORDER BY timestamp DESC 
       LIMIT ?`,
      [limit]
    );
    return rows;
  } catch (error) {
    console.error('❌ Error getting sensor data history:', error.message);
    throw error;
  }
}

// Insert status history
async function insertStatusHistory(message) {
  try {
    // Convert to MySQL DATETIME format
    const date = new Date();
    const mysqlTimestamp = date.toISOString().slice(0, 19).replace('T', ' ');
    
    const [result] = await pool.query(
      'INSERT INTO status_history (message, timestamp) VALUES (?, ?)',
      [message, mysqlTimestamp]
    );
    return result.insertId;
  } catch (error) {
    console.error('❌ Error inserting status history:', error.message);
    throw error;
  }
}

// Get status history
async function getStatusHistory(limit = 50) {
  try {
    const [rows] = await pool.query(
      `SELECT 
        id, message,
        CONVERT_TZ(timestamp, '+00:00', '+07:00') as timestamp
       FROM status_history 
       ORDER BY timestamp DESC 
       LIMIT ?`,
      [limit]
    );
    return rows;
  } catch (error) {
    console.error('❌ Error getting status history:', error.message);
    throw error;
  }
}

// Insert control command
async function insertControlCommand(command, source = 'API') {
  try {
    // Convert to MySQL DATETIME format
    const date = new Date();
    const mysqlTimestamp = date.toISOString().slice(0, 19).replace('T', ' ');
    
    const [result] = await pool.query(
      'INSERT INTO control_commands (command, source, timestamp) VALUES (?, ?, ?)',
      [command, source, mysqlTimestamp]
    );
    return result.insertId;
  } catch (error) {
    console.error('❌ Error inserting control command:', error.message);
    throw error;
  }
}

// Clear old data (keep last N records)
async function clearOldData(keepRecords = 1000) {
  try {
    await pool.query(`
      DELETE FROM sensor_data 
      WHERE id NOT IN (
        SELECT id FROM (
          SELECT id FROM sensor_data ORDER BY timestamp DESC LIMIT ?
        ) AS temp
      )
    `, [keepRecords]);
    
    await pool.query(`
      DELETE FROM status_history 
      WHERE id NOT IN (
        SELECT id FROM (
          SELECT id FROM status_history ORDER BY timestamp DESC LIMIT ?
        ) AS temp
      )
    `, [keepRecords]);
    
    console.log(`✅ Old data cleared, kept last ${keepRecords} records`);
    return true;
  } catch (error) {
    console.error('❌ Error clearing old data:', error.message);
    throw error;
  }
}

// Get statistics
async function getStatistics() {
  try {
    const [sensorCount] = await pool.query('SELECT COUNT(*) as count FROM sensor_data');
    const [statusCount] = await pool.query('SELECT COUNT(*) as count FROM status_history');
    const [commandCount] = await pool.query('SELECT COUNT(*) as count FROM control_commands');
    
    return {
      sensorDataCount: sensorCount[0].count,
      statusHistoryCount: statusCount[0].count,
      controlCommandsCount: commandCount[0].count
    };
  } catch (error) {
    console.error('❌ Error getting statistics:', error.message);
    throw error;
  }
}

module.exports = {
  pool,
  testConnection,
  initDatabase,
  insertSensorData,
  getLatestSensorData,
  getSensorDataHistory,
  insertStatusHistory,
  getStatusHistory,
  insertControlCommand,
  clearOldData,
  getStatistics
};
