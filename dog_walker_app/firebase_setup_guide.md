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