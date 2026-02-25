# Flutter Run Script
# This script helps you run Flutter from the correct directory

Write-Host "Navigating to Flutter project directory..." -ForegroundColor Green
Set-Location $PSScriptRoot

Write-Host "Current directory: $(Get-Location)" -ForegroundColor Cyan

if (Test-Path "pubspec.yaml") {
    Write-Host "✓ pubspec.yaml found!" -ForegroundColor Green
    Write-Host "Running Flutter..." -ForegroundColor Green
    Write-Host ""
    
    # Check for device argument
    $device = $args[0]
    if ($device) {
        flutter run -d $device
    } else {
        Write-Host "Available devices:" -ForegroundColor Yellow
        flutter devices
        Write-Host ""
        Write-Host "Running on Chrome (default). Use: .\run_flutter.ps1 chrome|windows|edge" -ForegroundColor Yellow
        flutter run -d chrome
    }
} else {
    Write-Host "✗ Error: pubspec.yaml not found!" -ForegroundColor Red
    Write-Host "Make sure you're in the Flutter project directory." -ForegroundColor Red
    exit 1
}

