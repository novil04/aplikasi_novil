# Changelog - Aplikasi Pengering Ikan

## Version 1.1.0 (Build 2) - 2024-12-XX

### 🎉 Fitur Baru
- ✅ **Status Relay Real-time**: Aplikasi sekarang menampilkan status relay (Heater 1, Heater 2, Fan, Exhaust) secara real-time dari ESP32
- ✅ **Exhaust Otomatis**: Exhaust akan otomatis menyala saat suhu mencapai 60°C atau lebih
- ✅ **Cooling Down 20 Detik**: Setelah pengeringan selesai, sistem akan menjalankan cooling down selama 20 detik dengan exhaust menyala dan countdown di LCD
- ✅ **Auto Reset**: Setelah cooling down, sistem otomatis kembali ke mode "Ready to Dry" untuk batch berikutnya

### 🔧 Perbaikan Backend
- ✅ **Parse Relay Status**: Backend sekarang membaca dan menyimpan status relay1, relay2, relay3, relay4 dari data MQTT ESP32
- ✅ **Real-time Update**: Status relay di database dan API diupdate secara real-time

### 🔧 Perbaikan ESP32
- ✅ **Kirim Status Relay**: ESP32 sekarang mengirim status semua relay (relay1-4) dalam format JSON ke MQTT
- ✅ **Kontrol Exhaust Otomatis**: Exhaust dikendalikan berdasarkan suhu (ON jika >= 60°C)
- ✅ **4 Relay Support**: Mendukung Heater 1 (GPIO 13), Heater 2 (GPIO 12), Fan (GPIO 14), Exhaust (GPIO 27)
- ✅ **Load Cell Error Handling**: Penanganan error yang lebih baik untuk load cell dengan timeout
- ✅ **LCD Status**: Tampilan LCD yang lebih informatif di setiap tahap proses

### 🐛 Bug Fixes
- ✅ Fixed: Perhitungan berat load cell (dari rata-rata menjadi penjumlahan)
- ✅ Fixed: Crash saat inisialisasi HX711 (skip tare di setup, tare saat start pengeringan)
- ✅ Fixed: Status relay tidak update di aplikasi Flutter

### 📊 Format Data MQTT (ESP32 → Backend)
```json
{
  "suhu": 55.5,
  "berat": 850,
  "target": 600,
  "relay1": true,   // Heater 1
  "relay2": true,   // Heater 2
  "relay3": true,   // Fan
  "relay4": false   // Exhaust (ON jika suhu >= 60°C)
}
```

### 🎯 Alur Pengeringan Baru
1. Ready to Dry → Tekan Button
2. Calibrating (Tare Load Cell)
3. Pengeringan Berjalan (Heater 1, 2, Fan ON | Exhaust ON jika suhu >= 60°C)
4. Target Tercapai → "PENGERINGAN SELESAI" (5 detik)
5. Cooling Down dengan Exhaust ON (20 detik dengan countdown)
6. Auto Reset → Kembali ke "Ready to Dry"

---

## Version 1.0.0 (Build 1) - 2024-XX-XX

### 🎉 Rilis Pertama
- ✅ Dashboard monitoring suhu dan berat real-time
- ✅ Grafik history suhu dan berat
- ✅ Kontrol relay (Heater, Fan, Exhaust) via MQTT
- ✅ Notifikasi pengeringan selesai
- ✅ Koneksi ke backend Railway dengan MySQL database
- ✅ Support MQTT broker HiveMQ

---

## 🔮 Roadmap (Coming Soon)
- [ ] Push notification ke smartphone
- [ ] Export data ke Excel/CSV
- [ ] Multi-user dengan login
- [ ] Dashboard web version
- [ ] Schedule pengeringan otomatis
