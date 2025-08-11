# RideShare API Documentation

A comprehensive ride-sharing platform API built with FastAPI, featuring real-time location tracking, safety features, environmental impact calculation, community matching, analytics, notifications, and route optimization.

## 🚀 Features

- **Real-time Ride Management**: Create, update, and manage rides with real-time status tracking
- **Location Tracking**: WebSocket-based real-time location updates and geospatial queries
- **Safety Features**: Emergency alerts, panic button, and safety checks
- **Environmental Impact**: CO2 savings calculation and environmental metrics
- **Community Matching**: Community-based ride matching with trust scores
- **Analytics & Reporting**: Comprehensive ride and user analytics
- **Real-time Notifications**: Push notifications for ride updates and safety alerts
- **Route Optimization**: Advanced algorithms for driver route planning
- **Payment Processing**: Secure payment handling and transaction management
- **User Authentication**: JWT-based authentication with FastAPI-Users

## 🏗️ Architecture

- **Framework**: FastAPI (async Python web framework)
- **Database**: MongoDB with Motor (async driver)
- **Authentication**: FastAPI-Users with JWT strategy
- **Real-time**: WebSocket support for live updates
- **Geospatial**: MongoDB 2dsphere indexing for location queries
- **Routing**: OSRM integration for route optimization

## 📋 API Endpoints

### Authentication (`/auth`)
- `POST /auth/jwt/login` - User login
- `POST /auth` - User registration
- `GET /users/me` - Get current user profile
- `PUT /users/me` - Update user profile

### Rides (`/rides`)
- `POST /` - Create a new ride
- `GET /` - Get all rides
- `GET /{ride_id}` - Get specific ride
- `GET /find` - Find available rides with matching
- `PUT /{ride_id}` - Update ride
- `DELETE /{ride_id}` - Cancel ride

### Driver (`/driver`)
- `POST /routes` - Create driver route
- `GET /routes` - Get driver routes
- `POST /routes/{route_id}/accept-ride` - Accept a ride
- `PUT /routes/{route_id}/status` - Update route status

### Payments (`/payments`)
- `POST /` - Create payment
- `GET /{payment_id}` - Get payment details
- `PUT /{payment_id}/status` - Update payment status
- `GET /user/{user_id}` - Get user payments

### Location (`/location`)
- `POST /update` - Update user location
- `GET /user/{user_id}/recent` - Get recent locations
- `GET /ride/{ride_id}/participants` - Get ride participants' locations
- `WEBSOCKET /ws/ride/{ride_id}` - Real-time location updates
- `GET /nearby-drivers` - Find nearby available drivers

### Safety (`/safety`)
- `POST /emergency` - Create emergency alert
- `GET /emergency/{alert_id}` - Get emergency alert
- `PUT /emergency/{alert_id}/resolve` - Resolve emergency alert
- `GET /emergency/active` - Get active emergency alerts
- `POST /panic-button` - Activate panic button
- `GET /safety-check/{ride_id}` - Perform safety check

### Environmental (`/environmental`)
- `POST /calculate-ride-impact` - Calculate ride environmental impact
- `GET /ride/{ride_id}/impact` - Get ride environmental impact
- `GET /user/{user_id}/total-impact` - Get user total environmental impact
- `GET /analytics` - Get platform environmental analytics
- `GET /comparison` - Compare transport modes

### Feedback (`/feedback`)
- `POST /` - Submit feedback
- `GET /ride/{ride_id}` - Get ride feedback
- `GET /user/{user_id}` - Get user feedback
- `GET /user/{user_id}/summary` - Get user feedback summary
- `PUT /{feedback_id}` - Update feedback
- `DELETE /{feedback_id}` - Delete feedback
- `GET /analytics/platform` - Get platform feedback analytics

### Community (`/community`)
- `POST /filters` - Create community filter
- `GET /filters/{user_id}` - Get user community filter
- `PUT /filters/{user_id}` - Update community filter
- `POST /match` - Find community-based ride matches
- `GET /trust-score/{user_id}` - Get user trust score
- `POST /trust-score/{user_id}` - Update user trust score

### Analytics (`/analytics`)
- `GET /rides` - Get ride analytics
- `GET /user/{user_id}` - Get user analytics
- `GET /platform` - Get platform analytics
- `GET /trends` - Get trend analytics

