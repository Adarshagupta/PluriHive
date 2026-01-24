# 🔍 Google Sign-In Token Error - Troubleshooting

## ✅ Confirmed Correct Configuration

- ✅ SHA-1: `F7:D8:06:5C:03:E3:65:F1:35:C9:1D:4C:73:6A:A5:1B:C1:B3:1D:32`
- ✅ Package: `com.example.territory_fitness`
- ✅ Android OAuth client created in Google Cloud Console

---

## 🕐 Most Common Cause: Propagation Delay

**Google needs 5-10 minutes to propagate OAuth credentials globally.**

### When did you create the Android OAuth client?
- ⏰ **Less than 5 minutes ago?** → Wait longer
- ⏰ **5-10 minutes ago?** → Should work soon
- ⏰ **More than 10 minutes ago?** → Check other issues below

---

## 🔧 Step-by-Step Fix

### Step 1: Clear App Data on Phone
1. On your phone: **Settings** → **Apps** → **Territory Fitness**
2. Tap **Storage**
3. Tap **Clear Data** and **Clear Cache**
4. Confirm

### Step 2: Rebuild and Run
```bash
# Already ran: flutter clean
# Now run:
flutter pub get
flutter run
```

### Step 3: Test Google Sign-In
1. Tap "Continue with Google"
2. Select your account
3. Check the logs for detailed error info

---

## 📋 Verification Checklist

### In Google Cloud Console (https://console.cloud.google.com/apis/credentials)

Check you have **BOTH** OAuth clients:

#### 1. Web OAuth Client ✅
- Type: Web application
- Client ID: `603877706963-ave40d4ic4hhnein0uhcj1iij4o279rs.apps.googleusercontent.com`
- Used for: Backend token verification

#### 2. Android OAuth Client ✅
- Type: Android
- Package name: `com.example.territory_fitness`
- SHA-1: `F7:D8:06:5C:03:E3:65:F1:35:C9:1D:4C:73:6A:A5:1B:C1:B3:1D:32`
- Used for: Mobile app authentication

### APIs Enabled
- [ ] Google+ API (or Google Sign-In API)
- [ ] Google Identity Toolkit API (optional but recommended)

---

## 🔍 Check Flutter Logs

When you tap "Continue with Google", look for these logs:

### ✅ Success Pattern:
```
🔵 Google Sign-In: Starting sign-in process...
✅ Google Sign-In: Signed in as your.email@gmail.com
🔵 Getting ID token...
🔵 Getting authentication for: your.email@gmail.com
🔍 Auth details:
   - Has accessToken: true
   - Has idToken: true  ← SHOULD BE TRUE!
✅ Google Sign-In: Got ID token (...)
🔵 Attempting Google sign in to: http://10.1.80.76:3000/auth/google
```

### ❌ Error Pattern:
```
🔵 Google Sign-In: Starting sign-in process...
✅ Google Sign-In: Signed in as your.email@gmail.com
🔵 Getting ID token...
🔵 Getting authentication for: your.email@gmail.com
🔍 Auth details:
   - Has accessToken: true
   - Has idToken: false  ← PROBLEM!
❌ ID Token is NULL!
```

---

## 🐛 If idToken is Still NULL

### Possible Causes:

#### 1. **Credentials Not Propagated Yet**
**Solution:** Wait 10-15 minutes total, then try again

#### 2. **Wrong OAuth Client Type**
**Check:** Make sure you created an **Android** client, not just Web
**Fix:** Create Android OAuth client if missing

#### 3. **Google Play Services Issue**
**Check:** On phone, update Google Play Services
**Fix:** 
- Open Play Store
- Search "Google Play Services"
- Update if available
- Restart phone

#### 4. **App Signature Mismatch**
**Check:** The app you're running must be signed with the debug keystore
**Fix:** Make sure you're running in debug mode: `flutter run` (not release)

#### 5. **Multiple Google Accounts**
**Try:** Sign out of all Google accounts on phone, then sign in with just one

---

## 🧪 Advanced Debugging

### Check if Google Sign-In is Working at All

Add this test to see what Google returns:

1. After tapping "Continue with Google"
2. Check logs for the account email
3. If you see the email but no token → OAuth client issue
4. If you don't see the email → Google Play Services issue

---

## 🔄 Nuclear Option: Complete Reset

If nothing works:

```bash
# 1. Uninstall app from phone completely
# 2. On PC:
flutter clean
flutter pub get

# 3. Delete Google Cloud OAuth clients and recreate:
#    - Delete Android OAuth client
#    - Wait 5 minutes
#    - Create new Android OAuth client with same SHA-1
#    - Wait 10 minutes

# 4. Reinstall app:
flutter run

# 5. On phone: Clear all Google account data
#    Settings → Accounts → Google → Remove Account
#    Then add it back

# 6. Try again
```

---

## ✅ Expected Timeline

- **Create OAuth client** → Wait 0 minutes
- **First test** → Might fail (too soon)
- **Wait 5 minutes** → Try again
- **Wait 10 minutes** → Should work now ✅
- **Still failing after 15 minutes** → Check other issues

---

## 📞 What to Check Right Now

1. **How long ago did you create the Android OAuth client?**
   - Write down the exact time

2. **Can you see both OAuth clients in Google Cloud Console?**
   - Web client ✅
   - Android client ✅

3. **What do the Flutter logs show?**
   - `Has idToken: true` or `false`?

---

**Most likely: Just need to wait a bit longer for Google to propagate! ⏰**

Try again in 5 minutes after clearing app data!
