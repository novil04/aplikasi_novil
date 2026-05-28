const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const mqtt = require('mqtt');
const aedes = require('aedes')();
const { createServer } = require('net');
const { WebSocketServer } = require('ws');
const http = require('http');
require('dotenv').config();

// Import database functions
const db = require('./database');

// =====================================================
// CONFIGURATION
// =====================================================
const PORT = process.env.PORT || 3000;
const MQTT_PORT = process.env.MQTT_PORT || 1883;
const WS_PORT = process.env.WS_PORT || 8883;

// MQTT Client Configuration (untuk connect ke HiveMQ)
const MQTT_BROKER_URL = process.env.MQTT_BROKER_URL || 'mqtt://broker.hivemq.com:1883';
const MQTT_TOPICS = {
  data: 'novil/pengering/data',
  status: 'novil/pengering/status',
  button: 'novil/pengering/button',
  control: 'novil/pengering/control'
};

// =====================================================
// EXPRESS APP
// =====================================================
const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

// =====================================================
// DATA STORAGE (MySQL Database)
// =====================================================
let latestData = {
  suhu: 0,
  berat: 0,
  target: 0,
  relay1: false,
  relay2: false,
  relay3: false,
  relay4: false,
  status: 'DISCONNECTED',
  timestamp: new Date().toISOString()
};

// Initialize database on startup
(async () => {
  try {
    console.log('🔄 Initializing database connection...');
    const connected = await db.testConnection();
    if (connected) {
      console.log('✅ Database connected, initializing tables...');
      await db.initDatabase();
      // Load latest data from database
      try {
        const latest = await db.getLatestSensorData();
        if (latest) {
          latestData = {
            suhu: latest.suhu,
            berat: latest.berat,
            target: latest.target,
            relay1: latest.relay1,
            relay2: latest.relay2,
            relay3: latest.relay3,
            relay4: latest.relay4,
            status: latest.status,
            timestamp: latest.timestamp
          };
          console.log('✅ Latest data loaded from database');
        }
      } catch (loadError) {
        console.warn('⚠️  Could not load latest data:', loadError.message);
      }
    } else {
      console.warn('⚠️  Running without database connection');
    }
  } catch (error) {
    console.error('❌ Database initialization error:', error.message);
    console.warn('⚠️  Continuing without database...');
  }
})();

// =====================================================
// MQTT CLIENT (Connect to HiveMQ)
// =====================================================
console.log('🔄 Connecting to MQTT Broker:', MQTT_BROKER_URL);

const mqttClient = mqtt.connect(MQTT_BROKER_URL, {
  clientId: `backend_${Math.random().toString(16).slice(2, 10)}`,
  clean: true,
  connectTimeout: 4000,
  reconnectPeriod: 1000,
  keepalive: 60
});

mqttClient.on('connect', () => {
  console.log('✅ Connected to MQTT Broker (HiveMQ)');
  
  // Subscribe to all topics
  mqttClient.subscribe([
    MQTT_TOPICS.data,
    MQTT_TOPICS.status,
    MQTT_TOPICS.button,
    MQTT_TOPICS.control
  ], (err) => {
    if (err) {
      console.error('❌ Failed to subscribe:', err);
    } else {
      console.log('✅ Subscribed to topics:');
      console.log('   -', MQTT_TOPICS.data);
      console.log('   -', MQTT_TOPICS.status);
      console.log('   -', MQTT_TOPICS.button);
      console.log('   -', MQTT_TOPICS.control);
    }
  });
});

mqttClient.on('error', (error) => {
  console.error('❌ MQTT Client Error:', error.message);
});

mqttClient.on('reconnect', () => {
  console.log('🔄 Reconnecting to MQTT Broker...');
});

mqttClient.on('offline', () => {
  console.warn('⚠️  MQTT Client offline');
});

