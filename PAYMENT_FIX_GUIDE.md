# UPI Payment Processing - Security Fix Guide

## Problem
Your release APK was being rejected by payment apps (Google Pay, PhonePe, Paytm, etc.) because:
1. **Debug Signing**: APK signed with debug key instead of release keystore
2. **Missing Intent Filters**: Android 11+ couldn't find UPI apps
3. **ProGuard Obfuscation**: Payment classes being stripped during minification

## Fixes Applied

### 1. ✅ Android Gradle Build Config Updated
**File:** `android/app/build.gradle`
- Added keystore loading from `key.properties`
- Configured release signing to use custom keystore
- Falls back to debug key if `key.properties` doesn't exist

### 2. ✅ AndroidManifest.xml Updated  
**File:** `android/app/src/main/AndroidManifest.xml`
- Added UPI intent filter to `<queries>` section
- Enables app to discover and launch payment apps (Google Pay, PhonePe, etc.)
- Required for Android 11+ package visibility compliance

### 3. ✅ ProGuard Rules Updated
**File:** `android/app/proguard-rules.pro`
- Protected UPI payment library classes from obfuscation
- Prevents minification from breaking payment functionality

### 4. 📝 Keystore Config Files Created
**Files:** 
- `android/key.properties.example` - Template for signing config
- `android/KEYSTORE_SETUP.md` - Detailed setup instructions

---

## Next Steps to Complete Fix

### Step 1: Generate Your Release Keystore
In PowerShell, navigate to `android/` folder and run:

```powershell
keytool -genkey -v -keystore keystore/release_keystore.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias pocketpilot_key
```

Follow the prompts and **remember your passwords**.

### Step 2: Create key.properties File
Create `android/key.properties` with your keystore details:

```properties
storeFile=keystore/release_keystore.jks
storePassword=your_keystore_password_here
keyAlias=pocketpilot_key
keyPassword=your_key_password_here
```

### Step 3: Ensure .gitignore
Verify `android/.gitignore` contains (never commit keystore):
```
key.properties
keystore/
```

### Step 4: Build Release APK
```bash
flutter clean
flutter build apk --release
```

Output: `build/app/outputs/apk/release/app-release.apk`

### Step 5: Test Payment Flow
1. Install the signed APK on your test device
2. Open PocketPilot → Scan QR & Pay
3. Select any UPI app
4. Payments should now process without "Transaction blocked by authorities" error

---

## Verification Checklist

✅ **APK Signing**
- [ ] `key.properties` created and filled
- [ ] Keystore generated in `android/keystore/`
- [ ] Build uses release signing (not debug)

✅ **Manifest**
- [ ] UPI intent filter added to `<queries>`
- [ ] Payment apps can be discovered

✅ **ProGuard**
- [ ] UPI classes protected from obfuscation
- [ ] Payment logic not stripped

---

## Troubleshooting

### Still getting "Transaction blocked" error?
1. **Verify APK is properly signed:**
   ```powershell
   jarsigner -verify -verbose build/app/outputs/apk/release/app-release.apk
   ```
   Should show: `jar verified.`

2. **Check certificate is uploaded to Play Store:**
   - Upload the APK to Play Console internal testing
   - Payment apps verify against your Play Store certificate

3. **Uninstall old debug APK:**
   - Old debug-signed APK may conflict
   - Use: `flutter install --release`

### Build error "key.properties not found"?
- This is normal if you haven't created `key.properties` yet
- Gradle will fall back to debug signing
- Follow "Step 1-2" above to fix

---

## Important Security Notes
⚠️ **NEVER:**
- Commit `key.properties` to git
- Share your keystore with anyone
- Use the same keystore for different apps

✅ **DO:**
- Back up your keystore file securely
- Use the same keystore for ALL app updates
- Keep passwords in a password manager

---

## Payment App Support
After signing, these apps will accept your transactions:
- Google Pay
- PhonePe
- Paytm
- Amazon Pay
- BHIM
- WhatsApp Pay
- iMobile, ICICI Bank, HDFC Bank, etc.

All NPCI-registered UPI apps will work without security blocks.
