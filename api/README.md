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





 





 
1.0 Introduction
1.1 Motivation:
The rising costs of transportation, traffic congestion, and environmental concerns have made traditional commuting methods increasingly unsustainable. As urban populations grow, there is a growing need for affordable, efficient, and eco-friendly transportation options. Ride-sharing offers a practical solution by enabling individuals to share car journeys, reducing both travel expenses and carbon emissions. The motivation behind this research is to explore how technology-driven ride-sharing platforms can optimize travel efficiency, promote sustainability, and foster a sense of community among commuters.
1.2 Background:
Ride-sharing services have gained popularity worldwide, with platforms like Uber, Lyft, and BlaBlaCar leading the market. These platforms leverage GPS technology, data analytics, and mobile connectivity to connect drivers with passengers traveling along similar routes. However, despite their success, existing systems face challenges related to route optimization, user safety, cost-effectiveness, and environmental impact. Many current solutions focus primarily on urban areas, leaving suburban and rural commuters underserved. Additionally, concerns regarding privacy, trust, and ride availability persist, highlighting the need for more secure and community-driven platforms.
Technological advancements in cloud computing, artificial intelligence, and real-time data processing present new opportunities to address these challenges. By developing an innovative ride-sharing system that integrates advanced route-matching algorithms, secure user authentication, and digital payment solutions, this research aims to create a platform that enhances commuting experiences while contributing to broader environmental and social goals.
1.3 Context: 
This research is conducted within the context of sustainable transportation, smart cities, and digital transformation. With governments and organizations increasingly prioritizing sustainability, the transportation sector is undergoing a significant shift toward eco-friendly solutions. Ride-sharing aligns with global efforts to reduce carbon footprints and alleviate urban congestion, making it a key component of future mobility systems. The study will also explore the role of cloud-based platforms in enabling scalable, real-time ride-sharing services that can adapt to evolving commuter needs.
 

1.4 Research Problem:
Despite the benefits of ride-sharing, existing platforms often fall short in terms of efficiency, user experience, and environmental impact. Key challenges include inefficient route matching, limited availability in non-urban areas, and concerns about passenger safety and data privacy. Additionally, the high costs associated with some services can deter potential users. The research problem is to design a ride-sharing system that addresses these limitations by optimizing ride utilization, ensuring secure and transparent transactions, and promoting environmentally friendly commuting practices. This study seeks to answer the question:
"How can a technology-driven ride-sharing system improve commuting efficiency, reduce transportation costs, and promote environmental sustainability while ensuring user safety and trust?"
 
