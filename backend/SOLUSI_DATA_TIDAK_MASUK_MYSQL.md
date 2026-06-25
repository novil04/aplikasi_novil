# 🔧 SOLUSI: Data ESP32 Tidak Masuk ke MySQL Railway

## 🎯 Masalah

ESP32 sudah publish data ke MQTT, tapi data **tidak masuk ke MySQL** di Railway.

---

## 🔍 Penyebab

### Arsitektur yang Salah:

```
❌ SEBELUM:

ESP32 → HiveMQ (broker.hivemq.com)
                ↓
            (data hilang di sini)
                
Backend Railway (Aedes Broker Internal - DISABLED)
                ↓
            MySQL (tidak ada data)
```

**Masalah:**
1. ESP32 publish ke **HiveMQ** public broker
2. Backend Railway menggunakan **Aedes** (MQTT broker internal)
3. Aedes **DISABLED** di Railway (tidak bisa bind port 1883)
4. Backend **TIDAK connect** ke HiveMQ
5. Backend **TIDAK subscribe** ke topic ESP32
6. **Data hilang** karena tidak ada yang terima

---

## ✅ Solusi

### Arsitektur yang Benar:

```
✅ SESUDAH:

ESP32 → HiveMQ (broker.hivemq.com)
                ↓
        Backend Railway (MQTT Client)
                ↓ (subscribe & save)
            MySQL Database
```

**Perubahan:**
1. Backend connect ke **HiveMQ sebagai MQTT Client**
2. Backend **subscribe** ke topic ESP32
3. Backend **terima data** dari ESP32
4. Backend **save ke MySQL**

---

## 🛠️ Perubahan yang Sudah Dilakukan

### 1. **Install Package MQTT Client**
```bash
npm install mqtt
```

### 2. **Update `server.js`**
- Tambah import `mqtt` client
- Connect ke HiveMQ sebagai client
- Subscribe ke topic: `novil/pengering/data`, `status`, `button`
- Handle message dan save ke MySQL
- Publish command via HiveMQ

### 3. **Update `.env`**
- Tambah `MQTT_BROKER_URL=mqtt://broker.hivemq.com:1883`
- Tambah template untuk MySQL credentials

---

## 🚀 Cara Deploy

### 1. **Test Lokal (Optional)**

```bash
cd backend
npm install
npm start
```

**Expected Output:**
```
✅ Connected to MQTT Broker (HiveMQ)
✅ Subscribed to topics:
   - novil/pengering/data
   - novil/pengering/status
   - novil/pengering/button
🚀 REST API running on port 3000
```

### 2. **Push ke GitHub**

```bash
cd backend
git add .
git commit -m "Fix: Backend connect to HiveMQ as MQTT client"
git push
```

### 3. **Configure Railway**

Di Railway Dashboard:

1. Buka project → **Variables**
2. Tambahkan variable baru:
   - **Key:** `MQTT_BROKER_URL`
   - **Value:** `mqtt://broker.hivemq.com:1883`
3. MySQL credentials sudah otomatis dari Railway MySQL Plugin (tidak perlu diubah)

### 4. **Wait for Auto-Deploy**

Railway akan otomatis deploy setelah push ke GitHub.

---

## 🧪 Testing

### 1. **Check MQTT Connection**

```bash
curl https://your-app.railway.app/api/stats
```

**Expected Response:**
```json
{
  "success": true,
  "stats": {
    "mqttConnected": true,  // ← HARUS TRUE
    "sensorDataCount": 0,
    "statusHistoryCount": 0,
    ...
  }
}
```

**Jika `mqttConnected: false`:**
- Check Railway logs
- Pastikan `MQTT_BROKER_URL` sudah ditambahkan
- Redeploy

---

### 2. **Test dengan ESP32**

1. **Upload sketch ESP32** (tidak perlu diubah)
2. **Buka Serial Monitor** (115200 baud)
3. **Tekan button** untuk start pengeringan
4. **Tunggu 5 detik** (scan berat)
5. **Check Serial Monitor:**
```
MQTT Data Sent: {"suhu":28.5,"berat":450,"target":315}
MQTT Data Sent: {"suhu":28.6,"berat":448,"target":315}
```

---

### 3. **Check Data di MySQL**

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

**Jika data masih kosong:**
- Check Railway logs untuk error
- Pastikan ESP32 sudah publish data
- Check MySQL credentials

---

