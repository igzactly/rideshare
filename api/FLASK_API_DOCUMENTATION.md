# RideShare Flask API Documentation

## Overview
The RideShare API is built with Flask and provides comprehensive ride-sharing functionality including real-time location tracking, user management, ride management, and safety features.

## Base URL
```
http://158.158.41.106:8000
```

## Authentication
All protected endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

## API Endpoints

### Authentication (`/auth`)

#### POST `/auth/register`
Register a new user account.

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "securepassword",
  "phone": "+1234567890"
}
```

**Response:**
```json
{
  "access_token": "jwt_token_here",
  "token_type": "bearer",
  "user": {
    "id": "user_id",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+1234567890",
    "is_driver": false,
    "is_verified": false
  }
}
```

#### POST `/auth/login`
Login with email and password.

**Request Body:**
```json
{
  "email": "john@example.com",
  "password": "securepassword"
}
```

**Response:**
```json
{
  "access_token": "jwt_token_here",
  "token_type": "bearer",
  "user": {
    "id": "user_id",
    "name": "John Doe",
    "email": "john@example.com",
    "is_driver": false
  }
}
```

#### GET `/auth/validate`
Validate the current user's token.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "valid": true,
  "user_id": "user_id",
  "email": "john@example.com"
}
```

### Rides (`/rides`)

#### POST `/rides/`
Create a new ride.

**Request Body:**
```json
{
  "pickup_location": {
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "dropoff_location": {
    "latitude": 40.7589,
    "longitude": -73.9851
  },
  "pickup_address": "123 Main St, New York, NY",
  "dropoff_address": "456 Broadway, New York, NY",
  "pickup_time": "2024-01-15T10:00:00Z",
  "ride_type": "standard",
  "max_passengers": 4,
  "price_per_seat": 15.50
}
```

**Response:**
```json
{
  "id": "ride_id",
  "driver_id": "driver_id",
  "pickup_location": {
    "type": "Point",
    "coordinates": [-74.0060, 40.7128]
  },
  "dropoff_location": {
    "type": "Point", 
    "coordinates": [-73.9851, 40.7589]
  },
  "status": "active",
  "created_at": "2024-01-15T09:30:00Z"
}
```

#### GET `/rides/`
List rides with optional filters.

**Query Parameters:**
- `passenger_id`: Filter by passenger ID
- `driver_id`: Filter by driver ID
- `status`: Filter by ride status
- `limit`: Maximum number of results (default: 50, max: 200)

**Response:**
```json
[
  {
    "id": "ride_id",
    "driver_id": "driver_id",
    "status": "active",
    "pickup_location": {...},
    "dropoff_location": {...}
  }
]
```

#### GET `/rides/my_rides`
Get all rides for the current user (as driver or passenger).

**Query Parameters:**
- `user_id`: User ID (required)
- `limit`: Maximum number of results (default: 50, max: 200)

**Response:**
```json
[
  {
    "id": "ride_id",
    "driver_id": "driver_id",
    "passenger_id": "passenger_id",
    "status": "completed",
    "pickup_location": {...},
    "dropoff_location": {...}
  }
]
```

#### GET `/rides/<ride_id>`
Get a specific ride by ID.

**Response:**
```json
{
  "id": "ride_id",
  "driver_id": "driver_id",
  "passenger_id": "passenger_id",
  "status": "active",
  "pickup_location": {...},
  "dropoff_location": {...},
  "created_at": "2024-01-15T09:30:00Z"
}
```

#### PUT `/rides/<ride_id>`
Update a ride.

**Request Body:**
```json
{
  "status": "accepted",
  "passenger_id": "passenger_id"
}
```

#### POST `/rides/<ride_id>/accept`
Accept a ride.

**Request Body:**
```json
{
  "driver_id": "driver_id"
}
```

#### PUT `/rides/<ride_id>/status`
Update ride status.

**Request Body:**
```json
{
  "status": "picked_up"
}
```

**Valid Status Values:**
- `active` - Ride is available
- `accepted` - Ride has been accepted
- `picked_up` - Passenger has been picked up
- `in_progress` - Ride is in progress
- `completed` - Ride is completed
- `cancelled` - Ride has been cancelled

#### POST `/rides/find`
Find nearby rides using geospatial search.

**Request Body:**
```json
{
  "pickup_location": {
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "radius_km": 5.0,
  "limit": 20
}
```

**Response:**
```json
{
  "rides": [
    {
      "id": "ride_id",
      "driver_id": "driver_id",
      "pickup_location": {...},
      "dropoff_location": {...},
      "status": "active"
    }
  ]
}
```

### Location (`/location`)