### Notifications (`/notifications`)
- `POST /` - Create notification
- `GET /user/{user_id}` - Get user notifications
- `PUT /{notification_id}/read` - Mark notification as read
- `PUT /user/{user_id}/read-all` - Mark all notifications as read
- `DELETE /{notification_id}` - Delete notification
- `GET /user/{user_id}/unread-count` - Get unread count
- `POST /ride-update` - Send ride update notification
- `POST /safety-alert` - Send safety alert notification
- `POST /payment-reminder` - Send payment reminder

### Route Optimization (`/optimization`)
- `POST /route` - Optimize single route
- `POST /multi-ride` - Optimize multi-ride route
- `GET /efficiency/{driver_id}` - Get driver efficiency metrics

## 🚀 Getting Started

### Prerequisites
- Python 3.8+
- MongoDB 4.4+
- Docker (optional)

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd rideshare/api
```

2. **Install dependencies**
```bash
pip install -r requirements.txt
```

3. **Set up environment variables**
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. **Start MongoDB**
```bash
# Using Docker
docker run -d -p 27017:27017 --name mongodb mongo:latest

# Or start your local MongoDB instance
```

5. **Run the application**
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Environment Variables

```env
# MongoDB
MONGODB_URL=mongodb://localhost:27017
MONGODB_DB=rideshare

# JWT
SECRET_KEY=your-secret-key-here
ACCESS_TOKEN_EXPIRE_MINUTES=30

# OSRM
OSRM_URL=http://router.project-osrm.org

# Rate Limiting
RATE_LIMIT_PER_MINUTE=60

# Environmental Impact
DEFAULT_FUEL_EFFICIENCY=15.0
CO2_PER_LITER_FUEL=2.31

# Safety
EMERGENCY_RESPONSE_TIMEOUT=30
PANIC_BUTTON_COOLDOWN=300

# Community
DEFAULT_TRUST_SCORE_THRESHOLD=3.0
MAX_COMMUNITY_DISTANCE=50.0
```

## 📊 Database Schema

### Collections
- `users` - User accounts and authentication
- `rides` - Ride information and status
- `drivers` - Driver profiles and routes
- `payments` - Payment transactions
- `locations` - User location history
- `emergency_alerts` - Safety and emergency alerts
- `user_profiles` - Extended user information
- `environmental_metrics` - Environmental impact data
- `community_filters` - Community matching preferences
- `feedback` - User ratings and feedback
- `notifications` - User notifications

### Key Indexes
- Geospatial indexes on coordinates for location-based queries
- Compound indexes on status and user IDs for efficient filtering
- Text indexes for search functionality
- Unique indexes on critical fields

## 🔒 Security Features

- JWT-based authentication
- Role-based access control
- Input validation with Pydantic
- Rate limiting
- CORS configuration
- Secure password hashing

## 🌍 Environmental Impact Calculation

The API calculates CO2 savings based on:
- DEFRA 2024 emission factors
- Haversine distance calculation
- Vehicle fuel efficiency
- Transport mode comparison

## 🚨 Safety Features

- Real-time emergency alerts
- Panic button functionality
- Safety check endpoints
- Emergency contact notifications
- Background task processing

## 📱 Real-time Features

- WebSocket support for live updates
- Real-time location tracking
- Live ride status updates
- Instant notifications
- Background task processing

## 🧪 Testing

```bash
# Run tests
pytest

# Run with coverage
pytest --cov=app

# Run specific test file
pytest tests/test_rides.py
```

## 📚 API Documentation

Once the server is running, visit:
- **Interactive API Docs**: http://localhost:8000/docs
- **ReDoc Documentation**: http://localhost:8000/redoc
- **OpenAPI Schema**: http://localhost:8000/openapi.json

## 🚀 Deployment

### Docker
```bash
docker build -t rideshare-api .
docker run -p 8000:8000 rideshare-api
```

### Docker Compose
```bash
docker-compose up -d
```

### Production
```bash
# Use production server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4

# Or use Gunicorn
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

## 🔮 Future Enhancements

- Machine learning for ride matching
- Advanced fraud detection
- Integration with external services
- Mobile app APIs
- Real-time traffic integration
- Advanced analytics dashboard 