mqttClient.on('message', async (topic, message) => {
  const msg = message.toString();
  console.log(`📨 MQTT Message received:`);
  console.log(`   Topic: ${topic}`);
  console.log(`   Message: ${msg}`);
  
  // =====================================================
  // TOPIC: novil/pengering/data
  // Format: {"suhu":28.5,"berat":450,"target":315}
  // =====================================================
  if (topic === MQTT_TOPICS.data) {
    try {
      const data = JSON.parse(msg);
      
      // Get current time in WIB (UTC+7)
      const now = new Date();
      const wibTime = new Date(now.getTime() + (7 * 60 * 60 * 1000));
      
      // Update latestData dengan data dari ESP32
      latestData = {
        suhu: data.suhu || 0,
        berat: data.berat || 0,
        target: data.target || 0,
        relay1: latestData.relay1 || false, // Keep current relay status
        relay2: latestData.relay2 || false,
        relay3: latestData.relay3 || false,
        relay4: latestData.relay4 || false,
        status: latestData.status, // Keep current status
        timestamp: wibTime.toISOString()
      };
      
      // Save to database
      try {
        await db.insertSensorData(latestData);
        console.log('✅ Data saved to MySQL database');
      } catch (dbError) {
        console.error('❌ Failed to save to database:', dbError.message);
      }
      
      console.log('✅ Data updated:', latestData);
    } catch (e) {
      console.error('❌ Error parsing data:', e);
    }
  }
  
  // =====================================================
  // TOPIC: novil/pengering/status
  // Format: "ESP32 CONNECTED", "PENGERINGAN DIMULAI", dll
  // =====================================================
  if (topic === MQTT_TOPICS.status) {
    // Update status di latestData
    if (msg.includes('ESP32 CONNECTED')) {
      latestData.status = 'CONNECTED';
    } else if (msg.includes('PENGERINGAN SIAP')) {
      latestData.status = 'READY';
    } else if (msg.includes('PENGERINGAN DIMULAI')) {
      latestData.status = 'RUNNING';
    } else if (msg.includes('PENGERINGAN BERJALAN')) {
      latestData.status = 'RUNNING';
    } else if (msg.includes('PENGERINGAN SELESAI')) {
      latestData.status = 'COMPLETED';
    } else if (msg.includes('SCAN BERAT')) {
      latestData.status = 'SCANNING';
    } else if (msg.includes('DHT ERROR')) {
      latestData.status = 'ERROR';
    }
    
    // Save to database
    try {
      await db.insertStatusHistory(msg);
      console.log('✅ Status saved to MySQL database');
    } catch (dbError) {
      console.error('❌ Failed to save status to database:', dbError.message);
    }
    console.log('📊 Status:', msg);
  }
  
  // =====================================================
  // TOPIC: novil/pengering/button
  // Format: "BUTTON PRESSED", "START_BUTTON", "RESET_BUTTON"
  // =====================================================
  if (topic === MQTT_TOPICS.button) {
    console.log('🔘 Button Event:', msg);
    
    // Save button event to status history
    try {
      await db.insertStatusHistory(`BUTTON: ${msg}`);
      console.log('✅ Button event saved to MySQL database');
    } catch (dbError) {
      console.error('❌ Failed to save button event:', dbError.message);
    }
  }
  
  // =====================================================
  // TOPIC: novil/pengering/control
  // Format: "STATUS:HEATER_ON", "HEATER_ON", "FAN_OFF", dll
  // =====================================================
  if (topic === MQTT_TOPICS.control) {
    console.log('🎛️  Control Message:', msg);
    
    // Jika pesan dimulai dengan "STATUS:", ini adalah feedback dari ESP32
    if (msg.startsWith('STATUS:')) {
      const statusMsg = msg.replace('STATUS:', '');
      console.log('📊 Relay Status Update:', statusMsg);
      
      // Update relay state di latestData
      if (statusMsg === 'HEATER_ON') latestData.relay1 = true;
      else if (statusMsg === 'HEATER_OFF') latestData.relay1 = false;
      else if (statusMsg === 'FAN_ON') latestData.relay2 = true;
      else if (statusMsg === 'FAN_OFF') latestData.relay2 = false;
      else if (statusMsg === 'EXHAUST_ON') latestData.relay3 = true;
      else if (statusMsg === 'EXHAUST_OFF') latestData.relay3 = false;
      
      // Save status update to status_history
      try {
        await db.insertStatusHistory(`RELAY: ${statusMsg}`);
        console.log('✅ Relay status saved to status_history');
      } catch (dbError) {
        console.error('❌ Failed to save relay status:', dbError.message);
      }
      
      // Save juga ke control_commands dengan source ESP32
      try {
        await db.insertControlCommand(statusMsg, 'ESP32');
        console.log('✅ Relay status saved to control_commands');
      } catch (dbError) {
        console.error('❌ Failed to save to control_commands:', dbError.message);
      }
    } else {
      // Ini adalah command dari API/Flutter, simpan ke control_commands
      try {
        await db.insertControlCommand(msg, 'MQTT');
        console.log('✅ Control command saved to control_commands');
      } catch (dbError) {
        console.error('❌ Failed to save control command:', dbError.message);
      }
    }
  }
});

