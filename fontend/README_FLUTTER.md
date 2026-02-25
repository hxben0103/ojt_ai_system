# Flutter Project - Running Instructions

## ⚠️ Important: Always run Flutter commands from the `fontend` directory!

The Flutter project is located in the `fontend` directory (note: it's "fontend" not "frontend").

## Quick Start

### Option 1: Use the PowerShell Script (Easiest)
```powershell
cd fontend
.\run_flutter.ps1
```

Or specify a device:
```powershell
.\run_flutter.ps1 chrome    # Run on Chrome
.\run_flutter.ps1 windows   # Run on Windows desktop
.\run_flutter.ps1 edge      # Run on Edge browser
```

### Option 2: Manual Commands
```powershell
# Navigate to Flutter project
cd fontend

# Get dependencies (first time only)
flutter pub get

# Run the app
flutter run -d chrome
```

## Available Devices

- `chrome` - Google Chrome browser
- `windows` - Windows desktop app
- `edge` - Microsoft Edge browser

## Common Commands

### Get Dependencies
```powershell
cd fontend
flutter pub get
```

### Run on Specific Device
```powershell
cd fontend
flutter run -d chrome      # Chrome browser
flutter run -d windows     # Windows desktop
flutter run -d edge        # Edge browser
```

### Check Flutter Setup
```powershell
cd fontend
flutter doctor
```

### List Available Devices
```powershell
cd fontend
flutter devices
```

### Build for Production
```powershell
cd fontend
flutter build web          # Build for web
flutter build windows      # Build for Windows
```

## Troubleshooting

### Error: "No pubspec.yaml file found"
**Solution:** Make sure you're in the `fontend` directory:
```powershell
cd fontend
```

### Error: "No devices found"
**Solution:** Check available devices:
```powershell
cd fontend
flutter devices
```

### Error: "Package not found"
**Solution:** Get dependencies:
```powershell
cd fontend
flutter pub get
```

## Project Structure

```
fontend/              ← Flutter project root (run commands here)
├── lib/              ← Dart source code
│   ├── core/         ← Configuration
│   ├── models/       ← Data models
│   ├── services/     ← API services
│   ├── screens/      ← UI screens
│   └── widgets/      ← Reusable widgets
├── assets/           ← Images, fonts, etc.
├── pubspec.yaml      ← Dependencies file
└── README_FLUTTER.md ← This file
```

## Remember

**Always run Flutter commands from the `fontend` directory!**

The error "No pubspec.yaml file found" means you're running the command from the wrong directory (likely the root `ojt_ai_system` directory instead of `fontend`).

