# =====================================================
# Script Deploy Backend ke Railway
# =====================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DEPLOY BACKEND KE RAILWAY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Cek apakah di folder yang benar
$currentPath = Get-Location
if (-not $currentPath.Path.EndsWith("backend")) {
    Write-Host "❌ Error: Script harus dijalankan dari folder backend" -ForegroundColor Red
    Write-Host "   Current path: $currentPath" -ForegroundColor Yellow
    Write-Host "   Pindah ke folder backend dulu:" -ForegroundColor Yellow
    Write-Host "   cd backend" -ForegroundColor Yellow
    exit 1
}

Write-Host "📁 Current directory: $currentPath" -ForegroundColor Green
Write-Host ""

# =====================================================
# 1. CEK GIT STATUS
# =====================================================
Write-Host "🔍 Checking Git status..." -ForegroundColor Yellow
git status --short

Write-Host ""
$confirm = Read-Host "Lanjutkan commit dan push? (y/n)"
if ($confirm -ne "y") {
    Write-Host "❌ Deployment dibatalkan" -ForegroundColor Red
    exit 0
}

# =====================================================
# 2. GIT ADD
# =====================================================
Write-Host ""
Write-Host "📦 Adding files to Git..." -ForegroundColor Yellow
git add server.js
git add DEPLOY_PERBAIKAN.md
git add deploy-to-railway.ps1
git add ../PERBAIKAN_CONTROL_COMMANDS.md

Write-Host "✅ Files added" -ForegroundColor Green

# =====================================================
# 3. GIT COMMIT
# =====================================================
Write-Host ""
Write-Host "💾 Committing changes..." -ForegroundColor Yellow
$commitMessage = "Fix: Subscribe to control topic and save to database

- Backend now subscribes to novil/pengering/control topic
- Added handler to save control commands to database
- Added handler to update relay status from ESP32
- Status messages with STATUS: prefix saved to status_history
- Command messages saved to control_commands table"

git commit -m $commitMessage

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Commit successful" -ForegroundColor Green
} else {
    Write-Host "⚠️  No changes to commit or commit failed" -ForegroundColor Yellow
}

# =====================================================
# 4. GIT PUSH
# =====================================================
Write-Host ""
Write-Host "🚀 Pushing to repository..." -ForegroundColor Yellow
git push origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Push successful" -ForegroundColor Green
} else {
    Write-Host "❌ Push failed" -ForegroundColor Red
    Write-Host "   Coba push manual: git push origin main" -ForegroundColor Yellow
    exit 1
}

# =====================================================
# 5. TUNGGU RAILWAY DEPLOY
# =====================================================
Write-Host ""
Write-Host "⏳ Railway sedang deploy..." -ForegroundColor Yellow
Write-Host "   Buka Railway Dashboard untuk monitor progress:" -ForegroundColor Cyan
Write-Host "   https://railway.app/dashboard" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Tunggu hingga status: ✅ Deployed" -ForegroundColor Green
Write-Host ""

$waitDeploy = Read-Host "Sudah selesai deploy? (y/n)"
if ($waitDeploy -ne "y") {
    Write-Host "⏸️  Tunggu deploy selesai dulu, lalu jalankan test manual" -ForegroundColor Yellow
    exit 0
}

# =====================================================
# 6. TEST DEPLOYMENT
# =====================================================
Write-Host ""
Write-Host "🧪 Testing deployment..." -ForegroundColor Yellow
Write-Host ""

$railwayUrl = Read-Host "Masukkan URL Railway (contoh: https://your-app.up.railway.app)"

if ([string]::IsNullOrWhiteSpace($railwayUrl)) {
    Write-Host "⚠️  URL tidak diisi, skip testing" -ForegroundColor Yellow
    Write-Host "   Test manual dengan:" -ForegroundColor Yellow
    Write-Host "   curl https://your-app.up.railway.app/" -ForegroundColor Cyan
    exit 0
}

# Remove trailing slash
$railwayUrl = $railwayUrl.TrimEnd('/')

Write-Host ""
Write-Host "📡 Testing health check..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$railwayUrl/" -Method Get
    Write-Host "✅ Health check OK" -ForegroundColor Green
    Write-Host "   Status: $($response.status)" -ForegroundColor Cyan
    Write-Host "   Message: $($response.message)" -ForegroundColor Cyan
    Write-Host "   Version: $($response.version)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Health check failed" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "📊 Testing stats..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$railwayUrl/api/stats" -Method Get
    Write-Host "✅ Stats OK" -ForegroundColor Green
    Write-Host "   MQTT Connected: $($response.stats.mqttConnected)" -ForegroundColor Cyan
    Write-Host "   Sensor Data Count: $($response.stats.sensorDataCount)" -ForegroundColor Cyan
    Write-Host "   Status History Count: $($response.stats.statusHistoryCount)" -ForegroundColor Cyan
    Write-Host "   Control Commands Count: $($response.stats.controlCommandsCount)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Stats failed" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎛️  Testing control command..." -ForegroundColor Yellow
try {
    $body = @{
        command = "HEATER_ON"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$railwayUrl/api/control" -Method Post -Body $body -ContentType "application/json"
    Write-Host "✅ Control command OK" -ForegroundColor Green
    Write-Host "   Success: $($response.success)" -ForegroundColor Cyan
    Write-Host "   Message: $($response.message)" -ForegroundColor Cyan
    Write-Host "   Command: $($response.command)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Control command failed" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
}

# =====================================================
# 7. SELESAI
# =====================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ✅ DEPLOYMENT SELESAI" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Cek Railway logs untuk memastikan subscribe ke control topic" -ForegroundColor White
Write-Host "   2. Upload kode ESP32 (esp32_pengering_ikan_v2.ino)" -ForegroundColor White
Write-Host "   3. Monitor Serial ESP32 untuk melihat status relay" -ForegroundColor White
Write-Host "   4. Cek database Railway untuk memastikan data masuk" -ForegroundColor White
Write-Host ""
Write-Host "📚 Dokumentasi:" -ForegroundColor Yellow
Write-Host "   - PERBAIKAN_CONTROL_COMMANDS.md" -ForegroundColor Cyan
Write-Host "   - DEPLOY_PERBAIKAN.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔗 Railway URL: $railwayUrl" -ForegroundColor Cyan
Write-Host ""
