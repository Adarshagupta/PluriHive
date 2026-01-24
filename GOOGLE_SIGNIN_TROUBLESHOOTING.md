# 🔧 Google Sign-In Troubleshooting

## ❌ Error: "Failed to get Google authentication token"

This error means Google Sign-In worked, but the app couldn't get the ID token needed for backend authentication.

---

## 🎯 Most Common Cause

**You haven't created the Android OAuth client in Google Cloud Console yet!**

### ✅ Solution: Create Android OAuth Client

1. **Go to:** https://console.cloud.google.com/apis/credentials

2. **Click:** "+ CREATE CREDENTIALS" → "OAuth client ID"

3. **Select:** "Android"

4. **Fill in:**
   ```
   Package name: com.example.territory_fitness
   SHA-1: F7:D8:06:5C:03:E3:C4:E0:22:FD:43:AA:0
   ```

5. **Click:** "CREATE"

6. **Wait:** 5-10 minutes for Google to propagate

7. **Test again!**

---

## 🔍 Other Possible Causes

### 1. **SHA-1 Fingerprint Mismatch**

**Check:**
```bash
# Run this to verify your SHA-1
.\get_sha1.bat
```

**Expected:**
```
SHA1: F7:D8:06:5C:03:E3:C4:E0:22:FD:43:AA:0
```

**Fix:** If different, update the Android OAuth client in Google Cloud Console

---

### 2. **Package Name Mismatch**

**Check:** `android/app/build.gradle.kts`
```kotlin
applicationId = "com.example.territory_fitness"
```

**Fix:** Make sure it matches exactly in Google Cloud Console

---

### 3. **Google Play Services Not Updated**

**Check:** On your Android device:
- Open Google Play Store
- Search "Google Play Services"
- Update if available

**Fix:** Update and restart device

---

### 4. **Credentials Not Propagated Yet**

**Wait:** 5-10 minutes after creating OAuth client

**Fix:** Be patient, Google needs time to propagate credentials globally

---

### 5. **App Cache Issues**

**Fix:**
1. Stop the app
2. Clear app data:
   - Settings → Apps → Territory Fitness → Storage → Clear Data
3. Uninstall and reinstall:
   ```bash
   flutter clean
   flutter run
   ```

---

## 🧪 Testing Steps

### Step 1: Check Logs
When you tap "Continue with Google", check the Flutter logs for:

```
🔵 Google Sign-In: Starting sign-in process...
✅ Google Sign-In: Signed in as your.email@gmail.com
🔵 Getting ID token...
🔵 Getting authentication for: your.email@gmail.com
🔍 Auth details:
   - Has accessToken: true
   - Has idToken: true  ← Should be TRUE!
✅ Google Sign-In: Got ID token (...)
```

### Step 2: If idToken is NULL
You'll see:
```
❌ ID Token is NULL!
⚠️ This usually means:
   1. Android OAuth client not created in Google Cloud Console
   2. SHA-1 fingerprint mismatch
   3. Package name mismatch
   4. Need to wait 5-10 minutes after creating OAuth client
```

**Action:** Create the Android OAuth client!

---

## ✅ Verification Checklist

- [ ] Android OAuth client created in Google Cloud Console
- [ ] Package name is exactly: `com.example.territory_fitness`
- [ ] SHA-1 is exactly: `F7:D8:06:5C:03:E3:C4:E0:22:FD:43:AA:0`
- [ ] Waited at least 5 minutes after creating OAuth client
- [ ] Google Play Services is updated on device
- [ ] App has been restarted after creating OAuth client
- [ ] Device and PC are on same network (for local backend)

---

## 🔄 Quick Fix Steps

1. **Create Android OAuth client** (if not done)
2. **Wait 10 minutes**
3. **Restart app:**
   ```bash
   # In Flutter terminal, press 'r' for hot reload
   # Or stop and run again:
   flutter run
   ```
4. **Clear app data** (if still failing)
5. **Try again!**

---

## 📱 Expected Behavior

### ✅ Success Flow:
1. Tap "Continue with Google"
2. Google account picker appears
3. Select account
4. App gets ID token
5. App sends to backend
6. User logged in! ✅

### ❌ Current Issue:
1. Tap "Continue with Google"
2. Google account picker appears
3. Select account
4. ❌ **App can't get ID token**
5. Error: "Failed to get Google authentication token"

---

## 🆘 Still Not Working?

### Check These:

1. **Google Cloud Console:**
   - Go to: https://console.cloud.google.com/apis/credentials
   - You should see **TWO** OAuth clients:
     - ✅ Web client (already created)
     - ⏳ Android client (create this!)

2. **Enable Google+ API:**
   - Go to: https://console.cloud.google.com/apis/library
   - Search: "Google+ API" or "Google Sign-In API"
   - Click "Enable"

3. **Check Logs:**
   - Run: `flutter run`
   - Watch for detailed error messages
   - Share the logs if still stuck

---

## 📞 Need More Help?

**Share these details:**
1. Did you create the Android OAuth client? (Yes/No)
2. How long ago did you create it?
3. What do the Flutter logs show?
4. Screenshot of Google Cloud Console credentials page

---

**Most likely fix: Create the Android OAuth client and wait 10 minutes! 🚀**