2.0 Aims & Objectives
2.1 Suitability
the proposed project, RideShare – A Community-Centric Ride-Sharing System, is highly suitable for the MSc Software Engineering programme as it demonstrates both technical depth and practical relevance. It integrates modern technologies such as Python with FastAPI, MongoDB for geospatial querying, Flutter for cross-platform mobile development, and Apache Kafka for real-time messaging—each selected to align with best practices in full-stack, scalable systems engineering.
The project moves beyond basic development by incorporating applied research through a real-world pilot study, evaluating metrics like ride-match efficiency, user trust, and CO₂ savings. This addresses critical learning outcomes such as ethical system design, analytical thinking, and rigorous performance evaluation. Additionally, the system tackles real societal challenges—urban congestion, environmental sustainability, and digital trust—making it both academically rich and socially impactful.
The scope and timeline are carefully tailored to a 4–6 week development window, with a focused MVP, milestone-based work plan, and use of free-tier cloud and mapping services. Altogether, RideShare is a technically sound, research-informed, and realistically scoped project that meets the expectations of an MSc-level dissertation in Software Engineering.
Furthermore, the project reflects a strong alignment with core MSc Software Engineering competencies, including system architecture, agile development, real-time data handling, and ethical technology implementation. It provides an opportunity to demonstrate mastery in designing and deploying a distributed, user-facing application that incorporates both functional and non-functional requirements. With its emphasis on measurable outcomes, user-centric design, and sustainable impact, RideShare offers a holistic platform to showcase both technical proficiency and applied research within a compressed but achievable timeline.

 
2.2 SMARTness of the Objectives
The objectives set for the RideShare project are fully aligned with the SMART framework—Specific, Measurable, Attainable, Relevant, and Time-bound—as defined by ProjectSmart. Each objective is designed not only to guide implementation but also to meet academic expectations for precision, feasibility, and evaluation.
Specific (S):
Every objective clearly outlines the intended task and expected outcome. For example, "Design and implement a ride-matching algorithm using OSRM and Mapbox Directions API" explicitly defines what will be built and which technologies will be used. Similarly, the aim to “develop a Flutter-based passenger interface” outlines a defined user-facing component with a clear platform and scope.
Measurable (M):
Progress and success are tracked through measurable outputs: API availability (e.g., visible in Swagger UI), match rates (e.g., ≥ 60% successful matches in test cases), response times, user satisfaction (Likert-scale surveys), and environmental impact (CO₂ saved using DEFRA factors). These quantifiable indicators ensure that the project’s success is based on tangible, data-driven results rather than subjective assessments.
Attainable (A):
Objectives are carefully scoped to match my technical background and the available development timeframe (4–6 weeks). Technologies like Python, FastAPI, MongoDB, and Flutter are within my current skill set or supported with quick start learning curves. The MVP is streamlined by excluding complex features like payment processing and multi-hop routing, making each task realistically achievable with the given resources.
Relevant (R):
Each objective directly supports the core aim of the project: to deliver a working, user-tested ride-sharing system that addresses real-world challenges such as route optimisation, trust, and urban sustainability. Features like driver verification, geo-matching, and real-time updates serve the system’s value proposition and are aligned with both technical goals and stakeholder needs.
Time-bound (T):
All objectives are explicitly scheduled within a detailed 6-week Gantt chart, with week-level deadlines for backend/API completion, UI integration, testing, evaluation, and final write-up. This allows for milestone-based tracking and effective risk management, ensuring that progress can be monitored and adjustments made as needed.

Summary
The RideShare project’s objectives are SMART in such a way that they ensure that every task is focused, assessable, and achievable within the project’s constraints, while still delivering a meaningful, research-informed, and technically robust outcome.

 
3.0 Initial Literature Review
3.1 Route Matching Algorithms and Optimisation
At the heart of any ride-sharing system is a matching mechanism that connects passengers with drivers travelling along compatible routes. Traditional approaches such as the vehicle routing problem (VRP) and its variants form the theoretical basis for these systems. Dantzig and Ramser (1959) first formalised the VRP, and it has since evolved to include dynamic and time-dependent variants suitable for real-time ride-matching (Psaraftis et al., 2016). Contemporary implementations use heuristics and spatial indexing to enable real-time operation (Agatz et al., 2012). However, existing systems often treat the algorithm as a “black box,” leaving users unaware of why certain matches are made. RideShare addresses this gap by making the detour cost visible to users, adding transparency to the decision-making process.
3.2 User Trust, Safety, and Adoption Barriers
Trust remains a major barrier to ride-sharing adoption. Studies by Bösch et al. (2018) and Dias et al. (2017) show that concerns over driver vetting, personal safety, and accountability limit participation, especially among women and first-time users. These findings support industry trends where safety features such as real-time tracking, panic buttons, and verified identities have become standard. RideShare integrates these elements at the MVP level, applying multi-factor user authentication and a built-in safety alert protocol. This aligns with best practices recommended in privacy-preserving mobility systems (Shaheen & Cohen, 2018).
3.3 Environmental and Economic Impact
Several studies confirm the environmental benefits of shared mobility. According to a European Commission white paper (2017), carpooling can reduce traffic volume and emissions by up to 20% when widely adopted. More recently, Arslan et al. (2019) found that dynamic ride-sharing systems in urban areas reduced CO₂ emissions and travel costs significantly, depending on occupancy and route efficiency. Although most findings are simulation-based, they provide strong indicators of impact potential. RideShare builds on this by evaluating real-world pilot data using DEFRA (2024) carbon reporting conversion factors.
3.4 Technology Stack Reviews
Modern ride-sharing applications leverage distributed, containerised architectures for scalability. Uber’s architecture (Garg et al., 2019) is a benchmark example, using microservices, cloud-native infrastructure, and real-time analytics. For this project, technologies like FastAPI, MongoDB (with 2dsphere indexing), Docker, and Kafka have been selected due to their compatibility with open-source development, academic licensing, and ease of integration. These tools also reflect current industry practice and are covered extensively in open developer documentation and usage case studies (Tiangolo, 2024; MongoDB, 2024).
3.5 Adoption Challenges in Suburban Areas
Most ride-sharing systems are designed with urban densities in mind. Shaheen & Chan (2016) highlight that suburban regions often suffer from limited ride availability, weaker demand clustering, and low trust among users. Cultural and psychological barriers such as stigma or a preference for private travel also reduce uptake in semi-urban settings. RideShare addresses these limitations through optional community-based filtering and simplified matching logic that reduces wait times and builds trust within local user pools.

