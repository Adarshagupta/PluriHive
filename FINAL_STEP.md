# 🎯 FINAL STEP: Create Android OAuth Client

## You're Almost Done! Just One More Step in Google Cloud Console

---

## 📍 Step-by-Step Instructions

### 1. Go to Google Cloud Console
🔗 **URL:** https://console.cloud.google.com/apis/credentials

### 2. Click "Create Credentials"
- Click the **"+ CREATE CREDENTIALS"** button at the top
- Select **"OAuth client ID"**

### 3. Select Application Type
- Choose **"Android"** from the dropdown

### 4. Fill in the Form

**Name:** (optional)
```
PluriHive Android
```

**Package name:** (REQUIRED - copy exactly)
```
com.example.territory_fitness
```

**SHA-1 certificate fingerprint:** (REQUIRED - copy exactly)
```
F7:D8:06:5C:03:E3:C4:E0:22:FD:43:AA:0
```

### 5. Click "CREATE"
- Google will create the Android OAuth client
- You'll see a confirmation dialog
- **You don't need to copy anything** - Android clients don't show a Client ID

### 6. Done! ✅
- Wait **5-10 minutes** for Google to propagate the credentials
- Then test your app!

---

## 🖼️ Visual Guide

```
Google Cloud Console
    ↓
APIs & Services → Credentials
    ↓
+ CREATE CREDENTIALS
    ↓
OAuth client ID
    ↓
Application type: Android
    ↓
Package name: com.example.territory_fitness
SHA-1: F7:D8:06:5C:03:E3:C4:E0:22:FD:43:AA:0
    ↓
CREATE
    ↓
✅ Done!
```

---

## ✅ Verification

After creating, you should see **TWO** OAuth clients in your credentials list:

1. **Web client** - Shows Client ID (already created ✅)
   - `603877706963-ave40d4ic4hhnein0uhcj1iij4o279rs.apps.googleusercontent.com`

2. **Android client** - Shows package name (create this now ⏳)
   - `com.example.territory_fitness`

---

## 🧪 Test After Creating

### Wait 5-10 minutes, then:

```bash
flutter run
```

1. Open the app
2. Tap **"Continue with Google"**
3. Select your Google account
4. ✅ **You should be logged in!**

---

## 🐛 If It Doesn't Work

### Double-check:
- ✅ Package name is **exactly**: `com.example.territory_fitness`
- ✅ SHA-1 is **exactly**: `F7:D8:06:5C:03:E3:C4:E0:22:FD:43:AA:0`
- ✅ You waited at least 5 minutes
- ✅ Backend is running with new `.env` variables

### Still not working?
1. Clear app data
2. Uninstall and reinstall app
3. Check backend logs for errors
4. Verify Google+ API is enabled

---

## 📞 Need Help?

Check these files:
- `GOOGLE_SIGNIN_COMPLETE.md` - Full setup summary
- `YOUR_GOOGLE_CREDENTIALS.md` - Your credentials
- `GOOGLE_SIGNIN_SETUP.md` - Detailed guide

---

**You're one step away from Google Sign-In! 🚀**
