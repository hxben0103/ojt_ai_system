# 🔄 Rebuild App for Phone - Step by Step

Your config files are updated, but the app on your phone still has the old `localhost` configuration. You need to rebuild and reinstall the app.

## ✅ Step-by-Step Instructions

### Step 1: Verify Your IP Address
```powershell
ipconfig | findstr IPv4
```
Make sure you're using the correct IP (should be `192.168.184.236` for WiFi).

### Step 2: Verify Config Files Are Updated

**Check `fontend/lib/core/config.dart`:**
- Should have: `'http://192.168.184.236:3000/api'`

**Check `fontend/lib/core/ai_config.dart`:**
- Should have: `'http://192.168.184.236:5000'`

### Step 3: Start Backend Servers

**Terminal 1 - Backend API:**
```powershell
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\backend"
npm run dev
```
Wait for: `🚀 Server running on port 3000`

**Terminal 2 - AI Server:**
```powershell
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\ai_module\ollama_integration"
python server.py
```
Wait for: `Running on http://0.0.0.0:5000`

### Step 4: Configure Firewall (If Not Done)

**Run PowerShell as Administrator:**
```powershell
New-NetFirewallRule -DisplayName "Node.js Server" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Python Flask Server" -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Allow
```

### Step 5: Test Connection from Phone Browser

**On your phone:**
1. Open browser (Chrome/Safari)
2. Go to: `http://192.168.184.236:3000/api/health`
3. You should see: `{"status":"OK","message":"OJT AI System API is running",...}`

**If this doesn't work:**
- Check firewall settings
- Verify both devices are on same WiFi
- Verify backend is running

### Step 6: Rebuild Flutter App

**Terminal 3 - Flutter:**
```powershell
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\fontend"
flutter clean
flutter pub get
```

**Then rebuild and install:**

**Option A: Direct Install (if phone connected via USB)**
```powershell
flutter run
```
Select your phone when prompted.

**Option B: Build APK and Install Manually**
```powershell
flutter build apk
```
Then:
1. Find APK at: `build\app\outputs\flutter-apk\app-release.apk`
2. Transfer to phone (USB, email, cloud storage)
3. Install on phone (enable "Install from unknown sources" if needed)

**Option C: Build APK Bundle (for Play Store)**
```powershell
flutter build appbundle
```

### Step 7: Verify New App Works

1. **Uninstall old app** from phone (if needed)
2. **Install new app** (from Step 6)
3. **Open app** and try to login
4. **Check error message** - should NOT say "localhost" anymore

### Step 8: Test Login

Try logging in with:
- Email: `mmm@gmail.com` (or your registered email)
- Password: (your password)

**Expected:**
- ✅ No "Connection refused" error
- ✅ Either successful login OR "Invalid email or password" (which means connection works!)

## 🔍 Troubleshooting

### Still Getting "localhost" Error?

1. **Verify app was rebuilt:**
   - Check app version/build number changed
   - Or uninstall completely and reinstall

2. **Check config files again:**
   - Make sure no typos in IP address
   - Make sure no spaces

3. **Hot reload vs Full rebuild:**
   - `flutter run` does a full rebuild
   - If using hot reload, do a full restart

### Connection Still Refused?

1. **Verify servers are running:**
   - Check Terminal 1 and Terminal 2
   - Look for error messages

2. **Test from phone browser again:**
   - `http://192.168.184.236:3000/api/health`
   - If this works, app should work too

3. **Check IP address hasn't changed:**
   - Some networks use DHCP
   - Run `ipconfig` again to verify

4. **Verify same WiFi network:**
   - Phone and computer must be on same network
   - Check WiFi name matches

### "Invalid email or password" Error?

**This is GOOD!** It means:
- ✅ Connection works!
- ✅ Backend is reachable!
- ❌ Just need correct credentials

**Solutions:**
- Register a new account
- Or check database for existing users
- Or use admin account: `admin` / `admin` (if configured)

## ✅ Success Checklist

- [ ] Config files updated with correct IP
- [ ] Backend server running (Terminal 1)
- [ ] AI server running (Terminal 2)
- [ ] Firewall allows ports 3000 and 5000
- [ ] Phone can access `http://IP:3000/api/health` in browser
- [ ] App rebuilt and reinstalled
- [ ] Error message no longer says "localhost"
- [ ] Login works or shows "Invalid credentials" (not connection error)

---

**Once login works, you're all set!** 🎉

