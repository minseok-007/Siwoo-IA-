# Firebase Setup Guide for PawPal

## Quick Setup (5 minutes)

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Name it "PawPal" or "dog-walker-app"
4. Enable Google Analytics (optional)
5. Click "Create project"

### 2. Enable Authentication
1. In Firebase Console, go to "Authentication"
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Email/Password"
5. Click "Save"

### 3. Create Firestore Database
1. Go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location close to you
5. Click "Done"

### 4. Get Configuration Files

#### For iOS:
1. Go to Project Settings (gear icon)
2. Click "Add app" → iOS
3. Enter Bundle ID: `com.example.dogWalkerApp`
4. Download `GoogleService-Info.plist`
5. Add to `ios/Runner/GoogleService-Info.plist`

#### For Android:
1. Go to Project Settings (gear icon)
2. Click "Add app" → Android
3. Enter Package name: `com.example.dog_walker_app`
4. Download `google-services.json`
5. Add to `android/app/google-services.json`

### 5. Update Android Configuration
Add to `android/app/build.gradle`:
```gradle
// Add this at the bottom
apply plugin: 'com.google.gms.google-services'
```

Add to `android/build.gradle`:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
}
```

### 6. Update iOS Configuration
Add to `ios/Podfile`:
```ruby
platform :ios, '16.0'
```

### 7. Install Dependencies
```bash
flutter pub get
cd ios && pod install && cd ..
```

## Test the Setup
Run the app and try to sign up - if it works, Firebase is connected!

## Web Setup (Flutter Web)

Flutter Web requires explicit Firebase config at runtime. Provide these via `--dart-define` when running or building:

- FIREBASE_API_KEY
- FIREBASE_APP_ID
- FIREBASE_MESSAGING_SENDER_ID
- FIREBASE_PROJECT_ID
- FIREBASE_AUTH_DOMAIN (optional but recommended)
- FIREBASE_STORAGE_BUCKET (optional)
- FIREBASE_MEASUREMENT_ID (optional)

Example run command:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=YOUR_API_KEY \
  --dart-define=FIREBASE_APP_ID=1:XXXXXXXX:web:YYYYYYYY \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=XXXXXXXX \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com \
  --dart-define=FIREBASE_MEASUREMENT_ID=G-XXXXXXXX
```

For production builds:

```bash
flutter build web \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=... \
  --dart-define=FIREBASE_MEASUREMENT_ID=...
```

Tip: Alternatively, you can run `flutterfire configure` to generate `lib/firebase_options.dart` and replace the web initialization with `DefaultFirebaseOptions.currentPlatform`. The current setup uses `--dart-define` to avoid committing secrets.

## Security Rules (Optional)
In Firestore Console → Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
``` 