#### POST `/location/update`
Update user's current location with live tracking support.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "coordinates": [40.7128, -74.0060],
  "accuracy": 10.0,
  "speed": 25.5,
  "heading": 180.0,
  "ride_id": "ride_id"
}
```

**Response:**
```json
{
  "message": "Location updated successfully",
  "location_id": "location_id",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

#### GET `/location/user/<user_id>/recent`
Get recent location updates for a user.

**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters:**
- `limit`: Number of recent locations (default: 10, max: 50)

**Response:**
```json
[
  {
    "id": "location_id",
    "user_id": "user_id",
    "coordinates": {
      "type": "Point",
      "coordinates": [-74.0060, 40.7128]
    },
    "timestamp": "2024-01-15T10:30:00Z",
    "accuracy": 10.0,
    "speed": 25.5,
    "heading": 180.0
  }
]
```

#### GET `/location/ride/<ride_id>/participants`
Get current locations of all participants in a ride.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
[
  {
    "id": "location_id",
    "user_id": "user_id",
    "coordinates": {...},
    "timestamp": "2024-01-15T10:30:00Z"
  }
]
```

#### GET `/location/nearby-drivers`
Find nearby available drivers.

**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters:**
- `latitude`: Current latitude (required)
- `longitude`: Current longitude (required)
- `radius_km`: Search radius in kilometers (default: 5.0)

**Response:**
```json
[
  {
    "driver_id": "driver_id",
    "current_location": {
      "type": "Point",
      "coordinates": [-74.0060, 40.7128]
    },
    "last_seen": "2024-01-15T10:30:00Z",
    "available_seats": 3
  }
]
```

#### POST `/location/live-tracking/start`
Start live location tracking for a ride.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "ride_id": "ride_id"
}
```

**Response:**
```json
{
  "message": "Live tracking started successfully",
  "ride_id": "ride_id"
}
```

#### POST `/location/live-tracking/stop`
Stop live location tracking for a ride.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "ride_id": "ride_id"
}
```

**Response:**
```json
{
  "message": "Live tracking stopped successfully",
  "ride_id": "ride_id"
}
```

#### GET `/location/live-tracking/<ride_id>/status`
Get live tracking status for a ride.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "ride_id": "ride_id",
  "live_tracking_active": true,
  "tracking_started_at": "2024-01-15T10:00:00Z",
  "tracking_stopped_at": null,
  "last_location_update": "2024-01-15T10:30:00Z",
  "recent_locations": [...]
}
```

### Users (`/users`)

#### GET `/users/`
List users (admin only).

#### GET `/users/<user_id>`
Get user profile by ID.

#### PUT `/users/<user_id>`
Update user profile.

### Drivers (`/driver`)

#### GET `/driver/`
List drivers.

#### POST `/driver/`
Register as a driver.

#### GET `/driver/<driver_id>`
Get driver profile.

#### PUT `/driver/<driver_id>`
Update driver profile.

### Payments (`/payments`)

#### POST `/payments/`
Create a payment.

#### GET `/payments/<payment_id>`
Get payment details.

#### PUT `/payments/<payment_id>/status`
Update payment status.

### Safety (`/safety`)

#### POST `/safety/emergency`
Create emergency alert.

#### GET `/safety/emergency/<alert_id>`
Get emergency alert details.

## Error Responses

All endpoints return consistent error responses:

```json
{
  "detail": "Error message description"
}
```

**Common HTTP Status Codes:**
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `409` - Conflict
- `500` - Internal Server Error

## Live Location Tracking

The API supports comprehensive live location tracking with the following features:

1. **Real-time Updates**: POST to `/location/update` with coordinates
2. **Ride Context**: Include `ride_id` for ride-specific tracking
3. **Participant Tracking**: Get locations of all ride participants
4. **Nearby Drivers**: Find available drivers within radius
5. **Live Tracking Control**: Start/stop tracking for specific rides
6. **Status Monitoring**: Check tracking status and recent locations

## Database Schema

### Rides Collection
- `_id`: ObjectId (primary key)
- `driver_id`: ObjectId (reference to users)
- `passenger_id`: ObjectId (reference to users)
- `pickup_location`: GeoJSON Point
- `dropoff_location`: GeoJSON Point
- `status`: String (active, accepted, picked_up, completed, cancelled)
- `created_at`: DateTime
- `updated_at`: DateTime
- `live_tracking_active`: Boolean
- `last_known_location`: GeoJSON Point

### Locations Collection
- `_id`: ObjectId (primary key)
- `user_id`: ObjectId (reference to users)
- `ride_id`: ObjectId (reference to rides, optional)
- `coordinates`: GeoJSON Point
- `timestamp`: DateTime
- `accuracy`: Float
- `speed`: Float
- `heading`: Float

### Users Collection
- `_id`: ObjectId (primary key)
- `email`: String (unique)
- `name`: String
- `phone`: String
- `is_driver`: Boolean
- `is_verified`: Boolean
- `hashed_password`: String
- `created_at`: DateTime
- `updated_at`: DateTime

## Security Features

1. **JWT Authentication**: All protected endpoints require valid JWT tokens
2. **Password Hashing**: Passwords are hashed using bcrypt
3. **CORS Support**: Cross-origin requests are properly handled
4. **Input Validation**: All inputs are validated and sanitized
5. **Authorization Checks**: Users can only access their own data or shared ride data

## Performance Optimizations

1. **Database Indexes**: Geospatial indexes for location queries
2. **Query Limits**: All list endpoints have configurable limits
3. **Efficient Aggregations**: MongoDB aggregation pipelines for complex queries
4. **Connection Pooling**: Optimized database connections

## Testing

Use the `/test` endpoint to verify API connectivity:

```bash
curl http://158.158.41.106:8000/test
```

Response:
```json
{
  "message": "Flask app is working",
  "endpoints": ["/", "/health", "/test"]
}
```

## Health Check

Monitor API health using:

```bash
curl http://158.158.41.106:8000/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z",
  "service": "RideShare API",
  "version": "1.0.0"
}
```
