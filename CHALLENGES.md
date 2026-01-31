# 🚧 Challenges & Solutions

## 1. 🗺️ **GPS Tracking Auto-Starting Bug**

### The Problem
Users reported that GPS tracking would automatically start 5 seconds after entering the map screen, even without pressing the "Start" button. The speed indicator showed "1.1 km/h" and a "Tracking: 0.01 km" banner appeared, confusing users who hadn't initiated any activity.

### Root Cause
The `LocationBloc` was persisting its state across screen navigations. When users completed a tracking session and returned to the dashboard, then navigated back to the map screen, the bloc was still in the `LocationTracking` state. The BlocListener would detect this state and start updating the UI as if tracking was active.

### Solution
```dart
@override
void initState() {
  super.initState();
  // ... other initialization ...
  
  // IMPORTANT: Stop any previous tracking session first
  context.read<LocationBloc>().add(StopLocationTracking());
  context.read<LocationBloc>().add(GetInitialLocation());
}
```

**Added a force-reset** by dispatching `StopLocationTracking()` event before initializing the map screen. This ensures a clean state on every screen entry.

**Learning:** State management in Flutter requires explicit cleanup, especially with singleton blocs. Always reset to a known state when entering critical screens.

---

## 2. 🔐 **Google OAuth Secret Exposure**

### The Problem
GitHub's secret scanning blocked our push with this error:
```
remote: error: GH013: Repository rule violations found for refs/heads/main
remote: - Push cannot contain secrets
remote: —— Google OAuth Client ID ————————————
```

Our documentation file `GOOGLE_SIGNIN_COMPLETE.md` contained real OAuth credentials for setup instructions.

### Solution
```bash
# Remove the sensitive file from git history
git rm GOOGLE_SIGNIN_COMPLETE.md

# Amend the commit to exclude it
git commit --amend --no-edit

# Force push the cleaned commit
git push --force
```

**Immediately rotated** the exposed credentials in Google Cloud Console and updated `.gitignore` to exclude documentation with credentials.

**Learning:** 
- Never commit credentials, even in documentation
- Use environment variable placeholders in docs: `GOOGLE_CLIENT_ID=your-client-id-here`
- Enable pre-commit hooks to scan for secrets before pushing

---

## 3. 📱 **Permission Dialog Overflow on Small Screens**

### The Problem
The permission request dialog was overflowing on devices with small screens (< 6 inches). The error message was verbose, causing content to exceed the dialog's height:

```
RenderFlex overflowing: constraints BoxConstraints(0.0<=h<=84.5)
The overflowing RenderFlex has an orientation of Axis.vertical.
```

### Solution
```dart
// Before: Static Text widget with \n separators
content: const Text(
  '⚠️ This app REQUIRES all permissions...\n\n• Location...',
  style: TextStyle(fontSize: 14),
),

// After: Scrollable Column with smaller font
content: SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: const [
      Text('⚠️ This app REQUIRES all permissions...'),
      SizedBox(height: 12),
      Text('• Location: Track your movement'),
      // ... more items
    ],
  ),
),
```

**Reduced font size** from 14 to 12 and **wrapped content in SingleChildScrollView** to allow scrolling on constrained screens.

**Learning:** Always test UI on different screen sizes. Use `LayoutBuilder` or `MediaQuery` to adapt layouts dynamically. SingleChildScrollView is essential for content that might expand.

---

## 4. 🏃 **Duplicate Function Definition Build Error**

### The Problem
During territory enhancement, we added a polygon area calculation function without checking if it already existed:

```
lib/features/tracking/presentation/pages/map_screen.dart:453:10: 
Error: '_calculatePolygonArea' is already declared in this scope.
```

The build failed because the function existed at both line 453 and line 1329.

### Solution
```bash
# Used grep to find all occurrences
grep -n "_calculatePolygonArea" map_screen.dart

# Removed the duplicate and kept the more sophisticated implementation
# (The one using Uber's H3 library for spherical geometry)
```

**Learning:** 
- Search before adding new functions: `Ctrl+F` in VS Code
- Use code navigation (`F12` - Go to Definition) to avoid duplicates
- The 3000+ line file was getting unwieldy - refactoring into smaller widgets would have prevented this

