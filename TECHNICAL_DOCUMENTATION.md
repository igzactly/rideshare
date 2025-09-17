# RideShare App - Technical Documentation

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [API Documentation](#api-documentation)
3. [Database Schema](#database-schema)
4. [Authentication](#authentication)
5. [Location Services](#location-services)
6. [Real-time Features](#real-time-features)
7. [Deployment](#deployment)
8. [Development Setup](#development-setup)

---

## Architecture Overview

### Tech Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Flask (Python)
- **Database**: MongoDB
- **Authentication**: JWT (JSON Web Tokens)
- **Location Services**: Google Maps API
- **Real-time**: WebSocket connections

### System Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │◄──►│   Flask API     │◄──►│    MongoDB      │
│   (Frontend)    │    │   (Backend)     │    │   (Database)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Location API   │    │   JWT Auth      │    │  Geospatial     │
│  (Google Maps)  │    │   (Security)    │    │   Indexes       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## API Documentation

### Base URL
```
http://158.158.41.106:8000
```

### Authentication Endpoints

#### Register User
```http
POST /auth/register
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "password123",
  "phone": "+44 7123 456789"
}
```

**Response:**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "user_id",
    "name": "John Doe",
    "email": "john@example.com"
  },
  "token": "jwt_token"
}
```

#### Login User
```http
POST /auth/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "message": "Login successful",
  "user": {
    "id": "user_id",
    "name": "John Doe",
    "email": "john@example.com"
  },
  "token": "jwt_token"
}
```

#### Validate Token
```http
GET /auth/validate
Authorization: Bearer jwt_token
```

### Ride Management Endpoints

#### Create Ride (Driver)
```http
POST /rides
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "pickup_location": {
    "latitude": 51.5074,
    "longitude": -0.1278
  },
  "dropoff_location": {
    "latitude": 51.5154,
    "longitude": -0.0925
  },
  "pickup_address": "London Bridge",
  "dropoff_address": "Canary Wharf",
  "pickup_time": "2024-01-15T10:00:00Z",
  "price": 15.50,
  "status": "active"
}
```

#### Search Rides (Passenger)
```http
POST /rides/find
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "pickup_location": {
    "latitude": 51.5074,
    "longitude": -0.1278
  },
  "radius_km": 10.0
}
```

#### Get User Rides
```http
GET /rides/my_rides
Authorization: Bearer jwt_token
```

#### Accept Ride
```http
POST /rides/{ride_id}/accept
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "passenger_id": "passenger_id"
}
```

### Location Tracking Endpoints

#### Update Location
```http
POST /location/update
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "coordinates": [51.5074, -0.1278],
  "accuracy": 10.0,
  "speed": 0.0,
  "heading": 0.0,
  "ride_id": "ride_id"
}
```

#### Start Live Tracking
```http
POST /location/live-tracking/start
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "ride_id": "ride_id"
}
```

#### Get Live Tracking Status
```http
GET /location/live-tracking/{ride_id}/status
Authorization: Bearer jwt_token
```

---

## Database Schema

### Users Collection
```javascript
{
  "_id": ObjectId,
  "name": String,
  "email": String (unique),
  "password": String (hashed),
  "phone": String,
  "is_driver": Boolean,
  "is_verified_driver": Boolean,
  "created_at": Date,
  "updated_at": Date
}
```

### Rides Collection
```javascript
{
  "_id": ObjectId,
  "driver_id": ObjectId,
  "passenger_id": ObjectId,
  "pickup_location": {
    "type": "Point",
    "coordinates": [longitude, latitude]
  },
  "dropoff_location": {
    "type": "Point", 
    "coordinates": [longitude, latitude]
  },
  "pickup_address": String,
  "dropoff_address": String,
  "pickup_time": Date,
  "price": Number,
  "status": String, // "active", "pending", "accepted", "in_progress", "completed", "cancelled"
  "created_at": Date,
  "updated_at": Date,
  "live_tracking_active": Boolean,
  "last_known_location": [longitude, latitude]
}
```

### Locations Collection
```javascript
{
  "_id": ObjectId,
  "user_id": ObjectId,
  "ride_id": ObjectId,
  "coordinates": {
    "type": "Point",
    "coordinates": [longitude, latitude]
  },
  "timestamp": Date,
  "accuracy": Number,
  "speed": Number,
  "heading": Number
}
```

### Drivers Collection
```javascript
{
  "_id": ObjectId,
  "driver_id": ObjectId,
  "is_online": Boolean,
  "status": String, // "active", "busy", "offline"
  "current_location": [longitude, latitude],
  "available_seats": Number,
  "rating": Number,
  "updated_at": Date
}
```

---

## Authentication

### JWT Token Structure
```json
{
  "sub": "user_id",
  "email": "user@example.com",
  "name": "User Name",
  "iat": 1640995200,
  "exp": 1641081600
}
```

### Token Validation
- Tokens expire after 24 hours
- Refresh tokens for extended sessions
- Automatic token validation on protected routes

### Security Headers
```http
Authorization: Bearer jwt_token
Content-Type: application/json
```

---

## Location Services

### Geospatial Queries
```javascript
// Find rides near pickup location
db.rides.find({
  "pickup_location": {
    "$near": {
      "$geometry": {
        "type": "Point",
        "coordinates": [longitude, latitude]
      },
      "$maxDistance": 5000 // 5km in meters
    }
  }
})
```

### Location Indexes
```javascript
// 2dsphere indexes for geospatial queries
db.rides.createIndex({"pickup_location": "2dsphere"})
db.rides.createIndex({"dropoff_location": "2dsphere"})
db.locations.createIndex({"coordinates": "2dsphere"})
```

### Real-time Location Updates
- WebSocket connections for live tracking
- Location updates every 5-10 seconds during active rides
- Geofencing for automatic ride status updates

---

## Real-time Features

### WebSocket Events
```javascript
// Client connects
ws://158.158.41.106:8000/ws/{user_id}