// =====================================================
// MQTT BROKER (AEDES)
// =====================================================
const mqttServer = createServer(aedes.handle);

// MQTT Event Handlers
aedes.on('client', (client) => {
  console.log(`📱 Client Connected: ${client.id}`);
});

aedes.on('clientDisconnect', (client) => {
  console.log(`📴 Client Disconnected: ${client.id}`);
});

aedes.on('publish', async (packet, client) => {
  if (client) {
    const topic = packet.topic;
    const message = packet.payload.toString();
    
    console.log(`📨 Message from ${client.id}:`);
    console.log(`   Topic: ${topic}`);
    console.log(`   Message: ${message}`);
    
    // =====================================================
    // TOPIC: novil/pengering/data
    // Format: {"suhu":28.5,"berat":450,"target":315}
    // =====================================================
    if (topic === 'novil/pengering/data') {
      try {
        const data = JSON.parse(message);
        
        // Update latestData dengan data dari ESP32
        latestData = {
          suhu: data.suhu || 0,
          berat: data.berat || 0,
          target: data.target || 0,
          relay1: latestData.relay1 || false, // Keep current relay status
          relay2: latestData.relay2 || false,
          relay3: latestData.relay3 || false,
          relay4: latestData.relay4 || false,
          status: latestData.status, // Keep current status
          timestamp: new Date().toISOString()
        };
        
        // Save to database
        try {
          await db.insertSensorData(latestData);
          console.log('✅ Data saved to database');
        } catch (dbError) {
          console.error('❌ Failed to save to database:', dbError.message);
        }
        
        console.log('✅ Data updated:', latestData);
      } catch (e) {
        console.error('❌ Error parsing data:', e);
      }
    }
    
    // =====================================================
    // TOPIC: novil/pengering/status
    // Format: "ESP32 CONNECTED", "PENGERINGAN DIMULAI", dll
    // =====================================================
    if (topic === 'novil/pengering/status') {
      // Update status di latestData
      if (message.includes('ESP32 CONNECTED')) {
        latestData.status = 'CONNECTED';
      } else if (message.includes('PENGERINGAN SIAP')) {
        latestData.status = 'READY';
      } else if (message.includes('PENGERINGAN DIMULAI')) {
        latestData.status = 'RUNNING';
      } else if (message.includes('PENGERINGAN BERJALAN')) {
        latestData.status = 'RUNNING';
      } else if (message.includes('PENGERINGAN SELESAI')) {
        latestData.status = 'COMPLETED';
      } else if (message.includes('SCAN BERAT')) {
        latestData.status = 'SCANNING';
      } else if (message.includes('DHT ERROR')) {
        latestData.status = 'ERROR';
      }
      
      // Save to database
      try {
        await db.insertStatusHistory(message);
        console.log('✅ Status saved to database');
      } catch (dbError) {
        console.error('❌ Failed to save status to database:', dbError.message);
      }
      console.log('📊 Status:', message);
    }
    
    // =====================================================
    // TOPIC: novil/pengering/button
    // Format: "BUTTON PRESSED", "START_BUTTON", "RESET_BUTTON"
    // =====================================================
    if (topic === 'novil/pengering/button') {
      console.log('🔘 Button Event:', message);
      
      // Save button event to status history
      try {
        await db.insertStatusHistory(`BUTTON: ${message}`);
      } catch (dbError) {
        console.error('❌ Failed to save button event:', dbError.message);
      }
    }
    
    // =====================================================
    // TOPIC: novil/pengering/control
    // Format: "STATUS:HEATER_ON", "HEATER_ON", "FAN_OFF", dll
    // =====================================================
    if (topic === 'novil/pengering/control') {
      console.log('🎛️  Control Message:', message);
      
      // Jika pesan dimulai dengan "STATUS:", ini adalah feedback dari ESP32
      if (message.startsWith('STATUS:')) {
        const statusMsg = message.replace('STATUS:', '');
        console.log('📊 Relay Status Update:', statusMsg);
        
        // Update relay state di latestData
        if (statusMsg === 'HEATER_ON') latestData.relay1 = true;
        else if (statusMsg === 'HEATER_OFF') latestData.relay1 = false;
        else if (statusMsg === 'FAN_ON') latestData.relay2 = true;
        else if (statusMsg === 'FAN_OFF') latestData.relay2 = false;
        else if (statusMsg === 'EXHAUST_ON') latestData.relay3 = true;
        else if (statusMsg === 'EXHAUST_OFF') latestData.relay3 = false;
        
        // Save status update to status_history
        try {
          await db.insertStatusHistory(`RELAY: ${statusMsg}`);
          console.log('✅ Relay status saved to database');
        } catch (dbError) {
          console.error('❌ Failed to save relay status:', dbError.message);
        }
      } else {
        // Ini adalah command dari API/Flutter, simpan ke control_commands
        try {
          await db.insertControlCommand(message, 'MQTT');
          console.log('✅ Control command saved to database');
        } catch (dbError) {
          console.error('❌ Failed to save control command:', dbError.message);
        }
      }
    }
  }
});