---

## 5. 🎯 **Territory Details Showing Limited Information**

### The Problem
When users tapped on territories, they only saw:
- Owner name
- Capture count

This didn't leverage the rich data available from the backend (points, captured date, area, battle history).

### Architectural Challenge
The backend `Territory` entity had these fields, but the frontend wasn't storing or displaying them:
```typescript
@Column({ default: 50 })
points: number;

@Column({ type: 'timestamp', nullable: true })
lastBattleAt: Date;

@CreateDateColumn()
capturedAt: Date;
```

### Solution

**Step 1:** Enhanced data storage in `_territoryData` map:
```dart
_territoryData[territory['hexId']] = {
  'polygonPoints': polygonPoints,
  'ownerId': ownerId,
  'ownerName': territory['owner']?['name'] ?? 'Unknown',
  'captureCount': territory['captureCount'] ?? 1,
  'isOwn': isOwnTerritory,
  // NEW: Additional fields
  'points': territory['points'],
  'capturedAt': territory['capturedAt'] != null 
      ? DateTime.parse(territory['capturedAt']) 
      : null,
  'lastBattleAt': territory['lastBattleAt'] != null 
      ? DateTime.parse(territory['lastBattleAt']) 
      : null,
  'areaSqMeters': _calculatePolygonArea(polygonPoints),
};
```

**Step 2:** Created reusable detail row widget:
```dart
Widget _buildDetailRow({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Row(
    children: [
      Icon(icon, size: 20, color: color),
      SizedBox(width: 8),
      Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: Text(value)),
    ],
  );
}
```

**Step 3:** Added smart date formatting:
```dart
String _formatDate(DateTime date) {
  final difference = DateTime.now().difference(date);
  
  if (difference.inHours == 0) return '${difference.inMinutes} min ago';
  if (difference.inDays == 0) return '${difference.inHours}h ago';
  if (difference.inDays == 1) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays} days ago';
  return '${date.day}/${date.month}/${date.year}';
}
```

**Learning:** 
- Always leverage all available backend data - users appreciate details
- Create reusable UI components for consistency
- Smart formatting (relative time) improves UX significantly

---

## 6. 🔄 **Onboarding Flow State Management**

### The Problem
The profile screen wasn't saving user data to the backend. After completing onboarding, users would see the onboarding flow again on app restart.

### Root Cause Analysis

**Database Schema Issue:**
```sql
-- Backend had the field
has_completed_onboarding BOOLEAN DEFAULT FALSE

-- But frontend wasn't updating it
```

**Frontend Issue:**
```dart
// AuthApiService.updateProfile() wasn't sending the field
await _client.put(
  Uri.parse('${ApiConfig.baseUrl}${ApiConfig.userProfileEndpoint}'),
  body: json.encode({
    'weight': weight,
    'height': height,
    // Missing: 'hasCompletedOnboarding': true
  }),
);
```

### Solution

**Backend:** Added endpoint to mark onboarding complete:
```typescript
@Patch('profile')
async updateProfile(@Request() req, @Body() updateDto: UpdateProfileDto) {
  return this.userService.updateProfile(req.user.id, updateDto);
}
```

**Frontend:** Updated the DTO to include the flag:
```dart
Future<void> updateProfile({
  required bool hasCompletedOnboarding,
  // ... other fields
}) async {
  final response = await _client.put(
    Uri.parse('${ApiConfig.baseUrl}${ApiConfig.userProfileEndpoint}'),
    body: json.encode({
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'weight': weight,
      // ...
    }),
  );
}
```

**AuthBloc:** Ensured the flag was set after profile save:
```dart
await authApiService.updateProfile(
  hasCompletedOnboarding: true,
  weight: event.weight,
  // ...
);
```

**Learning:**
- Full-stack debugging requires checking both ends: frontend AND backend
- Use database inspection tools to verify data is actually saved
- Add logging at each step: "Profile API called → Response received → DB updated"

---

## 7. 🌐 **Dynamic Backend URL Management**