3.6 Critical Synthesis & Gaps Addressed
The reviewed literature confirms that while ride-sharing can promote environmental sustainability, reduce travel costs, and increase vehicle utilisation, persistent challenges remain in transparency, inclusivity, and suburban adoption. RideShare directly responds to these gaps through:
•	A transparent route-matching interface that displays detour and proximity data.
•	A community-centric design tailored for smaller or lower-density regions.
•	Integration of core safety features at the MVP level, with compliance to ethical and legal norms.
By combining these elements with a user-tested pilot and real-time data evaluation, the project moves beyond replication to offer meaningful, research-led innovation.
 
4.0 Ethics and Legal Relevance & Progress 
The RideShare project involves the collection and processing of real-time location data, hashed user identities, and survey responses for system evaluation. Given the nature of this data and its association with identifiable individuals, the project must fully comply with the UK GDPR, Data Protection Act 2018, and the latest guidance issued by the Information Commissioner's Office (ICO).
All ethics risks have been reviewed according to the Accountability Principle (Art. 5(2), UK GDPR) and aligned with privacy-by-design (Art. 25), ensuring compliance is embedded throughout the system's architecture and pilot research protocol.
4.1 Key Ethics and Legal Compliance Measures

Area	Risk	Response
Data Minimisation & Lawfulness (Art. 5, 6)	Over-collection of personal data	Only essential data is collected (pickup/drop-off coordinates, hashed user IDs). Lawful basis is performance of a contract (Art. 6(1)(b)) for app use and informed consent (Art. 6(1)(a)) for pilot research participation (ICO, 2023a).
Consent Transparency (Art. 7)	Lack of clear explanation of rights	A GDPR-compliant Privacy Notice will be displayed in-app and at the start of all research participation, fulfilling ICO guidance on "clear, plain language" (ICO, 2023a).
User Rights (Art. 15–22)	Inability to exercise access/erasure	Procedures are documented to handle Subject Access Requests (SARs), withdrawal of consent, and deletion requests within 30 days, in line with ICO timelines.
Children’s Data (Art. 8)	Underage user sign-up	Age-restricted sign-up prevents use by anyone under 16. Age is validated by self-declaration with an optional secondary check (e.g. year of birth).
Data Security (Art. 32)	Unauthorised access or data loss	Enforced TLS encryption (HTTPS), hashed credentials (bcrypt), and token-based authentication (JWT). The system will apply OWASP ASVS Level 1 as a baseline.
International Transfers (Art. 44–49)	Non-compliant data export	All data is stored in UK-based AWS and MongoDB Atlas regions. No transfers outside the UK/EEA are allowed.

