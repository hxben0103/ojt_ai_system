# How to Open Terminal - Quick Guide

## 🖥️ In VS Code / Cursor (Recommended)

### Method 1: Keyboard Shortcut (Fastest)
1. Press **`Ctrl + ` `** (Ctrl + Backtick)
   - The backtick key is usually above the Tab key
   - This opens/closes the terminal instantly

### Method 2: Menu
1. Click **Terminal** in the top menu
2. Click **New Terminal**

### Method 3: Command Palette
1. Press **`Ctrl + Shift + P`**
2. Type "Terminal: Create New Terminal"
3. Press Enter

### Method 4: Right-Click
1. Right-click on any file in the Explorer
2. Select **"Open in Integrated Terminal"**

## 🪟 In Windows (Standalone)

### Method 1: Start Menu
1. Click the **Start** button
2. Type **"PowerShell"** or **"Command Prompt"**
3. Click on the app

### Method 2: Run Dialog
1. Press **`Win + R`**
2. Type **"powershell"** or **"cmd"**
3. Press Enter

### Method 3: File Explorer
1. Open File Explorer
2. Navigate to your project folder
3. Click in the address bar
4. Type **"powershell"**
5. Press Enter

### Method 4: Context Menu
1. Open File Explorer
2. Navigate to your project folder (`fontend`)
3. **Shift + Right-click** in the folder
4. Select **"Open PowerShell window here"**

## 📁 For Your Flutter Project

### Quick Steps:
1. **Open VS Code/Cursor**
2. Open your project folder: `C:\Users\ACER\OneDrive\Desktop\OJT_AI_System\ojt_ai_system`
3. Press **`Ctrl + ` `** to open terminal
4. Navigate to Flutter project:
   ```powershell
   cd fontend
   ```
5. Run Flutter:
   ```powershell
   flutter run -d chrome
   ```

## 🎯 Terminal Tips

### Change Terminal Type
- In VS Code/Cursor, click the **`+`** dropdown next to the terminal
- Select **PowerShell**, **Command Prompt**, or **Git Bash**

### Multiple Terminals
- Click the **`+`** button to open multiple terminals
- Or press **`Ctrl + Shift + ` `** to create a new terminal

### Split Terminal
- Right-click on terminal tab
- Select **"Split Terminal"**

### Close Terminal
- Type **`exit`** and press Enter
- Or click the trash icon on the terminal tab

## 🔍 Verify You're in the Right Directory

After opening terminal, check your location:
```powershell
Get-Location    # PowerShell
# or
pwd             # Git Bash
```

You should see:
```
C:\Users\ACER\OneDrive\Desktop\OJT_AI_System\ojt_ai_system
```

Then navigate to Flutter project:
```powershell
cd fontend
```

## ✅ Quick Test

Once terminal is open, test Flutter:
```powershell
cd fontend
flutter --version
```

If this works, you're all set! 🎉

## 🆘 Troubleshooting

### Terminal not opening?
- Try restarting VS Code/Cursor
- Check if terminal is hidden (look for terminal icon at bottom)
- Press `Ctrl + J` to toggle bottom panel

### Wrong directory?
- Use `cd` to change directory
- Use `cd ..` to go up one level
- Use `cd fontend` to go to Flutter project

### Flutter not found?
- Make sure Flutter is installed and in PATH
- Run `flutter doctor` to check setup
- Restart terminal after installing Flutter