### The Problem
During development, the app needed to switch between:
- **Local backend** (`http://10.1.80.51:3000`) for debugging
- **Production backend** (`https://plurihubb.onrender.com`) for deployment

Hardcoding URLs meant recompiling the app every time the developer's local IP changed.

### Solution

**Created runtime-configurable endpoint:**
```dart
class ApiConfig {
  static const String localUrl = 'http://10.1.80.51:3000';
  static const String productionUrl = 'https://plurihubb.onrender.com';
  
  static String baseUrl = localUrl; // Default
  
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendPrefKey, url);
    baseUrl = url; // Update runtime value
  }
  
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backendPrefKey) ?? localUrl;
  }
}
```

**Added Settings screen toggle:**
```dart
// User can switch backend without recompiling
ListTile(
  title: Text('Backend Server'),
  subtitle: Text(currentBackend),
  trailing: Switch(
    value: isProduction,
    onChanged: (value) {
      ApiConfig.setBaseUrl(
        value ? ApiConfig.productionUrl : ApiConfig.localUrl
      );
    },
  ),
)
```

**Learning:**
- Configuration should be runtime-changeable for development
- Use SharedPreferences for persistent settings
- Provide UI controls for developers and testers to switch environments

---

## 8. 📍 **GPS Accuracy & Noise Filtering**

### The Problem
Raw GPS data is notoriously noisy. We observed:
- **Sudden jumps** of 100+ meters when stationary
- **Speed spikes** to 50+ km/h while walking
- **Zigzag patterns** instead of smooth paths

This made territory capture unreliable and routes looked erratic.

### Solution

**Implemented multi-layered filtering:**

```dart
// Layer 1: Reject impossible speeds
const double MAX_REALISTIC_SPEED = 15.0; // 15 m/s = 54 km/h max
if (speedMps > MAX_REALISTIC_SPEED) {
  print('🚫 Rejected: Speed too high ($speedMps m/s)');
  return;
}

// Layer 2: Reject impossible accelerations
const double MAX_ACCELERATION = 6.0; // 6 m/s² max
final acceleration = (speedMps - _lastValidSpeed).abs() / timeDelta;
if (acceleration > MAX_ACCELERATION) {
  print('🚫 Rejected: Acceleration too high ($acceleration m/s²)');
  return;
}

// Layer 3: Exponential Moving Average smoothing
const double ALPHA = 0.25;
_smoothedSpeed = ALPHA * currentSpeed + (1 - ALPHA) * _smoothedSpeed;

// Layer 4: Require minimum distance between points
const double MIN_DISPLACEMENT = 3.0; // 3 meters minimum
if (distanceToLastPoint < MIN_DISPLACEMENT) {
  return; // Too close, ignore
}
```

**Added GPS accuracy monitoring:**
```dart
if (position.accuracy > 20.0) {
  print('⚠️ Low GPS accuracy: ${position.accuracy}m');
  // Don't update route with inaccurate points
}
```

**Learning:**
- Never trust raw sensor data - always filter
- Understand the physics of what you're measuring (realistic speeds, accelerations)
- Multiple validation layers catch different types of noise
- Exponential Moving Average is simple but effective for smoothing

---

## 9. 🎨 **Map Performance with Large Territory Sets**

### The Problem
When loading 500+ territories on the map, the app became laggy. Frame rate dropped from 60fps to 15fps. Polygon rendering was the bottleneck.

### Diagnosis
```dart
// This was running on EVERY territory update
setState(() {
  _polygons.clear();
  for (final territory in territories) {
    _polygons.add(Polygon(/* ... */)); // 500+ polygons
  }
});
```

### Solution

**Implemented aggressive caching:**
```dart
int _lastLoadedTerritoryCount = 0;

void _updateTerritoryPolygons(List<Territory> territories) {
  // Skip if already loaded
  if (territories.length == _lastLoadedTerritoryCount) {
    print('⚡ Cache hit - skipping territory reload');
    return;
  }
  
  _lastLoadedTerritoryCount = territories.length;
  
  // Only update if data actually changed
  setState(() {
    // Update polygons...
  });
}
```

