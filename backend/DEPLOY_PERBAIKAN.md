# Deploy Perbaikan Control Commands ke Railway

## Perubahan yang Dilakukan
✅ Backend sekarang **subscribe ke topic `novil/pengering/control`**  
✅ Handler untuk menyimpan pesan control ke database `control_commands`  
✅ Handler untuk update status relay dari ESP32

## Cara Deploy ke Railway

### Opsi 1: Deploy via Git (Recommended)

#### 1. Commit Perubahan
```bash
cd c:\Users\abilh\aplikasi_novil

# Cek status
git status

# Add file yang berubah
git add backend/server.js
git add PERBAIKAN_CONTROL_COMMANDS.md
git add backend/DEPLOY_PERBAIKAN.md

# Commit
git commit -m "Fix: Subscribe to control topic and save to database"

# Push ke repository
git push origin main
```

#### 2. Railway Auto-Deploy
- Railway akan otomatis detect perubahan
- Build dan deploy akan berjalan otomatis
- Tunggu hingga status "Deployed" (biasanya 2-3 menit)

#### 3. Verifikasi Deployment
```bash
# Cek health check
curl https://your-railway-app.up.railway.app/

# Cek stats
curl https://your-railway-app.up.railway.app/api/stats
```

---

### Opsi 2: Deploy via Railway CLI

#### 1. Install Railway CLI (jika belum)
```bash
# Windows (PowerShell)
iwr https://railway.app/install.ps1 | iex
```

#### 2. Login ke Railway
```bash
railway login
```

#### 3. Link Project
```bash
cd c:\Users\abilh\aplikasi_novil\backend
railway link
```

#### 4. Deploy
```bash
railway up
```

#### 5. Cek Logs
```bash
railway logs
```

---

### Opsi 3: Manual Upload via Railway Dashboard

#### 1. Buka Railway Dashboard
- Login ke https://railway.app
- Pilih project "aplikasi_novil" atau nama project Anda

#### 2. Buka Service Backend
- Klik service backend Anda
- Pilih tab "Deployments"

#### 3. Trigger Redeploy
- Klik tombol "Deploy" atau "Redeploy"
- Pilih branch yang benar (main/master)
- Railway akan pull code terbaru dan deploy

---

## Verifikasi Setelah Deploy

### 1. Cek Logs Railway

Di Railway Dashboard → Service → Logs, pastikan muncul:

```
✅ Subscribed to topics:
   - novil/pengering/data
   - novil/pengering/status
   - novil/pengering/button
   - novil/pengering/control  ← HARUS ADA INI
```

### 2. Test API Health Check

```bash
# Ganti dengan URL Railway Anda
curl https://your-app.up.railway.app/
```

Response:
```json
{
  "status": "OK",
  "message": "Pengering Ikan Backend Server - MQTT Client Enabled",
  "version": "1.0.1",
  "uptime": 123.45,
  "timestamp": "2026-05-29T10:30:00.000Z"
}
```

### 3. Test Stats API

```bash
curl https://your-app.up.railway.app/api/stats
```

Response harus include:
```json
{
  "success": true,
  "stats": {
    "mqttConnected": true,
    "sensorDataCount": 100,
    "statusHistoryCount": 50,
    "controlCommandsCount": 10,  ← HARUS ADA INI
    ...
  }
}
```

### 4. Test Control Command

```bash
# Kirim command test
curl -X POST https://your-app.up.railway.app/api/control \
  -H "Content-Type: application/json" \
  -d '{"command":"HEATER_ON"}'
```

Response:
```json
{
  "success": true,
  "message": "Command sent successfully",
  "command": "HEATER_ON"
}
```

### 5. Cek Database Railway

Login ke Railway MySQL:

```bash
# Via Railway CLI
railway connect MySQL
```

Atau via Railway Dashboard → MySQL → Connect → Copy connection string

Query untuk verifikasi:

