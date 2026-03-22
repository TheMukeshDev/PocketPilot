# PocketPilot Settings

## App Configuration

### Demo Mode
- `ENABLE_DEMO_LOGIN=true` - Enable demo login
- `DEMO_EMAIL=test@gmail.com` - Demo account email
- `DEMO_PASSWORD=123456` - Demo account password

### SMS Auto-Tracking
- `ENABLE_SMS_AUTOTRACK=false` - Enable SMS expense detection

## Firebase Configuration

Required for Google Sign-In:
```
FIREBASE_API_KEY=your_key
FIREBASE_APP_ID=your_app_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_bucket
```

## Google Sign-In
```
GOOGLE_WEB_CLIENT_ID=your_web_client_id
```

## Build Instructions

### Debug APK
```bash
flutter build apk --debug
```

### Release APK
```bash
flutter build apk --release
```

### Clean Build
```bash
flutter clean
flutter pub get
flutter build apk --debug
```
