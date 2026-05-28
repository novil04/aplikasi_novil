-- =====================================================
-- SCRIPT UNTUK MEMBUAT TABEL DI RAILWAY MYSQL
-- Copy-paste script ini ke Railway MySQL Query
-- =====================================================

-- Table: sensor_data
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

-- Table: status_history
CREATE TABLE IF NOT EXISTS status_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  message TEXT NOT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table: control_commands
CREATE TABLE IF NOT EXISTS control_commands (
  id INT AUTO_INCREMENT PRIMARY KEY,
  command VARCHAR(50) NOT NULL,
  source VARCHAR(50) DEFAULT 'API',
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Verify tables created
SHOW TABLES;

-- Check table structure
DESCRIBE sensor_data;
DESCRIBE status_history;
DESCRIBE control_commands;
