@echo off
REM RideShare Flutter Android Build Script for Windows
REM This script builds the Android APK for the RideShare app

echo 🚀 Starting RideShare Flutter Android build...

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed or not in PATH
    echo Please install Flutter from: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

REM Check if we're in the correct directory
if not exist "pubspec.yaml" (
    echo ❌ pubspec.yaml not found. Make sure you're in the Flutter app directory.
    pause
    exit /b 1
)

REM Clean previous builds
echo 🧹 Cleaning previous builds...
flutter clean

REM Get dependencies
echo 📦 Getting Flutter dependencies...
flutter pub get

REM Check for any dependency issues
echo 🔍 Running Flutter doctor...
flutter doctor

REM Create .env file if it doesn't exist
if not exist ".env" (
    echo ⚠️ .env file not found. Creating default configuration...
    (
        echo # RideShare Flutter App Environment Configuration
        echo.
        echo # API Configuration
        echo API_BASE_URL=http://158.158.41.106
        echo API_TIMEOUT=30
        echo.
        echo # App Configuration
        echo APP_NAME=RideShare
        echo APP_VERSION=1.0.0
        echo DEBUG_MODE=true
        echo.
        echo # Feature Flags
        echo ENABLE_NOTIFICATIONS=true
        echo ENABLE_LOCATION_TRACKING=true
        echo ENABLE_OFFLINE_MODE=false
    ) > .env
    echo ✅ Created .env file with default configuration
)

REM Analyze code for potential issues
echo 🔍 Analyzing code...
flutter analyze

REM Build debug APK
echo 🔨 Building debug APK...
flutter build apk --debug

REM Build release APK
echo 🔨 Building release APK...
flutter build apk --release

REM Check if builds were successful
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ✅ Release APK built successfully!
    echo Release APK location: build\app\outputs\flutter-apk\app-release.apk
    dir "build\app\outputs\flutter-apk\app-release.apk"
) else (
    echo ❌ Release APK build failed!
)

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo ✅ Debug APK built successfully!
    echo Debug APK location: build\app\outputs\flutter-apk\app-debug.apk
    dir "build\app\outputs\flutter-apk\app-debug.apk"
) else (
    echo ❌ Debug APK build failed!
)

REM Build app bundle (for Google Play Store)
echo 📱 Building app bundle for Play Store...
flutter build appbundle --release

if exist "build\app\outputs\bundle\release\app-release.aab" (
    echo ✅ App bundle built successfully!
    echo App bundle location: build\app\outputs\bundle\release\app-release.aab
    dir "build\app\outputs\bundle\release\app-release.aab"
) else (
    echo ⚠️ App bundle build failed (this is optional)
)

echo.
echo 🎉 Build process completed!
echo.
echo 📱 Installation Instructions:
echo 1. Enable 'Unknown Sources' in Android Settings
echo 2. Transfer the APK to your Android device
echo 3. Install using: adb install build\app\outputs\flutter-apk\app-release.apk
echo    Or open the APK file directly on your device
echo.
echo 🔧 Development Commands:
echo - Run in debug mode: flutter run
echo - Run on connected device: flutter run -d ^<device_id^>
echo - Hot reload: r (while running)
echo - Hot restart: R (while running)
echo.
pause

