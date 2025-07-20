# Quick Start Guide - PawPal App

## Option 1: Test Without Firebase (Easiest)

### 1. Install Xcode (for iOS development)
```bash
# Install Xcode from App Store or download from Apple Developer
# Then run these commands:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### 2. Install CocoaPods
```bash
sudo gem install cocoapods
```

### 3. Run the App
```bash
# Install dependencies
flutter pub get

# Run on iOS Simulator
flutter run -d ios

# Or run on Chrome (web) for testing
flutter run -d chrome
```

## Option 2: With Firebase (Production Ready)

### 1. Follow Firebase Setup
See `firebase_setup_guide.md` for detailed instructions.

### 2. Update main.dart
Replace the current main.dart with the Firebase version.

### 3. Run the App
```bash
flutter run -d ios
```

## Testing the App

1. **Sign Up**: Create a new account as either Dog Owner or Dog Walker
2. **Login**: Sign in with your credentials
3. **Home Screen**: See the dashboard with role-specific actions
4. **Logout**: Test the logout functionality

## Features to Test

- ✅ User registration with validation
- ✅ User type selection (Dog Owner/Walker)
- ✅ Login and logout
- ✅ Form validation (email, password, phone)
- ✅ Password reset (simplified)
- ✅ Role-based home screen
- ✅ Modern UI with animations

## Troubleshooting

### If you get iOS build errors:
```bash
cd ios
pod install
cd ..
flutter clean
flutter pub get
flutter run -d ios
```

### If you get Android build errors:
```bash
flutter clean
flutter pub get
flutter run -d android
```

## Next Steps

1. **Add Firebase** (recommended for production)
2. **Add more screens** (dog profiles, walk requests, etc.)
3. **Add real-time features** (messaging, notifications)
4. **Add location services**
5. **Add payment integration**

## Firebase vs Local Storage

| Feature | Local Storage | Firebase |
|---------|---------------|----------|
| Setup Time | 2 minutes | 10 minutes |
| Data Persistence | Device only | Cloud |
| Real-time Updates | No | Yes |
| Scalability | Limited | Unlimited |
| Offline Support | Yes | Yes |
| Cost | Free | Free tier available |

**Recommendation**: Start with local storage for testing, then migrate to Firebase for production. 