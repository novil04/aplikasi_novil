# 🔧 Fix: Data Tidak Masuk ke MySQL Railway

## 🔍 Masalah yang Ditemukan

### 1. **Backend Tidak Connect ke HiveMQ**
- Backend menggunakan **Aedes** sebagai MQTT Broker internal
- Aedes broker **DISABLED** di Railway (tidak bisa bind port 1883)
- ESP32 publish data ke **HiveMQ** (`broker.hivemq.com`)
- Backend **TIDAK subscribe** ke HiveMQ, jadi tidak terima data dari ESP32

### 2. **Alur Data yang Salah**
```
❌ SEBELUM (TIDAK BERFUNGSI):

ESP32 → HiveMQ (broker.hivemq.com)
                ↓
            (data hilang)
                
Backend Railway (Aedes Broker) → MySQL
                ↑
            (tidak ada data)
```

### 3. **Solusi yang Benar**
```
✅ SESUDAH (BERFUNGSI):

ESP32 → HiveMQ (broker.hivemq.com)
                ↓
        Backend Railway (MQTT Client)
                ↓
            MySQL Database
```

---

## ✅ Perubahan yang Dilakukan

### 1. **Install MQTT Client Package**

**File: `package.json`**
```json
"dependencies": {
  "mqtt": "^5.3.5",  // ← TAMBAHAN BARU
  ...
}
```

**Install:**
```bash
cd backend
npm install mqtt
```

---

### 2. **Backend Connect ke HiveMQ sebagai Client**

**File: `server.js`**

#### Import MQTT Client:
```javascript
const mqtt = require('mqtt');  // ← TAMBAHAN BARU
```

#### Konfigurasi:
```javascript
const MQTT_BROKER_URL = process.env.MQTT_BROKER_URL || 'mqtt://broker.hivemq.com:1883';
const MQTT_TOPICS = {
  data: 'novil/pengering/data',
  status: 'novil/pengering/status',
  button: 'novil/pengering/button',
  control: 'novil/pengering/control'
};
```

#### Connect ke HiveMQ:
```javascript
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
    MQTT_TOPICS.button
  ]);
});
```

#### Handle Messages dari ESP32:
```javascript
mqttClient.on('message', async (topic, message) => {
  const msg = message.toString();
  
  // TOPIC: novil/pengering/data
  if (topic === MQTT_TOPICS.data) {
    const data = JSON.parse(msg);
    
    // Update latestData
    latestData = {
      suhu: data.suhu || 0,
      berat: data.berat || 0,
      target: data.target || 0,
      ...
    };
    
    // Save to MySQL
    await db.insertSensorData(latestData);
    console.log('✅ Data saved to MySQL database');
  }
  
  // TOPIC: novil/pengering/status
  if (topic === MQTT_TOPICS.status) {
    // Update status
    latestData.status = ...;
    
    // Save to MySQL
    await db.insertStatusHistory(msg);
    console.log('✅ Status saved to MySQL database');
  }
  
  // TOPIC: novil/pengering/button
  if (topic === MQTT_TOPICS.button) {
    // Save button event
    await db.insertStatusHistory(`BUTTON: ${msg}`);
    console.log('✅ Button event saved to MySQL database');
  }
});
```

#### Publish Command ke ESP32:
```javascript
app.post('/api/control', async (req, res) => {
  const { command } = req.body;
  
  // Publish to HiveMQ
  mqttClient.publish(MQTT_TOPICS.control, command, { qos: 1 }, (err) => {
    if (err) {
      return res.status(500).json({ success: false, error: err.message });
    }
    
    console.log(`✅ Command published to MQTT: ${command}`);
    res.json({ success: true, command: command });
  });
});
```

---

### 3. **Update Environment Variables**

**File: `.env`**
```env
# MQTT Broker Configuration
MQTT_BROKER_URL=mqtt://broker.hivemq.com:1883

# MySQL Database Configuration (Railway)
# Isi dengan credentials dari Railway MySQL Plugin
DATABASE_URL=mysql://user:password@host:port/database
# atau:
MYSQLHOST=your-railway-mysql-host.railway.app
MYSQLPORT=3306
MYSQLUSER=root
MYSQLPASSWORD=your-password
MYSQLDATABASE=railway
```

---

## 🚀 Cara Deploy ke Railway

### 1. **Install Dependencies**
```bash
cd backend
npm install
```

### 2. **Test Lokal**
```bash
npm start
```

**Expected Output:**
```
🔄 Connecting to MQTT Broker: mqtt://broker.hivemq.com:1883
✅ Connected to MQTT Broker (HiveMQ)
✅ Subscribed to topics:
   - novil/pengering/data
   - novil/pengering/status
   - novil/pengering/button

🚀 REST API running on port 3000
✅ Server is ready!
```

### 3. **Test dengan ESP32**
- Upload sketch ESP32
- Tekan button untuk start pengeringan
- Cek log backend:
```
📨 MQTT Message received:
   Topic: novil/pengering/status
   Message: PENGERINGAN DIMULAI
✅ Status saved to MySQL database

📨 MQTT Message received:
   Topic: novil/pengering/data
   Message: {"suhu":28.5,"berat":450,"target":315}
✅ Data saved to MySQL database
```

### 4. **Push ke GitHub**
```bash
git add .
git commit -m "Fix: Backend connect to HiveMQ as MQTT client"
git push
```

### 5. **Configure Railway Environment Variables**

