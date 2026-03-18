# Android Release APK Signing Setup

## Issue
Your release APK is currently signed with the debug key, which triggers security blocks in UPI payment apps. Banks and payment gateways reject transactions from debug-signed APKs for security reasons.

## Solution: Generate a Release Keystore

### Step 1: Create a Keystore (One-time setup)
Run this command in the `android/` directory:

```powershell
keytool -genkey -v -keystore keystore/release_keystore.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias pocketpilot_key
```

**When prompted, enter:**
- **First/Last Name:** Your Name or Company Name
- **Organization Unit:** (leave blank or enter your company)
- **Organization:** Your Company (or leave blank)
- **City/Locality:** Your City
- **State:** Your State
- **Country Code:** IN (or your 2-letter country code)
- **Keystore Password:** Create a strong password (remember it!)
- **Key Password:** Same as keystore or different (remember it!)

**Result:** Creates `android/keystore/release_keystore.jks`

### Step 2: Create key.properties File
Copy the `key.properties.example` to `key.properties` and fill in your values:

```properties
storeFile=keystore/release_keystore.jks
storePassword=your_keystore_password_here
keyAlias=pocketpilot_key
keyPassword=your_key_password_here
```

### Step 3: Add to .gitignore
Ensure `key.properties` is never committed (security risk):
```
android/key.properties
android/keystore/release_keystore.jks
```

### Step 4: Build Release APK
Now your release APK will be properly signed:

```bash
flutter build apk --release
```

The signed APK will be at: `build/app/outputs/apk/release/app-release.apk`

## Verification
After building, verify the signing certificate in your APK by running:

```powershell
# You need jarsigner (from Java SDK)
jarsigner -verify -verbose build/app/outputs/apk/release/app-release.apk
```

## Additional Security Notes
1. **Never share** your `key.properties` or keystore file
2. **Back up** your keystore safely—you'll need it for app updates forever
3. **Use the same keystore** for all PocketPilot updates to maintain app identity
4. Payment apps verify the signing certificate against your Play Store certificate

---

**After setting up:** Payment apps (Google Pay, PhonePe, Paytm, etc.) will trust your APK and transactions will process normally.
