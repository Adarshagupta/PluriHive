# 🏃 PluriHive - Real-World Territory Conquest Game

> Transform your daily walks and runs into an epic territory battle! Capture real-world locations, compete on global leaderboards, and build your fitness empire.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![NestJS](https://img.shields.io/badge/NestJS-E0234E?style=for-the-badge&logo=nestjs&logoColor=white)](https://nestjs.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org)
[![Mapbox](https://img.shields.io/badge/Mapbox-000000?style=for-the-badge&logo=mapbox&logoColor=white)](https://www.mapbox.com)

## 🎯 Problem Statement

Traditional fitness apps lack **gamification** and **competitive elements** that keep users motivated. Walking and running feel like chores rather than adventures. We need a solution that:
- Makes fitness **fun and engaging**
- Provides **real-time competition** with global players
- Rewards **consistent activity** with tangible achievements
- Creates **social proof** through territory ownership

## 💡 Solution

**PluriHive** transforms real-world movement into a competitive territory conquest game. As users walk or run, they capture hexagonal territories on a live map, compete for points, and defend their conquered areas from challengers.

Think **Pokémon GO meets Risk** - but for fitness enthusiasts.

---

## 🚀 Key Features

### 🗺️ Real-Time Territory Capture
- **GPS-based tracking** with sub-5-meter accuracy
- **Hexagonal grid system** overlays the real world
- **Live territory visualization** on Mapbox
- **Route shape preservation** - your exact walking path becomes your territory

### 🏆 Competitive Gameplay
- **Global leaderboard** with real-time rankings
- **Territory battles** - capture others' territories by walking the same area
- **Points system** - earn rewards for distance, territories, and consistency
- **Capture history** - see who owned a territory before you

### 📊 Advanced Activity Tracking
- **Multi-modal motion detection** - distinguishes walking, jogging, running
- **Step counter** with pedometer integration
- **Speed and distance** tracking with GPS fusion algorithms
- **Workout summaries** - detailed stats for each session

### 🔐 Secure Authentication
- **Google Sign-In** integration
- **JWT-based security** for API protection
- **Profile customization** - weight, height, age, gender for accurate calorie calculations

### 🌐 Backend Architecture
- **RESTful API** with NestJS (TypeScript)
- **PostgreSQL** for scalable data persistence
- **WebSocket** support for real-time updates
- **Geospatial queries** with PostGIS for efficient territory lookups

### 📱 Mobile-First Design
- **Native Android** performance with Flutter
- **Offline caching** for seamless experience
- **Background tracking** with foreground services
- **Picture-in-Picture mode** for multitasking

---

## 🛠️ Tech Stack

### **Frontend (Mobile)**
| Technology | Purpose |
|------------|---------|
| **Flutter 3.x** | Cross-platform UI framework |
| **Dart** | Primary programming language |
| **BLoC Pattern** | State management with flutter_bloc |
| **Mapbox Maps Flutter** | Interactive map rendering |
| **Geolocator** | GPS location tracking |
| **Sensors Plus** | Accelerometer/gyroscope for motion detection |
| **Pedometer** | Step counting |
| **Secure Storage** | Encrypted credential storage |

### **Backend (Server)**
| Technology | Purpose |
|------------|---------|
| **NestJS** | Node.js framework with TypeScript |
| **PostgreSQL** | Relational database |
| **TypeORM** | ORM for database operations |
| **JWT** | Stateless authentication |
| **Passport** | Authentication middleware |
| **WebSockets** | Real-time communication |
| **Docker** | Containerization (optional) |

### **DevOps & Infrastructure**
| Technology | Purpose |
|------------|---------|
| **Render** | Backend hosting (plurihubb.onrender.com) |
| **Google Cloud** | OAuth (Google Sign-In) |
| **Mapbox** | Maps platform |
| **Git** | Version control |
| **GitHub** | Repository hosting |

---

## 📐 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Mobile App                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   Auth   │  │   Map    │  │ Tracking │  │Dashboard │   │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  Screen  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │             │          │
│  ┌────┴─────────────┴──────────────┴─────────────┴────┐   │
│  │              BLoC State Management                  │   │
│  │  (AuthBloc, LocationBloc, TerritoryBloc, GameBloc) │   │
│  └───────────────────┬─────────────────────────────────┘   │
│                      │                                      │
│  ┌───────────────────┴─────────────────────────────────┐   │
│  │           Services & Repositories                    │   │
│  │  • AuthApiService      • TrackingApiService         │   │
│  │  • TerritoryApiService • MotionDetectionService     │   │
│  │  • BackgroundTrackingService                        │   │
│  └───────────────────┬─────────────────────────────────┘   │
└────────────────────┬─┴──────────────────────────────────────┘
                     │
            ┌────────┴────────┐
            │   HTTPS / WSS   │
            └────────┬────────┘
                     │
┌────────────────────┴────────────────────────────────────────┐
│                      NestJS Backend                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   Auth   │  │   User   │  │Territory │  │ Activity │   │
│  │Controller│  │Controller│  │Controller│  │Controller│   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │             │          │
│  ┌────┴─────────────┴──────────────┴─────────────┴────┐   │
│  │                    Services Layer                    │   │
│  │  • AuthService  • UserService  • TerritoryService   │   │
│  └───────────────────┬─────────────────────────────────┘   │
│                      │                                      │
│  ┌───────────────────┴─────────────────────────────────┐   │
│  │                TypeORM Repository                    │   │
│  │  • UserRepository  • TerritoryRepository            │   │
│  │  • ActivityRepository                               │   │
│  └───────────────────┬─────────────────────────────────┘   │
└────────────────────┬─┴──────────────────────────────────────┘
                     │
            ┌────────┴────────┐
            │   PostgreSQL     │
            │    Database      │
            └──────────────────┘
```

---

## 🔧 Installation & Setup

### Prerequisites
- **Flutter SDK** 3.x or higher
- **Node.js** 16.x or higher
- **PostgreSQL** 14.x or higher
- **Android Studio** (for mobile development)
- **Google Cloud Console** account (for OAuth)
- **Mapbox** account (for maps)

### 1️⃣ Clone Repository
```bash
git clone https://github.com/Adarshagupta/PluriHive.git
cd PluriHive
```

### 2️⃣ Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Create .env file
cat > .env << EOF
DATABASE_URL=postgresql://user:password@localhost:5432/plurihive
JWT_SECRET=your-super-secret-jwt-key-change-in-production
GOOGLE_CLIENT_ID=your-google-oauth-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-oauth-client-secret
PORT=3000
EOF

# Run database migrations
npm run migration:run

# Start development server
npm run start:dev
```

### 3️⃣ Frontend Setup

```bash
# Return to root directory
cd ..

# Install Flutter dependencies
flutter pub get

# Configure API endpoint in lib/core/services/api_config.dart
# Update localUrl to your backend IP address

# Get your local IP
ipconfig  # Windows
# or
ifconfig  # Mac/Linux

# Run the app
flutter run
```

### 4️⃣ Mapbox + Google Sign-In Setup

1. **Mapbox access:**
   - Create a Mapbox access token
   - Add your downloads token to `android/gradle.properties` as `MAPBOX_DOWNLOADS_TOKEN=...`
   - Provide the access token at runtime: `--dart-define=MAPBOX_ACCESS_TOKEN=...`

2. **Google Sign-In:**
   - Enable the Google Sign-In API
   - Create OAuth 2.0 credentials
   - Add SHA-1 fingerprint from your Android keystore
   - Configure authorized redirect URIs
   - OAuth Client ID → Backend `.env`

---

## 📡 API Documentation

### Authentication Endpoints

#### `POST /auth/signup`
Register a new user with email/password.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "name": "John Doe"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

#### `POST /auth/google`
Authenticate with Google Sign-In.

**Request:**
```json
{
  "idToken": "google-oauth-id-token",
  "email": "user@gmail.com",
  "displayName": "John Doe",
  "photoUrl": "https://..."
}
```

#### `GET /auth/me`
Get current authenticated user profile.

**Headers:**
```
Authorization: Bearer <jwt-token>
```

---

### Territory Endpoints

#### `POST /territories/capture`
Capture new territories from a completed route.

**Request:**
```json
{
  "routePoints": [
    { "latitude": 27.7172, "longitude": 85.3240 },
    { "latitude": 27.7175, "longitude": 85.3245 }
  ]
}
```

**Response:**
```json
{
  "newTerritories": 15,
  "pointsEarned": 750,
  "capturedHexIds": ["h3-hex-id-1", "h3-hex-id-2"]
}
```

#### `GET /territories/user/:userId`
Get all territories owned by a specific user.

#### `GET /territories/nearby`
Get territories near a location.

**Query Params:**
- `lat`: Latitude
- `lng`: Longitude
- `radius`: Search radius in meters (default: 1000)

---

### Activity Endpoints

#### `POST /activities`
Save a completed workout activity.

**Request:**
```json
{
  "routePoints": [...],
  "distanceMeters": 5000,
  "durationSeconds": 1800,
  "territoriesCaptured": 10,
  "pointsEarned": 500
}
```

#### `GET /activities`
Get user's activity history.

**Query Params:**
- `limit`: Number of activities (default: 20)
- `offset`: Pagination offset

---

## 🎨 Key Algorithms

### 1. Territory Hexagonal Grid (H3)
```typescript
// Uses Uber's H3 library for efficient hexagonal tessellation
// Resolution 9 = ~100m hexagons
const hexId = geoToH3(latitude, longitude, 9);
```

### 2. GPS Noise Filtering
```dart
// Kalman-like filtering for GPS accuracy
if (speedMps > MAX_REALISTIC_SPEED) {
  // Reject outlier
} else {
  smoothedSpeed = alpha * newSpeed + (1 - alpha) * prevSpeed;
}
```

### 3. Polygon Area Calculation
```dart
// Shoelace formula for spherical polygons
double area = 0.0;
for (int i = 0; i < points.length; i++) {
  final p1 = points[i];
  final p2 = points[(i + 1) % points.length];
  area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2));
}
area = area.abs() * earthRadius * earthRadius / 2.0;
```

### 4. Motion Classification
```dart
// Multi-sensor fusion for activity detection
if (variance < 1.0 && rotationRate < 0.5) {
  motionType = MotionType.stationary;
} else if (variance < 3.0 && mean < 11.0) {
  motionType = MotionType.walking;
} else if (variance >= 3.0 && mean >= 11.0) {
  motionType = MotionType.running;
}
```

---

## 📊 Database Schema

### Users Table
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255),
  name VARCHAR(255),
  google_id VARCHAR(255),
  profile_picture TEXT,
  weight DECIMAL,
  height DECIMAL,
  age INTEGER,
  gender VARCHAR(50),
  has_completed_onboarding BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Territories Table
```sql
CREATE TABLE territories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  hex_id VARCHAR(255) UNIQUE NOT NULL,
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  route_points JSONB,
  owner_id UUID REFERENCES users(id),
  capture_count INTEGER DEFAULT 1,
  points INTEGER DEFAULT 50,
  last_battle_at TIMESTAMP,
  captured_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_hex_id ON territories(hex_id);
CREATE INDEX idx_owner_id ON territories(owner_id);
```

### Activities Table
```sql
CREATE TABLE activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  route_points JSONB,
  distance_meters DECIMAL,
  duration_seconds INTEGER,
  territories_captured INTEGER,
  points_earned INTEGER,
  avg_speed_kmh DECIMAL,
  steps INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🎯 Future Enhancements

### Phase 2 (Next 2 Months)
- [ ] **Team Battles** - Form alliances and conquer territories together
- [ ] **Territory Decay** - Inactive territories lose strength over time
- [ ] **Power-ups** - Speed boosts, territory shields, point multipliers
- [ ] **Achievements & Badges** - Unlock rewards for milestones
- [ ] **Social Features** - Friend challenges, chat, activity feed

### Phase 3 (6 Months)
- [ ] **AR Integration** - View territories in augmented reality
- [ ] **Apple Watch** - Standalone tracking without phone
- [ ] **Offline Mode** - Cache territories and sync later
- [ ] **Voice Commands** - Hands-free tracking control
- [ ] **AI Coach** - Personalized training recommendations

### Long-term Vision
- [ ] **City Events** - Organized territory conquest competitions
- [ ] **Sponsorships** - Local businesses sponsor territories
- [ ] **NFT Integration** - Own territories as blockchain assets
- [ ] **Metaverse Bridge** - Connect real-world territories to virtual worlds

---

## 🏅 Hackathon Highlights

### Innovation
- **First fitness app** to combine real-world territory conquest with precise GPS tracking
- **Advanced motion detection** using multi-sensor fusion (accelerometer + gyroscope)
- **Hexagonal grid system** for fair and efficient territory division

### Technical Excellence
- **Clean Architecture** with separation of concerns (BLoC pattern)
- **Type Safety** with TypeScript backend and Dart frontend
- **Real-time Updates** via WebSockets for live leaderboard
- **Scalable Backend** designed for millions of concurrent users

### User Experience
- **Intuitive onboarding** with Google Sign-In
- **Beautiful UI** with smooth animations and Material Design
- **Background tracking** keeps working even when app is closed
- **Detailed analytics** help users track progress

### Social Impact
- **Promotes physical fitness** in a fun, engaging way
- **Builds community** through friendly competition
- **Encourages exploration** of local neighborhoods
- **Gamifies healthy habits** for sustained motivation

---

## 👥 Team

- **Adarsh Gupta** - Full Stack Developer
  - Flutter mobile development
  - NestJS backend architecture
  - Database design & optimization
  - GPS algorithms & geospatial logic

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

---

## 🙏 Acknowledgments

- **Uber H3** for hexagonal grid library
- **Mapbox platform** for mapping infrastructure
- **Flutter Community** for excellent packages
- **NestJS Team** for the robust backend framework

---

## 📸 Screenshots

![Map Screen](./screenshots/map_screen.jpg)
*Real-time territory capture with GPS tracking*

![Dashboard](./screenshots/dashboard.jpg)
*User stats and global leaderboard*

![Workout Summary](./screenshots/workout_summary.jpg)
*Detailed activity analytics*

---

## 🔗 Links

- **Live Demo**: [Download APK](./build/app/outputs/flutter-apk/app-release.apk)
- **Backend API**: https://plurihubb.onrender.com
- **Documentation**: [Wiki](./docs)
- **Issue Tracker**: [GitHub Issues](https://github.com/Adarshagupta/PluriHive/issues)

---

## 🚀 Getting Started Video

[Watch Setup Tutorial](https://youtu.be/placeholder) - 5-minute quickstart guide

---

<div align="center">

**Made with ❤️ for Hackathon 2026**

[⭐ Star this repo](https://github.com/Adarshagupta/PluriHive) if you found it useful!

</div>
