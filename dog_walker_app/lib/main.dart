// Flutter framework imports
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Firebase imports for backend services
import 'package:firebase_core/firebase_core.dart';

// State management using Provider pattern
import 'package:provider/provider.dart';

// Local service providers for app-wide state management
import 'services/auth_provider.dart';
import 'services/theme_provider.dart';
import 'services/locale_provider.dart';

// Internationalization support
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Authentication routing wrapper
import 'screens/auth_wrapper.dart';

/// Configures Firebase for Flutter Web using environment variables injected via `--dart-define`.
/// 
/// This approach provides several benefits:
/// - Keeps sensitive Firebase configuration out of source control
/// - Allows different configurations for different environments (dev, staging, prod)
/// - Prevents accidental exposure of API keys in version control
/// 
/// Trade-offs:
/// - Values are compile-time constants, so updates require a rebuild
/// - Must be provided at build time, not runtime
/// 
/// @return FirebaseOptions configured for web platform
/// @throws StateError if required configuration values are missing
FirebaseOptions _webFirebaseOptionsFromEnv() {
  // Extract Firebase configuration from compile-time environment variables
  // These are injected via --dart-define flags during build process
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');

  // Validate that all required Firebase configuration values are present
  // This prevents runtime errors due to missing configuration
  if (apiKey.isEmpty || appId.isEmpty || messagingSenderId.isEmpty || projectId.isEmpty) {
    throw StateError(
      'Missing Firebase web config. Provide --dart-define values for '
      'FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, and FIREBASE_PROJECT_ID.'
    );
  }

  // Return configured FirebaseOptions with optional fields set to null if empty
  // This allows for flexible configuration where some fields may not be required
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    measurementId: measurementId.isEmpty ? null : measurementId,
  );
}

/// Application entry point that initializes Firebase and starts the Flutter app.
/// 
/// This function:
/// 1. Ensures Flutter binding is initialized before any other operations
/// 2. Initializes Firebase with platform-specific configuration
/// 3. Launches the main application widget
/// 
/// Platform-specific initialization:
/// - Web: Uses environment variables for Firebase configuration
/// - Mobile/Desktop: Uses default Firebase configuration from platform files
void main() async {
  // Initialize Flutter binding to ensure framework is ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific configuration
  if (kIsWeb) {
    // Web platform requires explicit Firebase configuration
    await Firebase.initializeApp(options: _webFirebaseOptionsFromEnv());
  } else {
    // Mobile/Desktop platforms use default configuration from platform files
    await Firebase.initializeApp();
  }
  
  // Launch the main application
  runApp(const MyApp());
}

/// Root application widget that configures the entire app with providers and theming.
/// 
/// This widget serves as the top-level configuration for:
/// - State management providers (Auth, Theme, Locale)
/// - Material Design theming (light/dark mode support)
/// - Internationalization (i18n) support
/// - Navigation routing
/// 
/// Architecture:
/// - Uses Provider pattern for state management
/// - Implements responsive theming with light/dark mode support
/// - Supports multiple locales (English, Korean)
/// - Routes to AuthWrapper for authentication flow
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Configure all app-wide state providers
      providers: [
        // Authentication state management
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Theme state management (light/dark mode)
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Locale state management (language selection)
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      // Consumer that rebuilds when theme or locale changes
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return MaterialApp(
            // App metadata
            title: 'PawPal',
            debugShowCheckedModeBanner: false,
            
            // Theme configuration
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            
            // Internationalization configuration
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('en'), // English
              Locale('ko'), // Korean
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,           // Custom app translations
              GlobalMaterialLocalizations.delegate, // Material Design translations
              GlobalCupertinoLocalizations.delegate, // iOS-style translations
              GlobalWidgetsLocalizations.delegate,   // Flutter widget translations
            ],
            
            // Initial route - authentication wrapper
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}