aedes.on('subscribe', (subscriptions, client) => {
  console.log(`📬 Client ${client.id} subscribed to:`, subscriptions.map(s => s.topic).join(', '));
});

// Start MQTT Server (only if not in production or if explicitly enabled)
if (process.env.ENABLE_MQTT_BROKER === 'true') {
  mqttServer.listen(MQTT_PORT, () => {
    console.log(`🚀 MQTT Broker running on port ${MQTT_PORT}`);
  }).on('error', (err) => {
    console.warn(`⚠️  MQTT Broker failed to start on port ${MQTT_PORT}:`, err.message);
    console.log('ℹ️  MQTT Broker disabled. Use external MQTT broker (e.g., HiveMQ)');
  });
} else {
  console.log('ℹ️  MQTT Broker disabled (use external MQTT broker like HiveMQ)');
}

// =====================================================
// WEBSOCKET MQTT (for web clients)
// =====================================================
const httpServer = http.createServer();
const ws = new WebSocketServer({ server: httpServer });

ws.on('connection', (socket) => {
  const stream = require('websocket-stream')(socket);
  aedes.handle(stream);
  console.log('🌐 WebSocket MQTT client connected');
});

if (process.env.ENABLE_MQTT_BROKER === 'true') {
  httpServer.listen(WS_PORT, () => {
    console.log(`🌐 WebSocket MQTT running on port ${WS_PORT}`);
  }).on('error', (err) => {
    console.warn(`⚠️  WebSocket MQTT failed to start on port ${WS_PORT}:`, err.message);
  });
} else {
  console.log('ℹ️  WebSocket MQTT disabled');
}

// =====================================================
// REST API ENDPOINTS
// =====================================================