Di Railway Dashboard:
1. Buka project → Variables
2. Tambahkan:
   - `MQTT_BROKER_URL` = `mqtt://broker.hivemq.com:1883`
3. MySQL credentials sudah otomatis dari Railway MySQL Plugin:
   - `MYSQLHOST`
   - `MYSQLPORT`
   - `MYSQLUSER`
   - `MYSQLPASSWORD`
   - `MYSQLDATABASE`

### 6. **Redeploy**
Railway akan auto-deploy setelah push ke GitHub.

---

## 🧪 Testing

### 1. **Test MQTT Connection**
```bash
curl https://your-app.railway.app/api/stats
```

**Expected Response:**
```json
{
  "success": true,
  "stats": {
    "mqttConnected": true,  // ← Harus true
    "sensorDataCount": 123,
    "statusHistoryCount": 45,
    ...
  }
}
```

### 2. **Test Data dari ESP32**
- Jalankan ESP32
- Tunggu beberapa detik
- Check database:
```bash
curl https://your-app.railway.app/api/data/latest
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "suhu": 28.5,
    "berat": 450.0,
    "target": 315.0,
    "status": "RUNNING",
    "timestamp": "2026-05-28T10:30:00.000Z"
  }
}
```

### 3. **Test History**
```bash
curl https://your-app.railway.app/api/data/history?limit=10
```

**Expected Response:**
```json
{
  "success": true,
  "count": 10,
  "data": [
    {
      "id": 1,
      "suhu": 28.5,
      "berat": 450.0,
      "target": 315.0,
      "timestamp": "2026-05-28 10:30:00"
    },
    ...
  ]
}
```

### 4. **Test Send Command**
```bash
curl -X POST https://your-app.railway.app/api/control \
  -H "Content-Type: application/json" \
  -d '{"command":"HEATER_ON"}'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Command sent successfully",
  "command": "HEATER_ON"
}
```

**Check ESP32 Serial Monitor:**
```
MQTT Message [novil/pengering/control] : HEATER_ON
HEATER ON
```

---

## 📊 Monitoring

### Railway Logs
```bash
# Di Railway Dashboard → Deployments → View Logs
```

**Expected Logs:**
```
✅ Connected to MQTT Broker (HiveMQ)
✅ Subscribed to topics
📨 MQTT Message received: novil/pengering/data
✅ Data saved to MySQL database
📨 MQTT Message received: novil/pengering/status
✅ Status saved to MySQL database
```

### ESP32 Serial Monitor
```
MQTT Data Sent: {"suhu":28.5,"berat":450,"target":315}
MQTT Data Sent: {"suhu":28.6,"berat":448,"target":315}
```

---

## 🔍 Troubleshooting

### Problem: `mqttConnected: false`

**Cause:** Backend tidak bisa connect ke HiveMQ

**Solution:**
1. Check Railway logs untuk error
2. Pastikan `MQTT_BROKER_URL` benar
3. Check firewall/network Railway

---

### Problem: Data masih tidak masuk ke MySQL

**Cause:** Database credentials salah

**Solution:**
1. Check Railway MySQL Plugin variables
2. Pastikan `MYSQLHOST`, `MYSQLUSER`, `MYSQLPASSWORD`, `MYSQLDATABASE` benar
3. Test connection:
```bash
curl https://your-app.railway.app/api/database/test
```

---

### Problem: ESP32 tidak terima command

**Cause:** ESP32 tidak subscribe ke topic control

**Solution:**
1. Check ESP32 Serial Monitor:
```
Subscribed to: novil/pengering/control
```
2. Restart ESP32
3. Check MQTT connection

---

## 📝 Ringkasan Perubahan

| Aspek | Sebelum | Sesudah |
|-------|---------|---------|
| MQTT Role | ❌ Broker (Aedes) | ✅ Client (mqtt.js) |
| Connect to HiveMQ | ❌ Tidak | ✅ Ya |
| Subscribe Topics | ❌ Tidak | ✅ Ya (data, status, button) |
| Publish Commands | ⚠️ Via Aedes | ✅ Via HiveMQ |
| Save to MySQL | ❌ Tidak ada data | ✅ Berfungsi |
| Package | Aedes only | ✅ Aedes + mqtt |

---

## ✅ Checklist

### Pre-Deploy:
- [x] Install package `mqtt`
- [x] Update `server.js` dengan MQTT client
- [x] Update `.env` dengan MQTT_BROKER_URL
- [x] Test lokal

### Deploy:
- [ ] Push ke GitHub
- [ ] Configure Railway environment variables
- [ ] Wait for auto-deploy
- [ ] Check Railway logs

### Post-Deploy:
- [ ] Test `/api/stats` → `mqttConnected: true`
- [ ] Test ESP32 → data masuk ke MySQL
- [ ] Test `/api/data/latest` → ada data
- [ ] Test `/api/data/history` → ada history
- [ ] Test send command → ESP32 terima

---

## 🎯 Expected Result

Setelah fix ini:

1. ✅ Backend connect ke HiveMQ sebagai MQTT client
2. ✅ Backend subscribe ke topic `novil/pengering/data`, `status`, `button`
3. ✅ ESP32 publish data → Backend terima → Save ke MySQL
4. ✅ Flutter send command → Backend publish ke HiveMQ → ESP32 terima
5. ✅ Data history tersimpan di MySQL Railway
6. ✅ Status history tersimpan di MySQL Railway

---

Selamat mencoba! 🚀🎉
