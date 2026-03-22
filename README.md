# PocketPilot - Smart Budget Tracker for Students

![App Logo](screenshots/logo.jpeg)

**Hackathon:** TRAE Re{Vibe}  
**Team Name:** Quantum Coders

PocketPilot is an AI-powered smart budget tracker designed specifically for students. It helps track spending, predict overspending, manage monthly budgets, and build healthy financial habits through gamification.

---

## Problem Statement

Students often face practical money-management challenges:

- Running out of money before the end of the month
- Inconsistent daily spending tracking
- Complex finance apps that are overwhelming for student use

**Why it matters:**
- Financial stress directly affects academic focus and well-being
- Small daily expenses become large monthly leaks when untracked
- Students need a lightweight, smart, and actionable budgeting assistant

---

## Solution

PocketPilot is a student-first budgeting app combining simplicity with intelligent insights:

- **Smart daily limits** based on remaining budget and days left
- **AI overspending prediction** using spending pace analysis
- **Gamification system** with daily/weekly challenges and badges
- **Receipt scanning** with OCR to auto-fill expense details
- **Financial health scoring** with personalized insights
- **Cloud sync** for data backup across devices

---

## Features

### Authentication & Onboarding
- Email/Password registration and login
- Google Sign-In authentication
- Demo mode for trying features without account
- 4-step onboarding flow for new users
- Email verification support

### Budget Management
- Monthly budget setting with rent deduction
- Dynamic daily spending limit calculation
- Budget cycle management (custom start date)
- Real-time budget remaining tracking

### Expense Tracking
- Quick expense entry with categories
- Expense history with filtering
- Multiple payment apps integration
- QR code scanning for UPI payments
- SMS-based expense auto-detection
- Receipt scanning with OCR (Google ML Kit)

### Analytics & Reports
- Spending analytics charts (weekly/monthly)
- Category-wise spending breakdown
- Monthly spending reports (PDF export)
- Weekly trends visualization
- Financial health score calculation

### AI & Predictions
- Overspending prediction based on spending pace
- Personalized tips for budget optimization
- Smart alerts for risky spending patterns
- Daily spending recommendations

### Gamification System
- **Daily Challenges:** Stay under budget each day (20 points)
- **Weekly Challenges:** Save ₹300 over 7 days (40 points)
- **Streak Tracking:** Consecutive days under budget
- **Badges:** Unlock achievements (First Save, Week Warrior, etc.)
- **Points History:** Track earned rewards
- **Weekly Bonus:** 50 points for 7-day streak milestones

### Notifications & Alerts
- Daily spending reminders
- Budget threshold alerts
- Challenge completion notifications
- Smart spending alerts
- Configurable notification preferences

### Settings & Customization
- Theme support (Light/Dark)
- Budget cycle configuration
- Notification preferences
- Data export options
- Firebase status indicator
- Profile management

---

## Screens

| Screen | Description |
|--------|-------------|
| Login Screen | Email/Password, Google Sign-In, Demo mode |
| Onboarding | 4-step welcome flow for new users |
| Home Dashboard | Budget summary, recent expenses, predictions, challenges |
| Add Expense | Quick expense entry with categories and receipt scan |
| Payment History | Full expense history with search and filters |
| Monthly Report | Category breakdown, top expenses, PDF export |
| Weekly Trends | Visual charts for weekly spending patterns |
| Challenges | Daily/Weekly challenges, streaks, badges, points history |
| Alerts | Smart spending alerts and warnings |
| Notifications | All app notifications and reminders |
| Scan Receipt | Camera-based receipt scanning with OCR |
| Scan QR/Pay | UPI QR code scanning for payment apps |
| Payment | Payment app shortcuts (GPay, PhonePe, Paytm) |
| Settings | App preferences, theme, notifications, about |

---

## Tech Stack

### Frontend Framework
- **Flutter** - Cross-platform mobile development

### Backend & Cloud
- **Firebase Authentication** - User authentication
- **Cloud Firestore** - Cloud data storage (optional)
- **MongoDB Atlas** - Alternative cloud sync option

### Local Storage
- **SQLite (sqflite)** - Local database for expenses
- **SharedPreferences** - App settings and session storage

### AI & ML
- **Google ML Kit** - Text recognition for receipt scanning

