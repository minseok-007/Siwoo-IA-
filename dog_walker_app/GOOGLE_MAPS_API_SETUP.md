# Google Maps API Setup for Walk Routes

The walk route feature uses Google Places API to find nearby parks and walking paths. 

## Setup Instructions

### 1. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the following APIs:
   - **Places API** (for finding parks and trails)
   - **Maps SDK for Android** (if testing on Android)
   - **Maps SDK for iOS** (if testing on iOS)

### 2. Create API Key

1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **API Key**
3. Copy the API key

### 3. Configure in Flutter

#### Option A: Environment Variable (Recommended)

Run the app with:
```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_API_KEY_HERE
```

#### Option B: Direct Code (For Testing Only)

Edit `lib/services/walk_route_service.dart`:
```dart
static const String _googleMapsApiKey = 'YOUR_API_KEY_HERE';
```

⚠️ **Warning**: Don't commit API keys to version control!

### 4. Restrict API Key (Production)

1. In Google Cloud Console, edit your API key
2. Set **Application restrictions**:
   - Android: Add your package name and SHA-1
   - iOS: Add your bundle identifier
3. Set **API restrictions**: Only allow Places API

## Without API Key

If no API key is provided, the app will:
- Use simple circular routes as fallback
- Still generate 3 routes with time estimates
- Work without internet connection (for basic routes)

## Testing

1. Run the app
2. Go to **Walk Route** screen
3. Click the green route button (top right)
4. You should see 3 recommended routes with:
   - Distance
   - Estimated walking time
   - Place names (if API key is set)
