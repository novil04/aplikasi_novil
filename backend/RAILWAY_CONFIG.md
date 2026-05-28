# ✅ Railway Configuration - Verified

## 🎯 Environment Variables di Railway Anda

Railway Anda sudah menggunakan format yang **BENAR** dan **SUDAH DIDUKUNG** oleh backend:

```bash
DB_HOST=mysql.railway.internal
DB_NAME=railway
DB_PASSWORD=jIRceppgKCeUdEAjeYtzLaiAdPbBhDPX
DB_PORT=3306
DB_USER=root
MQTT_PORT=1883
NODE_ENV=production
WS_PORT=8883
```

✅ **Backend otomatis detect dan gunakan variables ini!**

---

## 🔍 Penjelasan Variables

### Database Variables (MySQL):
| Variable | Value | Keterangan |
|----------|-------|------------|
| `DB_HOST` | `mysql.railway.internal` | Internal hostname Railway MySQL |
| `DB_PORT` | `3306` | Port MySQL standard |
| `DB_USER` | `root` | Username MySQL |
| `DB_PASSWORD` | `jIRc...hDPX` | Password MySQL (disembunyikan) |
| `DB_NAME` | `railway` | Nama database |

### Server Variables:
| Variable | Value | Keterangan |
|----------|-------|------------|
| `NODE_ENV` | `production` | Environment mode |
| `MQTT_PORT` | `1883` | Port MQTT broker (tidak digunakan di Railway) |
| `WS_PORT` | `8883` | Port WebSocket MQTT (tidak digunakan di Railway) |

---

## 📝 Catatan Penting

### 1. **`mysql.railway.internal`**
Ini adalah **internal hostname** Railway untuk MySQL.
- ✅ Hanya bisa diakses dari dalam Railway network
- ✅ Lebih cepat dan aman
- ✅ Tidak perlu expose ke public

### 2. **MQTT_PORT dan WS_PORT**
Railway **TIDAK SUPPORT** custom ports untuk MQTT broker.
- ❌ Port 1883 dan 8883 tidak bisa digunakan di Railway
- ✅ Solusi: Gunakan **HiveMQ Cloud** (public MQTT broker)
- ✅ ESP32 connect ke `broker.hivemq.com`
- ✅ Backend hanya handle REST API, tidak host MQTT broker

### 3. **Database Name: `railway`**
Railway otomatis create database dengan nama `railway`.
- ✅ Backend sudah support ini
- ✅ Tidak perlu ganti nama database

---

## 🚀 Cara Kerja Backend di Railway

### 1. **Backend Startup**
```javascript
// Backend baca environment variables
DB_HOST=mysql.railway.internal
DB_PORT=3306
DB_USER=root
DB_PASSWORD=jIRc...
DB_NAME=railway

// Backend connect ke MySQL
📦 Using individual environment variables for connection
🔧 Database Config: {
  host: 'mysql.railway.internal',
  port: 3306,
  user: 'root',
  database: 'railway',
  password: '***'
}
✅ Database connected successfully
✅ Database tables initialized
```

### 2. **Backend Create Tables**
Backend otomatis create 3 tables di database `railway`:
- `sensor_data` - Data sensor dari ESP32
- `status_history` - Riwayat status
- `control_commands` - Riwayat command

### 3. **Backend Ready**
```
🚀 REST API running on port 3000
📡 MQTT Broker: mqtt://localhost:1883 (DISABLED di Railway)
🌐 WebSocket MQTT: ws://localhost:8883 (DISABLED di Railway)
✅ Server is ready!
```

---

## 🔄 Flow Komunikasi

### ESP32 → Backend (via MQTT Public Broker)
```
ESP32:
├── Connect ke broker.hivemq.com (PUBLIC)
└── Publish data ke topic: novil/pengering/data

Backend di Railway:
├── Connect ke broker.hivemq.com (PUBLIC)
├── Subscribe topic: novil/pengering/data
├── Terima data dari ESP32
└── Simpan ke MySQL (mysql.railway.internal)
```

### Flutter → Backend (via REST API)
```
Flutter:
└── POST https://web-production-47eb.up.railway.app/api/control

Backend di Railway:
├── Terima REST API request
├── Simpan command ke MySQL
└── Publish command ke broker.hivemq.com

ESP32:
└── Terima command dari broker.hivemq.com
```

---

## 🧪 Test Connection

### 1. Test Database Connection
```bash
curl https://web-production-47eb.up.railway.app/api/database/test
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Database connection successful"
}
```

### 2. Initialize Database Tables
```bash
curl -X POST https://web-production-47eb.up.railway.app/api/database/init
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Database tables initialized successfully"
}
```

### 3. Check Server Status
```bash
curl https://web-production-47eb.up.railway.app/
```

**Expected Response:**
```json
{
  "status": "OK",
  "message": "Pengering Ikan Backend Server",
  "version": "1.0.0",
  "uptime": 123.45,
  "timestamp": "2026-05-28T10:30:00.000Z"
}
```

---

## 🛠️ Troubleshooting

### Error: "Database connection failed"

**Cek Railway Logs:**
```bash
# Di Railway Dashboard:
# 1. Go to your service
# 2. Click "Deployments"
# 3. Click latest deployment
# 4. View logs
```

**Cari log:**
```
📦 Using individual environment variables for connection
🔧 Database Config: { ... }
❌ Database connection failed: ...
```

**Solusi:**
1. Pastikan MySQL service running di Railway
2. Pastikan environment variables benar
3. Pastikan `mysql.railway.internal` bisa diakses

---

### Error: "Access denied for user 'root'"

**Solusi:**
1. Cek `DB_PASSWORD` benar
2. Cek `DB_USER` benar
3. Restart MySQL service di Railway

---

### Error: "Unknown database 'railway'"

**Solusi:**
1. Database belum dibuat
2. Connect ke MySQL via Railway CLI:
   ```bash
   railway connect mysql
   ```
3. Create database:
   ```sql
   CREATE DATABASE railway;
   ```

---

## ✅ Checklist Setup

- [x] Environment variables sudah set di Railway
- [x] Backend code sudah support `DB_*` variables
- [ ] Deploy backend ke Railway
- [ ] Test `/api/database/test`
- [ ] Initialize tables via `/api/database/init`
- [ ] Test insert data via ESP32
- [ ] Test query data via `/api/data/latest`

---

## 🎯 Next Steps

### 1. Deploy Backend
```bash
cd backend
git add .
git commit -m "Update database config untuk Railway"
git push
```

### 2. Wait for Railway Deploy
Railway akan auto-deploy (2-3 menit).

### 3. Test Endpoints
```bash
# Health check
curl https://web-production-47eb.up.railway.app/

# Test database
curl https://web-production-47eb.up.railway.app/api/database/test

# Initialize tables
curl -X POST https://web-production-47eb.up.railway.app/api/database/init
```

### 4. Check Logs
Di Railway Dashboard, cek logs untuk:
```
✅ Database connected successfully
✅ Database tables initialized
✅ Server is ready!
```

---

## 🎉 Done!

Konfigurasi Railway Anda sudah **BENAR** dan **SIAP DIGUNAKAN**!

Backend akan otomatis:
- ✅ Connect ke MySQL di `mysql.railway.internal`
- ✅ Create tables di database `railway`
- ✅ Handle REST API requests
- ✅ Connect ke MQTT broker public (HiveMQ)

Tinggal deploy dan test! 🚀
