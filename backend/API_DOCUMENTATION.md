# 📡 API Documentation - Pengering Ikan Backend

## 🔌 Koneksi

### MQTT Broker
- **Host:** `broker.hivemq.com` (public) atau Railway URL (jika deploy)
- **Port:** `1883` (TCP) atau `8883` (WebSocket)
- **Client ID:** `ESP32_PENGERING` (untuk ESP32)

### REST API
- **Base URL:** `https://web-production-47eb.up.railway.app`
- **Local:** `http://localhost:3000`

---

## 📨 MQTT Topics

### 1. **novil/pengering/data** (ESP32 → Backend)
ESP32 publish data sensor setiap 1 detik saat pengeringan berjalan.

**Format:**
```json
{
  "suhu": 28.5,
  "berat": 450.0,
  "target": 315.0
}
```

**Field:**
- `suhu` (float): Suhu dalam Celsius
- `berat` (float): Berat saat ini dalam gram
- `target` (float): Target berat akhir dalam gram

---

### 2. **novil/pengering/status** (ESP32 → Backend)
ESP32 publish status/event penting.

**Format:** Plain text string

**Contoh pesan:**
- `"ESP32 CONNECTED"` - ESP32 berhasil connect
- `"PENGERINGAN SIAP"` - Mode ready
- `"PENGERINGAN DIMULAI"` - Pengeringan mulai
- `"SCAN BERAT..."` - Sedang scan berat ikan
- `"PENGERINGAN BERJALAN - Awal:500g Target:350g"` - Berat tersimpan
- `"PENGERINGAN SELESAI"` - Target tercapai
- `"DHT ERROR"` - Sensor DHT error

---

### 3. **novil/pengering/button** (ESP32 → Backend)
ESP32 publish event button press.

**Format:** Plain text string

**Contoh pesan:**
- `"BUTTON PRESSED"` - Button ditekan
- `"START_BUTTON"` - Button untuk start
- `"RESET_BUTTON"` - Button untuk reset

---

### 4. **novil/pengering/control** (Backend → ESP32)
Backend/Flutter publish command untuk kontrol relay dan sistem.

**Format:** Plain text string

**Valid Commands:**
- `"HEATER_ON"` - Nyalakan heater (RELAY1)
- `"HEATER_OFF"` - Matikan heater
- `"FAN_ON"` - Nyalakan fan (RELAY2)
- `"FAN_OFF"` - Matikan fan
- `"LAMP_ON"` - Nyalakan lamp (RELAY3)
- `"LAMP_OFF"` - Matikan lamp
- `"EXHAUST_ON"` - Nyalakan exhaust (RELAY4)
- `"EXHAUST_OFF"` - Matikan exhaust
- `"START"` - Mulai pengeringan (dari aplikasi)
- `"RESET"` - Reset ke mode ready (dari aplikasi)

---

## 🌐 REST API Endpoints

### 1. **GET /** - Health Check
Cek status server.

**Response:**
```json
{
  "status": "OK",
  "message": "Pengering Ikan Backend Server",
  "version": "1.0.0",
  "uptime": 12345.67,
  "timestamp": "2026-05-28T10:30:00.000Z"
}
```

---

### 2. **GET /api/data/latest** - Get Latest Data
Ambil data sensor terbaru.

**Response:**
```json
{
  "success": true,
  "data": {
    "suhu": 28.5,
    "berat": 450.0,
    "target": 315.0,
    "relay1": true,
    "relay2": true,
    "relay3": true,
    "relay4": false,
    "status": "RUNNING",
    "timestamp": "2026-05-28T10:30:00.000Z"
  }
}
```

**Status Values:**
- `CONNECTED` - ESP32 terhubung
- `READY` - Siap untuk pengeringan
- `RUNNING` - Pengeringan berjalan
- `SCANNING` - Sedang scan berat
- `COMPLETED` - Pengeringan selesai
- `ERROR` - Ada error

---

### 3. **GET /api/data/history?limit=50** - Get Data History
Ambil riwayat data sensor.

**Query Parameters:**
- `limit` (optional): Jumlah data (default: 50)

**Response:**
```json
{
  "success": true,
  "count": 50,
  "data": [
    {
      "id": 1,
      "suhu": 28.5,
      "berat": 450.0,
      "target": 315.0,
      "relay1": true,
      "relay2": true,
      "relay3": true,
      "relay4": false,
      "status": "RUNNING",
      "timestamp": "2026-05-28 10:30:00"
    }
  ]
}
```

---

### 4. **GET /api/status/history?limit=50** - Get Status History
Ambil riwayat status/event.

**Query Parameters:**
- `limit` (optional): Jumlah data (default: 50)

**Response:**
```json
{
  "success": true,
  "count": 50,
  "data": [
    {
      "id": 1,
      "message": "PENGERINGAN DIMULAI",
      "timestamp": "2026-05-28 10:30:00"
    }
  ]
}
```

---

### 5. **POST /api/control** - Send Control Command
Kirim command ke ESP32 via MQTT.

**Request Body:**
```json
{
  "command": "HEATER_ON"
}
```

