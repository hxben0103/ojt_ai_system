# 📱 Hotspot IP Address Guide

## Current Status
Your current IP: **192.168.184.236** (Wi-Fi adapter)
This matches your config files ✅

## ⚠️ When You Switch Hotspots

Each hotspot/network gives your computer a **different IP address**. You need to update the app config.

---

## 🔍 Step 1: Find Your New IP (After Switching)

**After connecting to the new hotspot, run:**
```powershell
ipconfig | findstr IPv4
```

**Look for the Wi-Fi adapter IP** (not the Ethernet adapter):
```
Wireless LAN adapter Wi-Fi:
   IPv4 Address. . . . . . . . . . : 192.168.X.X  ← Use this one!
```

**Ignore:**
- `192.168.56.1` (Virtual adapter - VirtualBox/VMware)
- Ethernet adapters (if not using)

---

## ✅ Step 2: Update Config Files

### Method A: Edit Config Files (Permanent)

**File 1: `fontend/lib/core/config.dart`**
- Line 18: Change `192.168.184.236` to your new IP

**File 2: `fontend/lib/core/ai_config.dart`**
- Line 21: Change `192.168.184.236` to your new IP

**Example:**
```dart
// OLD:
defaultValue: 'http://192.168.184.236:3000/api',

// NEW (if new IP is 192.168.1.100):
defaultValue: 'http://192.168.1.100:3000/api',
```

### Method B: Use Environment Variables (No Code Edit!)

**Just run with new IP:**
```powershell
cd fontend
flutter run --dart-define=API_URL=http://NEW_IP:3000/api --dart-define=CHATBOT_URL=http://NEW_IP:5000
```

**Example:**
```powershell
flutter run --dart-define=API_URL=http://192.168.1.100:3000/api --dart-define=CHATBOT_URL=http://192.168.1.100:5000
```

---

## 🔄 Step 3: Rebuild App

**After updating config:**
```powershell
cd fontend
flutter clean
flutter pub get
flutter run
```

**Or build APK:**
```powershell
flutter build apk
```

---

## 📋 Quick Checklist

- [ ] Connected to new hotspot on computer
- [ ] Found new IP address (`ipconfig | findstr IPv4`)
- [ ] Updated config files OR using environment variables
- [ ] Phone connected to **same hotspot** as computer
- [ ] Backend server running (`npm run dev`)
- [ ] AI server running (`python server.py`)
- [ ] Rebuilt app with new IP
- [ ] Tested connection from phone browser: `http://NEW_IP:3000/api/health`

---

## 🎯 Pro Tip

**Use environment variables** - No need to edit code every time!

Create a batch file `run_with_ip.bat`:
```batch
@echo off
echo Enter your IP address:
set /p IP="IP: "
flutter run --dart-define=API_URL=http://%IP%:3000/api --dart-define=CHATBOT_URL=http://%IP%:5000
```

Then just run: `run_with_ip.bat` and enter your IP!

---

## ⚠️ Important Notes

1. **Same Network:** Phone and computer MUST be on the same WiFi/hotspot
2. **IP Changes:** Every network gives a different IP
3. **Firewall:** Make sure ports 3000 and 5000 are allowed
4. **Servers Running:** Both backend and AI servers must be running

---

## 🐛 Troubleshooting

**"Can't connect" after switching hotspot:**
1. Check new IP: `ipconfig | findstr IPv4`
2. Update config files with new IP
3. Rebuild app
4. Verify phone and computer on same network
5. Test: `http://NEW_IP:3000/api/health` from phone browser

**"Connection refused":**
- Backend not running
- Wrong IP address
- Firewall blocking

**"Internal server error":**
- Database not set up (see `CREATE_DATABASE_NOW.md`)

---

**Current IP in config: `192.168.184.236`**

**When you switch hotspots, share your new IP and I can update the files for you!**

