# 🔄 Changing IP Address for Different Hotspot/Network

## Problem
When you switch to a different hotspot or WiFi network, your computer gets a new IP address. The app is hardcoded to the old IP, so it can't connect.

## ✅ Quick Fix: Update IP Address

### Step 1: Find Your New IP Address

**On Windows:**
```powershell
ipconfig | findstr IPv4
```

Look for the IP address that matches your current network (usually the WiFi adapter, not the virtual adapter).

**Example output:**
```
IPv4 Address. . . . . . . . . . . : 192.168.1.100  ← Use this one
IPv4 Address. . . . . . . . . . . : 192.168.56.1   ← Virtual adapter (ignore)
```

### Step 2: Update Config Files

**File 1: `fontend/lib/core/config.dart`**

Change line 18:
```dart
// OLD:
static const String baseUrl = 'http://192.168.184.236:3000/api';

// NEW (with your new IP):
static const String baseUrl = 'http://192.168.1.100:3000/api';
```

**File 2: `fontend/lib/core/ai_config.dart`**

Change line 20:
```dart
// OLD:
defaultValue: 'http://192.168.184.236:5000',

// NEW (with your new IP):
defaultValue: 'http://192.168.1.100:5000',
```

### Step 3: Rebuild App

```powershell
cd fontend
flutter clean
flutter pub get
flutter run
```

Or if building APK:
```powershell
flutter build apk
```

---

## 🎯 Better Solution: Use Environment Variables

Instead of hardcoding, you can use environment variables when building:

### Build with IP Address:
```powershell
flutter run --dart-define=API_URL=http://192.168.1.100:3000/api --dart-define=CHATBOT_URL=http://192.168.1.100:5000
```

### Or Build APK with IP:
```powershell
flutter build apk --dart-define=API_URL=http://192.168.1.100:3000/api --dart-define=CHATBOT_URL=http://192.168.1.100:5000
```

Then update the config files to use these variables (see next section).

---

## 🔧 Advanced: Make Config Dynamic

I can update the config files to:
1. Support environment variables
2. Fall back to a default IP
3. Make it easier to change

Would you like me to implement this?

---

## 📝 Quick Reference

**Current IP in config:** `192.168.184.236`

**To find new IP:**
```powershell
ipconfig | findstr IPv4
```

**Files to update:**
1. `fontend/lib/core/config.dart` (line 18)
2. `fontend/lib/core/ai_config.dart` (line 20)

**After updating:**
- Rebuild app: `flutter run` or `flutter build apk`

---

## ⚠️ Important Notes

1. **Same Network Required:** Phone and computer must be on the **same WiFi/hotspot network**
2. **IP Changes:** Each network gives a different IP address
3. **Firewall:** Make sure firewall allows ports 3000 and 5000
4. **Backend Running:** Both servers must be running before testing

---

**Need help?** Share your new IP address and I can update the files for you!