```sql
-- Cek apakah ada data di control_commands
SELECT COUNT(*) as total FROM control_commands;

-- Lihat 10 command terakhir
SELECT * FROM control_commands ORDER BY timestamp DESC LIMIT 10;

-- Lihat status relay terakhir
SELECT * FROM status_history 
WHERE message LIKE 'RELAY:%' 
ORDER BY timestamp DESC LIMIT 10;
```

---

## Testing dengan ESP32

### 1. Update Kode ESP32 (jika perlu)

Pastikan ESP32 menggunakan URL Railway yang benar:

```cpp
// Di file esp32_pengering_ikan_railway.ino
const char* mqtt_server = "broker.hivemq.com";
const int mqtt_port = 1883;
```

### 2. Upload ke ESP32

```bash
# Via Arduino IDE atau PlatformIO
# Upload esp32_pengering_ikan_v2.ino
```

### 3. Monitor Serial ESP32

Buka Serial Monitor (115200 baud), pastikan muncul:

```
WiFi Connected
MQTT Connected
Heater → ON
Fan → ON
Data sent: {"suhu":28.5,"berat":450,...}
```

### 4. Cek Railway Logs Real-time

Di Railway Dashboard → Logs, pastikan muncul:

```
📨 MQTT Message received:
   Topic: novil/pengering/control
   Message: STATUS:HEATER_ON
🎛️  Control Message: STATUS:HEATER_ON
📊 Relay Status Update: HEATER_ON
✅ Relay status saved to MySQL database
```

---

## Troubleshooting

### ❌ Logs tidak muncul "Subscribed to control topic"

**Solusi:**
1. Pastikan file `server.js` sudah ter-commit dan ter-push
2. Trigger manual redeploy di Railway Dashboard
3. Cek Railway logs untuk error

### ❌ Database connection failed

**Solusi:**
1. Cek environment variables di Railway Dashboard
2. Pastikan MySQL plugin sudah ter-install
3. Verifikasi `DATABASE_URL` atau `MYSQL*` variables ada

### ❌ MQTT not connected

**Solusi:**
1. Cek `MQTT_BROKER_URL` di Railway environment variables
2. Default: `mqtt://broker.hivemq.com:1883`
3. Pastikan Railway tidak block port 1883

### ❌ Control commands tidak masuk database

**Solusi:**
1. Cek Railway logs: `railway logs`
2. Pastikan ESP32 kirim ke topic yang benar: `novil/pengering/control`
3. Verifikasi database table `control_commands` sudah ada:
   ```sql
   SHOW TABLES;
   DESCRIBE control_commands;
   ```

---

## Checklist Deployment

- [ ] Commit perubahan `server.js`
- [ ] Push ke Git repository
- [ ] Railway auto-deploy selesai (status: Deployed)
- [ ] Cek logs: "Subscribed to control topic" muncul
- [ ] Test API health check berhasil
- [ ] Test API stats menunjukkan `controlCommandsCount`
- [ ] Test kirim command via API berhasil
- [ ] Database table `control_commands` ada data
- [ ] ESP32 connect ke MQTT berhasil
- [ ] ESP32 kirim status relay, muncul di Railway logs
- [ ] Database `control_commands` bertambah saat ESP32 kirim status

---

## URL Penting

Ganti dengan URL Railway Anda:

- **Backend API:** `https://your-app.up.railway.app`
- **Health Check:** `https://your-app.up.railway.app/`
- **Stats:** `https://your-app.up.railway.app/api/stats`
- **Control:** `https://your-app.up.railway.app/api/control`
- **Data History:** `https://your-app.up.railway.app/api/data/history`

---

## Setelah Deploy Berhasil

1. ✅ Update dokumentasi dengan URL Railway yang benar
2. ✅ Test dengan Flutter app (jika ada)
3. ✅ Monitor logs Railway untuk memastikan tidak ada error
4. ✅ Setup monitoring/alerting (optional)
5. ✅ Backup database secara berkala

---

## Kontak & Support

Jika ada masalah:
1. Cek Railway logs: `railway logs`
2. Cek Railway Dashboard → Service → Logs
3. Cek Railway Dashboard → MySQL → Metrics
4. Review dokumentasi: `PERBAIKAN_CONTROL_COMMANDS.md`
