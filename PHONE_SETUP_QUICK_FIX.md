# 🔧 Quick Fix: Phone Login Error

## The Problem
Your phone can't connect to `localhost` - it needs your computer's **IP address**.

## ✅ Quick Fix (3 Steps)

### Step 1: Find Your IP Address
```powershell
ipconfig | findstr IPv4
```
Look for the IP that matches your WiFi network (usually `192.168.x.x`)

**Your current IPs found:**
- `192.168.184.236` ← **Use this one if on WiFi**
- `192.168.56.1` ← Virtual adapter (usually not this)

### Step 2: Update Config Files

**File 1:** `fontend/lib/core/config.dart`
```dart
// Change this line:
static const String baseUrl = 'http://192.168.184.236:3000/api';
// (Replace 192.168.184.236 with YOUR IP if different)
```

**File 2:** `fontend/lib/core/ai_config.dart`
```dart
// Change this line:
defaultValue: 'http://192.168.184.236:5000',
// (Replace 192.168.184.236 with YOUR IP if different)
```

### Step 3: Allow Firewall & Rebuild

**Allow through firewall (Run PowerShell as Administrator):**
```powershell
New-NetFirewallRule -DisplayName "Node.js" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Flask" -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Allow
```

**Rebuild app:**
```bash
cd fontend
flutter clean
flutter pub get
flutter run
```

## ✅ Verify It Works

1. **Test from phone browser:**
   - Open: `http://192.168.184.236:3000/api/health`
   - Should see: `{"status":"OK",...}`

2. **Make sure:**
   - ✅ Backend running: `npm run dev` in `backend/` folder
   - ✅ AI server running: `python server.py` in `ai_module/ollama_integration/`
   - ✅ Phone and computer on **same WiFi network**
   - ✅ Firewall allows ports 3000 and 5000

## 🎯 That's It!

After updating the IP addresses and rebuilding, your phone should be able to login.

**Note:** If your IP address changes (some networks use DHCP), you'll need to update the config files again.

---

**Full guide:** See `PHONE_TESTING_GUIDE.md` for detailed troubleshooting.

