# ⚡ Quick IP Update Guide

## 🔍 Problem
You switched to a different hotspot → New IP address → App can't connect

## ✅ Solution (Choose One)

### Option 1: Update Config Files (Permanent)

**Step 1: Find your new IP**
```powershell
ipconfig | findstr IPv4
```

**Step 2: Update 2 files**

**File: `fontend/lib/core/config.dart` (line 18)**
```dart
// Change this:
defaultValue: 'http://192.168.184.236:3000/api',

// To your new IP:
defaultValue: 'http://YOUR_NEW_IP:3000/api',
```

**File: `fontend/lib/core/ai_config.dart` (line 20)**
```dart
// Change this:
defaultValue: 'http://192.168.184.236:5000',

// To your new IP:
defaultValue: 'http://YOUR_NEW_IP:5000',
```

**Step 3: Rebuild**
```powershell
cd fontend
flutter run
```

---

### Option 2: Use Environment Variables (No Code Change!)

**Just run with your new IP:**
```powershell
cd fontend
flutter run --dart-define=API_URL=http://YOUR_NEW_IP:3000/api --dart-define=CHATBOT_URL=http://YOUR_NEW_IP:5000
```

**Or build APK:**
```powershell
flutter build apk --dart-define=API_URL=http://YOUR_NEW_IP:3000/api --dart-define=CHATBOT_URL=http://YOUR_NEW_IP:5000
```

**Example:**
```powershell
flutter run --dart-define=API_URL=http://192.168.1.100:3000/api --dart-define=CHATBOT_URL=http://192.168.1.100:5000
```

---

## 🎯 Which Method?

- **Option 1:** If you always use the same network
- **Option 2:** If you switch networks frequently (no code changes needed!)

---

## ⚠️ Remember

1. Phone and computer must be on **same WiFi/hotspot**
2. Both servers must be running (backend + AI server)
3. Firewall must allow ports 3000 and 5000

---

**Share your new IP and I can update the files for you!**

