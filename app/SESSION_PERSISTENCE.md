# Session Persistence Feature

## Overview
The RideShare app now includes automatic session persistence, which means users will stay logged in between app sessions. This eliminates the need to log in every time the app is opened.

## How It Works

### 1. **Automatic Session Storage**
- When a user logs in successfully, their authentication token and user data are automatically saved to the device's secure storage
- This happens using Flutter's `SharedPreferences` package
- The session data is stored locally and persists across app restarts

### 2. **Session Validation**
- When the app starts, it automatically checks for stored session data
- If found, the app validates the token with the server to ensure it's still valid
- If the token is invalid or expired, the session is cleared and the user is redirected to login

### 3. **User Experience**
- **First Login**: User logs in normally and session is saved
- **App Restart**: User is automatically logged in and taken to the home screen
- **Manual Logout**: User can log out from the profile screen, which clears the session
- **Session Expiry**: If the server token expires, user is automatically logged out

## Technical Implementation

### AuthProvider Changes
- Added `_initializeAuth()` method for proper async initialization
- Enhanced `_loadStoredAuth()` with token validation
- Added `_validateToken()` method to check token validity with server
- Added `_clearStoredAuth()` method for proper session cleanup
- Session data is always saved on successful login (no "Remember Me" toggle needed)

### API Service
- Added `validateToken()` endpoint to check token validity
- Endpoint: `GET /auth/validate`

### UI Updates
- **Login Screen**: "Stay logged in" option is enabled by default
- **Profile Screen**: Added session status indicator
- **Splash Screen**: Enhanced to wait for auth initialization

## Security Features

### Token Validation
- Tokens are validated with the server on app startup
- Invalid tokens are automatically cleared
- Network errors during validation result in session clearance

### Secure Storage
- Session data is stored using Flutter's SharedPreferences
- Data is stored locally on the device
- No sensitive data is transmitted unnecessarily

## User Controls

### Login Options
- **Stay Logged In**: Enabled by default, saves session data
- Users can disable this option if they prefer manual login

### Logout
- **Profile Screen**: Users can manually log out
- **Automatic**: Session is cleared if token becomes invalid

## Debug Information
The app includes debug logging to help track session state:
- Session loading status
- Token validation results
- Session save confirmations

## Benefits
1. **Improved UX**: No need to log in repeatedly
2. **Faster Access**: Direct access to app features
3. **Security**: Automatic token validation
4. **Flexibility**: Users can still manually log out

## Future Enhancements
- Biometric authentication support
- Session timeout settings
- Multiple account support
- Enhanced security features
