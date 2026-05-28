# 🔧 Fix Railway 502 Error

## ❌ Masalah yang Ditemukan

### 1. **Error: `digitalRead()` is not defined**
Di `server.js` baris 105-108, ada kode Arduino yang tidak valid di Node.js:
```javascript
relay1: digitalRead(RELAY1) === 'LOW',  // ❌ ERROR!
```

**Penyebab:** Copy-paste dari kode Arduino ke Node.js

**Fix:** Ganti dengan keep current relay status:
```javascript
relay1: latestData.relay1 || false,  // ✅ FIXED
```

---

### 2. **Error: MQTT Broker Port Binding Failed**
Railway tidak support custom ports (1883, 8883) untuk MQTT broker.

**Penyebab:** 
```javascript
mqttServer.listen(MQTT_PORT, () => {  // ❌ Port 1883 tidak tersedia
  console.log(`🚀 MQTT Broker running on port ${MQTT_PORT}`);
});
```

**Fix:** Disable MQTT broker di Railway, gunakan external broker (HiveMQ):
```javascript
if (process.env.ENABLE_MQTT_BROKER === 'true') {
  mqttServer.listen(MQTT_PORT, () => {
    console.log(`🚀 MQTT Broker running on port ${MQTT_PORT}`);
  }).on('error', (err) => {
    console.warn(`⚠️  MQTT Broker failed to start`);
  });
} else {
  console.log('ℹ️  MQTT Broker disabled (use external MQTT broker)');
}
```

---

## ✅ Perubahan yang Dilakukan

### File: `server.js`

#### 1. Fix `digitalRead()` Error
**Baris 100-111:**
```javascript
// SEBELUM (❌ ERROR):
latestData = {
  suhu: data.suhu || 0,
  berat: data.berat || 0,
  target: data.target || 0,
  relay1: digitalRead(RELAY1) === 'LOW',  // ❌
  relay2: digitalRead(RELAY2) === 'LOW',  // ❌
  relay3: digitalRead(RELAY3) === 'LOW',  // ❌
  relay4: digitalRead(RELAY4) === 'LOW',  // ❌
  status: latestData.status,
  timestamp: new Date().toISOString()
};

// SESUDAH (✅ FIXED):
latestData = {
  suhu: data.suhu || 0,
  berat: data.berat || 0,
  target: data.target || 0,
  relay1: latestData.relay1 || false,  // ✅ Keep current status
  relay2: latestData.relay2 || false,  // ✅
  relay3: latestData.relay3 || false,  // ✅
  relay4: latestData.relay4 || false,  // ✅
  status: latestData.status,
  timestamp: new Date().toISOString()
};
```

#### 2. Disable MQTT Broker di Railway
**Baris 180-210:**
```javascript
// SEBELUM (❌ CRASH):
mqttServer.listen(MQTT_PORT, () => {
  console.log(`🚀 MQTT Broker running on port ${MQTT_PORT}`);
});

httpServer.listen(WS_PORT, () => {
  console.log(`🌐 WebSocket MQTT running on port ${WS_PORT}`);
});

// SESUDAH (✅ FIXED):
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

if (process.env.ENABLE_MQTT_BROKER === 'true') {
  httpServer.listen(WS_PORT, () => {
    console.log(`🌐 WebSocket MQTT running on port ${WS_PORT}`);
  }).on('error', (err) => {
    console.warn(`⚠️  WebSocket MQTT failed to start on port ${WS_PORT}:`, err.message);
  });
} else {
  console.log('ℹ️  WebSocket MQTT disabled');
}
```

---

## 🚀 Deploy

```bash
cd backend
git add .
git commit -m "Fix: Remove digitalRead error and disable MQTT broker in Railway"
git push
```

✅ **Pushed to GitHub!** Railway akan auto-deploy dalam 2-3 menit.

---

## 🧪 Test Setelah Deploy

Tunggu 2-3 menit, lalu test:

### PowerShell:
```powershell
# Health check
Invoke-WebRequest -Uri "https://web-production-47eb.up.railway.app/" -UseBasicParsing

# Test database
Invoke-WebRequest -Uri "https://web-production-47eb.up.railway.app/api/database/test" -UseBasicParsing

# Initialize tables
Invoke-WebRequest -Uri "https://web-production-47eb.up.railway.app/api/database/init" -Method POST -UseBasicParsing

# Get latest data
Invoke-WebRequest -Uri "https://web-production-47eb.up.railway.app/api/data/latest" -UseBasicParsing
```

### Browser:
```
https://web-production-47eb.up.railway.app/
https://web-production-47eb.up.railway.app/api/database/test
https://web-production-47eb.up.railway.app/api/data/latest
```

---

## 📊 Expected Logs di Railway

Setelah deploy berhasil, Railway logs akan menampilkan:

```
📦 Using MYSQL_URL for connection
🔧 Database Config: {
  host: 'mysql.railway.internal',
  port: 3306,
  user: 'root',
  database: 'railway',
  password: '***'
}
✅ Database connected successfully
✅ Database tables initialized
ℹ️  MQTT Broker disabled (use external MQTT broker like HiveMQ)
ℹ️  WebSocket MQTT disabled
🚀 REST API running on port 3000
✅ Server is ready!
```

---

## 🔄 Arsitektur Baru

### Sebelum (❌ CRASH):
```
Backend di Railway:
├── REST API ✅
├── MQTT Broker (port 1883) ❌ CRASH!
└── WebSocket MQTT (port 8883) ❌ CRASH!
```

### Sesudah (✅ WORKS):
```
Backend di Railway:
└── REST API ✅ (port 3000)

MQTT Broker External (HiveMQ):
└── broker.hivemq.com:1883 ✅

ESP32:
├── Connect ke HiveMQ ✅
└── Publish data ✅

Flutter:
├── Connect ke HiveMQ (real-time) ✅
└── Call REST API (control) ✅
```

---

## 📝 Catatan Penting

### 1. **MQTT Broker di Railway**
Railway **TIDAK SUPPORT** custom ports untuk MQTT broker.
- ❌ Port 1883 (MQTT) tidak bisa digunakan
- ❌ Port 8883 (WebSocket MQTT) tidak bisa digunakan
- ✅ Solusi: Gunakan **HiveMQ Cloud** (public MQTT broker)

### 2. **ESP32 Configuration**
ESP32 harus connect ke **HiveMQ**, bukan Railway:
```cpp
const char* mqtt_server = "broker.hivemq.com";  // ✅ Public broker
// BUKAN: "web-production-47eb.up.railway.app"  // ❌ Tidak support MQTT
```

### 3. **Relay Status Tracking**
Backend tidak bisa tahu relay status dari MQTT (ESP32 tidak kirim).
- Backend track relay status saat kirim command via `/api/control`
- Flutter ambil relay status dari `/api/data/latest`

---

## ✅ Checklist

- [x] Fix `digitalRead()` error
- [x] Disable MQTT broker di Railway
- [x] Add error handling untuk port binding
- [x] Commit dan push ke GitHub
- [ ] Tunggu Railway deploy (2-3 menit)
- [ ] Test endpoints
- [ ] Cek Railway logs
- [ ] Initialize database tables
- [ ] Test dengan ESP32

---

## 🎉 Done!

Backend sekarang akan:
- ✅ Start tanpa crash
- ✅ Connect ke MySQL Railway
- ✅ Handle REST API requests
- ✅ Tidak mencoba start MQTT broker (karena tidak support)

ESP32 dan Flutter akan connect ke **HiveMQ** untuk MQTT, dan call **Railway** untuk REST API.

Selamat! 🚀
