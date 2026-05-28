# 🔧 Troubleshooting Railway Deployment

## ❌ Error 502: Application Failed to Respond

### Penyebab Umum:

1. **Missing Dependencies**
2. **Port Binding Error**
3. **Database Connection Failed**
4. **Syntax Error di Code**
5. **Environment Variables Salah**

---

## 🔍 Cara Debug

### 1. Cek Railway Logs

**Di Railway Dashboard:**
1. Go to your project
2. Click service name
3. Click "Deployments"
4. Click latest deployment
5. View "Deploy Logs" dan "Application Logs"

**Cari error:**
```
Error: Cannot find module 'websocket-stream'
Error: listen EADDRINUSE: address already in use :::1883
Error: connect ECONNREFUSED
SyntaxError: Unexpected token
```

---

## 🛠️ Fix yang Sudah Dilakukan

### Fix 1: Remove `digitalRead()` Error
**Error:**
```javascript
relay1: digitalRead(RELAY1) === 'LOW',  // ❌ Arduino function in Node.js
```

**Fix:**
```javascript
relay1: latestData.relay1 || false,  // ✅ Keep current status
```

**Status:** ✅ FIXED (commit b08ad68)

---

### Fix 2: Disable MQTT Broker
**Error:**
```
Error: listen EADDRINUSE: address already in use :::1883
```

**Penyebab:** Railway tidak support custom ports (1883, 8883)

**Fix:**
```javascript
if (process.env.ENABLE_MQTT_BROKER === 'true') {
  mqttServer.listen(MQTT_PORT, () => {
    console.log(`🚀 MQTT Broker running`);
  }).on('error', (err) => {
    console.warn(`⚠️  MQTT Broker failed`);
  });
} else {
  console.log('ℹ️  MQTT Broker disabled');
}
```

**Status:** ✅ FIXED (commit b08ad68)

---

### Fix 3: Add Missing Dependency
**Error:**
```
Error: Cannot find module 'websocket-stream'
```

**Penyebab:** `websocket-stream` digunakan di code tapi tidak ada di `package.json`

**Fix:**
```json
{
  "dependencies": {
    "websocket-stream": "^5.5.2"  // ✅ Added
  }
}
```

**Status:** ✅ FIXED (commit 794201c)

---

## 🧪 Test Deployment

### Tunggu 2-3 Menit
Railway perlu waktu untuk:
1. Pull code dari GitHub
2. Install dependencies (`npm install`)
3. Build (jika perlu)
4. Start server (`npm start`)

### Test Health Check
```powershell
# PowerShell
Invoke-WebRequest -Uri "https://web-production-47eb.up.railway.app/" -UseBasicParsing

# Expected Response:
# StatusCode: 200
# Content: {"status":"OK","message":"Pengering Ikan Backend Server",...}
```

### Test Database
```powershell
Invoke-WebRequest -Uri "https://web-production-47eb.up.railway.app/api/database/test" -UseBasicParsing

# Expected Response:
# {"success":true,"message":"Database connection successful"}
```

---

## 📊 Expected Railway Logs

### Successful Deployment:
```
Building...
✓ Dependencies installed
✓ Build completed

Starting...
📦 Using MYSQL_URL for connection
🔧 Database Config: { host: 'mysql.railway.internal', ... }
✅ Database connected successfully
✅ Database tables initialized
ℹ️  MQTT Broker disabled (use external MQTT broker like HiveMQ)
ℹ️  WebSocket MQTT disabled
🚀 REST API running on port 3000
✅ Server is ready!
```

### Failed Deployment:
```
Building...
✓ Dependencies installed

Starting...
Error: Cannot find module 'xxx'
  at Function.Module._resolveFilename
  ...
Application exited with code 1
```

---

## 🔄 Jika Masih Error 502

### 1. Cek Railway Logs
Lihat error message di logs.

### 2. Cek Environment Variables
Pastikan ada:
```
MYSQL_URL=mysql://root:...@mysql.railway.internal:3306/railway
NODE_ENV=production
PORT=3000
```

### 3. Cek Dependencies
Pastikan semua dependencies ada di `package.json`:
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "aedes": "^0.51.3",
    "ws": "^8.16.0",
    "websocket-stream": "^5.5.2",  // ← Harus ada!
    "dotenv": "^16.4.5",
    "morgan": "^1.10.0",
    "mysql2": "^3.9.1"
  }
}
```

### 4. Test Locally
```bash
cd backend
npm install
npm start

# Jika error, fix dulu sebelum push
```

### 5. Restart Railway Service
Di Railway Dashboard:
- Click service
- Click "Settings"
- Click "Restart"

---

## 📝 Checklist Deployment

- [x] Fix `digitalRead()` error
- [x] Disable MQTT broker
- [x] Add `websocket-stream` dependency
- [ ] Wait for Railway deploy (2-3 menit)
- [ ] Test health check endpoint
- [ ] Test database connection
- [ ] Initialize database tables
- [ ] Test with ESP32

---

## 🎯 Next Steps

### 1. Tunggu Deploy Selesai
Railway sedang deploy dengan fix terbaru.

### 2. Test Endpoints
```powershell
cd C:\Users\abilh\aplikasi_novil\backend
.\test-railway.ps1
```

### 3. Cek Logs
Jika masih error, cek Railway logs untuk error message.

### 4. Initialize Database
```powershell
Invoke-WebRequest -Uri "https://web-production-47eb.up.railway.app/api/database/init" -Method POST -UseBasicParsing
```

---

## 🆘 Jika Masih Gagal

### Option 1: Simplify Server
Buat versi minimal tanpa MQTT:
```javascript
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ status: 'OK' });
});

app.listen(3000, () => {
  console.log('Server running');
});
```

Test apakah ini bisa deploy. Jika bisa, tambahkan fitur satu per satu.

### Option 2: Check Railway Status
Cek https://status.railway.app/ untuk service outage.

### Option 3: Redeploy
Di Railway Dashboard:
- Click "Deployments"
- Click "Redeploy" pada deployment terakhir

---

## 📚 Resources

- **Railway Docs:** https://docs.railway.app/
- **Railway Logs:** Railway Dashboard → Deployments → View Logs
- **GitHub Repo:** https://github.com/novil04/backend_aplikasi_novil

---

## ✅ Current Status

**Latest Commit:** 794201c - Add missing websocket-stream dependency  
**Deploy Status:** ⏳ Deploying...  
**Expected Time:** 2-3 minutes  

Tunggu deploy selesai, lalu test! 🚀