// Events
{
  "type": "location_update",
  "data": {
    "user_id": "user_id",
    "coordinates": [longitude, latitude],
    "timestamp": "2024-01-15T10:00:00Z"
  }
}

{
  "type": "ride_status_update", 
  "data": {
    "ride_id": "ride_id",
    "status": "in_progress",
    "timestamp": "2024-01-15T10:00:00Z"
  }
}
```

### Live Tracking Implementation
1. Driver starts ride and enables live tracking
2. Location updates sent via WebSocket
3. Passengers receive real-time location updates
4. Automatic status updates based on geofencing

---

## Deployment

### Backend Deployment (Flask)
```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export MONGODB_URL="mongodb://localhost:27017/rideshare"
export SECRET_KEY="your-secret-key"

# Run Flask app
python app/flask_app.py
```

### Frontend Deployment (Flutter)
```bash
# Build Android APK
flutter build apk --release

# Build iOS (requires macOS)
flutter build ios --release
```

### Docker Deployment
```dockerfile
# Dockerfile for Flask backend
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["python", "app/flask_app.py"]
```

---

## Development Setup

### Prerequisites
- Python 3.9+
- Flutter SDK
- MongoDB
- Node.js (for development tools)

### Backend Setup
```bash
# Clone repository
git clone https://github.com/your-repo/rideshare.git
cd rideshare/api

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp env.example .env
# Edit .env with your configuration

# Run database migrations
python scripts/setup_db.py

# Start development server
python app/flask_app.py
```

### Frontend Setup
```bash
# Navigate to Flutter app directory
cd rideshare/app

# Install Flutter dependencies
flutter pub get

# Run on Android emulator
flutter run

# Run on iOS simulator (macOS only)
flutter run -d ios
```

### Database Setup
```bash
# Start MongoDB
mongod --dbpath /path/to/your/db

# Create database and collections
mongo rideshare
> db.createCollection("users")
> db.createCollection("rides") 
> db.createCollection("locations")
> db.createCollection("drivers")

# Create indexes
> db.rides.createIndex({"pickup_location": "2dsphere"})
> db.rides.createIndex({"dropoff_location": "2dsphere"})
> db.locations.createIndex({"coordinates": "2dsphere"})
```

---

## API Testing

### Using curl
```bash
# Register user
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","password":"password123","phone":"+44 7123 456789"}'

# Login user
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Create ride (replace TOKEN with actual JWT)
curl -X POST http://localhost:8000/rides \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"pickup_location":{"latitude":51.5074,"longitude":-0.1278},"dropoff_location":{"latitude":51.5154,"longitude":-0.0925},"pickup_address":"London Bridge","dropoff_address":"Canary Wharf","price":15.50}'
```

### Using Postman
1. Import API collection
2. Set base URL: `http://localhost:8000`
3. Configure authentication headers
4. Test endpoints individually

---

## Monitoring & Logging

### Application Logs
```python
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('app.log'),
        logging.StreamHandler()
    ]
)
```

### Performance Monitoring
- API response times
- Database query performance
- WebSocket connection counts
- Error rates and exceptions

### Health Checks
```http
GET /health
```
Returns API status and database connectivity.

---

## Security Considerations

### Data Protection
- All passwords hashed with bcrypt
- JWT tokens signed with secret key
- HTTPS enforced in production
- Input validation on all endpoints

### Privacy
- Location data only shared during active rides
- User data encrypted at rest
- GDPR compliance for EU users
- Data retention policies implemented

### Rate Limiting
```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)
```

---

## Contributing

### Code Style
- Follow PEP 8 for Python code
- Use Dart/Flutter style guide
- Write comprehensive tests
- Document all public APIs

### Testing
```bash
# Backend tests
python -m pytest tests/

# Frontend tests
flutter test
```

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit pull request with description

---

*This technical documentation is maintained by the development team. For updates or questions, contact dev@rideshare.com.*
