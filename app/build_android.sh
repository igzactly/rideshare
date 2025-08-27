#!/bin/bash

# RideShare Flutter Android Build Script
# This script builds the Android APK for the RideShare app

set -e  # Exit on any error

echo "🚀 Starting RideShare Flutter Android build..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check Flutter version
print_status "Checking Flutter version..."
flutter --version

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Make sure you're in the Flutter app directory."
    exit 1
fi

# Clean previous builds
print_status "Cleaning previous builds..."
flutter clean

# Get dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Check for any dependency issues
print_status "Running Flutter doctor..."
flutter doctor

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    print_warning ".env file not found. Creating default configuration..."
    cat > .env << EOF
# RideShare Flutter App Environment Configuration

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
EOF
    print_status "Created .env file with default configuration"
fi

# Analyze code for potential issues
print_status "Analyzing code..."
flutter analyze

# Build debug APK
print_status "Building debug APK..."
flutter build apk --debug

# Build release APK
print_status "Building release APK..."
flutter build apk --release

# Check if builds were successful
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    print_status "✅ Release APK built successfully!"
    echo "Release APK location: build/app/outputs/flutter-apk/app-release.apk"
    
    # Get APK size
    APK_SIZE=$(ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print $5}')
    echo "APK Size: $APK_SIZE"
else
    print_error "❌ Release APK build failed!"
fi

if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    print_status "✅ Debug APK built successfully!"
    echo "Debug APK location: build/app/outputs/flutter-apk/app-debug.apk"
    
    # Get APK size
    APK_SIZE=$(ls -lh build/app/outputs/flutter-apk/app-debug.apk | awk '{print $5}')
    echo "APK Size: $APK_SIZE"
else
    print_error "❌ Debug APK build failed!"
fi

# Build app bundle (for Google Play Store)
print_status "Building app bundle for Play Store..."
flutter build appbundle --release

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    print_status "✅ App bundle built successfully!"
    echo "App bundle location: build/app/outputs/bundle/release/app-release.aab"
    
    # Get bundle size
    BUNDLE_SIZE=$(ls -lh build/app/outputs/bundle/release/app-release.aab | awk '{print $5}')
    echo "Bundle Size: $BUNDLE_SIZE"
else
    print_warning "⚠️ App bundle build failed (this is optional)"
fi

print_status "🎉 Build process completed!"
print_status ""
print_status "📱 Installation Instructions:"
print_status "1. Enable 'Unknown Sources' in Android Settings"
print_status "2. Transfer the APK to your Android device"
print_status "3. Install using: adb install build/app/outputs/flutter-apk/app-release.apk"
print_status "   Or open the APK file directly on your device"
print_status ""
print_status "🔧 Development Commands:"
print_status "- Run in debug mode: flutter run"
print_status "- Run on connected device: flutter run -d <device_id>"
print_status "- Hot reload: r (while running)"
print_status "- Hot restart: R (while running)"