**Viewport-based culling** (planned but not implemented due to time):
```dart
// Only render territories visible in current camera bounds
final visibleBounds = await mapController.getVisibleRegion();
final visibleTerritories = territories.where((t) => 
  visibleBounds.contains(LatLng(t.latitude, t.longitude))
).toList();
```

**Learning:**
- Rendering hundreds of polygons is expensive - use caching
- Implement viewport culling for large datasets
- Consider using Mapbox clustering for dense areas
- Profile with Flutter DevTools to find bottlenecks

---

## 10. 🔄 **WebSocket Real-Time Updates**

### The Problem
We wanted real-time leaderboard updates when other users captured territories, but implementing WebSockets in both NestJS and Flutter proved challenging.

### Challenges Faced

**Backend (NestJS):**
```typescript
// WebSocket gateway setup
@WebSocketGateway({
  cors: {
    origin: '*', // Had to debug CORS issues
  },
})
export class GameGateway {
  @SubscribeMessage('territory_captured')
  handleTerritoryCapture(client: Socket, data: any) {
    // Broadcast to all clients
    this.server.emit('territory_update', data);
  }
}
```

**Frontend (Flutter):**
```dart
// Socket.IO client connection issues
final socket = io.io('ws://10.1.80.51:3000', <String, dynamic>{
  'transports': ['websocket'],
  'autoConnect': false,
});

socket.on('territory_update', (data) {
  // Update UI in real-time
});
```

**Issues Encountered:**
1. **Connection failures** on different network types (WiFi vs Mobile)
2. **Message serialization** - JSON encoding/decoding mismatches
3. **State synchronization** - ensuring UI updates atomically

### Solution
We **simplified the MVP** to use HTTP polling instead of WebSockets for the hackathon deadline:

```dart
// Polling every 30 seconds for territory updates
Timer.periodic(Duration(seconds: 30), (timer) {
  territoryBloc.add(LoadTerritories());
});
```

**Post-Hackathon Plan:**
- Implement WebSockets properly with socket.io
- Add connection resilience (reconnect logic)
- Use binary protocol (MessagePack) for efficiency

**Learning:**
- Feature prioritization is critical in time-constrained projects
- A working polling solution beats a broken real-time one
- Complex features (WebSockets) need dedicated time for debugging
- Always have a Plan B when implementing cutting-edge features

---

## 🎓 **Key Takeaways**

### What Worked Well
✅ **BLoC pattern** - Excellent state management separation  
✅ **TypeScript** - Caught type errors before runtime  
✅ **PostgreSQL** - Relational model perfect for territory ownership  
✅ **Flutter hot reload** - Rapid iteration and debugging  

### What Was Challenging
❌ **GPS noise filtering** - Required research into Kalman filters  
❌ **Map performance** - Polygon rendering at scale is hard  
❌ **State persistence** - Bloc state carried across screens  
❌ **Secrets management** - Almost exposed OAuth credentials  

### If I Could Start Over
1. **Start with TypeScript on both ends** (avoid type mismatches)
2. **Implement proper logging** from day 1 (Sentry, Firebase Crashlytics)
3. **Write tests** for critical paths (auth, territory capture)
4. **Refactor map_screen.dart** into smaller widgets earlier
5. **Use feature flags** to toggle WebSockets on/off

---

## 💪 **Lessons Learned**

> "Debugging is twice as hard as writing the code in the first place. Therefore, if you write the code as cleverly as possible, you are, by definition, not smart enough to debug it."  
> — Brian Kernighan

This project taught me that **simple, debuggable code beats clever code**. Every bug we encountered was solvable because we:
1. ✅ Used clear naming conventions
2. ✅ Added print statements generously
3. ✅ Tested on real devices (not just emulator)
4. ✅ Read error messages carefully
5. ✅ Googled the exact error strings

The hardest bugs were the ones caused by **state management** and **asynchronous operations**. Understanding the Flutter widget lifecycle and BLoC event flow was crucial to solving the auto-start tracking bug.

**Final thought:** Every bug is an opportunity to understand the system better. The challenges we faced made us better developers and resulted in a more robust, production-ready application.
