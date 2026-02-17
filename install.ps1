Write-Host "Installing AMR-Predictor..." -ForegroundColor Cyan

# Check if running in correct directory
if (-not (Test-Path "AMR-Predictor.ps1")) {
    Write-Host "Please run this script from the AMR-Predictor root directory" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Installation complete!" -ForegroundColor Green
Write-Host "Run '.\AMR-Predictor.ps1 -h' for usage information" -ForegroundColor Green