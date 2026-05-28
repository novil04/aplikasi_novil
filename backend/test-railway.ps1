# Test Railway API Endpoints
# Run this script after Railway deployment completes

$baseUrl = "https://web-production-47eb.up.railway.app"

Write-Host "🧪 Testing Railway Backend..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Health Check
Write-Host "1️⃣  Testing Health Check..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/" -Method GET -UseBasicParsing
    $json = $response.Content | ConvertFrom-Json
    Write-Host "✅ Health Check OK" -ForegroundColor Green
    Write-Host "   Status: $($json.status)" -ForegroundColor Gray
    Write-Host "   Message: $($json.message)" -ForegroundColor Gray
    Write-Host "   Version: $($json.version)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Health Check FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 2: Database Connection
Write-Host "2️⃣  Testing Database Connection..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/database/test" -Method GET -UseBasicParsing
    $json = $response.Content | ConvertFrom-Json
    if ($json.success) {
        Write-Host "✅ Database Connection OK" -ForegroundColor Green
        Write-Host "   Message: $($json.message)" -ForegroundColor Gray
    } else {
        Write-Host "❌ Database Connection FAILED" -ForegroundColor Red
        Write-Host "   Message: $($json.message)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Database Connection FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 3: Initialize Database
Write-Host "3️⃣  Initializing Database Tables..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/database/init" -Method POST -UseBasicParsing
    $json = $response.Content | ConvertFrom-Json
    if ($json.success) {
        Write-Host "✅ Database Initialized" -ForegroundColor Green
        Write-Host "   Message: $($json.message)" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  Database Init Warning" -ForegroundColor Yellow
        Write-Host "   Message: $($json.message)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Database Init FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Get Latest Data
Write-Host "4️⃣  Getting Latest Data..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/data/latest" -Method GET -UseBasicParsing
    $json = $response.Content | ConvertFrom-Json
    if ($json.success) {
        Write-Host "✅ Latest Data Retrieved" -ForegroundColor Green
        Write-Host "   Suhu: $($json.data.suhu)°C" -ForegroundColor Gray
        Write-Host "   Berat: $($json.data.berat)g" -ForegroundColor Gray
        Write-Host "   Target: $($json.data.target)g" -ForegroundColor Gray
        Write-Host "   Status: $($json.data.status)" -ForegroundColor Gray
    } else {
        Write-Host "❌ Get Latest Data FAILED" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Get Latest Data FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 5: Get Statistics
Write-Host "5️⃣  Getting Statistics..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/stats" -Method GET -UseBasicParsing
    $json = $response.Content | ConvertFrom-Json
    if ($json.success) {
        Write-Host "✅ Statistics Retrieved" -ForegroundColor Green
        Write-Host "   Connected Clients: $($json.stats.connectedClients)" -ForegroundColor Gray
        Write-Host "   Sensor Data Count: $($json.stats.sensorDataCount)" -ForegroundColor Gray
        Write-Host "   Status History Count: $($json.stats.statusHistoryCount)" -ForegroundColor Gray
        Write-Host "   Uptime: $([math]::Round($json.stats.uptime, 2))s" -ForegroundColor Gray
    } else {
        Write-Host "❌ Get Statistics FAILED" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Get Statistics FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Write-Host "🎉 Testing Complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Check Railway logs for any errors" -ForegroundColor Gray
Write-Host "   2. Test ESP32 connection to HiveMQ" -ForegroundColor Gray
Write-Host "   3. Test Flutter app connection" -ForegroundColor Gray
Write-Host ""
