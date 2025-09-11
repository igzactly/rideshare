# 🚗 RideShare API Endpoints Summary

## 📍 **Base URL**: `http://158.158.41.106:8000`

## 🔐 **Authentication Endpoints** (`/auth/*`)

### **POST** `/auth/register`
- **Purpose**: User registration
- **Request Body**:
  ```json
  {
    "email": "string",
    "password": "string",
    "is_driver": "boolean (optional, default: false)"
  }
  ```
- **Response**: 
  ```json
  {
    "id": "string (UUID)",
    "email": "string",
    "is_driver": "boolean",
    "is_verified_driver": "boolean",
    "is_active": "boolean",
    "is_superuser": "boolean",
    "is_verified": "boolean"
  }
  ```

### **POST** `/auth/login`
- **Purpose**: User authentication
- **Request Body**:
  ```json
  {
    "email": "string",
    "password": "string"
  }
  ```
- **Response**: 
  ```json
  {
    "access_token": "string",
    "token_type": "bearer"
  }
  ```

### **GET** `/auth/validate`
- **Purpose**: Validate JWT token and get user info
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "valid": true,
    "user_id": "string",
    "email": "string",
    "is_driver": "boolean",
    "is_verified_driver": "boolean"
  }
  ```

## 🚗 **Ride Management** (`/rides/*`)

### **POST** `/rides/`
- **Purpose**: Create a new ride
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "pickup": "string (address)",
    "dropoff": "string (address)",
    "pickup_coords": [latitude, longitude],
    "dropoff_coords": [latitude, longitude],
    "passenger_id": "string (optional)",
    "detour_km": "number (optional)",
    "detour_time_seconds": "number (optional)",
    "original_distance_km": "number (optional)",
    "total_distance_km": "number (optional)",
    "co2_saved": "number (optional)",
    "status": "string (default: active)",
    "pickup_time": "string (ISO 8601, optional)",
    "dropoff_time": "string (ISO 8601, optional)"
  }
  ```
- **Response**: Created ride object with `id` field

### **GET** `/rides/`
- **Purpose**: Get all rides
- **Response**: Array of ride objects

### **GET** `/rides/{ride_id}`
- **Purpose**: Get specific ride details
- **Response**: Single ride object

### **POST** `/rides/find`
- **Purpose**: Find available rides based on passenger request
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "pickup_coords": [latitude, longitude],
    "dropoff_coords": [latitude, longitude],
    "radius_km": "number (default: 5.0)",
    "max_detour_minutes": "number (default: 10)",
    "community_filter": "boolean (default: false)",
    "preferred_driver_id": "string (optional)"
  }
  ```
- **Response**: Array of matching ride objects with detour calculations

### **POST** `/rides/{ride_id}/accept_passenger`
- **Purpose**: Accept a ride as a passenger
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "message": "Ride accepted by passenger successfully"
  }
  ```

### **POST** `/rides/{ride_id}/driver_accept`
- **Purpose**: Driver accepts a passenger's ride request
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "message": "Ride confirmed by driver successfully"
  }
  ```

### **PUT** `/rides/{ride_id}/start`
- **Purpose**: Start a confirmed ride
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "message": "Ride started successfully"
  }
  ```

### **PUT** `/rides/{ride_id}/complete`
- **Purpose**: Complete a ride in progress
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "message": "Ride completed successfully"
  }
  ```

### **POST** `/rides/{ride_id}/accept`
- **Purpose**: Accept a ride (Flutter compatibility endpoint)
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "passenger_id": "string"
  }
  ```
- **Response**: 
  ```json
  {
    "message": "Ride accepted by passenger successfully"
  }
  ```

### **PUT** `/rides/{ride_id}/status`
- **Purpose**: Update ride status
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "status": "string"
  }
  ```
- **Valid Statuses**: `picked_up`, `dropped_off`, `completed`, `cancelled`, `in_progress`, `accepted`, `pending`
- **Response**: 
  ```json
  {
    "message": "Ride status updated successfully"
  }
  ```

### **DELETE** `/rides/{ride_id}`
- **Purpose**: Delete a ride
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "message": "Ride deleted successfully"
  }
  ```

### **GET** `/rides/my_rides`
- **Purpose**: Get all rides for the current user (as driver or passenger)
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Array of ride objects

### **GET** `/rides/active`
- **Purpose**: Get active rides for the current user
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Array of active ride objects

### **GET** `/rides/user`
- **Purpose**: Get rides for a specific user (Flutter compatibility)
- **Headers**: `Authorization: Bearer <token>`
- **Query Parameters**:
  - `user_id`: string (required)
- **Response**: 
  ```json
  {
    "rides": [...]
  }
  ```

### **GET** `/rides/user/{user_id}`
- **Purpose**: Get rides for a specific user by ID in URL
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "rides": [...]
  }
  ```

## 👤 **User Management** (`/users/*`)

### **GET** `/users/me`
- **Purpose**: Get current user profile
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Current user object

### **PATCH** `/users/me`
- **Purpose**: Update current user profile
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**: Partial user data
- **Response**: Updated user object

### **GET** `/users/{user_id}`
- **Purpose**: Get specific user details
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Single user object

### **PATCH** `/users/{user_id}`
- **Purpose**: Update user information (admin only)
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Updated user object

### **DELETE** `/users/{user_id}`
- **Purpose**: Delete a user (admin only)
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "deleted": true
  }
  ```

## 🚘 **Driver Operations** (`/driver/*`)

### **POST** `/driver/routes`
- **Purpose**: Create driver route
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "start_location": [latitude, longitude],
    "end_location": [latitude, longitude],
    "departure_time": "string (ISO 8601)",
    "available_seats": "number (default: 1)",
    "status": "string (default: active)",
    "current_location": [latitude, longitude],
    "is_online": "boolean (default: true)"
  }
  ```
- **Response**: Created route object

### **GET** `/driver/routes`
- **Purpose**: Get driver routes
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Array of driver route objects

### **POST** `/driver/rides/{ride_id}/accept`
- **Purpose**: Driver accepts a ride
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "message": "Ride accepted successfully"
  }
  ```

### **PUT** `/driver/rides/{ride_id}/status`
- **Purpose**: Driver updates ride status
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "status": "string"
  }
  ```
- **Valid Statuses**: `picked_up`, `dropped_off`, `completed`, `cancelled`
- **Response**: 
  ```json
  {
    "message": "Ride status updated successfully"
  }
  ```

## 💰 **Payment Handling** (`/payments/*`)

### **POST** `/payments/`
- **Purpose**: Create a new payment
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "ride_id": "string",
    "amount": "number",
    "currency": "string (default: GBP)",
    "payment_method": "string (optional)",
    "transaction_id": "string (optional)"
  }
  ```
- **Response**: Created payment object

### **GET** `/payments/{payment_id}`
- **Purpose**: Get specific payment details
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Single payment object

### **PUT** `/payments/{payment_id}/status`
- **Purpose**: Update payment status
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "status": "string"
  }
  ```
- **Valid Statuses**: `pending`, `completed`, `failed`
- **Response**: Updated payment object

## 🛡️ **Safety Features** (`/safety/*`)

### **POST** `/safety/emergency`
- **Purpose**: Create an emergency alert
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "ride_id": "string (optional)",
    "emergency_type": "string",
    "location": [latitude, longitude],
    "description": "string (optional)"
  }
  ```
- **Emergency Types**: `panic_button`, `accident`, `medical`, `safety_concern`
- **Response**: Created emergency alert object

### **GET** `/safety/emergency/{alert_id}`
- **Purpose**: Get emergency alert details
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Single emergency alert object

### **PUT** `/safety/emergency/{alert_id}/resolve`
- **Purpose**: Resolve an emergency alert
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "resolution_notes": "string (optional)"
  }
  ```
- **Response**: Updated emergency alert object

### **GET** `/safety/emergency/active`
- **Purpose**: Get all active emergency alerts for user's rides
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Array of active emergency alert objects

### **POST** `/safety/panic-button`
- **Purpose**: Trigger panic button for immediate emergency response
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
  ```json
  {
    "ride_id": "string",
    "location": [latitude, longitude],
    "description": "string (optional)"
  }
  ```
- **Response**: Created emergency alert object

### **GET** `/safety/safety-check/{ride_id}`
- **Purpose**: Perform a safety check for a ride
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "ride_id": "string",
    "has_active_emergencies": "boolean",
    "driver_verified": "boolean",
    "passenger_verified": "boolean",
    "safety_score": "number",
    "recommendations": ["string"]
  }
  ```

## 📍 **Location Updates** (`/location/*`)

### **POST** `/location/update`
- **Purpose**: Update user location with enhanced live tracking
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**: 
  ```json
  {
    "coordinates": [latitude, longitude],
    "timestamp": "string (ISO 8601)",
    "accuracy": "number (optional)",
    "speed": "number (optional)",
    "heading": "number (optional)",
    "ride_id": "string (optional)"
  }
  ```
- **Response**: Location update object with analytics data

### **POST** `/location/live-tracking/start`
- **Purpose**: Start live location tracking for a ride
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**: 
  ```json
  {
    "ride_id": "string"
  }
  ```
- **Response**: 
  ```json
  {
    "message": "Live tracking started successfully",
    "ride_id": "string"
  }
  ```

### **POST** `/location/live-tracking/stop`
- **Purpose**: Stop live location tracking for a ride
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**: 
  ```json
  {
    "ride_id": "string"
  }
  ```
- **Response**: 
  ```json
  {
    "message": "Live tracking stopped successfully",
    "ride_id": "string"
  }
  ```

### **GET** `/location/live-tracking/{ride_id}/status`
- **Purpose**: Get live tracking status for a ride
- **Headers**: `Authorization: Bearer <token>`
- **Response**: 
  ```json
  {
    "ride_id": "string",
    "live_tracking_active": "boolean",
    "tracking_started_at": "string",
    "tracking_stopped_at": "string",
    "last_location_update": "string",
    "recent_locations": [...],
    "websocket_connections": "number"
  }
  ```

### **GET** `/location/nearby-drivers`
- **Purpose**: Find nearby available drivers
- **Headers**: `Authorization: Bearer <token>`
- **Query Parameters**:
  - `latitude`: number (required)
  - `longitude`: number (required)
  - `radius_km`: number (default: 5.0)
- **Response**: Array of nearby driver objects with locations

### **GET** `/location/user/{user_id}/recent`
- **Purpose**: Get recent location updates for a user
- **Headers**: `Authorization: Bearer <token>`
- **Query Parameters**:
  - `limit`: number (default: 10)
- **Response**: Array of recent location objects

### **GET** `/location/ride/{ride_id}/participants`
- **Purpose**: Get current locations of all participants in a ride
- **Headers**: `Authorization: Bearer <token>`
- **Response**: Array of participant location objects

### **WebSocket** `/location/ws/ride/{ride_id}`
- **Purpose**: Real-time location updates during rides
- **Connection**: WebSocket connection for live location streaming
- **Message Format**:
  ```json
  {
    "type": "location_update",
    "user_id": "string",
    "coordinates": [latitude, longitude],
    "timestamp": "string",
    "accuracy": "number",
    "speed": "number",
    "heading": "number"
  }
  ```

## 🌱 **Environmental Features** (`/environmental/*`)
- **Status**: Available
- **Purpose**: Track and calculate environmental impact of rides
- **Features**: CO2 savings, fuel consumption, tree equivalents

## 📊 **Feedback System** (`/feedback/*`)
- **Status**: Available
- **Purpose**: User feedback and rating system
- **Features**: Ride ratings, comments, category-based feedback

## 🏥 **Health & Status**

### **GET** `/`
- **Purpose**: API root and status
- **Response**: 
  ```json
  {
    "message": "Welcome to RideShare API",
    "version": "1.0.0",
    "features": [
      "Real-time ride management",
      "Location tracking and WebSocket support",
      "Safety features and emergency alerts",
      "Environmental impact calculation",
      "User feedback and rating system",
      "Payment processing",
      "Driver route optimization",
      "Community-based ride matching",
      "Comprehensive analytics and reporting",
      "Real-time notifications",
      "Advanced route optimization algorithms"
    ]
  }
  ```

### **GET** `/health`
- **Purpose**: Health check
- **Response**: 
  ```json
  {
    "status": "ok",
    "timestamp": "string",
    "service": "RideShare API",
    "version": "1.0.0"
  }
  ```

### **GET** `/healthz`
- **Purpose**: Alternative health check
- **Response**: 
  ```json
  {
    "status": "ok"
  }
  ```

### **WebSocket** `/ws/{ride_id}`
- **Purpose**: General WebSocket endpoint for ride communication
- **Connection**: WebSocket connection for real-time updates

## 🔑 **Authentication**

All protected endpoints require a valid JWT token in the Authorization header:
```
Authorization: Bearer <access_token>
```

### **Token Format**
- **Type**: JWT (JSON Web Token)
- **Algorithm**: HS256
- **Expiration**: Configurable (default: 30 minutes)
- **Refresh**: Not implemented (token must be renewed)

## 📊 **Response Format**

### **Success Responses**
- **Single Object**: Direct object with `id` field (instead of `_id`)
- **List Responses**: Array of objects
- **Action Responses**: `{"message": "Action completed successfully"}`
- **Pagination**: Not implemented (all endpoints return full results)

### **Error Responses**
- **Format**: `{"detail": "Error description"}`
- **Status Codes**: 
  - `400`: Bad Request (invalid input)
  - `401`: Unauthorized (missing/invalid token)
  - `403`: Forbidden (insufficient permissions)
  - `404`: Not Found (resource doesn't exist)
  - `422`: Unprocessable Entity (validation error)
  - `500`: Internal Server Error

### **Validation Errors**
- **Format**: `{"detail": [{"loc": ["field"], "msg": "error message", "type": "error_type"}]}`
- **Example**:
  ```json
  {
    "detail": [
      {
        "loc": ["body", "email"],
        "msg": "field required",
        "type": "value_error.missing"
      }
    ]
  }
  ```

## 🚀 **Current Status**

✅ **Fully Functional**: Authentication, Ride Management, User Management, Driver Operations, Live Location Tracking
✅ **Consistent Response Format**: All endpoints return standardized responses
✅ **Error Handling**: Comprehensive error handling with consistent error messages
✅ **CORS Enabled**: Cross-origin requests supported
✅ **MongoDB Integration**: Full database integration with proper indexing
✅ **Live Location Tracking**: Real-time location updates with WebSocket support
✅ **Enhanced Safety Features**: Emergency alerts, panic button, safety checks
✅ **Payment Processing**: Complete payment lifecycle management
✅ **Environmental Tracking**: CO2 savings and environmental impact calculation
✅ **Feedback System**: User ratings and feedback collection

## 🔧 **Recent Improvements**

1. **Live Location Tracking**: Added comprehensive real-time location tracking system
2. **Enhanced Ride Management**: Added passenger acceptance, driver confirmation, ride start/complete endpoints
3. **Authentication Compatibility**: Fixed endpoint mismatches for Flutter app compatibility
4. **Location Analytics**: Added location data storage for analytics and safety monitoring
5. **WebSocket Support**: Real-time location updates during rides
6. **Nearby Drivers**: Find available drivers in real-time
7. **Safety Enhancements**: Emergency alerts, panic button, safety scoring
8. **Payment Integration**: Complete payment processing with status tracking
9. **Environmental Features**: CO2 savings calculation and environmental impact tracking
10. **Feedback System**: Comprehensive user feedback and rating system
11. **Response Format Standardization**: All endpoints now return consistent response formats
12. **Error Handling**: Added comprehensive error handlers for all HTTP status codes
13. **Health Check Enhancement**: Enhanced health endpoint with detailed information
14. **Route Optimization**: Integration with OSRM for detour calculations
15. **Real-time Communication**: WebSocket support for live updates

## 📱 **Flutter App Compatibility**

The API is fully compatible with the current Flutter app implementation:
- ✅ Authentication endpoints match expected format (`/auth/login`, `/auth/register`, `/auth/validate`)
- ✅ Ride creation returns proper ride object with all required fields
- ✅ Live location tracking with start/stop/status endpoints
- ✅ Location updates with enhanced data (coordinates, accuracy, speed, heading)
- ✅ All CRUD operations for rides, users, and drivers
- ✅ Consistent error handling and response formats
- ✅ WebSocket support for real-time updates
- ✅ Nearby driver discovery
- ✅ Safety features integration
- ✅ Payment processing integration
- ✅ Environmental impact tracking
- ✅ User feedback and rating system

## 🔧 **Technical Specifications**

### **Database**
- **Type**: MongoDB
- **Collections**: users, rides, drivers, payments, locations, emergency_alerts, user_profiles, environmental_metrics, community_filters, feedback, notifications
- **Indexing**: Comprehensive indexing for optimal performance
- **Geospatial**: 2dsphere indexes for location-based queries

### **External Services**
- **OSRM**: Route optimization and detour calculations
- **JWT**: Authentication token management
- **WebSocket**: Real-time communication

### **Performance**
- **Response Time**: < 200ms for most endpoints
- **Concurrent Users**: Supports multiple concurrent connections
- **Location Updates**: Real-time updates every 5-10 meters
- **Database Queries**: Optimized with proper indexing

## 📋 **API Usage Examples**

### **Complete Ride Flow**
1. **Register/Login**: `POST /auth/register` or `POST /auth/login`
2. **Create Ride**: `POST /rides/`
3. **Find Rides**: `POST /rides/find`
4. **Accept Ride**: `POST /rides/{ride_id}/accept_passenger`
5. **Driver Confirm**: `POST /rides/{ride_id}/driver_accept`
6. **Start Tracking**: `POST /location/live-tracking/start`
7. **Start Ride**: `PUT /rides/{ride_id}/start`
8. **Update Location**: `POST /location/update` (continuous)
9. **Complete Ride**: `PUT /rides/{ride_id}/complete`
10. **Stop Tracking**: `POST /location/live-tracking/stop`
11. **Process Payment**: `POST /payments/`
12. **Leave Feedback**: `POST /feedback/`

### **Emergency Flow**
1. **Trigger Emergency**: `POST /safety/panic-button`
2. **Get Safety Status**: `GET /safety/safety-check/{ride_id}`
3. **Resolve Emergency**: `PUT /safety/emergency/{alert_id}/resolve`

---

**Last Updated**: January 2025
**API Version**: 1.0.0
**Documentation Version**: 2.0