**Valid Commands:**
- `HEATER_ON`, `HEATER_OFF`
- `FAN_ON`, `FAN_OFF`
- `LAMP_ON`, `LAMP_OFF`
- `EXHAUST_ON`, `EXHAUST_OFF`
- `START` (mulai pengeringan)
- `RESET` (reset ke ready)

**Response:**
```json
{
  "success": true,
  "message": "Command sent successfully",
  "command": "HEATER_ON"
}
```

---

### 6. **GET /api/stats** - Get Statistics
Ambil statistik server dan database.

**Response:**
```json
{
  "success": true,
  "stats": {
    "connectedClients": 2,
    "sensorDataCount": 1234,
    "statusHistoryCount": 567,
    "controlCommandsCount": 89,
    "latestData": { ... },
    "uptime": 12345.67,
    "timestamp": "2026-05-28T10:30:00.000Z"
  }
}
```

---

### 7. **DELETE /api/history/clear** - Clear History
Hapus semua riwayat data.

**Response:**
```json
{
  "success": true,
  "message": "History cleared successfully"
}
```

---

### 8. **POST /api/database/init** - Initialize Database
Buat tabel database (hanya perlu sekali).

**Response:**
```json
{
  "success": true,
  "message": "Database tables initialized successfully"
}
```

---

### 9. **GET /api/database/test** - Test Database Connection
Test koneksi ke MySQL.

**Response:**
```json
{
  "success": true,
  "message": "Database connection successful"
}
```

---

## 🔄 Flow Komunikasi

### Skenario 1: Pengeringan Normal (via Button ESP32)

1. **ESP32 Connect**
   - ESP32 → MQTT: `novil/pengering/status` = `"ESP32 CONNECTED"`
   - Backend: Update status = `CONNECTED`

2. **User Tekan Button (Ready → Start)**
   - ESP32 → MQTT: `novil/pengering/button` = `"START_BUTTON"`
   - ESP32 → MQTT: `novil/pengering/status` = `"PENGERINGAN DIMULAI"`
   - Backend: Update status = `RUNNING`

3. **Scan Berat Ikan**
   - ESP32 → MQTT: `novil/pengering/status` = `"SCAN BERAT..."`
   - Backend: Update status = `SCANNING`

4. **Berat Tersimpan**
   - ESP32 → MQTT: `novil/pengering/status` = `"PENGERINGAN BERJALAN - Awal:500g Target:350g"`
   - Backend: Update status = `RUNNING`

5. **Kirim Data Sensor (setiap 1 detik)**
   - ESP32 → MQTT: `novil/pengering/data` = `{"suhu":28.5,"berat":450,"target":315}`
   - Backend: Simpan ke database

6. **Target Tercapai**
   - ESP32 → MQTT: `novil/pengering/status` = `"PENGERINGAN SELESAI"`
   - Backend: Update status = `COMPLETED`

7. **User Tekan Button (Selesai → Ready)**
   - ESP32 → MQTT: `novil/pengering/button` = `"RESET_BUTTON"`
   - ESP32 → MQTT: `novil/pengering/status` = `"PENGERINGAN SIAP"`
   - Backend: Update status = `READY`

---

### Skenario 2: Kontrol dari Flutter App

1. **Flutter Subscribe MQTT**
   - Subscribe: `novil/pengering/data`
   - Subscribe: `novil/pengering/status`
   - Terima data real-time

2. **Flutter Kirim Command START**
   - Flutter → API: `POST /api/control` body: `{"command":"START"}`
   - Backend → MQTT: `novil/pengering/control` = `"START"`
   - ESP32: Terima command, mulai pengeringan

3. **Flutter Kirim Command HEATER_ON**
   - Flutter → API: `POST /api/control` body: `{"command":"HEATER_ON"}`
   - Backend → MQTT: `novil/pengering/control` = `"HEATER_ON"`
   - ESP32: Nyalakan RELAY1

4. **Flutter Get Latest Data**
   - Flutter → API: `GET /api/data/latest`
   - Backend: Return data terbaru

---

## 🛠️ Testing dengan cURL

### Test Health Check
```bash
curl https://web-production-47eb.up.railway.app/
```

### Test Get Latest Data
```bash
curl https://web-production-47eb.up.railway.app/api/data/latest
```

### Test Send Command
```bash
curl -X POST https://web-production-47eb.up.railway.app/api/control \
  -H "Content-Type: application/json" \
  -d '{"command":"HEATER_ON"}'
```

### Test Get History
```bash
curl https://web-production-47eb.up.railway.app/api/data/history?limit=10
```

---

## 📝 Catatan Penting

1. **ESP32 hanya menggunakan MQTT**, tidak ada HTTP request ke Railway
2. **Flutter bisa menggunakan:**
   - MQTT untuk real-time data (subscribe topics)
   - REST API untuk kontrol dan history
3. **Backend menerima data dari ESP32 via MQTT** dan menyimpan ke MySQL
4. **Semua command dari Flutter dikirim via REST API**, backend forward ke ESP32 via MQTT

---

## 🚀 Deploy ke Railway

Setelah perubahan, push ke GitHub:

```bash
cd backend
git add .
git commit -m "Update backend untuk ESP32 MQTT integration"
git push
```

Railway akan auto-deploy! ✅
