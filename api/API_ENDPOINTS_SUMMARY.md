# 🚗 RideShare API Endpoints Summary

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
    "phone": "string"
  }
  ```
- **Response**: 
  ```json
  {
    "access_token": "string",
    "token_type": "bearer",
    "user": { ... }
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
    "token_type": "bearer",
    "user": { ... }
  }
  ```

## 🚗 **Ride Management** (`/rides/*`)

### **POST** `/rides/`
- **Purpose**: Create a new ride
- **Request Body**:
  ```json
  {
    "pickup_location": {
      "latitude": "number",
      "longitude": "number"
    },
    "dropoff_location": {
      "latitude": "number",
      "longitude": "number"
    },
    "pickup_address": "string",
    "dropoff_address": "string",
    "pickup_time": "string (ISO 8601)",
    "ride_type": "string",
    "price_per_seat": "number"
  }
  ```
- **Response**: Created ride object with `id` field

### **GET** `/rides/`
- **Purpose**: List rides with filters
- **Query Parameters**:
  - `passenger_id`: string
  - `driver_id`: string
  - `status`: string
  - `limit`: number (max 200)
- **Response**: Array of ride objects

### **GET** `/rides/<ride_id>`
- **Purpose**: Get specific ride details
- **Response**: Single ride object

### **PUT** `/rides/<ride_id>`
- **Purpose**: Update ride information
- **Request Body**: Partial ride data
- **Response**: Updated ride object

### **DELETE** `/rides/<ride_id>`
- **Purpose**: Delete a ride
- **Response**: 
  ```json
  {
    "message": "Ride deleted successfully"
  }
  ```

### **GET** `/rides/search`
- **Purpose**: Search rides with filters
- **Query Parameters**: Same as list rides
- **Response**: 
  ```json
  {
    "rides": [...]
  }
  ```

### **POST** `/rides/find`
- **Purpose**: Find nearby rides (geographic search)
- **Request Body**:
  ```json
  {
    "pickup_location": {
      "latitude": "number",
      "longitude": "number"
    },
    "radius_km": "number (default: 5.0)"
  }
  ```
- **Response**: 
  ```json
  {
    "rides": [...]
  }
  ```

### **GET** `/rides/user`
- **Purpose**: Get rides for a specific user
- **Query Parameters**:
  - `user_id`: string (required)
- **Response**: 
  ```json
  {
    "rides": [...]
  }
  ```

### **GET** `/rides/user/<user_id>`
- **Purpose**: Get rides for a specific user by ID in URL
- **Response**: 
  ```json
  {
    "rides": [...]
  }
  ```

### **POST** `/rides/<ride_id>/accept`
- **Purpose**: Accept a ride
- **Request Body**:
  ```json
  {
    "driver_id": "string"
  }
  ```
- **Response**: 
  ```json
  {
    "message": "Ride accepted successfully"
  }
  ```

### **PUT** `/rides/<ride_id>/status`
- **Purpose**: Update ride status
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

## 👤 **User Management** (`/users/*`)

### **POST** `/users/`
- **Purpose**: Create a new user
- **Response**: Created user object

### **GET** `/users/`
- **Purpose**: List users
- **Query Parameters**:
  - `limit`: number (max 200)
- **Response**: Array of user objects

### **GET** `/users/<user_id>`
- **Purpose**: Get specific user details
- **Response**: Single user object

### **PUT** `/users/<user_id>`
- **Purpose**: Update user information
- **Response**: Updated user object

### **DELETE** `/users/<user_id>`
- **Purpose**: Delete a user
- **Response**: 
  ```json
  {
    "deleted": true
  }
  ```

### **GET** `/users/profile`
- **Purpose**: Get user profile
- **Query Parameters**:
  - `user_id`: string
- **Response**: User profile object

### **PUT** `/users/profile`
- **Purpose**: Update user profile
- **Request Body**: Partial profile data
- **Response**: Updated profile object

## 🚘 **Driver Operations** (`/driver/*`)

### **POST** `/driver/routes`
- **Purpose**: Create driver route
- **Response**: Created route object

### **GET** `/driver/routes`
- **Purpose**: Get driver routes
- **Query Parameters**:
  - `user_id`: string
- **Response**: 
  ```json
  {
    "routes": [...]
  }
  ```

### **POST** `/driver/rides/<ride_id>/accept`
- **Purpose**: Driver accepts a ride
- **Request Body**:
  ```json
  {
    "driver_id": "string"
  }
  ```
- **Response**: 
  ```json
  {
    "message": "Ride accepted"
  }
  ```

### **PUT** `/driver/rides/<ride_id>/status`
- **Purpose**: Driver updates ride status
- **Response**: 
  ```json
  {
    "message": "Status updated"
  }
  ```

### **POST** `/driver/`
- **Purpose**: Create driver profile
- **Response**: Created driver object

### **GET** `/driver/`
- **Purpose**: List drivers
- **Response**: Array of driver objects

### **GET** `/driver/<driver_id>`
- **Purpose**: Get specific driver details
- **Response**: Single driver object

### **PUT** `/driver/<driver_id>`
- **Purpose**: Update driver information
- **Response**: Updated driver object

### **DELETE** `/driver/<driver_id>`
- **Purpose**: Delete driver profile
- **Response**: 
  ```json
  {
    "deleted": true
  }
  ```

## 💰 **Payment Handling** (`/payments/*`)
- **Status**: Blueprint registered, endpoints available
- **Details**: See blueprint file for specific endpoints

## 🛡️ **Safety Features** (`/safety/*`)
- **Status**: Blueprint registered, endpoints available
- **Details**: See blueprint file for specific endpoints

## 📍 **Location Updates** (`/location/*`)

### **POST** `/location/update`
- **Purpose**: Update user location
- **Request Body**: Location data
- **Response**: 
  ```json
  {
    "message": "Location updated successfully",
    "timestamp": "string"
  }
  ```

## 🏥 **Health & Status**

### **GET** `/`
- **Purpose**: API root and status
- **Response**: API information and available features

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

### **GET** `/test`
- **Purpose**: Test endpoint
- **Response**: Basic API test information

### **GET** `/__routes__`
- **Purpose**: List all registered routes (debug)
- **Response**: Array of route information

## 🔑 **Authentication**

All protected endpoints require a valid JWT token in the Authorization header:
```
Authorization: Bearer <access_token>
```

## 📊 **Response Format**

### **Success Responses**
- **Single Object**: Direct object with `id` field (instead of `_id`)
- **List Responses**: Array of objects or `{"items": [...]}` format
- **Action Responses**: `{"message": "Action completed successfully"}`

### **Error Responses**
- **Format**: `{"detail": "Error description"}`
- **Status Codes**: Standard HTTP status codes (400, 401, 404, 500)

## 🚀 **Current Status**

✅ **Fully Functional**: Authentication, Ride Management, User Management, Driver Operations
✅ **Consistent Response Format**: All endpoints return standardized responses
✅ **Error Handling**: Comprehensive error handling with consistent error messages
✅ **CORS Enabled**: Cross-origin requests supported
✅ **MongoDB Integration**: Full database integration with proper indexing

## 🔧 **Recent Improvements**

1. **Response Format Standardization**: All endpoints now return consistent response formats
2. **Error Handling**: Added comprehensive error handlers for all HTTP status codes
3. **Location Endpoint**: Added `/location/update` endpoint for Flutter app
4. **Health Check Enhancement**: Enhanced health endpoint with detailed information
5. **Ride Management**: Improved ride creation, acceptance, and status updates

## 📱 **Flutter App Compatibility**

The API is fully compatible with the current Flutter app implementation:
- ✅ Authentication endpoints match expected format
- ✅ Ride creation returns proper ride object
- ✅ Location updates supported
- ✅ All CRUD operations for rides, users, and drivers
- ✅ Consistent error handling and response formats