### Libraries & Packages

| Category | Packages |
|----------|----------|
| Charts | `fl_chart` |
| Authentication | `firebase_auth`, `google_sign_in` |
| Database | `sqflite`, `shared_preferences` |
| Cloud | `cloud_firestore`, `mongo_dart` |
| ML/OCR | `google_mlkit_text_recognition`, `image_picker` |
| Notifications | `flutter_local_notifications`, `timezone` |
| Payments | `upi_india`, `mobile_scanner` |
| PDF/Printing | `pdf`, `printing` |
| UI Components | `confetti`, `cupertino_icons` |
| Utilities | `flutter_dotenv`, `intl`, `connectivity_plus`, `url_launcher`, `http`, `path_provider`, `telephony` |

---

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
│
├── models/                      # Data models
│   ├── app_notification.dart
│   ├── challenge.dart           # Challenge, Gamification models
│   ├── expense.dart             # Expense model
│   └── user.dart                # User model
│
├── services/                    # Business logic
│   ├── app_config.dart          # Environment configuration
│   ├── app_logger.dart          # Error logging
│   ├── auth_service.dart        # Authentication
│   ├── budget_cycle_preferences.dart
│   ├── challenge_service.dart   # Challenge generation
│   ├── database_service.dart    # SQLite operations
│   ├── date_cycle_service.dart  # Budget cycle management
│   ├── expense_service.dart     # Expense CRUD
│   ├── financial_score_service.dart  # Health score
│   ├── gamification_service.dart    # Points, badges, streaks
│   ├── mongo_expense_repository.dart
│   ├── mongo_gamification_repository.dart
│   ├── notification_preferences_service.dart
│   ├── notification_service.dart    # Push notifications
│   ├── notification_trigger_service.dart
│   ├── payment_service.dart     # Payment app integration
│   ├── prediction_service.dart  # AI spending prediction
│   ├── receipt_scanner_service.dart # OCR processing
│   ├── report_service.dart      # PDF report generation
│   ├── sms_expense_parser.dart  # SMS parsing
│   ├── sms_tracking_preferences.dart
│   └── theme_service.dart       # Theme management
│
├── screens/                     # UI screens
│   ├── about_app_screen.dart
│   ├── add_expense_screen.dart
│   ├── alerts_screen.dart
│   ├── challenge_screen.dart
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── monthly_report_screen.dart
│   ├── notifications_screen.dart
│   ├── onboarding_screen.dart
│   ├── payment_history_screen.dart
│   ├── payment_screen.dart
│   ├── register_screen.dart
│   ├── scan_qr_payment_screen.dart
│   ├── scan_receipt_screen.dart
│   ├── settings_screen.dart
│   └── weekly_trends_screen.dart
│
├── widgets/                     # Reusable components
│   ├── alert_card.dart
│   ├── budget_card.dart
│   ├── budget_summary_card.dart
│   ├── challenge_card.dart
│   ├── empty_states.dart
│   ├── expense_card.dart
│   ├── financial_health_card.dart
│   ├── home_header.dart
│   ├── main_bottom_nav.dart
│   ├── notification_tile.dart
│   ├── payment_app_card.dart
│   ├── points_history_card.dart
│   ├── prediction_card.dart
│   ├── safe_builder.dart
│   ├── smart_date_selector.dart
│   ├── sms_expense_dialog.dart
│   ├── spending_chart.dart
│   └── streak_savings_card.dart
│
└── utils/                       # Helpers
    ├── demo_seed_helper.dart
    ├── receipt_ocr_helper.dart
    └── upi_payment_validation.dart
```

---

## Installation Guide

### Prerequisites
- Flutter SDK (3.3.4+)
- Android Studio / Xcode
- Firebase account

### Steps

#### 1. Clone Repository
```bash
git clone https://github.com/TheMukeshDev/PocketPilot.git
cd PocketPilot
```

#### 2. Install Dependencies
```bash
flutter pub get
```

#### 3. Configure Firebase
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Register Android and iOS apps
3. Download config files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
4. Enable **Email/Password** and **Google** providers in Firebase Authentication

#### 4. Configure Environment Variables
Create a `.env` file in the project root:

```env
# App Configuration
ENABLE_DEMO_LOGIN=true
DEMO_EMAIL=test@gmail.com
DEMO_PASSWORD=123456
ENABLE_SMS_AUTOTRACK=false

