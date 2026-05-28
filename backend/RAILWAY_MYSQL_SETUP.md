# 🚂 Railway MySQL Setup Guide

## 📋 Environment Variables di Railway

Railway menyediakan environment variables dengan format yang berbeda tergantung cara setup MySQL.

### Format 1: Railway MySQL Plugin (Recommended)

Jika Anda menggunakan Railway MySQL Plugin, Railway otomatis menyediakan:

```bash
MYSQLHOST=containers-us-west-xxx.railway.app
MYSQLPORT=6543
MYSQLUSER=root
MYSQLPASSWORD=xxxxxxxxxxxxx
MYSQLDATABASE=railway
```

✅ **Backend sudah support format ini!** Tidak perlu setting manual.

---

### Format 2: DATABASE_URL

Beberapa Railway service menyediakan `DATABASE_URL`:

```bash
DATABASE_URL=mysql://root:password@host:port/database
```

✅ **Backend sudah support format ini!** Tidak perlu setting manual.

---

### Format 3: MYSQL_URL

Alternative format:

```bash
MYSQL_URL=mysql://root:password@host:port/database
```

✅ **Backend sudah support format ini!** Tidak perlu setting manual.

---

### Format 4: Custom Variables (Local Development)

Untuk development lokal, gunakan:

```bash
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=pengering_ikan
```

✅ **Backend sudah support format ini!**

---

## 🚀 Setup Railway MySQL

### Opsi 1: Menggunakan Railway MySQL Plugin (Recommended)

1. **Buka Railway Dashboard**
   - Go to your project
   - Click "New" → "Database" → "Add MySQL"

2. **Railway akan otomatis:**
   - Create MySQL database
   - Set environment variables:
     - `MYSQLHOST`
     - `MYSQLPORT`
     - `MYSQLUSER`
     - `MYSQLPASSWORD`
     - `MYSQLDATABASE`

3. **Link ke Service Anda:**
   - Railway otomatis link database ke service
   - Environment variables tersedia di service

4. **Deploy:**
   - Push code ke GitHub
   - Railway auto-deploy
   - Backend otomatis connect ke MySQL

✅ **DONE!** Backend akan otomatis detect dan gunakan variables ini.

---

### Opsi 2: Menggunakan External MySQL (Aiven, PlanetScale, dll)

1. **Dapatkan Connection String:**
   ```
   mysql://user:password@host:port/database
   ```

2. **Set di Railway:**
   - Go to your service
   - Click "Variables"
   - Add variable:
     - Name: `DATABASE_URL`
     - Value: `mysql://user:password@host:port/database`

3. **Deploy:**
   - Railway auto-redeploy
   - Backend otomatis connect

✅ **DONE!**

---

## 🔍 Cek Connection di Railway

### 1. Lihat Logs

Di Railway Dashboard:
- Go to your service
- Click "Deployments"
- Click latest deployment
- View logs

Cari log:
```
📦 Using MYSQLHOST for connection
🔧 Database Config: { host: '...', port: 3306, ... }
✅ Database connected successfully
✅ Database tables initialized
```

### 2. Test via API

Setelah deploy, test endpoint:

```bash
# Test connection
curl https://your-app.railway.app/api/database/test

# Response jika berhasil:
{
  "success": true,
  "message": "Database connection successful"
}
```

### 3. Initialize Tables

Jika belum ada tabel, initialize:

```bash
curl -X POST https://your-app.railway.app/api/database/init

# Response:
{
  "success": true,
  "message": "Database tables initialized successfully"
}
```

---

## 🛠️ Troubleshooting

### Error: "Database connection failed"

**Cek 1: Environment Variables**
```bash
# Di Railway Dashboard → Variables, pastikan ada salah satu:
# - MYSQLHOST, MYSQLPORT, MYSQLUSER, MYSQLPASSWORD, MYSQLDATABASE
# - DATABASE_URL
# - MYSQL_URL
```

**Cek 2: MySQL Service Running**
```bash
# Di Railway Dashboard, pastikan MySQL service status = "Active"
```

**Cek 3: Network Access**
```bash
# Pastikan Railway service bisa akses MySQL
# Jika pakai external MySQL, cek firewall/whitelist
```

---

### Error: "Access denied for user"

**Solusi:**
1. Cek username dan password benar
2. Cek user punya permission ke database
3. Jika pakai Railway MySQL Plugin, coba restart service

---

### Error: "Unknown database"

**Solusi:**
1. Database belum dibuat
2. Jika pakai Railway MySQL Plugin, database otomatis dibuat dengan nama `railway`
3. Jika pakai external MySQL, buat database manual:
   ```sql
   CREATE DATABASE pengering_ikan;
   ```

---

### Error: "Too many connections"

**Solusi:**
1. Backend sudah pakai connection pool (max 10 connections)
2. Jika masih error, cek MySQL max_connections setting
3. Atau upgrade Railway plan untuk lebih banyak connections

---

## 📊 Database Schema

Backend otomatis create 3 tables:

### 1. `sensor_data`
```sql
CREATE TABLE sensor_data (
  id INT AUTO_INCREMENT PRIMARY KEY,
  suhu FLOAT NOT NULL,
  berat FLOAT NOT NULL,
  target FLOAT NOT NULL,
  relay1 BOOLEAN DEFAULT FALSE,
  relay2 BOOLEAN DEFAULT FALSE,
  relay3 BOOLEAN DEFAULT FALSE,
  relay4 BOOLEAN DEFAULT FALSE,
  status VARCHAR(50) DEFAULT 'DISCONNECTED',
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_timestamp (timestamp)
);
```

### 2. `status_history`
```sql
CREATE TABLE status_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  message TEXT NOT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_timestamp (timestamp)
);
```

### 3. `control_commands`
```sql
CREATE TABLE control_commands (
  id INT AUTO_INCREMENT PRIMARY KEY,
  command VARCHAR(50) NOT NULL,
  source VARCHAR(50) DEFAULT 'API',
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_timestamp (timestamp)
);
```

---

## 🎯 Best Practices

### 1. Gunakan Railway MySQL Plugin
- ✅ Otomatis setup
- ✅ Otomatis backup
- ✅ Otomatis scaling
- ✅ Gratis untuk development

### 2. Set Connection Pool
Backend sudah set:
```javascript
connectionLimit: 10  // Max 10 concurrent connections
```

### 3. Regular Cleanup
Backend punya endpoint untuk clear old data:
```bash
curl -X DELETE https://your-app.railway.app/api/history/clear
```

### 4. Monitor Logs
Cek Railway logs secara berkala untuk detect issues early.

---

## 📝 Checklist Setup

- [ ] Railway MySQL Plugin installed
- [ ] Environment variables tersedia
- [ ] Backend deployed
- [ ] Test `/api/database/test` berhasil
- [ ] Initialize tables via `/api/database/init`
- [ ] Test insert data via ESP32
- [ ] Test query data via `/api/data/latest`

---

## 🆘 Need Help?

1. **Cek Railway Logs** untuk error messages
2. **Cek Environment Variables** di Railway Dashboard
3. **Test Connection** via `/api/database/test`
4. **Check MySQL Status** di Railway Dashboard

---

## 🎉 Done!

Setelah setup berhasil:
- ✅ Backend otomatis connect ke MySQL
- ✅ Tables otomatis dibuat
- ✅ Data dari ESP32 otomatis tersimpan
- ✅ Flutter app bisa query data via API

Selamat! 🚀