// Health check
app.get('/', (req, res) => {
  res.json({
    status: 'OK',
    message: 'Pengering Ikan Backend Server - MQTT Client Enabled',
    version: '1.0.1',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Initialize database tables (manual trigger)
app.post('/api/database/init', async (req, res) => {
  try {
    const connected = await db.testConnection();
    if (!connected) {
      return res.status(500).json({
        success: false,
        message: 'Database connection failed'
      });
    }
    
    const initialized = await db.initDatabase();
    if (initialized) {
      res.json({
        success: true,
        message: 'Database tables initialized successfully'
      });
    } else {
      res.status(500).json({
        success: false,
        message: 'Failed to initialize database tables'
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error initializing database',
      error: error.message
    });
  }
});

// Test database connection
app.get('/api/database/test', async (req, res) => {
  try {
    const connected = await db.testConnection();
    if (connected) {
      res.json({
        success: true,
        message: 'Database connection successful'
      });
    } else {
      res.status(500).json({
        success: false,
        message: 'Database connection failed'
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error testing database connection',
      error: error.message
    });
  }
});

// Post sensor data from ESP32
app.post('/api/data/sensor', async (req, res) => {
  try {
    const { suhu, berat, target, relay1, relay2, relay3, relay4, status } = req.body;
    
    // Validate data
    if (suhu === undefined || berat === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Suhu and berat are required'
      });
    }
    
    // Update latest data
    latestData = {
      suhu: suhu || 0,
      berat: berat || 0,
      target: target || 0,
      relay1: relay1 || false,
      relay2: relay2 || false,
      relay3: relay3 || false,
      relay4: relay4 || false,
      status: status || 'UNKNOWN',
      timestamp: new Date().toISOString()
    };
    
    // Save to database
    try {
      await db.insertSensorData(latestData);
      console.log('✅ Data from ESP32 saved to database');
    } catch (dbError) {
      console.error('❌ Failed to save to database:', dbError.message);
    }
    
    res.json({
      success: true,
      message: 'Data received successfully',
      data: latestData
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error processing sensor data',
      error: error.message
    });
  }
});

// Post status from ESP32
app.post('/api/status', async (req, res) => {
  try {
    const { message } = req.body;
    
    if (!message) {
      return res.status(400).json({
        success: false,
        message: 'Status message is required'
      });
    }
    
    // Save to database
    try {
      await db.insertStatusHistory(message);
      console.log('✅ Status from ESP32 saved:', message);
    } catch (dbError) {
      console.error('❌ Failed to save status to database:', dbError.message);
    }
    
    res.json({
      success: true,
      message: 'Status received successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error processing status',
      error: error.message
    });
  }
});

// Get latest data
app.get('/api/data/latest', (req, res) => {
  res.json({
    success: true,
    data: latestData
  });
});

// Get data history
app.get('/api/data/history', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const history = await db.getSensorDataHistory(limit);
    
    res.json({
      success: true,
      count: history.length,
      data: history
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to get data history',
      error: error.message
    });
  }
});

// Get status history
app.get('/api/status/history', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const history = await db.getStatusHistory(limit);
    
    res.json({
      success: true,
      count: history.length,
      data: history
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to get status history',
      error: error.message
    });
  }
});

// Publish control command
app.post('/api/control', async (req, res) => {
  const { command } = req.body;
  
  if (!command) {
    return res.status(400).json({
      success: false,
      message: 'Command is required'
    });
  }
  
  // Valid commands (sesuai dengan ESP32)
  const validCommands = [
    'HEATER_ON', 'HEATER_OFF',
    'FAN_ON', 'FAN_OFF',
    'LAMP_ON', 'LAMP_OFF',
    'EXHAUST_ON', 'EXHAUST_OFF',
    'START',  // Mulai pengeringan
    'RESET'   // Reset ke mode ready
  ];
  
  if (!validCommands.includes(command)) {
    return res.status(400).json({
      success: false,
      message: 'Invalid command',
      validCommands: validCommands
    });
  }
  
  // Save command to database
  try {
    await db.insertControlCommand(command, 'API');
  } catch (dbError) {
    console.error('❌ Failed to save command to database:', dbError.message);
  }
  
  // Publish to MQTT (HiveMQ)
  mqttClient.publish(MQTT_TOPICS.control, command, { qos: 1 }, (err) => {
    if (err) {
      return res.status(500).json({
        success: false,
        message: 'Failed to publish command',
        error: err.message
      });
    }
    
    console.log(`✅ Command published to MQTT: ${command}`);
    res.json({
      success: true,
      message: 'Command sent successfully',
      command: command
    });
  });
});

