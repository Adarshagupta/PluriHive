# 🔐 Your Google Sign-In Credentials

## SHA-1 Fingerprint (Debug Keystore)

```
SHA1: F7:D8:06:5C:03:E3:C4:E0:22:FD:43:AA:0
```

**⚠️ IMPORTANT:** This is your **DEBUG** keystore fingerprint. Use this for development/testing.

---

## 📋 Quick Setup Checklist

### Step 1: Google Cloud Console Setup

1. Go to: https://console.cloud.google.com/
2. Create a new project or select existing one
3. Enable **Google+ API** (or Google Sign-In API)
4. Go to **Credentials** → **Create Credentials** → **OAuth client ID**

### Step 2: Create Android OAuth Client

1. Select **Android** as application type
2. Enter the following details:
   - **Package name**: `com.example.territory_fitness`
   - **SHA-1 certificate fingerprint**: `F7:D8:06:5C:03:E3:C4:E0:22:FD:43:AA:0`
3. Click **Create**
4. **Save the Client ID** (you don't need to add it to your code for Android)

### Step 3: Create Web OAuth Client (for Backend)

1. Click **Create Credentials** → **OAuth client ID** again
2. Select **Web application**
3. Give it a name (e.g., "PluriHive Backend")
4. Click **Create**
5. **Copy the Client ID** - you'll need this for backend verification

### Step 4: Update Backend (Optional but Recommended)

Edit `backend/.env` and add:

```env
GOOGLE_CLIENT_ID=YOUR-WEB-CLIENT-ID.apps.googleusercontent.com
```

Then uncomment this line in `backend/src/modules/auth/auth.service.ts` (line ~78):

```typescript
const ticket = await this.googleClient.verifyIdToken({
  idToken,
  audience: process.env.GOOGLE_CLIENT_ID, // ← Uncomment this line
});
```

---

## 🍎 iOS Setup (When Ready)

For iOS, you'll need to:

1. Create an **iOS OAuth client** in Google Cloud Console
2. Get your iOS Bundle ID from Xcode
3. Configure `ios/Runner/Info.plist` with the reversed client ID

---

## 🧪 Testing

Once you've completed the Google Cloud Console setup:

1. Wait 5-10 minutes for Google to propagate the credentials
2. Run the app: `flutter run`
3. Tap "Continue with Google"
4. Select your Google account
5. You should be logged in! ✅

---

## 📱 Package Name

Your current package name is: **`com.example.territory_fitness`**

If you want to change it, update:
- `android/app/build.gradle` → `applicationId`
- Then regenerate SHA-1 and update Google Console

---

## 🔑 For Production Release

When you're ready to release your app, you'll need to:

1. Create a **release keystore**
2. Get the SHA-1 from the release keystore
3. Add it to Google Cloud Console (same project, same OAuth client)

To get release SHA-1:
```bash
keytool -list -v -keystore path/to/your/release.keystore -alias your-alias
```

---

## ✅ Current Status

- ✅ Debug SHA-1 extracted
- ⏳ Waiting for Google Cloud Console setup
- ⏳ Waiting for backend .env configuration (optional)

**Next:** Complete the Google Cloud Console setup using the SHA-1 above!

---

## 🆘 Need Help?

If you encounter issues:
1. Make sure Google+ API is enabled
2. Wait 5-10 minutes after creating credentials
3. Check that SHA-1 matches exactly
4. Verify package name is correct
5. Try clearing app data and reinstalling

---

**Generated on:** 2026-01-24
**Debug Keystore:** `%USERPROFILE%\.android\debug.keystore`
