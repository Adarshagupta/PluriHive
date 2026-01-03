# PluriHive Backend API

NestJS backend with PostgreSQL, WebSockets, and JWT authentication for the PluriHive fitness tracking app.

## Features

- ✅ User Authentication (JWT)
- ✅ Territory Capture System
- ✅ GPS Activity Tracking
- ✅ Real-time Updates (WebSockets)
- ✅ Leaderboard System
- ✅ Achievement System
- ✅ PostgreSQL Database

## Setup

### Prerequisites
- Node.js (v18+)
- PostgreSQL (v14+)
- npm or yarn

### Installation

```bash
cd backend
npm install
```

### Database Setup

1. Create PostgreSQL database:
```sql
CREATE DATABASE plurihive;
```

2. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

3. Update `.env` with your database credentials:
```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=your_password
DATABASE_NAME=plurihive
JWT_SECRET=your_super_secret_key
```

### Run the Server

```bash
# Development
npm run start:dev

# Production
npm run build
npm run start:prod
```

Server will run on `http://localhost:3000`

## API Endpoints

### Authentication
- `POST /auth/signup` - Register new user
- `POST /auth/signin` - Login
- `GET /auth/me` - Get current user (protected)

### User
- `GET /users/profile` - Get user profile (protected)
- `PUT /users/profile` - Update profile (protected)
- `GET /users/:id` - Get user by ID (protected)

### Territory
- `POST /territories/capture` - Capture territories (protected)
- `GET /territories/user/:userId` - Get user territories
- `GET /territories/nearby` - Get nearby territories

### Tracking
- `POST /activities` - Save activity (protected)
- `GET /activities` - Get user activities (protected)
- `GET /activities/:id` - Get activity details (protected)

### Leaderboard
- `GET /leaderboard/global` - Global leaderboard
- `GET /leaderboard/local` - Local leaderboard (within radius)

### WebSocket Events
Connect to: `ws://localhost:3000`

**Client Events:**
- `territory:captured` - When user captures territory
- `location:update` - Real-time location updates

**Server Events:**
- `territory:contested` - When territory is being captured by another user
- `leaderboard:update` - Leaderboard changes
- `achievement:unlocked` - New achievement earned

## Database Schema

### Users
- id, email, name, password (hashed)
- Physical stats: weight, height, age, gender
- Game stats: totalPoints, level, totalDistanceKm, totalSteps

### Territories
- id, hexId, latitude, longitude
- ownerId, captureCount, points
- lastBattleAt, capturedAt

### Activities
- id, userId, routePoints (JSONB)
- distanceMeters, duration, averageSpeed
- steps, caloriesBurned, territoriesCaptured

## Tech Stack

- **Framework**: NestJS
- **Database**: PostgreSQL + TypeORM
- **Authentication**: JWT + Passport
- **Real-time**: Socket.IO (WebSockets)
- **Validation**: class-validator
- **Security**: bcrypt

## Development

```bash
# Watch mode
npm run start:dev

# Run migrations
npm run migration:run

# Generate migration
npm run migration:generate -- -n MigrationName
```

## License

MIT
