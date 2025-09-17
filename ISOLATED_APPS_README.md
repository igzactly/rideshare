# RideShare - Isolated Driver and Passenger Apps

## Overview
The RideShare project has been split into two completely isolated, self-contained Flutter applications:

### 🚗 Driver App (`driver_app/`)
**Purpose**: For drivers to offer rides and manage passengers  
**Focus**: Earnings, ride management, passenger requests  
**Primary Color**: Purple  
**Tagline**: "Drive. Earn. Connect."

### 👥 Passenger App (`passenger_app/`)
**Purpose**: For passengers to find and book rides  
**Focus**: Finding rides, booking, status tracking  
**Primary Color**: Blue  
**Tagline**: "Travel. Connect. Save."

## App Structure

Both apps are completely isolated with their own:
- Dependencies (no shared packages)
- Models, Services, Providers
- UI Components and Screens
- Assets and Configuration

```
rideshare/
├── driver_app/               # 🚗 Complete driver app
│   ├── lib/
│   │   ├── models/          # User, Ride models
│   │   ├── services/        # API, Auth, Location services
│   │   ├── providers/       # State management
│   │   ├── utils/          # Theme, constants
│   │   ├── widgets/        # UI components
│   │   ├── screens/        # Driver-specific screens
│   │   └── main.dart       # Driver app entry
│   ├── assets/             # Driver app assets
│   ├── .env               # Environment config
│   └── pubspec.yaml       # Dependencies
├── passenger_app/          # 👥 Complete passenger app
│   ├── lib/
│   │   ├── models/         # User, Ride models
│   │   ├── services/       # API, Auth, Location services
│   │   ├── providers/      # State management
│   │   ├── utils/         # Theme, constants
│   │   ├── widgets/       # UI components
│   │   ├── screens/       # Passenger-specific screens
│   │   └── main.dart      # Passenger app entry
│   ├── assets/            # Passenger app assets
│   ├── .env              # Environment config
│   └── pubspec.yaml      # Dependencies
└── app/                   # Original app (can be archived)
```

## Key Features

### Driver App Features:
- **Dashboard**: Earnings overview, active rides, pending requests
- **Create Ride**: Simple form to offer rides to passengers
- **My Created Rides**: Manage all created rides and passenger requests
- **Request Management**: Accept/decline passenger requests
- **Ride Controls**: Start, manage, and complete rides
- **Earnings Tracking**: Monitor daily/weekly earnings

### Passenger App Features:
- **Dashboard**: Find rides, view nearby rides, booking status
- **Find Rides**: Search and filter available rides by location
- **My Rides**: View booking history and current ride status
- **Ride Booking**: Request rides with one-tap booking
- **Status Tracking**: Clear status updates and progress tracking
- **Driver Communication**: Contact driver during rides

## User Flows

### Driver Flow:
```
Login → Dashboard → Create Ride → Wait for Requests → Accept Passenger → Start Ride → Complete → Earnings
```

### Passenger Flow:
```
Login → Dashboard → Find Rides → Request Ride → Await Approval → Start Ride → Complete → Rate
```

## Running the Apps

### Driver App:
```bash
cd driver_app
flutter pub get
flutter run
```

### Passenger App:
```bash
cd passenger_app
flutter pub get
flutter run
```

## Benefits of Isolation

### User Experience:
- **Clear purpose** - no confusion about app mode
- **Focused features** - only relevant functionality
- **Better UX** - streamlined for specific user type
- **Faster navigation** - fewer irrelevant options

### Development:
- **No shared dependencies** - eliminates complex dependency issues
- **Easier maintenance** - separate, focused codebases
- **Independent deployment** - update one without affecting the other
- **Simpler testing** - test each app in isolation
- **Better app store optimization** - separate listings and descriptions

### Technical:
- **Self-contained** - each app has all necessary code
- **No import conflicts** - all imports are local
- **Independent versioning** - each app can evolve separately
- **Reduced complexity** - no shared package management

## API Compatibility

Both apps use the same Flask API backend at `http://158.158.41.106:8000` with endpoints:
- Authentication: `/auth/login`, `/auth/register`
- Rides: `/rides/`, `/rides/find`, `/rides/{id}/request`, etc.
- Users: `/users/profile`, `/users/{id}`
- Location: `/location/update`, `/location/nearby-drivers`

## Next Steps

1. **Test both apps independently**
2. **Customize themes** for each app's specific branding
3. **Add app-specific features** without affecting the other
4. **Deploy to app stores** with targeted descriptions
5. **Implement analytics** for each user type separately

Both apps are now completely isolated and ready for independent development and deployment!
