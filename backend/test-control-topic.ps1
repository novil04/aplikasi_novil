# =====================================================
# Script Test Control Topic di Railway
# =====================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$RailwayUrl = ""
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TEST CONTROL TOPIC" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Minta URL jika tidak diberikan
if ([string]::IsNullOrWhiteSpace($RailwayUrl)) {
    $RailwayUrl = Read-Host "Masukkan URL Railway (contoh: https://your-app.up.railway.app)"
}

# Remove trailing slash
$RailwayUrl = $RailwayUrl.TrimEnd('/')

Write-Host "🔗 Railway URL: $RailwayUrl" -ForegroundColor Cyan
Write-Host ""

# =====================================================
# 1. HEALTH CHECK
# =====================================================
Write-Host "1️⃣  Testing Health Check..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$RailwayUrl/" -Method Get
    Write-Host "   ✅ Status: $($response.status)" -ForegroundColor Green
    Write-Host "   📦 Version: $($response.version)" -ForegroundColor Cyan
    Write-Host "   ⏱️  Uptime: $([math]::Round($response.uptime, 2))s" -ForegroundColor Cyan
} catch {
    Write-Host "   ❌ Failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# =====================================================
# 2. STATS CHECK
# =====================================================
Write-Host "2️⃣  Testing Stats API..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$RailwayUrl/api/stats" -Method Get
    Write-Host "   ✅ Stats retrieved successfully" -ForegroundColor Green
    Write-Host "   🔌 MQTT Connected: $($response.stats.mqttConnected)" -ForegroundColor Cyan
    Write-Host "   📊 Sensor Data: $($response.stats.sensorDataCount)" -ForegroundColor Cyan
    Write-Host "   📝 Status History: $($response.stats.statusHistoryCount)" -ForegroundColor Cyan
    Write-Host "   🎛️  Control Commands: $($response.stats.controlCommandsCount)" -ForegroundColor Cyan
    
    if ($response.stats.controlCommandsCount -eq $null) {
        Write-Host "   ⚠️  WARNING: controlCommandsCount is null!" -ForegroundColor Yellow
        Write-Host "   Kemungkinan table control_commands belum ada atau kosong" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Failed: $_" -ForegroundColor Red
}

Write-Host ""

# =====================================================
# 3. TEST CONTROL COMMANDS
# =====================================================
Write-Host "3️⃣  Testing Control Commands..." -ForegroundColor Yellow

$commands = @("HEATER_ON", "FAN_ON", "EXHAUST_ON", "HEATER_OFF", "FAN_OFF", "EXHAUST_OFF")

foreach ($cmd in $commands) {
    Write-Host "   📤 Sending: $cmd" -ForegroundColor Cyan
    try {
        $body = @{
            command = $cmd
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$RailwayUrl/api/control" -Method Post -Body $body -ContentType "application/json"
        
        if ($response.success) {
            Write-Host "      ✅ Success" -ForegroundColor Green
        } else {
            Write-Host "      ❌ Failed: $($response.message)" -ForegroundColor Red
        }
    } catch {
        Write-Host "      ❌ Error: $_" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 500
}

Write-Host ""

# =====================================================
# 4. CHECK STATS AGAIN
# =====================================================
Write-Host "4️⃣  Checking Stats After Commands..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$RailwayUrl/api/stats" -Method Get
    Write-Host "   ✅ Stats retrieved" -ForegroundColor Green
    Write-Host "   🎛️  Control Commands Count: $($response.stats.controlCommandsCount)" -ForegroundColor Cyan
    
    if ($response.stats.controlCommandsCount -gt 0) {
        Write-Host "   ✅ Control commands berhasil tersimpan!" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Control commands masih 0" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Failed: $_" -ForegroundColor Red
}

Write-Host ""

# =====================================================
# 5. TEST INVALID COMMAND
# =====================================================
Write-Host "5️⃣  Testing Invalid Command..." -ForegroundColor Yellow
try {
    $body = @{
        command = "INVALID_COMMAND"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$RailwayUrl/api/control" -Method Post -Body $body -ContentType "application/json"
    Write-Host "   ⚠️  Invalid command accepted (should be rejected)" -ForegroundColor Yellow
} catch {
    $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
    if ($errorResponse.message -like "*Invalid command*") {
        Write-Host "   ✅ Invalid command correctly rejected" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Unexpected error: $($errorResponse.message)" -ForegroundColor Red
    }
}

Write-Host ""

# =====================================================
# 6. GET DATA HISTORY
# =====================================================
Write-Host "6️⃣  Getting Data History..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$RailwayUrl/api/data/history?limit=5" -Method Get
    Write-Host "   ✅ Retrieved $($response.count) records" -ForegroundColor Green
    
    if ($response.count -gt 0) {
        $latest = $response.data[0]
        Write-Host "   📊 Latest Data:" -ForegroundColor Cyan
        Write-Host "      Suhu: $($latest.suhu)°C" -ForegroundColor White
        Write-Host "      Berat: $($latest.berat)g" -ForegroundColor White
        Write-Host "      Relay1 (Heater): $($latest.relay1)" -ForegroundColor White
        Write-Host "      Relay2 (Fan): $($latest.relay2)" -ForegroundColor White
        Write-Host "      Relay3 (Exhaust): $($latest.relay3)" -ForegroundColor White
        Write-Host "      Status: $($latest.status)" -ForegroundColor White
        Write-Host "      Timestamp: $($latest.timestamp)" -ForegroundColor White
    }
} catch {
    Write-Host "   ❌ Failed: $_" -ForegroundColor Red
}

Write-Host ""

# =====================================================
# 7. GET STATUS HISTORY
# =====================================================
Write-Host "7️⃣  Getting Status History..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$RailwayUrl/api/status/history?limit=10" -Method Get
    Write-Host "   ✅ Retrieved $($response.count) records" -ForegroundColor Green
    
    if ($response.count -gt 0) {
        Write-Host "   📝 Recent Status Messages:" -ForegroundColor Cyan
        foreach ($status in $response.data | Select-Object -First 5) {
            Write-Host "      - $($status.message)" -ForegroundColor White
        }
    }
} catch {
    Write-Host "   ❌ Failed: $_" -ForegroundColor Red
}

Write-Host ""

# =====================================================
# SUMMARY
# =====================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  📋 TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Checklist:" -ForegroundColor Yellow
Write-Host "   [ ] Health check berhasil" -ForegroundColor White
Write-Host "   [ ] Stats API menampilkan controlCommandsCount" -ForegroundColor White
Write-Host "   [ ] Control commands berhasil dikirim" -ForegroundColor White
Write-Host "   [ ] Control commands tersimpan di database" -ForegroundColor White
Write-Host "   [ ] Invalid command ditolak" -ForegroundColor White
Write-Host "   [ ] Data history dapat diambil" -ForegroundColor White
Write-Host "   [ ] Status history dapat diambil" -ForegroundColor White
Write-Host ""
Write-Host "📚 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Cek Railway logs untuk melihat MQTT messages" -ForegroundColor White
Write-Host "   2. Upload ESP32 code dan test dengan hardware" -ForegroundColor White
Write-Host "   3. Monitor database Railway untuk memastikan data masuk" -ForegroundColor White
Write-Host ""
Write-Host "🔗 Useful URLs:" -ForegroundColor Yellow
Write-Host "   Health: $RailwayUrl/" -ForegroundColor Cyan
Write-Host "   Stats: $RailwayUrl/api/stats" -ForegroundColor Cyan
Write-Host "   Control: $RailwayUrl/api/control" -ForegroundColor Cyan
Write-Host "   History: $RailwayUrl/api/data/history" -ForegroundColor Cyan
Write-Host ""
