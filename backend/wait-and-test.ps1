# Wait for Railway Deployment and Test
# This script will wait for Railway to finish deploying and then test the endpoints

$baseUrl = "https://web-production-47eb.up.railway.app"
$maxAttempts = 20
$waitSeconds = 10

Write-Host "⏳ Waiting for Railway deployment to complete..." -ForegroundColor Cyan
Write-Host "   This may take 2-3 minutes" -ForegroundColor Gray
Write-Host ""

for ($i = 1; $i -le $maxAttempts; $i++) {
    Write-Host "Attempt $i/$maxAttempts..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/" -Method GET -UseBasicParsing -TimeoutSec 5
        
        if ($response.StatusCode -eq 200) {
            $json = $response.Content | ConvertFrom-Json
            
            Write-Host ""
            Write-Host "✅ Deployment Successful!" -ForegroundColor Green
            Write-Host ""
            Write-Host "📊 Server Info:" -ForegroundColor Cyan
            Write-Host "   Status: $($json.status)" -ForegroundColor Gray
            Write-Host "   Message: $($json.message)" -ForegroundColor Gray
            Write-Host "   Version: $($json.version)" -ForegroundColor Gray
            Write-Host "   Uptime: $([math]::Round($json.uptime, 2))s" -ForegroundColor Gray
            Write-Host ""
            
            # Run full test
            Write-Host "🧪 Running full test suite..." -ForegroundColor Cyan
            Write-Host ""
            & "$PSScriptRoot\test-railway.ps1"
            
            exit 0
        }
    } catch {
        $errorMessage = $_.Exception.Message
        
        if ($errorMessage -like "*502*") {
            Write-Host "   ⏳ Server still starting (502)..." -ForegroundColor Yellow
        } elseif ($errorMessage -like "*503*") {
            Write-Host "   ⏳ Service unavailable (503)..." -ForegroundColor Yellow
        } elseif ($errorMessage -like "*timeout*") {
            Write-Host "   ⏳ Connection timeout..." -ForegroundColor Yellow
        } else {
            Write-Host "   ❌ Error: $errorMessage" -ForegroundColor Red
        }
    }
    
    if ($i -lt $maxAttempts) {
        Write-Host "   Waiting $waitSeconds seconds before retry..." -ForegroundColor Gray
        Start-Sleep -Seconds $waitSeconds
    }
}

Write-Host ""
Write-Host "❌ Deployment did not complete within expected time" -ForegroundColor Red
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Check Railway Dashboard for deployment status" -ForegroundColor Gray
Write-Host "   2. View Railway logs for error messages" -ForegroundColor Gray
Write-Host "   3. Try manual test: Invoke-WebRequest -Uri '$baseUrl/'" -ForegroundColor Gray
Write-Host ""

exit 1
