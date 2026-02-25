# Testing on Physical Phone - Login Error Fix

## 🔍 Problem

When testing on a physical phone, you're getting a "login error" because the app is trying to connect to `localhost:3000`, which refers to the phone itself, not your computer running the server.

## ✅ Solution: Use Your Computer's IP Address

### Step 1: Find Your Computer's IP Address

**On Windows:**
```powershell
ipconfig
```
Look for "IPv4 Address" under your active network adapter (usually WiFi or Ethernet). It will look like `192.168.x.x` or `10.0.x.x`.

**Common IP addresses found:**
- `192.168.184.236` (your main network)
- `192.168.56.1` (virtual adapter - usually not this one)

**Use the IP address that matches your phone's network!**

### Step 2: Update Flutter App Configuration

You need to change the API base URL in the Flutter app to use your computer's IP address instead of `localhost`.

**File to edit:** `fontend/lib/core/config.dart`

**Change this:**
```dart
static const String baseUrl = 'http://localhost:3000/api';
```

**To this (replace with YOUR IP address):**
```dart
static const String baseUrl = 'http://192.168.184.236:3000/api';
```

**Also update AI chatbot URL:** `fontend/lib/core/ai_config.dart`

The AI config supports environment variables, so you can either:

**Option A: Update the default value:**
```dart
static const String chatbotBaseUrl = String.fromEnvironment(
  'CHATBOT_URL',
  defaultValue: 'http://192.168.184.236:5000', // Change this
);
```

**Option B: Use environment variable when running:**
```bash
flutter run --dart-define=CHATBOT_URL=http://192.168.184.236:5000
```

### Step 3: Make Backend Accessible from Network

The backend server needs to be accessible from your local network, not just localhost.

**Check `backend/api/index.js`** - Make sure it's listening on `0.0.0.0`:

```javascript
app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${port}`);
});
```

If it's set to `localhost` or `127.0.0.1`, change it to `0.0.0.0`.

### Step 4: Configure Firewall

Windows Firewall might be blocking incoming connections. Allow Node.js through the firewall:

1. Open Windows Defender Firewall
2. Click "Allow an app or feature through Windows Firewall"
3. Find "Node.js" and check both "Private" and "Public"
4. If Node.js isn't listed, click "Allow another app" and add it

**Or use PowerShell (Run as Administrator):**
```powershell
New-NetFirewallRule -DisplayName "Node.js Server" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Python Flask Server" -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Allow
```

### Step 5: Ensure Both Servers Are Running

**Terminal 1 - Backend API:**
```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\backend"
npm run dev
```

**Terminal 2 - AI Server:**
```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\ai_module\ollama_integration"
python server.py
```

### Step 6: Test Connection from Phone

**Before rebuilding the app, test if your phone can reach the server:**

1. Make sure your phone is on the **same WiFi network** as your computer
2. Open a browser on your phone
3. Go to: `http://YOUR_IP_ADDRESS:3000/api/health`
   - Example: `http://192.168.184.236:3000/api/health`
4. You should see a JSON response with health status

If this works, the backend is accessible. If not, check:
- Firewall settings
- Both devices are on the same network
- Backend server is running

### Step 7: Rebuild and Install App on Phone

After updating the configuration:

```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\fontend"
flutter clean
flutter pub get
flutter run
```

Or build APK for Android:
```bash
flutter build apk
# Then install the APK from: build/app/outputs/flutter-apk/app-release.apk
```

## 🔧 Quick Fix Script

I'll create a helper script to update the IP address automatically. But for now, manually update:

1. `fontend/lib/core/config.dart` - Change `localhost` to your IP
2. `fontend/lib/core/ai_config.dart` - Change `localhost` to your IP (or use environment variable)

## 📱 Alternative: Use ngrok for Testing (Advanced)

If you can't use local network IP, you can use ngrok to create a public tunnel:

1. Install ngrok: https://ngrok.com/
2. Start backend: `npm run dev`
3. Create tunnel: `ngrok http 3000`
4. Use the ngrok URL in your app config

**Note:** This is slower and requires internet connection.

## ✅ Verification Checklist

- [ ] Found your computer's IP address
- [ ] Updated `config.dart` with your IP address
- [ ] Updated `ai_config.dart` with your IP address (or using env variable)
- [ ] Backend server is listening on `0.0.0.0:3000`
- [ ] AI server is listening on `0.0.0.0:5000`
- [ ] Windows Firewall allows connections on ports 3000 and 5000
- [ ] Phone can access `http://YOUR_IP:3000/api/health` from browser
- [ ] Phone and computer are on the same WiFi network
- [ ] Rebuilt and reinstalled the app on phone

## 🐛 Still Having Issues?

### Check Backend Logs
Look at the terminal running `npm run dev` - you should see requests coming in when you try to login.

### Check Network Connection
- Ping your computer from phone: Use a network scanner app
- Verify IP address hasn't changed (some networks use DHCP)

### Test with Postman/curl
Test the login endpoint directly:
```bash
curl -X POST http://YOUR_IP:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

### Common Errors

**"Connection refused"**
- Backend not running
- Wrong IP address
- Firewall blocking

**"Timeout"**
- Wrong IP address
- Different networks
- Firewall blocking

**"Invalid email or password"**
- Good! This means connection works, but credentials are wrong
- Check if user exists in database
- Check if user status is "Active"

---

**Need more help?** Check the main `SETUP_GUIDE.md` for general setup instructions.