4.2 Additional Risk Controls
•	Pilot participants will sign e-consent forms stored securely in encrypted S3 buckets.
•	Data retention is limited to 90 days (raw logs); evaluation data will be pseudonymised before analysis.
•	If ethical approval is delayed, the pilot will shift to GPS replay simulation using synthetic users.

4.3 Summary
The RideShare project is designed to respect user autonomy, minimise data risks, and align fully with UK GDPR and university research ethics expectations. Consent, data minimisation, secure processing, and withdrawal mechanisms are all built into the project’s technical and research workflows. 
 
5.0 Technologies & Resources
The technical foundation of the RideShare project has been carefully selected to meet the demands of real-time geospatial matching, mobile accessibility, and rapid prototyping—while ensuring scalability, GDPR compliance, and feasibility within a research context.
5.1 Core Technologies and Justification
Layer	Chosen Technology	Relevance	Alternatives	Justification & References
Backend API	Python 3.12 + FastAPI	Enables async endpoints for ride matching and GPS streaming. Supports modern REST and WebSocket protocols.	Node.js (Express), Go (Gin)	FastAPI is praised for its automatic OpenAPI docs and async support, making it ideal for rapid, testable development (Tiangolo, 2024).
Database	MongoDB 6 (with 2dsphere indexing)	Ideal for GeoJSON format; supports $near and $geoWithin queries for driver-passenger matching.	PostgreSQL + PostGIS, Neo4j Spatial	MongoDB offers built-in spatial indexing with JSON flexibility and free cloud deployment (MongoDB, 2024). PostGIS has richer geospatial math, but MongoDB's performance and simplicity suit MVP timelines.
Route & Detour Engine	OSRM (Open Source Routing Machine) + Mapbox Directions API	OSRM handles millisecond-speed shortest path queries; Mapbox offers commercial-grade ETA and road data.	GraphHopper, Google Directions API	OSRM is open-source and containerised; Mapbox provides autocomplete and navigation tools under an academic tier (Project OSRM, 2024; Mapbox, 2024).
Real-time Messaging	Apache Kafka	Facilitates decoupled processing of ride requests and GPS updates. Supports log replay for debugging and fairness audits.	Redis Streams, RabbitMQ	Kafka is built for high-throughput systems and is open-source (Confluent, 2024). RabbitMQ is simpler but lacks Kafka’s durability and scalability.
Mobile Application	Flutter 3 (Dart)	One codebase compiles to Android, iOS, and Web; supports live maps and GPS.	React Native, Kotlin + Swift	Flutter allows cross-platform builds with native performance. It is preferred for its rendering engine and rapidly growing adoption (Google, 2024).
Maps & Geolocation	Mapbox SDKs (Flutter + JS)	High-performance tile rendering, vector maps, and global POI coverage.	Google Maps SDK, OpenLayers + OSM	Mapbox offers generous academic credits and offline caching options (Mapbox, 2024). Google Maps is accurate but imposes cost barriers.
Authentication	FastAPI Users + JWT	Lightweight, standards-based identity management with secure token handling.	Firebase Auth, AWS Cognito	JWT-based auth is stateless and GDPR-compliant, with bcrypt password hashing for security (OWASP, 2023).
DevOps & CI/CD	Docker Compose + GitHub Actions + AWS ECS Fargate	Portable local dev and CI pipeline; scalable cloud deployment without infrastructure maintenance.	Kubernetes (EKS), DigitalOcean App Platform	ECS + GitHub Actions are cost-effective and integrated into student workflows (AWS Educate, 2024).
Infrastructure as Code	Terraform (AWS + MongoDB Atlas modules)	Reproducible deployment; version-controlled infrastructure	CloudFormation, Pulumi	Terraform is cloud-agnostic and widely used in industry (HashiCorp, 2024).
Evaluation Datasets	DEFRA (2024 CO₂ factors), UK DfT road data, OpenStreetMap	Used to simulate environmental impact and route plausibility	EU EEA emissions data	DEFRA is UK-specific and required for accurate environmental modelling (DEFRA, 2024).
 








