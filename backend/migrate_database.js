// =====================================================
// DATABASE MIGRATION SCRIPT
// Migrate data dari Railway lama ke Railway baru
// =====================================================

const mysql = require('mysql2/promise');

// Konfigurasi Database LAMA (Railway account lama)
const oldDB = {
  host: process.env.OLD_DB_HOST || 'mysql.railway.internal',
  port: process.env.OLD_DB_PORT || 3306,
  user: process.env.OLD_DB_USER || 'root',
  password: process.env.OLD_DB_PASSWORD || '',
  database: process.env.OLD_DB_NAME || 'railway'
};

// Konfigurasi Database BARU (Railway account baru)
const newDB = {
  host: process.env.NEW_DB_HOST || 'mysql.railway.internal',
  port: process.env.NEW_DB_PORT || 3306,
  user: process.env.NEW_DB_USER || 'root',
  password: process.env.NEW_DB_PASSWORD || '',
  database: process.env.NEW_DB_NAME || 'railway'
};

async function migrateData() {
  let oldConnection, newConnection;
  
  try {
    console.log('🔄 Connecting to OLD database...');
    oldConnection = await mysql.createConnection(oldDB);
    console.log('✅ Connected to OLD database');
    
    console.log('🔄 Connecting to NEW database...');
    newConnection = await mysql.createConnection(newDB);
    console.log('✅ Connected to NEW database');
    
    // =====================================================
    // 1. Migrate sensor_data
    // =====================================================
    console.log('\n📊 Migrating sensor_data...');
    const [sensorData] = await oldConnection.query('SELECT * FROM sensor_data ORDER BY id');
    console.log(`   Found ${sensorData.length} records`);
    
    for (const row of sensorData) {
      await newConnection.query(
        `INSERT INTO sensor_data (suhu, berat, target, relay1, relay2, relay3, relay4, status, timestamp) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [row.suhu, row.berat, row.target, row.relay1, row.relay2, row.relay3, row.relay4, row.status, row.timestamp]
      );
    }
    console.log('✅ sensor_data migrated');
    
    // =====================================================
    // 2. Migrate status_history
    // =====================================================
    console.log('\n📝 Migrating status_history...');
    const [statusHistory] = await oldConnection.query('SELECT * FROM status_history ORDER BY id');
    console.log(`   Found ${statusHistory.length} records`);
    
    for (const row of statusHistory) {
      await newConnection.query(
        `INSERT INTO status_history (message, timestamp) VALUES (?, ?)`,
        [row.message, row.timestamp]
      );
    }
    console.log('✅ status_history migrated');
    
    // =====================================================
    // 3. Migrate control_commands
    // =====================================================
    console.log('\n🎛️  Migrating control_commands...');
    const [controlCommands] = await oldConnection.query('SELECT * FROM control_commands ORDER BY id');
    console.log(`   Found ${controlCommands.length} records`);
    
    for (const row of controlCommands) {
      await newConnection.query(
        `INSERT INTO control_commands (command, source, timestamp) VALUES (?, ?, ?)`,
        [row.command, row.source, row.timestamp]
      );
    }
    console.log('✅ control_commands migrated');
    
    console.log('\n🎉 MIGRATION COMPLETED SUCCESSFULLY!');
    console.log('=====================================');
    console.log(`Total sensor_data: ${sensorData.length}`);
    console.log(`Total status_history: ${statusHistory.length}`);
    console.log(`Total control_commands: ${controlCommands.length}`);
    console.log('=====================================');
    
  } catch (error) {
    console.error('❌ Migration Error:', error);
    throw error;
  } finally {
    if (oldConnection) await oldConnection.end();
    if (newConnection) await newConnection.end();
  }
}

// Run migration
console.log('🚀 Starting Database Migration...');
console.log('=====================================');
migrateData()
  .then(() => {
    console.log('✅ Migration script finished');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  });
