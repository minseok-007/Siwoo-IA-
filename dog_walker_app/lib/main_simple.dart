// Flutter framework imports
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Local service and screen imports
import 'services/auth_provider.dart';
import 'screens/auth_wrapper.dart';

/// Simplified application entry point for development and testing.
/// 
/// This version of main.dart provides a minimal setup without:
/// - Firebase configuration
/// - Internationalization support
/// - Advanced theming
/// - Multiple provider dependencies
/// 
/// Use this for:
/// - Quick development and testing
/// - Demonstrating core functionality
/// - Learning the app structure
/// - Debugging without external dependencies
/// 
/// For production use, prefer main.dart which includes full configuration.
void main() {
  runApp(const MyApp());
}

/// Simplified app widget with minimal configuration.
/// 
/// This widget provides a basic app setup with:
/// - Single provider for authentication
/// - Custom Material Design theme
/// - Direct routing to AuthWrapper
/// 
/// Theme features:
/// - Blue color scheme for consistency
/// - Rounded corners for modern look
/// - Elevated buttons with proper styling
/// - Custom input field decorations
/// - Card-based layouts
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Single provider for authentication state
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'PawPal',
        debugShowCheckedModeBanner: false,
        
        // Custom theme configuration
        theme: ThemeData(
          // Primary color scheme
          primarySwatch: Colors.blue,
          primaryColor: Colors.blue[600],
          scaffoldBackgroundColor: Colors.grey[50],
          
          // App bar styling
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue[600],
            elevation: 0, // Flat design
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          // Button styling
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
          
          // Input field styling
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          
          // Card styling
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
} 