### 4. **Check History**

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
      "relay1": true,
      "relay2": true,
      "relay3": true,
      "relay4": false,
      "status": "RUNNING",
      "timestamp": "2026-05-28 10:30:00"
    },
    ...
  ]
}
```

---

### 5. **Test Send Command**

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

Di Railway Dashboard → Deployments → View Logs

**Expected Logs:**
```
🔄 Connecting to MQTT Broker: mqtt://broker.hivemq.com:1883
✅ Connected to MQTT Broker (HiveMQ)
✅ Subscribed to topics:
   - novil/pengering/data
   - novil/pengering/status
   - novil/pengering/button

📨 MQTT Message received:
   Topic: novil/pengering/data
   Message: {"suhu":28.5,"berat":450,"target":315}
✅ Data saved to MySQL database

📨 MQTT Message received:
   Topic: novil/pengering/status
   Message: PENGERINGAN DIMULAI
✅ Status saved to MySQL database
```

---

## 🔍 Troubleshooting

### Problem 1: `mqttConnected: false`

**Penyebab:** Backend tidak bisa connect ke HiveMQ

**Solusi:**
1. Check Railway logs untuk error message
2. Pastikan variable `MQTT_BROKER_URL` sudah ditambahkan
3. Pastikan value: `mqtt://broker.hivemq.com:1883` (bukan `http://`)
4. Redeploy

---

### Problem 2: Data masih tidak masuk ke MySQL

**Penyebab:** Database credentials salah atau database belum diinit

**Solusi:**

1. **Test database connection:**
```bash
curl https://your-app.railway.app/api/database/test
```

2. **Initialize database tables:**
```bash
curl -X POST https://your-app.railway.app/api/database/init
```

3. **Check MySQL credentials di Railway:**
   - `MYSQLHOST`
   - `MYSQLPORT`
   - `MYSQLUSER`
   - `MYSQLPASSWORD`
   - `MYSQLDATABASE`

---

### Problem 3: ESP32 tidak terima command

**Penyebab:** ESP32 tidak subscribe atau MQTT disconnect

**Solusi:**

1. **Check ESP32 Serial Monitor:**
```
MQTT Connected
Subscribed to: novil/pengering/control
```

2. **Restart ESP32**

3. **Check WiFi connection**

---

### Problem 4: Railway logs error "Cannot find module 'mqtt'"

**Penyebab:** Package `mqtt` belum terinstall

**Solusi:**

1. **Pastikan `package.json` sudah update:**
```json
"dependencies": {
  "mqtt": "^5.3.5",
  ...
}
```

2. **Push ke GitHub lagi:**
```bash
git add package.json
git commit -m "Add mqtt package"
git push
```

---

## ✅ Checklist

### Pre-Deploy:
- [x] Package `mqtt` sudah ditambahkan di `package.json`
- [x] `server.js` sudah diupdate dengan MQTT client
- [x] `.env` sudah ada template MySQL credentials
- [x] `npm install` berhasil

### Deploy:
- [ ] Push ke GitHub
- [ ] Tambahkan `MQTT_BROKER_URL` di Railway Variables
- [ ] Wait for auto-deploy (2-3 menit)
- [ ] Check Railway logs untuk "Connected to MQTT Broker"

### Testing:
- [ ] Test `/api/stats` → `mqttConnected: true`
- [ ] Upload ESP32 sketch
- [ ] Test ESP32 publish data
- [ ] Test `/api/data/latest` → ada data
- [ ] Test `/api/data/history` → ada history
- [ ] Test send command → ESP32 terima

---

## 📝 Catatan Penting

1. **ESP32 tidak perlu diubah** - sketch tetap sama
2. **MySQL credentials** sudah otomatis dari Railway MySQL Plugin
3. **HiveMQ** adalah public broker, gratis, tidak perlu registrasi
4. **Backend sekarang sebagai MQTT Client**, bukan broker
5. **Aedes broker tetap ada** tapi disabled (untuk future use)

---

## 🎯 Expected Result

Setelah deploy:

1. ✅ Backend connect ke HiveMQ
2. ✅ Backend subscribe ke topic ESP32
3. ✅ ESP32 publish data → Backend terima
4. ✅ Backend save data ke MySQL
5. ✅ Data history tersimpan
6. ✅ Status history tersimpan
7. ✅ Command dari Flutter → ESP32 berfungsi

---

## 📞 Support

Jika masih ada masalah:

1. **Check Railway Logs** untuk error detail
2. **Check ESP32 Serial Monitor** untuk MQTT status
3. **Test API endpoints** untuk verify data
4. **Baca dokumentasi lengkap** di `backend/FIX_MQTT_MYSQL.md`

---

Selamat mencoba! 🚀🎉
