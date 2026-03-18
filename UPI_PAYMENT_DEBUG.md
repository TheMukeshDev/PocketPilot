# UPI Payment Debugging Guide

## Issue: "Unable to open this app" Error

This document explains the fixes applied and how to debug UPI payment issues.

---

## 🔧 Fixes Applied

### 1. **Enhanced Error Handling**
- Removed premature exit on empty packageName in `_launchWithPackage()`
- Native Android code now properly returns success/failure status
- Better exception handling with specific error types

### 2. **Improved Fallback Strategy**
Three-tier fallback approach when user clicks a payment app:
1. **Try Specific App** → Launch GPay/PayTM/etc directly
2. **Fallback to Chooser** → If specific app fails, show system UPI app chooser
3. **Fallback to url_launcher** → If chooser fails, use Flutter's url_launcher package

### 3. **Better URI Handling**
- `canLaunchUrl()` check now handles failures gracefully
- Attempts direct launch even if `canLaunchUrl()` returns false
- Fallback works on Android versions with different permission models

### 4. **Enhanced Android Intent Handling**
- Proper Intent creation with `ACTION_VIEW` + `CATEGORY_BROWSABLE`
- Correct flag handling: `FLAG_ACTIVITY_NEW_TASK`
- Chooser creation when packageName is empty
- Better exception catching with specific error types

---

## 🐛 Enable Debug Logging

To troubleshoot issues, enable debug logging:

### In `lib/services/payment_service.dart`:

Find this line (around line 68):
```dart
static const bool _debugLogging = false;
```

Change to:
```dart
static const bool _debugLogging = true;
```

Then rebuild the app:
```bash
flutter clean
flutter pub get
flutter run
```

Debug output will appear in the console with `[UPI Payment]` prefix, showing:
- Generated UPI URI
- `launchUpiIntent` result
- `canLaunchUrl` result
- Fallback attempts
- Exception details

### Example Debug Output:
```
[UPI Payment] Launching UPI URI: upi://pay?pa=merchant@hdfc&pn=Store&am=100.00&tn=Payment&cu=INR with package: com.google.android.apps.nbu.paisa.user
[UPI Payment] launchUpiIntent returned: true
```

---

## ✅ How It Works Now

### User Flow:
1. User enters UPI ID and amount on Scan QR Payment screen
2. User selects a payment app (GPay, PayTM, etc.)
3. **Attempt 1**: App tries to launch GPay directly
   - ✅ Success → Payment opens in GPay
   - ❌ Failure → Continue to Attempt 2
4. **Attempt 2**: System UPI app chooser appears
   - ✅ Success → User picks any UPI app from chooser
   - ❌ Failure → Continue to Attempt 3
5. **Attempt 3**: Uses url_launcher package
   - ✅ Success → Payment app opens
   - ❌ Failure → Show snackbar: "Unable to open this app. Try another or use the chooser."

---

## 🛠️ Technical Details

### URI Format (Properly Validated):
```
upi://pay?pa=upiid@bank&pn=ReceiverName&am=100.00&cu=INR&tn=Note
```
- `pa`: Payee Address (UPI ID) - **Required**
- `pn`: Payee Name - Sanitized (alphanumeric + space._-)
- `am`: Amount - Fixed to 2 decimal places (e.g., 100.00)
- `cu`: Currency - Always INR for India
- `tn`: Transaction Note - Sanitized

### Android Intent Handling:
```kotlin
val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriString)).apply {
    addCategory(Intent.CATEGORY_BROWSABLE)
    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    if (!packageName.isNullOrBlank()) {
        setPackage(packageName)  // Target specific app
    }
}

// If packageName is empty, create chooser
val launchIntent = if (packageName.isNullOrBlank()) {
    Intent.createChooser(intent, "Pay with")
} else {
    intent
}
startActivity(launchIntent)
```

---

## 📋 Validation Checklist

- ✅ AndroidManifest.xml has UPI intent queries
- ✅ URL format uses `upi://pay?` scheme
- ✅ All parameters are properly URL-encoded
- ✅ Fallback mechanisms are in place
- ✅ Exception handling doesn't silently fail
- ✅ Snackbar provides user feedback
- ✅ App discovery shows installed UPI apps

---

## 🔍 Testing Steps

1. **Test with Specific App:**
   - Install Google Pay or PhonePe
   - Scan a test UPI QR code
   - Click on GPay
   - ✅ Should open GPay app

2. **Test Fallback to Chooser:**
   - Enable debug logging
   - Uninstall all payment apps except one
   - Click on a non-installed app
   - ✅ Chooser should appear
   - ✅ Debug log shows "Attempt 2" (fallback to chooser)

3. **Test url_launcher Fallback:**
   - Temporarily modify code to skip first two attempts
   - Make final fallback is tested
   - ✅ Should still work

4. **Check Debug Output:**
   - Enable `_debugLogging = true`
   - Perform payment
   - Check console for `[UPI Payment]` logs
   - Should show URI, results, and fallbacks

---

## 🆘 If Still Not Working

1. **Enable debug logging** (see above)
2. **Check console output** for specific error messages
3. **Try different UPI apps** (GPay, PhonePe, PayTM, Amazon Pay)
4. **Check Android version** (ensure Android 11+ for proper manifest queries)
5 **Report the debug output** if issues persist

---

## 📌 Key Improvements Summary

| Issue | Before | After |
|-------|--------|-------|
| Empty packageName handling | Returns false immediately | Properly handles chooser flow |
| Specific app failure | No fallback, user sees error | Falls back to chooser, then url_launcher |
| Error visibility | Silent failure | Optional debug logging available |
| URL encoding | Manual, error-prone | Handled by Uri class automatically |
| canLaunchUrl false | Fails completely | Attempts direct launch anyway |
| Exception handling | Swallows all errors | Specific catch blocks with logging |

---

## 🏠 Related Files

- [lib/services/payment_service.dart](lib/services/payment_service.dart) - Main payment logic
- [android/app/src/main/kotlin/com/themukeshdev/pocketpilot/MainActivity.kt](android/app/src/main/kotlin/com/themukeshdev/pocketpilot/MainActivity.kt) - Native Android handler
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) - UPI intent queries
- [lib/screens/payment_screen.dart](lib/screens/payment_screen.dart) - Payment UI

