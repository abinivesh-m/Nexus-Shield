# NexusShield — Build & Deploy Guide

## Step 1: Deploy Backend to Railway (Free)

1. Go to https://railway.app and sign up (free)
2. Click "New Project" → "Deploy from GitHub repo"
   - OR click "New Project" → "Empty Project" → "Add Service" → "GitHub Repo"
3. Connect your GitHub account and upload/push the `backend/` folder
   - Easiest: create a new GitHub repo, put only the `backend/` folder contents in it (main.py, requirements.txt, app/, Procfile, railway.toml)
4. Railway auto-detects Python and deploys it
5. Go to your service → "Variables" tab → Add:
   ```
   GEMINI_API_KEY = <your-gemini-api-key>
   JWT_SECRET     = <your-jwt-secret>
   DATABASE_URL   = (Railway auto-fills this if you add a PostgreSQL plugin)
   ```
6. Go to "Settings" → "Networking" → "Generate Domain"
   - You'll get a URL like: `https://nexusshield-backend-production.up.railway.app`
7. Copy that URL

## Step 2: Update Flutter App with Your Railway URL

Open `lib/services/api_service.dart` and change two lines:
```dart
const String _PRODUCTION_URL = 'https://YOUR-APP.railway.app'; // ← paste your URL here
const bool _USE_PRODUCTION = true;  // ← change false to true
```

## Step 3: Generate Signing Keystore (one-time)

Run this in PowerShell (anywhere):
```powershell
keytool -genkey -v -keystore C:\Users\abini\nexusshield-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nexusshield
```
It will ask for passwords and your name/org — fill them in and remember the passwords.

Then copy `android/key.properties.template` to `android/key.properties` and fill in:
```
storePassword=<password you chose>
keyPassword=<password you chose>
keyAlias=nexusshield
storeFile=C:/Users/abini/nexusshield-release.jks
```

## Step 4: Build Release APK

```powershell
cd C:\Users\abini\Downloads\nexusshield
flutter pub get
flutter build apk --release --split-per-abi
```

`--split-per-abi` creates 3 smaller APKs instead of one fat one.
Your APKs will be at:
```
build\app\outputs\flutter-apk\app-arm64-v8a-release.apk   ← use this for modern phones
build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk  ← older 32-bit phones
build\app\outputs\flutter-apk\app-x86_64-release.apk       ← emulator
```

## Step 5: Install on Your Phone

Option A — USB:
```powershell
adb install build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

Option B — Transfer file:
- Copy `app-arm64-v8a-release.apk` to your phone via USB/WhatsApp/Drive
- On phone: Settings → Security → "Install from unknown sources" → ON
- Open the APK file and install

## Step 6: (Optional) Play Store

1. Build App Bundle instead of APK:
   ```powershell
   flutter build appbundle --release
   ```
   Output: `build\app\outputs\bundle\release\app-release.aab`

2. Go to https://play.google.com/console
3. Create app → Upload the .aab file
4. Fill in store listing (name, description, screenshots)
5. Submit for review (takes 1-3 days)

## Checklist Before Building

- [ ] Railway backend deployed and URL copied
- [ ] `_PRODUCTION_URL` updated in `api_service.dart`
- [ ] `_USE_PRODUCTION = true` in `api_service.dart`
- [ ] Keystore generated and `key.properties` filled in
- [ ] `flutter pub get` run successfully
- [ ] Test on emulator first: `flutter run -d <emulator-id>`

## Troubleshooting

**Build fails with "keystore not found"**
→ Check the path in `key.properties` matches exactly where you saved the .jks file

**App installs but can't connect to backend**
→ Check Railway deployment logs, make sure GEMINI_API_KEY is set in Railway variables
→ Visit `https://your-app.railway.app/health` in browser — should return {"status":"ok"}

**"Install blocked" on phone**
→ Settings → Apps → Special app access → Install unknown apps → Allow for your file manager

**Play Store "APK not aligned"**
→ Use `--release` flag, never `--debug` for store submission