# Google Sign-In
GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com

# Firebase Configuration
FIREBASE_API_KEY=your-api-key
FIREBASE_APP_ID=1:xxx:android:xxx
FIREBASE_MESSAGING_SENDER_ID=xxx
FIREBASE_PROJECT_ID=your-project
FIREBASE_STORAGE_BUCKET=your-project.appspot.com

# AI (Optional)
GEMINI_API_KEY=your-gemini-key
```

#### 5. Run the App
```bash
flutter run
```

---

## Configuration

### Environment Variables (.env)

| Variable | Required | Description |
|----------|----------|-------------|
| `ENABLE_DEMO_LOGIN` | No | Enable demo mode (default: false) |
| `DEMO_EMAIL` | No | Demo account email |
| `DEMO_PASSWORD` | No | Demo account password |
| `ENABLE_SMS_AUTOTRACK` | No | Auto-detect expenses from SMS |
| `GOOGLE_WEB_CLIENT_ID` | Yes* | Google Sign-In client ID |
| `FIREBASE_API_KEY` | Yes* | Firebase API key |
| `FIREBASE_APP_ID` | Yes* | Firebase app ID |
| `FIREBASE_MESSAGING_SENDER_ID` | Yes* | Firebase sender ID |
| `FIREBASE_PROJECT_ID` | Yes* | Firebase project ID |
| `FIREBASE_STORAGE_BUCKET` | Yes* | Firebase storage bucket |
| `GEMINI_API_KEY` | No | Gemini AI for enhanced OCR |

*Required for Firebase authentication to work

### Google Sign-In Setup
1. Enable Google provider in Firebase Console
2. Add SHA-1 and SHA-256 fingerprints to Android app settings
3. Re-download `google-services.json` after adding fingerprints

### MongoDB (Optional)
For cloud sync alternative:
```env
MONGO_URI=mongodb+srv://user:password@cluster.mongodb.net
MONGO_DB_NAME=budget_tracker
```

---

## Usage Flow

### New User
1. Complete onboarding flow (4 steps)
2. Set monthly budget and rent (if any)
3. Start tracking expenses

### Daily Usage
1. Add expenses manually or via receipt scan
2. View spending chart on home dashboard
3. Check AI prediction for overspending warnings
4. Complete daily challenges to earn points
5. Receive smart alerts for risky spending

### Weekly Review
1. View monthly report with category breakdown
2. Export PDF report for records
3. Check weekly trends
4. Complete weekly challenges
5. Unlock new badges

---

## Demo Flow (Hackathon)

**Suggested 90-second demo:**

1. Login with demo account
2. Show onboarding flow for new users
3. Add expense quickly (manual entry)
4. Use **Scan Receipt** to auto-fill merchant + amount
5. Display updated home dashboard with chart
6. Show AI prediction card with overspend warning
7. View Challenges screen with points and badges
8. Trigger/show smart alert behavior
9. Export monthly report as PDF

**Demo Flow:**
```
Login → Onboarding → Add Expense → Scan Receipt → 
View Chart → AI Prediction → Challenges → Smart Alert → PDF Export
```

---

## Quick Commands

```bash
# Install dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Clean and rebuild
flutter clean && flutter pub get && flutter build apk --debug
```

---

## Future Improvements

- [ ] Voice expense entry
- [ ] Bank SMS auto-detection
- [ ] Expense sharing with friends/groups
- [ ] Investment tracking
- [ ] Bill reminders
- [ ] Multi-currency support
- [ ] Dark mode enhancements
- [ ] Widgets for home screen

---

## Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

MIT License - See [LICENSE](LICENSE) file for details.

---

## Author

**Mukesh**

- GitHub: [TheMukeshDev](https://github.com/TheMukeshDev)

---

## Screenshots

![Login Screen](screenshots/login.jpeg)
![Home Screen](screenshots/home.jpeg)
![Add Expense Screen](screenshots/add_expense.jpeg)
![Settings Screen](screenshots/settings.jpeg)
![Scan QR & Pay Screen](screenshots/scan.jpeg)
