# 🔄 Perubahan Backend untuk ESP32

## ✅ Perubahan yang Dilakukan

### 1. **Update MQTT Handler di `server.js`**

#### ✨ Handler untuk `novil/pengering/data`
**Sebelum:**
```javascript
// Hanya parse JSON dan simpan
latestData = { ...data, timestamp: new Date().toISOString() };
```

**Sesudah:**
```javascript
// Parse JSON dengan field yang sesuai ESP32
latestData = {
  suhu: data.suhu || 0,
  berat: data.berat || 0,
  target: data.target || 0,
  relay1: false,  // Akan diupdate dari status
  relay2: false,
  relay3: false,
  relay4: false,
  status: latestData.status,
  timestamp: new Date().toISOString()
};
```

**Alasan:** ESP32 hanya kirim `suhu`, `berat`, `target` (tidak kirim relay status)

---

#### ✨ Handler untuk `novil/pengering/status`
**Ditambahkan:** Auto-update status berdasarkan pesan

```javascript
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
```

**Alasan:** Status otomatis terupdate sesuai pesan dari ESP32

---

#### ✨ Handler untuk `novil/pengering/button` (BARU)
**Ditambahkan:** Handler untuk event button

```javascript
if (topic === 'novil/pengering/button') {
  console.log('🔘 Button Event:', message);
  await db.insertStatusHistory(`BUTTON: ${message}`);
}
```

**Alasan:** ESP32 publish event button press ke topic ini

---

### 2. **Update Endpoint `/api/control`**

**Ditambahkan:** Command `START` dan `RESET`

```javascript
const validCommands = [
  'HEATER_ON', 'HEATER_OFF',
  'FAN_ON', 'FAN_OFF',
  'LAMP_ON', 'LAMP_OFF',
  'EXHAUST_ON', 'EXHAUST_OFF',
  'START',  // ← BARU
  'RESET'   // ← BARU
];
```

**Alasan:** Flutter bisa start/reset pengeringan via API

---

### 3. **Fix Timestamp Format di `database.js`**

**Sebelum:**
```javascript
data.timestamp || new Date()  // ❌ Format ISO tidak diterima MySQL
```

**Sesudah:**
```javascript
const date = new Date(data.timestamp);
const mysqlTimestamp = date.toISOString().slice(0, 19).replace('T', ' ');
// Hasil: '2026-05-28 10:30:00' ✅
```

**Alasan:** MySQL DATETIME tidak terima format ISO dengan 'Z'

---

## 📡 MQTT Topics yang Digunakan

| Topic | Direction | Format | Keterangan |
|-------|-----------|--------|------------|
| `novil/pengering/data` | ESP32 → Backend | JSON | Data sensor (suhu, berat, target) |
| `novil/pengering/status` | ESP32 → Backend | String | Status/event penting |
| `novil/pengering/button` | ESP32 → Backend | String | Event button press |
| `novil/pengering/control` | Backend → ESP32 | String | Command kontrol relay/sistem |

---

## 🌐 REST API Endpoints

### Endpoint untuk Flutter App:

1. **GET /api/data/latest** - Ambil data terbaru
2. **GET /api/data/history?limit=50** - Ambil riwayat data
3. **GET /api/status/history?limit=50** - Ambil riwayat status
4. **POST /api/control** - Kirim command (START, RESET, HEATER_ON, dll)
5. **GET /api/stats** - Ambil statistik
6. **DELETE /api/history/clear** - Hapus riwayat

### Endpoint untuk Testing:

7. **GET /** - Health check
8. **POST /api/database/init** - Init database (sekali saja)
9. **GET /api/database/test** - Test koneksi database

---

## 🔄 Flow Komunikasi

### ESP32 → Backend (via MQTT)
```
ESP32 publish:
├── novil/pengering/data      → Data sensor setiap 1 detik
├── novil/pengering/status    → Status/event penting
└── novil/pengering/button    → Event button press

Backend:
├── Terima via MQTT
├── Update latestData
└── Simpan ke MySQL
```

### Flutter → ESP32 (via Backend)
```
Flutter:
└── POST /api/control {"command":"HEATER_ON"}

Backend:
├── Terima REST API
├── Simpan command ke database
└── Publish ke MQTT: novil/pengering/control

ESP32:
└── Subscribe novil/pengering/control
    └── Eksekusi command (nyalakan relay)
```

---

## 🚀 Cara Deploy

### 1. Push ke GitHub
```bash
cd backend
git add .
git commit -m "Update backend untuk ESP32 MQTT integration"
git push
```

### 2. Railway Auto-Deploy
Railway akan otomatis detect perubahan dan deploy ulang.

### 3. Test Endpoint
```bash
# Health check
curl https://web-production-47eb.up.railway.app/

# Get latest data
curl https://web-production-47eb.up.railway.app/api/data/latest

# Send command
curl -X POST https://web-production-47eb.up.railway.app/api/control \
  -H "Content-Type: application/json" \
  -d '{"command":"START"}'
```

---

## 📝 Catatan Penting

### ✅ Yang Sudah Kompatibel:
- ✅ MQTT topics sesuai dengan ESP32
- ✅ Format data JSON sesuai
- ✅ Command START dan RESET tersedia
- ✅ Status auto-update dari pesan ESP32
- ✅ Timestamp format MySQL sudah fix

### ⚠️ Yang Perlu Diperhatikan:

1. **ESP32 tidak kirim relay status** di topic `data`
   - Backend tidak bisa tahu relay ON/OFF dari data
   - Solusi: Tracking relay status di backend saat kirim command

2. **MQTT Broker**
   - ESP32 pakai: `broker.hivemq.com` (public)
   - Railway mungkin tidak bisa host MQTT broker sendiri
   - Solusi: Tetap pakai HiveMQ public atau upgrade Railway plan

3. **Database Connection**
   - Pastikan Railway MySQL sudah setup
   - Environment variables harus diisi:
     - `DB_HOST`
     - `DB_PORT`
     - `DB_USER`
     - `DB_PASSWORD`
     - `DB_NAME`

---

## 🧪 Testing Checklist

- [ ] ESP32 connect ke MQTT broker
- [ ] ESP32 publish data ke `novil/pengering/data`
- [ ] Backend terima dan simpan data ke MySQL
- [ ] ESP32 publish status ke `novil/pengering/status`
- [ ] Backend update status otomatis
- [ ] Flutter kirim command via `/api/control`
- [ ] ESP32 terima command dari `novil/pengering/control`
- [ ] Relay ON/OFF sesuai command
- [ ] Flutter ambil data via `/api/data/latest`
- [ ] Flutter ambil history via `/api/data/history`

---

## 📚 File yang Berubah

1. ✅ `server.js` - Update MQTT handlers dan endpoint
2. ✅ `database.js` - Fix timestamp format
3. ✅ `API_DOCUMENTATION.md` - Dokumentasi lengkap API (BARU)
4. ✅ `PERUBAHAN_BACKEND.md` - Ringkasan perubahan (BARU)

---

## 🎯 Next Steps

1. **Push ke GitHub dan deploy ke Railway**
2. **Test ESP32 connection**
3. **Update Flutter app untuk pakai endpoint baru**
4. **Test end-to-end flow**

Selamat mencoba! 🚀
