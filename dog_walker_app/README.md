# PawPal - Dog Walking App

A Flutter-based mobile application that connects dog owners with dog walkers, making it easy to find walking companions and professional dog walking services.

## Features

### Authentication
- ✅ User registration and login
- ✅ User type selection (Dog Owner or Dog Walker)
- ✅ Password reset functionality
- ✅ Form validation
- ✅ Secure Firebase authentication

### User Interface
- ✅ Modern, responsive design
- ✅ Material Design components
- ✅ Custom theme with blue color scheme
- ✅ Google Fonts integration
- ✅ Loading states and error handling

### User Types
- **Dog Owners**: Can post walk requests, manage dog profiles, view walk history
- **Dog Walkers**: Can browse available walks, manage schedule, track earnings

## Project Structure

```
lib/
├── models/
│   └── user_model.dart          # User data model
├── screens/
│   ├── auth_wrapper.dart        # Authentication state handler
│   ├── login_screen.dart        # Login screen
│   ├── signup_screen.dart       # Registration screen
│   └── home_screen.dart         # Main dashboard
├── services/
│   ├── auth_service.dart        # Firebase authentication service
│   └── auth_provider.dart       # State management for auth
├── utils/
│   └── validators.dart          # Form validation utilities
└── main.dart                    # App entry point
```

## Setup Instructions

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code
- Firebase account

### 1. Clone and Setup
```bash
# Navigate to the project directory
cd dog_walker_app

# Install dependencies
flutter pub get
```

### 2. Firebase Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Enable Authentication (Email/Password)
4. Create a Firestore database

#### Configure Firebase for Flutter
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login to Firebase: `firebase login`
3. Initialize Firebase in your project: `firebase init`
4. Add your Firebase configuration files:
   - For Android: `android/app/google-services.json`
   - For iOS: `ios/Runner/GoogleService-Info.plist`

#### Update Dependencies
The following Firebase packages are already included in `pubspec.yaml`:
- `firebase_core: ^3.6.0`
- `firebase_auth: ^5.3.3`
- `cloud_firestore: ^5.4.3`

### 3. Run the App
```bash
# For Android
flutter run

# For iOS
flutter run -d ios
```

## Current Implementation

### Authentication Flow
1. **Signup Screen**: Users can register as either a Dog Owner or Dog Walker
   - Form validation for all fields
   - User type selection with visual cards
   - Password confirmation
   - Phone number validation

2. **Login Screen**: Existing users can sign in
   - Email and password authentication
   - Forgot password functionality
   - Error handling and loading states

3. **Home Screen**: Dashboard after successful authentication
   - Welcome card with user information
   - Role-specific quick actions
   - Navigation to different app sections

### Data Models
- **UserModel**: Comprehensive user data structure supporting both user types
- **UserType**: Enum for distinguishing between Dog Owner and Dog Walker

### State Management
- **Provider**: Used for state management throughout the app
- **AuthProvider**: Manages authentication state and user data
- **AuthService**: Handles Firebase authentication operations

## Validation Rules

### Email
- Required field
- Must be a valid email format

### Password
- Minimum 6 characters
- Must contain uppercase, lowercase, and numbers

### Full Name
- Minimum 2 characters
- Only letters and spaces allowed

### Phone Number
- Must be 10-15 digits
- Accepts various formats (parentheses, dashes, spaces)

## Security Features
- Firebase Authentication for secure user management
- Firestore security rules (to be configured)
- Input validation and sanitization
- Secure password handling

## Next Steps

### Planned Features
- [ ] Dog profile management
- [ ] Walk request posting and browsing
- [ ] Real-time messaging system
- [ ] Location-based matching
- [ ] Payment integration
- [ ] Push notifications
- [ ] Rating and review system
- [ ] Walk scheduling and calendar
- [ ] Photo upload functionality
- [ ] Emergency contact system

### Technical Improvements
- [ ] Add unit tests
- [ ] Implement error logging
- [ ] Add offline support
- [ ] Optimize performance
- [ ] Add accessibility features
- [ ] Implement deep linking

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions, please open an issue in the GitHub repository.
