# 📱 RideShare Flutter App Build Guide

This guide provides comprehensive instructions for building and deploying the RideShare Flutter mobile application.

## 🎯 **Overview**

The RideShare Flutter app is a comprehensive ride-sharing mobile application that connects to your FastAPI backend deployed on Azure VM. The app includes:

- **User Authentication**: Login/Register with JWT token management
- **Ride Management**: Create, search, accept, and track rides
- **Driver Mode**: Route creation and management for drivers
- **Real-time Location**: GPS tracking and live updates
- **Maps Integration**: Flutter Map for route visualization
- **Safety Features**: Emergency alerts and panic button

## 📋 **Prerequisites**

### **System Requirements:**
- **Flutter SDK**: 3.0.0 or higher
- **Dart SDK**: 3.0.0 or higher
- **Android Studio**: Latest version with Android SDK
- **Android SDK**: API level 21 (Android 5.0) minimum
- **Java**: JDK 11 or higher

### **Installation Steps:**

1. **Install Flutter:**
   ```bash
   # Windows (using chocolatey)
   choco install flutter
   
   # macOS (using homebrew)
   brew install flutter
   
   # Or download from: https://flutter.dev/docs/get-started/install
   ```

2. **Install Android Studio:**
   - Download from: https://developer.android.com/studio
   - Install Android SDK and build tools
   - Configure Flutter plugin

3. **Verify Installation:**
   ```bash
   flutter doctor
   ```

## 🛠️ **Configuration Changes Made**

### **1. API Endpoints Updated:**
- Updated base URL to your Azure VM: `http://158.158.41.106`
- Fixed authentication endpoints to match FastAPI backend:
  - Login: `/auth/jwt/login`
  - Register: `/auth`
  - Profile: `/users/me`

### **2. Android Permissions Added:**
```xml
<!-- Internet and Network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Location Services -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Camera and Storage -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- Emergency Features -->
<uses-permission android:name="android.permission.CALL_PHONE" />
```

### **3. Network Security Configuration:**
- Added `network_security_config.xml` to allow HTTP traffic to your Azure VM
- Configured cleartext traffic permissions

### **4. App Branding:**
- Updated app name to "RideShare"
- Configured proper application ID: `com.example.rideshare_app`

## 🚀 **Building the App**

### **Quick Build (Automated):**

#### **Windows:**
```cmd
cd app
build_android.bat
```

#### **Linux/macOS:**
```bash
cd app
chmod +x build_android.sh
./build_android.sh
```

### **Manual Build Steps:**

1. **Navigate to App Directory:**
   ```bash
   cd app
   ```

2. **Clean Previous Builds:**
   ```bash
   flutter clean
   ```

3. **Get Dependencies:**
   ```bash
   flutter pub get
   ```

4. **Create Environment File (.env):**
   ```env
   # API Configuration
   API_BASE_URL=http://158.158.41.106
   API_TIMEOUT=30
   
   # App Configuration
   APP_NAME=RideShare
   APP_VERSION=1.0.0
   DEBUG_MODE=true
   
   # Feature Flags
   ENABLE_NOTIFICATIONS=true
   ENABLE_LOCATION_TRACKING=true
   ENABLE_OFFLINE_MODE=false
   ```

5. **Analyze Code:**
   ```bash
   flutter analyze
   ```

6. **Build Debug APK:**
   ```bash
   flutter build apk --debug
   ```

7. **Build Release APK:**
   ```bash
   flutter build apk --release
   ```

8. **Build App Bundle (for Play Store):**
   ```bash
   flutter build appbundle --release
   ```

## 📱 **Installation & Testing**

### **Install on Android Device:**

#### **Method 1: Using ADB**
```bash
# Connect your Android device via USB
# Enable Developer Options and USB Debugging

# Install debug APK
adb install build/app/outputs/flutter-apk/app-debug.apk

# Install release APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

#### **Method 2: Direct Installation**
1. Enable "Unknown Sources" in Android Settings
2. Transfer APK file to your device
3. Open the APK file and install

#### **Method 3: Run Directly from Development**
```bash
# Connect Android device or start emulator
flutter devices

# Run in debug mode
flutter run

# Run on specific device
flutter run -d <device_id>
```

### **APK Locations:**
- **Debug APK**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Release APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`

## 🧪 **Testing the App**

### **1. API Connection Test:**
1. Open the app
2. Check if splash screen loads properly
3. Try to register a new account
4. Test login functionality

### **2. Core Features Test:**
- **Authentication**: Register/Login/Logout
- **Profile**: View and edit user profile
- **Ride Search**: Search for available rides
- **Ride Creation**: Create new ride offers
- **Location Services**: Test GPS functionality
- **Real-time Updates**: Test WebSocket connections

### **3. Network Connectivity:**
The app is configured to connect to your Azure VM at `158.158.41.106`. Ensure:
- Your Azure VM is running
- API is accessible at port 80 (via Nginx)
- Network security allows HTTP traffic

## 🔧 **Development Commands**

```bash
# Start development server
flutter run

# Hot reload (during development)
# Press 'r' in terminal

# Hot restart (during development)
# Press 'R' in terminal

# Run tests
flutter test

# Format code
flutter format .

# Generate app icons
flutter packages pub run flutter_launcher_icons:main

# Clean and rebuild
flutter clean && flutter pub get && flutter run
```

## 📊 **App Architecture**

### **State Management:**
- **Provider Pattern**: Used for state management
- **AuthProvider**: Handles authentication state
- **RideProvider**: Manages ride-related state
- **LocationProvider**: Handles location updates

### **API Communication:**
- **HTTP Service**: RESTful API calls to FastAPI backend
- **JWT Authentication**: Bearer token-based auth
- **WebSocket**: Real-time updates for rides and location

### **Local Storage:**
- **SharedPreferences**: Stores auth tokens and user preferences
- **Secure Storage**: For sensitive data

## 🚨 **Troubleshooting**

### **Common Issues:**

#### **1. Build Failures:**
```bash
# Clear Flutter cache
flutter clean
flutter pub get

# Clear Gradle cache (Android)
cd android
./gradlew clean
cd ..
```

#### **2. Network Connection Issues:**
- Check if Azure VM is accessible: `ping 158.158.41.106`
- Verify API is running: `curl http://158.158.41.106/`
- Check Android network security config

#### **3. Permission Issues:**
- Ensure all required permissions are in AndroidManifest.xml
- Test on actual device (not emulator) for location services

#### **4. API Endpoint Errors:**
- Verify API endpoints match FastAPI backend
- Check authentication token format
- Test API endpoints using Postman/curl

### **Debug Logs:**
```bash
# View Flutter logs
flutter logs

# View Android logs
adb logcat

# View specific app logs
adb logcat | grep "flutter"
```

## 🎯 **Next Steps**

### **For Development:**
1. Test all features thoroughly
2. Add error handling and validation
3. Implement offline mode
4. Add push notifications
5. Optimize performance

### **For Production:**
1. Sign the APK with release key
2. Upload to Google Play Store
3. Set up CI/CD pipeline
4. Monitor crash reports
5. Implement analytics

### **Integration with Backend:**
1. Test real ride creation and matching
2. Verify WebSocket connections
3. Test emergency features
4. Validate payment integration
5. Test driver-passenger matching

## 📞 **Support**

If you encounter any issues:
1. Check Flutter doctor: `flutter doctor`
2. Review build logs for specific errors
3. Verify API connectivity
4. Check Android device compatibility
5. Ensure all dependencies are properly installed

The app is now ready for testing and deployment! 🎉

