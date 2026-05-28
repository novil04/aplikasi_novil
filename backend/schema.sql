-- =====================================================
-- Database Schema untuk Pengering Ikan IoT
-- =====================================================

-- Create database (optional, Railway sudah provide)
-- CREATE DATABASE IF NOT EXISTS pengering_ikan;
-- USE pengering_ikan;

-- =====================================================
-- Table: sensor_data
-- Menyimpan data sensor dari ESP32
-- =====================================================
CREATE TABLE IF NOT EXISTS sensor_data (
  id INT AUTO_INCREMENT PRIMARY KEY,
  suhu FLOAT NOT NULL COMMENT 'Suhu dalam Celsius',
  berat FLOAT NOT NULL COMMENT 'Berat dalam gram',
  target FLOAT NOT NULL COMMENT 'Target berat dalam gram',
  relay1 BOOLEAN DEFAULT FALSE COMMENT 'Status Relay 1 (Heater)',
  relay2 BOOLEAN DEFAULT FALSE COMMENT 'Status Relay 2 (Fan)',
  relay3 BOOLEAN DEFAULT FALSE COMMENT 'Status Relay 3 (Lamp)',
  relay4 BOOLEAN DEFAULT FALSE COMMENT 'Status Relay 4 (Exhaust)',
  status VARCHAR(50) DEFAULT 'DISCONNECTED' COMMENT 'Status koneksi ESP32',
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Waktu data diterima',
  INDEX idx_timestamp (timestamp),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Data sensor dari ESP32';

-- =====================================================
-- Table: status_history
-- Menyimpan history status dari ESP32
-- =====================================================
CREATE TABLE IF NOT EXISTS status_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  message TEXT NOT NULL COMMENT 'Status message dari ESP32',
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Waktu status diterima',
  INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='History status dari ESP32';

-- =====================================================
-- Table: control_commands
-- Menyimpan history control commands
-- =====================================================
CREATE TABLE IF NOT EXISTS control_commands (
  id INT AUTO_INCREMENT PRIMARY KEY,
  command VARCHAR(50) NOT NULL COMMENT 'Command yang dikirim (HEATER_ON, FAN_OFF, dll)',
  source VARCHAR(50) DEFAULT 'API' COMMENT 'Sumber command (API, MQTT, Manual)',
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Waktu command dikirim',
  INDEX idx_timestamp (timestamp),
  INDEX idx_command (command)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='History control commands';

-- =====================================================
-- Sample Data (Optional, untuk testing)
-- =====================================================

-- Insert sample sensor data
INSERT INTO sensor_data (suhu, berat, target, relay1, relay2, relay3, relay4, status) VALUES
(25.5, 1000.0, 800.0, true, true, false, false, 'CONNECTED'),
(26.0, 950.0, 800.0, true, true, false, false, 'CONNECTED'),
(26.5, 900.0, 800.0, true, true, false, false, 'CONNECTED'),
(27.0, 850.0, 800.0, true, true, false, false, 'CONNECTED'),
(27.5, 800.0, 800.0, false, false, false, false, 'COMPLETED');

-- Insert sample status history
INSERT INTO status_history (message) VALUES
('ESP32 Connected'),
('Drying process started'),
('Temperature: 25.5°C, Weight: 1000g'),
('Temperature: 27.5°C, Weight: 800g'),
('Drying process completed');

-- Insert sample control commands
INSERT INTO control_commands (command, source) VALUES
('HEATER_ON', 'API'),
('FAN_ON', 'API'),
('HEATER_OFF', 'API'),
('FAN_OFF', 'API');

-- =====================================================
-- Useful Queries
-- =====================================================

-- Get latest sensor data
-- SELECT * FROM sensor_data ORDER BY timestamp DESC LIMIT 1;

-- Get data history (last 50 records)
-- SELECT * FROM sensor_data ORDER BY timestamp DESC LIMIT 50;

-- Get status history (last 50 records)
-- SELECT * FROM status_history ORDER BY timestamp DESC LIMIT 50;

-- Get control commands history
-- SELECT * FROM control_commands ORDER BY timestamp DESC LIMIT 50;

-- Get statistics
-- SELECT 
--   COUNT(*) as total_records,
--   MIN(suhu) as min_temp,
--   MAX(suhu) as max_temp,
--   AVG(suhu) as avg_temp,
--   MIN(berat) as min_weight,
--   MAX(berat) as max_weight,
--   AVG(berat) as avg_weight
-- FROM sensor_data;

-- Get data by date range
-- SELECT * FROM sensor_data 
-- WHERE timestamp BETWEEN '2024-01-01' AND '2024-01-31'
-- ORDER BY timestamp DESC;

-- Delete old data (keep last 1000 records)
-- DELETE FROM sensor_data 
-- WHERE id NOT IN (
--   SELECT id FROM (
--     SELECT id FROM sensor_data ORDER BY timestamp DESC LIMIT 1000
--   ) AS temp
-- );

-- =====================================================
-- Maintenance Queries
-- =====================================================

-- Check table sizes
-- SELECT 
--   table_name AS 'Table',
--   ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
-- FROM information_schema.TABLES
-- WHERE table_schema = 'pengering_ikan'
-- ORDER BY (data_length + index_length) DESC;

-- Optimize tables
-- OPTIMIZE TABLE sensor_data;
-- OPTIMIZE TABLE status_history;
-- OPTIMIZE TABLE control_commands;

-- Backup database (via mysqldump)
-- mysqldump -u root -p pengering_ikan > backup.sql

-- Restore database
-- mysql -u root -p pengering_ikan < backup.sql
