# 🚀 PluriHive Backend - Quick Start Guide

## Complete Backend Setup

Your NestJS backend with PostgreSQL, WebSockets, and JWT is ready!

### What's Included

✅ **Authentication Module**
- JWT-based auth
- Sign up / Sign in
- Protected routes
- Password hashing with bcrypt

✅ **User Module**
- User profiles
- Stats tracking (points, level, distance, territories)
- Profile updates

✅ **Territory Module**
- Territory capture system
- Recapture from other users
- Nearby territory queries
- Points calculation

✅ **Tracking Module**
- Activity saving
- Route storage (JSONB)
- Activity history
- Stats integration

✅ **Leaderboard Module**
- Global leaderboard
- Sort by points
- Top players

✅ **Realtime Module (WebSocket)**
- Real-time territory updates
- Location broadcasting
- Achievement notifications

## Setup Instructions

### 1. Install Dependencies
```bash
cd backend
npm install
npm install --save-dev ts-node-dev
```

### 2. Setup PostgreSQL Database
```bash
# Install PostgreSQL if not installed
# Then create database
createdb plurihive

# Or use psql
psql -U postgres
CREATE DATABASE plurihive;
\q
```

### 3. Configure Environment
```bash
cp .env.example .env
```

Edit `.env`:
```env
PORT=3000
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=your_password_here
DATABASE_NAME=plurihive
JWT_SECRET=change_this_to_a_random_secret_key
JWT_EXPIRATION=7d
CORS_ORIGINS=http://localhost:3000
ADMIN_API_KEY=replace_with_strong_value
SEED_LEADERBOARD=false
```

### 4. Start the Server
```bash
# Development mode with auto-reload
npm run start:dev

# Production mode
npm run build
npm run start:prod
```

Server runs on: **http://localhost:3000**

## API Endpoints

### Auth
```http
POST /auth/signup
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe"
}
```

```http
POST /auth/signin
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

```http
GET /auth/me
Authorization: Bearer <your_jwt_token>
```

### Territories
```http
POST /territories/capture
Authorization: Bearer <token>
Content-Type: application/json

{
  "hexIds": ["hex1", "hex2"],
  "coordinates": [
    {"lat": 16.4638, "lng": 80.5066},
    {"lat": 16.4639, "lng": 80.5067}
  ]
}
```

```http
GET /territories/nearby?lat=16.4638&lng=80.5066&radius=5
```

### Activities
```http
POST /activities
Authorization: Bearer <token>
Content-Type: application/json

{
  "routePoints": [...],
  "distanceMeters": 5000,
  "duration": "00:45:00",
  "steps": 6000,
  "territoriesCaptured": 10,
  "pointsEarned": 500
}
```

```http
GET /activities
Authorization: Bearer <token>
```

### Leaderboard
```http
GET /leaderboard/global?limit=50
```

## WebSocket Connection

### Connect from Flutter
```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socket = IO.io('http://localhost:3000', <String, dynamic>{
  'transports': ['websocket'],
  'autoConnect': true,
  'auth': {'token': jwtToken},
});

// Connect user
socket.emit('user:connect', userId);

// Listen for territory updates
socket.on('territory:contested', (data) {
  print('Territory contested: $data');
});

// Send location updates
socket.emit('location:update', {
  'userId': userId,
  'lat': latitude,
  'lng': longitude,
});
```

### Available Events

**Client → Server:**
- `user:connect` - Register user connection
- `territory:captured` - Notify territory capture
- `location:update` - Send real-time location

**Server → Client:**
- `territory:contested` - Territory being captured by another user
- `leaderboard:update` - Leaderboard changes
- `achievement:unlocked` - New achievement earned

## Database Schema

### Users Table
- Personal info (email, name, password)
- Physical stats (weight, height, age, gender)
- Game stats (points, level, distance, territories, steps)

### Territories Table
- Geographic data (hexId, lat, lng)
- Ownership (ownerId, captureCount)
- Battle info (points, lastBattleAt)

### Activities Table
- Route data (JSONB array of coordinates)
- Metrics (distance, duration, speed, steps)
- Game data (territories, points, calories)

## Integration with Flutter App

### 1. Install HTTP Package
```yaml
# pubspec.yaml
dependencies:
  http: ^1.1.0
  socket_io_client: ^2.0.3
```

### 2. Create API Service
```dart
class ApiService {
  static const String baseUrl = 'http://localhost:3000';
  
  Future<Map<String, dynamic>> signUp(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }
}
```

### 3. Update Injection Container
Add API service to your dependency injection.

## Testing

```bash
# Test signup
curl -X POST http://localhost:3000/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"password123","name":"Test User"}'

# Test signin
curl -X POST http://localhost:3000/auth/signin \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"password123"}'
```

## Troubleshooting

**Database connection fails:**
- Check PostgreSQL is running: `pg_isready`
- Verify credentials in `.env`
- Check database exists: `psql -l`

**Port already in use:**
- Change PORT in `.env`
- Or kill process: `lsof -ti:3000 | xargs kill`

**Module not found errors:**
- Delete node_modules: `rm -rf node_modules`
- Reinstall: `npm install`

## Production Deployment

### Using Docker
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
CMD ["npm", "run", "start:prod"]
```

### Environment Variables
Set all `.env` variables in your hosting platform (Heroku, AWS, etc.)

## Next Steps

1. ✅ Backend is running
2. Connect Flutter app to API
3. Test authentication flow
4. Test territory capture
5. Test real-time WebSocket updates
6. Deploy to production

🎉 Your backend is ready for PluriHive!