// Get statistics
app.get('/api/stats', async (req, res) => {
  try {
    const dbStats = await db.getStatistics();
    
    res.json({
      success: true,
      stats: {
        mqttConnected: mqttClient.connected,
        ...dbStats,
        latestData: latestData,
        uptime: process.uptime(),
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    res.json({
      success: true,
      stats: {
        mqttConnected: mqttClient.connected,
        latestData: latestData,
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        databaseError: error.message
      }
    });
  }
});

// Clear history
app.delete('/api/history/clear', async (req, res) => {
  try {
    await db.clearOldData(0); // Clear all data
    
    res.json({
      success: true,
      message: 'History cleared successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to clear history',
      error: error.message
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint not found'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('❌ Error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: err.message
  });
});

// =====================================================
// START EXPRESS SERVER
// =====================================================
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('='.repeat(60));
  console.log('🚀 PENGERING IKAN BACKEND SERVER');
  console.log('='.repeat(60));
  console.log(`📡 REST API: http://0.0.0.0:${PORT}`);
  console.log(`🔗 MQTT Broker: ${MQTT_BROKER_URL}`);
  console.log(`📊 MQTT Status: ${mqttClient.connected ? '✅ Connected' : '⏳ Connecting...'}`);
  console.log('');
  console.log('📋 Available Endpoints:');
  console.log('   GET  /                      - Health check');
  console.log('   GET  /api/data/latest       - Get latest sensor data');
  console.log('   GET  /api/data/history      - Get data history');
  console.log('   GET  /api/status/history    - Get status history');
  console.log('   GET  /api/stats             - Get server statistics');
  console.log('   POST /api/control           - Send control command');
  console.log('   POST /api/data/sensor       - Post sensor data (ESP32)');
  console.log('   POST /api/status            - Post status (ESP32)');
  console.log('   DELETE /api/history/clear   - Clear history');
  console.log('');
  console.log('📡 MQTT Topics:');
  console.log('   Subscribe:', MQTT_TOPICS.data);
  console.log('   Subscribe:', MQTT_TOPICS.status);
  console.log('   Subscribe:', MQTT_TOPICS.button);
  console.log('   Publish:  ', MQTT_TOPICS.control);
  console.log('');
  console.log('✅ Server is ready!');
  console.log('='.repeat(60));
});

server.on('error', (error) => {
  console.error('❌ Server error:', error);
  if (error.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use`);
  }
  process.exit(1);
});

// =====================================================
// GRACEFUL SHUTDOWN
// =====================================================
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully...');
  
  // Close MQTT client
  if (mqttClient) {
    mqttClient.end(() => {
      console.log('✅ MQTT client closed');
    });
  }
  
  // Close HTTP server
  server.close(() => {
    console.log('✅ HTTP server closed');
  });
  
  // Close MQTT broker if enabled
  if (process.env.ENABLE_MQTT_BROKER === 'true') {
    mqttServer.close(() => {
      console.log('✅ MQTT server closed');
    });
    httpServer.close(() => {
      console.log('✅ WebSocket server closed');
    });
  }
  
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 SIGINT received, shutting down gracefully...');
  
  // Close MQTT client
  if (mqttClient) {
    mqttClient.end(() => {
      console.log('✅ MQTT client closed');
    });
  }
  
  // Close HTTP server
  server.close(() => {
    console.log('✅ HTTP server closed');
  });
  
  process.exit(0);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});
