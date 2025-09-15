# 🚗 RideShare Flask API - Complete Endpoints Summary

## 📍 **Base URL**: `http://158.158.41.106:8000`

## 🔐 **Authentication Endpoints** (`/auth/*`)

### **POST** `/auth/register`
- **Purpose**: User registration
- **Request Body**:
  ```json
  {
    "name": "string",
    "email": "string", 
    "password": "string",
    "phone": "string (optional)"
  }
  ```
- **Response**: 
  ```json
  {
    "access_token": "jwt_token",
    "token_type": "bearer",
    "user": {
      "id": "string",
      "name": "string",
      "email": "string",
      "is_driver": false,
      "is_verified": false
    }
  }
  ```

### **POST** `/auth/login`
- **Purpose**: User login
- **Request Body**:
  ```json
  {
    "email": "string",
    "password": "string"
  }
  ```
- **Response**: Same as register

### **GET** `/auth/validate`
- **Purpose**: Validate JWT token
- **Headers**: `Authorization: Bearer <token>`
- **Response**:
  ```json
  {
    "valid": true,
    "user_id": "string",
    "email": "string"
  }
  ```

## 🚗 **Ride Management Endpoints** (`/rides/*`)

### **POST** `/rides/`
- **Purpose**: Create a new ride
- **Request Body**:
  ```json
  {
    "pickup_location": {"latitude": 40.7128, "longitude": -74.0060},
    "dropoff_location": {"latitude": 40.7589, "longitude": -73.9851},
    "pickup_address": "string",
    "dropoff_address": "string",
    "pickup_time": "ISO8601 datetime",
    "ride_type": "string",
    "max_passengers": 4,
    "price_per_seat": 15.50
  }
  ```

### **GET** `/rides/`
- **Purpose**: List rides with filters
- **Query Parameters**:
  - `passenger_id`: Filter by passenger
  - `driver_id`: Filter by driver
  - `status`: Filter by status
  - `limit`: Max results (default: 50, max: 200)

### **GET** `/rides/my_rides`
- **Purpose**: Get all rides for current user
- **Query Parameters**:
  - `user_id`: User ID (required)
  - `limit`: Max results

### **GET** `/rides/<ride_id>`
- **Purpose**: Get specific ride details

### **PUT** `/rides/<ride_id>`
- **Purpose**: Update ride details

### **POST** `/rides/<ride_id>/accept`
- **Purpose**: Accept a ride
- **Request Body**:
  ```json
  {
    "driver_id": "string"
  }
  ```

### **PUT** `/rides/<ride_id>/status`
- **Purpose**: Update ride status
- **Request Body**:
  ```json
  {
    "status": "accepted|picked_up|in_progress|completed|cancelled"
  }
  ```

### **POST** `/rides/find`
- **Purpose**: Find nearby rides (geospatial search)
- **Request Body**:
  ```json
  {
    "pickup_location": {"latitude": 40.7128, "longitude": -74.0060},
    "radius_km": 5.0,
    "limit": 20
  }
  ```

### **DELETE** `/rides/<ride_id>`
- **Purpose**: Delete a ride

## 📍 **Location Tracking Endpoints** (`/location/*`)

### **POST** `/location/update`
- **Purpose**: Update user location with live tracking
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "coordinates": [40.7128, -74.0060],
    "accuracy": 10.0,
    "speed": 25.5,
    "heading": 180.0,
    "ride_id": "string (optional)"
  }
  ```

### **GET** `/location/user/<user_id>/recent`
- **Purpose**: Get recent locations for a user
- **Headers**: `Authorization: Bearer <token>`
- **Query Parameters**:
  - `limit`: Number of locations (default: 10, max: 50)

### **GET** `/location/ride/<ride_id>/participants`
- **Purpose**: Get locations of all ride participants
- **Headers**: `Authorization: Bearer <token>`

### **GET** `/location/nearby-drivers`
- **Purpose**: Find nearby available drivers
- **Headers**: `Authorization: Bearer <token>`
- **Query Parameters**:
  - `latitude`: Current latitude (required)
  - `longitude`: Current longitude (required)
  - `radius_km`: Search radius (default: 5.0)

### **POST** `/location/live-tracking/start`
- **Purpose**: Start live tracking for a ride
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "ride_id": "string"
  }
  ```

