# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal Therapy is a Flutter-based mental health and emotional wellbeing application integrating Firebase for authentication/data storage, Google Gemini API for AI counseling, and platform-specific health data (HealthKit/Google Fit). The app is primarily designed for Korean-speaking users.

## Development Commands

### Setup
```bash
# Install dependencies
flutter pub get

# iOS: Install CocoaPods dependencies
cd ios && pod install && cd ..

# macOS: Install CocoaPods dependencies
cd macos && pod install && cd ..
```

### Running the App
```bash
# Run on default device
flutter run

# Run on specific device
flutter run -d <device_id>

# List available devices
flutter devices

# Run in release mode
flutter run --release

# Run with verbose output
flutter run -v
```

### Building
```bash
# Build for iOS (requires macOS)
flutter build ios

# Build for Android
flutter build apk
flutter build appbundle

# Clean build artifacts
flutter clean
```

### Code Quality
```bash
# Analyze code for issues
flutter analyze

# Check Flutter version
flutter --version
```

## Environment Configuration

### Required Environment Variables

The app requires a `.env` file at the project root containing:

```env
GEMINI_API_KEY=your_gemini_api_key_here
```

This file is loaded in `main.dart` using `flutter_dotenv` and is excluded from version control via `.gitignore`.

### Firebase Configuration

Firebase is configured per platform:
- **Android**: `android/app/google-services.json`
- **iOS**: `ios/Runner/GoogleService-Info.plist`

Firebase initialization happens in `main.dart` before `runApp()`:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## Architecture

### Application Entry and Navigation Flow

1. **main.dart** → Initializes Firebase, loads `.env`, sets app theme with Roboto font
2. **auth_wrapper.dart** → Routes to `LoginScreen` or `MainScreen` based on Firebase Auth state
3. **MainScreen** → Bottom navigation hub with 4 tabs using `IndexedStack` to preserve state

### Tab Structure (MainScreen)

The app uses a bottom navigation bar with 4 main tabs:

1. **Home Tab** (`_HomeScreenContent`): Quick mood check, mental health diagnosis link, wearable device connection, healing content, emergency contacts
2. **Chat Tab** (`AIChatScreen`): AI counseling powered by Google Gemini API
3. **Tracking Tab** (`EmotionTrackingTab`): Emotion and health metrics visualization with daily/weekly/monthly views
4. **Profile Tab** (`ProfileTab`): User health status, settings, emergency contacts, account management

### Data Layer: FirestoreService

Located in `lib/services/firestore_service.dart`, this service handles all Firestore operations:

**Collections Structure:**
```
users/{uid}
├── Fields: name, email, createdAt, conversationCount, averageHealthScore, healingContentCount, emergencyContacts[]
├── mood_scores/{doc_id}: score, timestamp
├── mental_health_scores/{doc_id}: score, timestamp
└── sleep_records/{date_key}: duration, timestamp (one per day, keyed by YYYY-MM-DD)
```

**Key Methods:**
- `addUser()` - Create user document on registration
- `getUserStream()` - Real-time user profile data
- `updateMoodScore()` / `getMoodScoresStream()` - Mood tracking
- `updateMentalHealthScore()` / `getMentalHealthScoresStream()` - Mental health tracking
- `addSleepRecord()` / `getSleepScoresStream()` - Sleep tracking (one record per day)
- `addEmergencyContact()` / `updateEmergencyContact()` / `deleteEmergencyContact()` / `getEmergencyContactsStream()` - Emergency contact management

### State Management Pattern

The app uses `StatefulWidget` with `StreamBuilder` for reactive UI updates. Firestore streams provide real-time data synchronization:

```dart
StreamBuilder<Map<String, dynamic>?>(
  stream: _firestoreService.getUserStream(userId),
  builder: (context, snapshot) {
    // Rebuild when Firestore data changes
  },
)
```

### AI Chat Integration

`aichat_screen.dart` implements the Gemini API client:
- API endpoint: `generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`
- API key loaded from `.env` via `flutter_dotenv`
- Sends user messages and displays AI responses in a chat interface

### Health Data Integration

The `health` package integrates with:
- **iOS**: HealthKit (requires `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` in Info.plist)
- **Android**: Google Fit (requires permissions in AndroidManifest.xml)

Access step count data through platform channels defined in native code (`MainActivity.kt` for Android).

## Platform-Specific Notes

### iOS
- **Minimum Deployment Target**: iOS 13+ (due to Firebase and health package requirements)
- **Permissions**: Health data access requires Info.plist entries (already configured)
- **CocoaPods**: Always run `pod install` after adding dependencies
- **Entitlements**: `Runner.entitlements` file exists for HealthKit capability

### Android
- **Minimum SDK**: 26 (Android 8.0)
- **Target SDK**: Defined by Flutter
- **MultiDex**: Enabled in `build.gradle.kts` (required for Firebase)
- **Google Services**: Gradle plugin configured for Firebase integration

## Important Implementation Details

### Emotion Tracking Tab

`emotion_tracking_tab.dart` contains complex time-based data visualization:
- Time period toggles (daily/weekly/monthly) control what data is displayed
- `_buildAverageSummaryItem()` calculates averages dynamically from Firestore streams
- Charts use `fl_chart` package for mood scores and mental health scores
- Sleep data shows weekly averages calculated from Firestore records

### Sleep Record Storage

Sleep records use a date-based document ID pattern:
```dart
final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
```
This ensures only one sleep record per day (updates overwrite previous entries for same day).

### UI Theming

The app uses a consistent color scheme defined in `main_screen.dart`:
- Primary Blue: `#2563EB`
- Background Gradient: `#EFF6FF` to `#FAF5FF`
- Card Background: White
- Text Colors: Various shades of gray (#1F2937, #4B5563, #374151, #9CA3AF)
- Emergency Colors: Red tones (#FEE2E2 background, #EF4444 text/border)

All text uses Google Fonts Roboto (configured globally in `main.dart` theme).

## Common Development Patterns

### Adding New Firestore Operations

1. Add method to `FirestoreService` class
2. Use `_db.collection('users').doc(uid)...` pattern
3. Return `Stream<T>` for real-time data or `Future<void>` for writes
4. Handle null/empty cases in UI with snapshot checks

### Adding New Screens

1. Create new file in `lib/` directory
2. Import in `main_screen.dart` or relevant parent
3. Navigate using `Navigator.push()` with `MaterialPageRoute`
4. Maintain consistent AppBar styling and background colors

### Working with Firebase Auth

Current user ID is accessed via:
```dart
final String? userId = FirebaseAuth.instance.currentUser?.uid;
```

Always check for null before Firestore operations.

## Testing on Devices

### iOS Testing
```bash
# List iOS simulators
flutter devices

# Run on iOS simulator
flutter run -d "iPhone 15 Pro"

# Run on physical device (requires Xcode setup)
flutter run -d <device-uuid>
```

### Android Testing
```bash
# List Android devices/emulators
flutter devices

# Run on Android emulator
flutter run -d emulator-5554

# Run on physical device (USB debugging enabled)
flutter run -d <device-id>
```

## Known Issues and Workarounds

### FlutterFire Configuration

If you encounter Firebase configuration issues, use:
```bash
flutterfire configure
```

This regenerates platform-specific Firebase config files.

### HealthKit Permissions

iOS HealthKit permissions must be requested at runtime. The app handles this in `wearable_device_screen.dart` and native iOS code.

## Project Naming Note

The project's internal name is "untitled" (visible in package names and bundle IDs), but displays as "Personal Therapy" in the UI. This is a legacy artifact - bundle identifiers remain `com.example.untitled`.
