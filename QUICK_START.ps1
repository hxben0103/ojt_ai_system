# OJT AI System - Quick Start Script for Windows
# This script helps you start all services quickly

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OJT AI System - Quick Start" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Node.js
try {
    $nodeVersion = node --version
    Write-Host "✓ Node.js found: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Node.js not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# Check Python
try {
    $pythonVersion = python --version
    Write-Host "✓ Python found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Python not found. Please install Python first." -ForegroundColor Red
    exit 1
}

# Check Flutter
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✓ Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Flutter not found. Please install Flutter first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Prerequisites check complete!" -ForegroundColor Green
Write-Host ""

# Get project root
$projectRoot = Split-Path -Parent $PSScriptRoot
$backendPath = Join-Path $projectRoot "backend"
$aiModulePath = Join-Path $projectRoot "ai_module"
$aiServerPath = Join-Path $aiModulePath "ollama_integration"
$frontendPath = Join-Path $projectRoot "fontend"

Write-Host "Project paths:" -ForegroundColor Yellow
Write-Host "  Backend: $backendPath"
Write-Host "  AI Server: $aiServerPath"
Write-Host "  Frontend: $frontendPath"
Write-Host ""

# Check if .env exists
$envPath = Join-Path $backendPath "config\env\.env"
if (-not (Test-Path $envPath)) {
    Write-Host "⚠ WARNING: Backend .env file not found!" -ForegroundColor Yellow
    Write-Host "  Please create: $envPath" -ForegroundColor Yellow
    Write-Host "  See SETUP_GUIDE.md for details" -ForegroundColor Yellow
    Write-Host ""
}

# Menu
Write-Host "What would you like to do?" -ForegroundColor Cyan
Write-Host "1. Install all dependencies"
Write-Host "2. Start Backend API (Node.js)"
Write-Host "3. Start AI Server (Python Flask)"
Write-Host "4. Start Flutter Frontend"
Write-Host "5. Start All Services (3 separate windows)"
Write-Host "6. Exit"
Write-Host ""

$choice = Read-Host "Enter your choice (1-6)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "Installing dependencies..." -ForegroundColor Yellow
        
        # Backend
        Write-Host "Installing backend dependencies..." -ForegroundColor Cyan
        Set-Location $backendPath
        npm install
        
        # AI Module
        Write-Host "Installing AI module dependencies..." -ForegroundColor Cyan
        Set-Location $aiModulePath
        pip install -r requirements.txt
        
        # Frontend
        Write-Host "Installing Flutter dependencies..." -ForegroundColor Cyan
        Set-Location $frontendPath
        flutter pub get
        
        Write-Host ""
        Write-Host "✓ All dependencies installed!" -ForegroundColor Green
        Set-Location $projectRoot
    }
    
    "2" {
        Write-Host ""
        Write-Host "Starting Backend API..." -ForegroundColor Yellow
        Set-Location $backendPath
        
        if (-not (Test-Path "node_modules")) {
            Write-Host "Dependencies not installed. Installing..." -ForegroundColor Yellow
            npm install
        }
        
        Write-Host "Starting server on http://localhost:3000" -ForegroundColor Green
        npm run dev
    }
    
    "3" {
        Write-Host ""
        Write-Host "Starting AI Server..." -ForegroundColor Yellow
        Set-Location $aiServerPath
        
        Write-Host "Starting Flask server on http://localhost:5000" -ForegroundColor Green
        python server.py
    }
    
    "4" {
        Write-Host ""
        Write-Host "Starting Flutter Frontend..." -ForegroundColor Yellow
        Set-Location $frontendPath
        
        if (-not (Test-Path ".dart_tool")) {
            Write-Host "Dependencies not installed. Installing..." -ForegroundColor Yellow
            flutter pub get
        }
        
        Write-Host "Starting Flutter app..." -ForegroundColor Green
        Write-Host "Choose your device when prompted" -ForegroundColor Yellow
        flutter run
    }
    
    "5" {
        Write-Host ""
        Write-Host "Starting all services in separate windows..." -ForegroundColor Yellow
        
        # Start Backend
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$backendPath'; Write-Host 'Backend API Server' -ForegroundColor Cyan; npm run dev"
        Start-Sleep -Seconds 2
        
        # Start AI Server
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$aiServerPath'; Write-Host 'AI Flask Server' -ForegroundColor Cyan; python server.py"
        Start-Sleep -Seconds 2
        
        # Start Frontend
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$frontendPath'; Write-Host 'Flutter Frontend' -ForegroundColor Cyan; flutter run"
        
        Write-Host ""
        Write-Host "✓ All services started in separate windows!" -ForegroundColor Green
        Write-Host "  - Backend API: http://localhost:3000" -ForegroundColor Cyan
        Write-Host "  - AI Server: http://localhost:5000" -ForegroundColor Cyan
        Write-Host "  - Flutter: Check the Flutter window" -ForegroundColor Cyan
    }
    
    "6" {
        Write-Host "Exiting..." -ForegroundColor Yellow
        exit 0
    }
    
    default {
        Write-Host "Invalid choice. Exiting..." -ForegroundColor Red
        exit 1
    }
}

