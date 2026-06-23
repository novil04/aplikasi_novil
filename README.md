# 📱 Aplikasi Monitoring Pengering Ikan

Aplikasi mobile untuk monitoring sistem pengering ikan otomatis berbasis IoT dengan ESP32.

---

## 🎯 Fitur Utama

- ✅ **Monitoring Real-time** - Data update setiap 5 detik
- ✅ **Push Notifications** - Notifikasi status pengeringan
- ✅ **Dashboard Lengkap** - Suhu, berat, target, status device
- ✅ **Cloud Backend** - Data tersimpan di Railway MySQL
- ✅ **Display Only** - Monitoring tanpa kontrol manual

---

## 🏗️ Arsitektur Sistem

```
ESP32 (Hardware)
    ↓
    ↓ MQTT Publish
    ↓
Backend Railway (Node.js)
    ↓
    ↓ Save to Database
    ↓
MySQL Database
    ↑
    ↑ API Polling (5 detik)
    ↑
Aplikasi Flutter (Android)
```

---

## 📦 Komponen

### 1. **Hardware (ESP32)**
- File: `esp32_pengering_ikan_railway.ino`
- Sensor: DHT22 (suhu), HX711 (berat)
- Relay: 4 channel (Heater, Fan, Lamp, Exhaust)
- Koneksi: WiFi + MQTT

### 2. **Backend (Node.js)**
- Folder: `backend/`
- Framework: Express.js
- Database: MySQL (Railway)
- MQTT Client: Subscribe dari ESP32
- REST API: Endpoint untuk aplikasi

### 3. **Mobile App (Flutter)**
- Folder: `lib/`
- Platform: Android
- Update: API polling 5 detik
- Notifikasi: flutter_local_notifications

---

## 🚀 Quick Start

### Build APK:
```bash
# Jalankan script build
.\build-with-icon.ps1

# Atau manual
flutter build apk --release
```

### Install di HP:
1. Copy `PengeringIkan.apk` dari Desktop
2. Install di HP Android
3. Izinkan notifikasi
4. Buka aplikasi

---

## 📱 Tampilan Aplikasi

### Status Card
- Status sistem (READY, SCANNING, BERJALAN, SELESAI)
- Waktu mulai & durasi
- Pesan status

### Metrics
- 🌡️ Suhu (°C)
- ⚖️ Berat (gram)
- 🎯 Target berat (gram)

### Device Status
- 🔥 Heater (ON/OFF)
- 💨 Fan (ON/OFF)
- 🌪️ Exhaust (ON/OFF)

### Connection Indicator
- ☁️🟢 API Connected
- ☁️🔴 API Disconnected

---

## 🔔 Notifikasi

Aplikasi mengirim push notification saat:

1. **Pengeringan Siap** (Status → READY)
2. **Ikan Terdeteksi** (Status → BERJALAN)
3. **Pengeringan Selesai** (Status → SELESAI)

Notifikasi muncul di dalam & luar aplikasi.

---

## 🔧 Konfigurasi

### Backend URL:
```dart
// lib/services/api_service.dart
static const String baseUrl = 'https://web-production-47eb.up.railway.app';
```

### Polling Interval:
```dart
// lib/screens/dashboard_screen_with_api.dart
Timer.periodic(const Duration(seconds: 5), ...);
```

### MQTT Topics (Backend):
```javascript
// backend/server.js
const TOPIC_DATA = 'novil/pengering/data';
const TOPIC_STATUS = 'novil/pengering/status';
const TOPIC_CONTROL = 'novil/pengering/control';
```

---

## 📊 API Endpoints

Dokumentasi lengkap: `backend/API_DOCUMENTATION.md`

### Main Endpoints:
- `GET /` - Health check
- `GET /api/data/latest` - Data sensor terbaru
- `GET /api/data/history` - Riwayat data
- `GET /api/status/history` - Riwayat status
- `GET /api/stats` - Statistik

---

## 🛠️ Development

### Requirements:
- Flutter SDK 3.5+
- Android SDK
- Node.js 18+
- MySQL 8.0+

### Setup Backend:
```bash
cd backend
npm install
npm start
```

### Setup Flutter:
```bash
flutter pub get
flutter run
```

---

## 📄 Dokumentasi

- **APK_MONITORING_FINAL.md** - Panduan lengkap aplikasi
- **PERBAIKAN_APK_FINAL.md** - Changelog & perbaikan
- **PERBAIKAN_STATUS_MQTT.md** - Penjelasan API only
- **backend/API_DOCUMENTATION.md** - API reference

---

## 🔍 Troubleshooting

### Icon Cloud Merah?
- Cek koneksi internet HP
- Test backend: https://web-production-47eb.up.railway.app/
- Restart aplikasi

### Data Tidak Update?
- Pastikan icon cloud hijau
- Cek ESP32 status (WiFi connected)
- Cek backend logs di Railway

### Notifikasi Tidak Muncul?
- Izinkan notifikasi di Settings
- Disable battery optimization
- Cek status berubah di ESP32

---

## 📝 Version History

### v1.0.0 (1 Juni 2026) - Current
- ✅ Monitoring only (no control)
- ✅ API polling 5 detik
- ✅ Push notifications
- ✅ 3 device cards (Heater, Fan, Exhaust)
- ✅ Auto-update data
- ✅ Connection indicator

---

## 👨‍💻 Tech Stack

- **Mobile:** Flutter 3.5, Dart 3.0
- **Backend:** Node.js 18, Express.js
- **Database:** MySQL 8.0 (Railway)
- **IoT:** ESP32, Arduino IDE
- **Protocol:** MQTT, REST API
- **Hosting:** Railway.app

---

## 📞 Support

Untuk pertanyaan atau masalah:
1. Cek dokumentasi di folder `docs/`
2. Lihat troubleshooting di README
3. Cek logs di Railway dashboard

---

## 📜 License

Private project - All rights reserved

---

**Build Date:** 1 Juni 2026  
**Version:** 1.0.0  
**Status:** ✅ Production Ready

🎉 **Aplikasi siap digunakan untuk monitoring pengering ikan!**