### **POST** `/location/live-tracking/stop`
- **Purpose**: Stop live tracking for a ride
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "ride_id": "string"
  }
  ```

### **GET** `/location/live-tracking/<ride_id>/status`
- **Purpose**: Get live tracking status
- **Headers**: `Authorization: Bearer <token>`

## 👥 **User Management Endpoints** (`/users/*`)

### **GET** `/users/`
- **Purpose**: List users (admin only)

### **GET** `/users/<user_id>`
- **Purpose**: Get user profile

### **PUT** `/users/<user_id>`
- **Purpose**: Update user profile

## 🚙 **Driver Management Endpoints** (`/driver/*`)

### **GET** `/driver/`
- **Purpose**: List drivers

### **POST** `/driver/`
- **Purpose**: Register as a driver

### **GET** `/driver/<driver_id>`
- **Purpose**: Get driver profile

### **PUT** `/driver/<driver_id>`
- **Purpose**: Update driver profile

## 💳 **Payment Endpoints** (`/payments/*`)

### **POST** `/payments/`
- **Purpose**: Create a payment

### **GET** `/payments/<payment_id>`
- **Purpose**: Get payment details

### **PUT** `/payments/<payment_id>/status`
- **Purpose**: Update payment status

## 🚨 **Safety Endpoints** (`/safety/*`)

### **POST** `/safety/emergency`
- **Purpose**: Create emergency alert

### **GET** `/safety/emergency/<alert_id>`
- **Purpose**: Get emergency alert details

## 🔧 **System Endpoints**

### **GET** `/`
- **Purpose**: API root information

### **GET** `/health`
- **Purpose**: Health check
- **Response**:
  ```json
  {
    "status": "ok",
    "timestamp": "ISO8601 datetime",
    "service": "RideShare API",
    "version": "1.0.0"
  }
  ```

### **GET** `/test`
- **Purpose**: Test endpoint connectivity

### **GET** `/__routes__`
- **Purpose**: List all available routes (debug)

## 📊 **Live Location Tracking Features**

### **Real-time Updates**
- POST to `/location/update` with coordinates
- Include `ride_id` for ride-specific tracking
- Automatic driver location updates

### **Participant Tracking**
- Get locations of all ride participants
- Recent location history (last 5 minutes)
- Geospatial queries for nearby drivers

### **Live Tracking Control**
- Start/stop tracking for specific rides
- Monitor tracking status
- View recent location updates

## 🗄️ **Database Collections**

### **rides**
- `_id`, `driver_id`, `passenger_id`
- `pickup_location`, `dropoff_location` (GeoJSON Points)
- `status`, `created_at`, `updated_at`
- `live_tracking_active`, `last_known_location`

### **locations**
- `_id`, `user_id`, `ride_id`
- `coordinates` (GeoJSON Point)
- `timestamp`, `accuracy`, `speed`, `heading`

### **users**
- `_id`, `email` (unique), `name`, `phone`
- `is_driver`, `is_verified`
- `hashed_password`, `created_at`, `updated_at`

## 🔒 **Security Features**

- **JWT Authentication**: All protected endpoints require valid tokens
- **Password Hashing**: bcrypt for secure password storage
- **CORS Support**: Proper cross-origin request handling
- **Input Validation**: All inputs validated and sanitized
- **Authorization**: Users can only access their own data or shared ride data

## ⚡ **Performance Optimizations**

- **Geospatial Indexes**: MongoDB 2dsphere indexes for location queries
- **Query Limits**: Configurable limits on all list endpoints
- **Aggregation Pipelines**: Efficient MongoDB aggregations
- **Connection Pooling**: Optimized database connections

## 🚀 **Getting Started**

1. **Register**: `POST /auth/register`
2. **Login**: `POST /auth/login`
3. **Create Ride**: `POST /rides/`
4. **Update Location**: `POST /location/update`
5. **Find Rides**: `POST /rides/find`

## 📱 **Flutter App Integration**

The Flutter app uses these endpoints with the following base URL:
```dart
static const String _baseUrl = 'http://158.158.41.106:8000';
```

All endpoints are compatible with the Flutter app's API service implementation.
