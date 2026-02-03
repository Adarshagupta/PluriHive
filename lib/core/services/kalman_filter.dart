import 'dart:math';

/// ═══════════════════════════════════════════════════════════════════════════
/// ULTRA-ADVANCED GPS FILTERING SYSTEM v2.0
/// Military-grade algorithms for maximum accuracy and noise rejection
/// ═══════════════════════════════════════════════════════════════════════════

/// Extended Kalman Filter for 2D position with velocity tracking
/// Uses state-space model: [x, y, vx, vy]
class ExtendedKalmanFilter2D {
  // State vector: [latitude, longitude, velocity_lat, velocity_lng]
  late List<double> _state;
  
  // Covariance matrix (4x4)
  late List<List<double>> _P;
  
  // Process noise covariance
  late List<List<double>> _Q;
  
  // Measurement noise covariance
  late List<List<double>> _R;
  
  bool _initialized = false;
  DateTime? _lastTimestamp;
  
  // Tuning parameters - STRICT values
  static const double POSITION_NOISE = 0.0000001;  // Very low - trust predictions
  static const double VELOCITY_NOISE = 0.000001;   // Low - smooth velocity
  static const double BASE_MEASUREMENT_NOISE = 0.0001;
  
  ExtendedKalmanFilter2D() {
    _state = [0.0, 0.0, 0.0, 0.0];
    _initializeMatrices();
  }
  
  void _initializeMatrices() {
    // Initial covariance - high uncertainty
    _P = [
      [1.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0],
      [0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 1.0],
    ];
    
    // Process noise
    _Q = [
      [POSITION_NOISE, 0.0, 0.0, 0.0],
      [0.0, POSITION_NOISE, 0.0, 0.0],
      [0.0, 0.0, VELOCITY_NOISE, 0.0],
      [0.0, 0.0, 0.0, VELOCITY_NOISE],
    ];
    
    // Measurement noise (updated based on GPS accuracy)
    _R = [
      [BASE_MEASUREMENT_NOISE, 0.0],
      [0.0, BASE_MEASUREMENT_NOISE],
    ];
  }
  
  Map<String, double> update({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
  }) {
    if (!_initialized) {
      _state = [latitude, longitude, 0.0, 0.0];
      _initialized = true;
      _lastTimestamp = timestamp;
      return {'latitude': latitude, 'longitude': longitude};
    }
    
    final dt = _lastTimestamp != null 
        ? timestamp.difference(_lastTimestamp!).inMilliseconds / 1000.0 
        : 0.5;
    _lastTimestamp = timestamp;
    
    if (dt <= 0) return {'latitude': _state[0], 'longitude': _state[1]};
    
    // === PREDICT STEP ===
    // State transition: x' = x + vx*dt, vx' = vx (constant velocity model)
    final predictedState = [
      _state[0] + _state[2] * dt,
      _state[1] + _state[3] * dt,
      _state[2],
      _state[3],
    ];
    
    // State transition matrix F
    final F = [
      [1.0, 0.0, dt, 0.0],
      [0.0, 1.0, 0.0, dt],
      [0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 1.0],
    ];
    
    // Predicted covariance: P' = F * P * F' + Q
    final predictedP = _addMatrices(
      _multiplyMatrices(_multiplyMatrices(F, _P), _transposeMatrix(F)),
      _Q,
    );
    
    // === UPDATE STEP ===
    // Measurement matrix H (we only measure position, not velocity)
    final H = [
      [1.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0],
    ];
    
    // Update measurement noise based on GPS accuracy
    final accuracyFactor = pow(max(accuracy, 1.0) / 10.0, 2).toDouble();
    _R = [
      [BASE_MEASUREMENT_NOISE * accuracyFactor, 0.0],
      [0.0, BASE_MEASUREMENT_NOISE * accuracyFactor],
    ];
    
    // Innovation covariance: S = H * P' * H' + R
    final HP = _multiplyMatrices(H, predictedP);
    final HPHt = _multiplyMatrices(HP, _transposeMatrix(H));
    final S = _addMatrices(HPHt, _R);
    
    // Kalman gain: K = P' * H' * S^-1
    final PHt = _multiplyMatrices(predictedP, _transposeMatrix(H));
    final SInv = _invertMatrix2x2(S);
    final K = _multiplyMatrices(PHt, SInv);
    
    // Innovation: y = z - H * x'
    final z = [latitude, longitude];
    final Hx = [
      H[0][0] * predictedState[0] + H[0][1] * predictedState[1],
      H[1][0] * predictedState[0] + H[1][1] * predictedState[1],
    ];
    final y = [z[0] - Hx[0], z[1] - Hx[1]];
    
    // Updated state: x = x' + K * y
    _state = [
      predictedState[0] + K[0][0] * y[0] + K[0][1] * y[1],
      predictedState[1] + K[1][0] * y[0] + K[1][1] * y[1],
      predictedState[2] + K[2][0] * y[0] + K[2][1] * y[1],
      predictedState[3] + K[3][0] * y[0] + K[3][1] * y[1],
    ];
    
    // Updated covariance: P = (I - K * H) * P'
    final KH = _multiplyMatrices(K, H);
    final I_KH = _subtractMatrices(_identityMatrix(4), KH);
    _P = _multiplyMatrices(I_KH, predictedP);
    
    return {
      'latitude': _state[0],
      'longitude': _state[1],
      'velocity_lat': _state[2],
      'velocity_lng': _state[3],
    };
  }
  
  // Matrix operations
  List<List<double>> _multiplyMatrices(List<List<double>> A, List<List<double>> B) {
    final m = A.length;
    final n = B[0].length;
    final k = B.length;
    final result = List.generate(m, (_) => List.filled(n, 0.0));
    
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        for (var p = 0; p < k; p++) {
          result[i][j] += A[i][p] * B[p][j];
        }
      }
    }
    return result;
  }
  
  List<List<double>> _transposeMatrix(List<List<double>> M) {
    final m = M.length;
    final n = M[0].length;
    return List.generate(n, (i) => List.generate(m, (j) => M[j][i]));
  }
  
  List<List<double>> _addMatrices(List<List<double>> A, List<List<double>> B) {
    return List.generate(A.length, (i) => 
      List.generate(A[0].length, (j) => A[i][j] + B[i][j]));
  }
  
  List<List<double>> _subtractMatrices(List<List<double>> A, List<List<double>> B) {
    return List.generate(A.length, (i) => 
      List.generate(A[0].length, (j) => A[i][j] - B[i][j]));
  }
  
  List<List<double>> _identityMatrix(int n) {
    return List.generate(n, (i) => 
      List.generate(n, (j) => i == j ? 1.0 : 0.0));
  }
  
  List<List<double>> _invertMatrix2x2(List<List<double>> M) {
    final det = M[0][0] * M[1][1] - M[0][1] * M[1][0];
    if (det.abs() < 1e-10) {
      return [[1.0, 0.0], [0.0, 1.0]]; // Return identity if singular
    }
    return [
      [M[1][1] / det, -M[0][1] / det],
      [-M[1][0] / det, M[0][0] / det],
    ];
  }
  
  void reset() {
    _initialized = false;
    _state = [0.0, 0.0, 0.0, 0.0];
    _lastTimestamp = null;
    _initializeMatrices();
  }
  
  Map<String, double> get currentPosition => {
    'latitude': _state[0],
    'longitude': _state[1],
    'velocity_lat': _state[2],
    'velocity_lng': _state[3],
  };
  
  double get currentSpeed {
    return sqrt(_state[2] * _state[2] + _state[3] * _state[3]) * 111000; // deg/s to m/s
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ULTRA-STRICT GPS FILTER with multi-layer validation
/// ═══════════════════════════════════════════════════════════════════════════
class AdvancedGPSFilter {
  final ExtendedKalmanFilter2D _ekf = ExtendedKalmanFilter2D();
  
  // Position history for advanced analysis
  final List<_GPSReading> _history = [];
  static const int MAX_HISTORY = 20;
  
  // Outlier detection
  int _consecutiveOutliers = 0;
  static const int MAX_CONSECUTIVE_OUTLIERS = 5;
  
  // Speed tracking
  double _smoothedSpeed = 0.0;
  static const double SPEED_SMOOTHING = 0.3; // EMA alpha
  
  // Statistical tracking for adaptive thresholds
  double _meanAccuracy = 10.0;
  double _stdAccuracy = 5.0;
  double _maxAccuracyMeters = 35.0;

  void setMaxAccuracyMeters(double value) {
    if (!value.isFinite || value <= 0) return;
    _maxAccuracyMeters = value;
  }
  
  /// STRICT filtering pipeline
  Map<String, double> process({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
  }) {
    print('🔬 AdvancedGPSFilter.process() called');
    print('   Input: ($latitude, $longitude) accuracy: ${accuracy.toStringAsFixed(1)}m');
    
    // === LAYER 1: Accuracy validation ===
    if (!_isAccuracyAcceptable(accuracy)) {
      print('   ❌ REJECTED: Poor accuracy (${accuracy.toStringAsFixed(1)}m > threshold)');
      return _getLastValidPosition();
    }
    
    // === LAYER 2: Outlier detection ===
    if (_isOutlier(latitude, longitude, accuracy, timestamp)) {
      _consecutiveOutliers++;
      print('   ❌ REJECTED: Outlier detected (consecutive: $_consecutiveOutliers)');
      
      // If too many consecutive outliers, user probably moved - accept it
      if (_consecutiveOutliers >= MAX_CONSECUTIVE_OUTLIERS) {
        print('   🔄 Too many outliers - accepting as valid position jump');
        _consecutiveOutliers = 0;
        _ekf.reset();
      } else {
        return _getLastValidPosition();
      }
    } else {
      _consecutiveOutliers = 0;
    }
    
    // === LAYER 3: Extended Kalman Filter ===
    final filtered = _ekf.update(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      timestamp: timestamp,
    );
    
    // === LAYER 4: Speed validation ===
    final instantSpeed = _calculateInstantSpeed(filtered['latitude']!, filtered['longitude']!, timestamp);
    if (instantSpeed > 15.0) { // Max 15 m/s = 54 km/h for walking/running
      print('   ⚠️ WARNING: High speed detected (${instantSpeed.toStringAsFixed(1)} m/s)');
      // Don't reject, but log for monitoring
    }
    
    // Update smoothed speed (EMA)
    _smoothedSpeed = SPEED_SMOOTHING * instantSpeed + (1 - SPEED_SMOOTHING) * _smoothedSpeed;
    
    // === LAYER 5: Store in history ===
    _history.add(_GPSReading(
      latitude: filtered['latitude']!,
      longitude: filtered['longitude']!,
      accuracy: accuracy,
      timestamp: timestamp,
      speed: instantSpeed,
    ));
    
    if (_history.length > MAX_HISTORY) {
      _history.removeAt(0);
    }
    
    // Update accuracy statistics
    _updateAccuracyStats(accuracy);
    
    print('   ✅ ACCEPTED: (${filtered['latitude']!.toStringAsFixed(6)}, ${filtered['longitude']!.toStringAsFixed(6)})');
    print('   📊 Speed: ${instantSpeed.toStringAsFixed(2)} m/s | Smoothed: ${_smoothedSpeed.toStringAsFixed(2)} m/s');
    
    return {
      'latitude': filtered['latitude']!,
      'longitude': filtered['longitude']!,
      'speed': _smoothedSpeed,
      'accuracy': accuracy,
    };
  }
  
  /// STRICT accuracy validation
  bool _isAccuracyAcceptable(double accuracy) {
    // Adaptive threshold based on historical accuracy
    final adaptiveThreshold = max(30.0, _meanAccuracy + 3 * _stdAccuracy);
    final threshold = min(_maxAccuracyMeters, adaptiveThreshold);
    return accuracy <= threshold;
  }
  
  /// Advanced outlier detection using multiple criteria
  bool _isOutlier(double lat, double lng, double accuracy, DateTime timestamp) {
    if (_history.isEmpty) return false;
    
    final last = _history.last;
    final distance = _haversineDistance(last.latitude, last.longitude, lat, lng);
    final dt = timestamp.difference(last.timestamp).inMilliseconds / 1000.0;
    
    if (dt <= 0) return true; // Invalid timestamp
    
    // Calculate required speed for this movement
    final requiredSpeed = distance / dt;
    
    // === CRITERION 1: Impossible speed ===
    // Max speed: 15 m/s (54 km/h) for running, with 2x buffer = 30 m/s
    if (requiredSpeed > 30.0) {
      print('   🚨 Outlier: Impossible speed ${requiredSpeed.toStringAsFixed(1)} m/s');
      return true;
    }
    
    // === CRITERION 2: Sudden direction change with high speed ===
    if (_history.length >= 3) {
      final prev2 = _history[_history.length - 2];
      final heading1 = _calculateBearing(prev2.latitude, prev2.longitude, last.latitude, last.longitude);
      final heading2 = _calculateBearing(last.latitude, last.longitude, lat, lng);
      final headingChange = _normalizeAngle(heading2 - heading1).abs();
      
      // If moving fast and sudden 90+ degree turn, likely GPS error
      if (requiredSpeed > 3.0 && headingChange > 90.0) {
        print('   🚨 Outlier: Sharp turn (${headingChange.toStringAsFixed(0)}°) at speed ${requiredSpeed.toStringAsFixed(1)} m/s');
        return true;
      }
    }
    
    // === CRITERION 3: Acceleration check ===
    if (_history.length >= 2) {
      final prevSpeed = last.speed;
      final acceleration = (requiredSpeed - prevSpeed) / dt;
      
      // Max acceleration: 5 m/s² (very generous for sprinting start)
      if (acceleration.abs() > 5.0) {
        print('   🚨 Outlier: Impossible acceleration ${acceleration.toStringAsFixed(1)} m/s²');
        return true;
      }
    }
    
    // === CRITERION 4: Statistical outlier (3-sigma rule) ===
    if (_history.length >= 5) {
      final recentDistances = <double>[];
      for (var i = 1; i < min(_history.length, 6); i++) {
        final d = _haversineDistance(
          _history[_history.length - i - 1].latitude,
          _history[_history.length - i - 1].longitude,
          _history[_history.length - i].latitude,
          _history[_history.length - i].longitude,
        );
        recentDistances.add(d);
      }
      
      final meanDist = recentDistances.reduce((a, b) => a + b) / recentDistances.length;
      final stdDist = sqrt(recentDistances.map((d) => pow(d - meanDist, 2)).reduce((a, b) => a + b) / recentDistances.length);
      
      if (distance > meanDist + 4 * stdDist && distance > 10.0) {
        print('   🚨 Outlier: Statistical anomaly (distance: ${distance.toStringAsFixed(1)}m, mean: ${meanDist.toStringAsFixed(1)}m, std: ${stdDist.toStringAsFixed(1)}m)');
        return true;
      }
    }
    
    return false;
  }
  
  double _calculateInstantSpeed(double lat, double lng, DateTime timestamp) {
    if (_history.isEmpty) return 0.0;
    
    final last = _history.last;
    final distance = _haversineDistance(last.latitude, last.longitude, lat, lng);
    final dt = timestamp.difference(last.timestamp).inMilliseconds / 1000.0;
    
    return dt > 0 ? distance / dt : 0.0;
  }
  
  void _updateAccuracyStats(double accuracy) {
    if (_history.length < 2) return;
    
    final accuracies = _history.map((r) => r.accuracy).toList();
    _meanAccuracy = accuracies.reduce((a, b) => a + b) / accuracies.length;
    _stdAccuracy = sqrt(
      accuracies.map((a) => pow(a - _meanAccuracy, 2)).reduce((a, b) => a + b) / accuracies.length
    );
  }
  
  Map<String, double> _getLastValidPosition() {
    if (_history.isEmpty) {
      return {'latitude': 0.0, 'longitude': 0.0, 'speed': 0.0};
    }
    final last = _history.last;
    return {
      'latitude': last.latitude,
      'longitude': last.longitude,
      'speed': _smoothedSpeed,
    };
  }
  
  /// Haversine formula for accurate distance calculation
  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
  
  /// Calculate bearing between two points
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _toRadians(lng2 - lng1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    
    final y = sin(dLng) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);
    
    return _toDegrees(atan2(y, x));
  }
  
  double _normalizeAngle(double angle) {
    while (angle > 180) angle -= 360;
    while (angle < -180) angle += 360;
    return angle;
  }
  
  double _toRadians(double deg) => deg * pi / 180.0;
  double _toDegrees(double rad) => rad * 180.0 / pi;
  
  void reset() {
    _ekf.reset();
    _history.clear();
    _consecutiveOutliers = 0;
    _smoothedSpeed = 0.0;
    _meanAccuracy = 10.0;
    _stdAccuracy = 5.0;
  }
  
  double get currentSpeed => _smoothedSpeed;
  
  List<Map<String, double>> get recentPositions => 
    _history.map((r) => {'lat': r.latitude, 'lng': r.longitude}).toList();
}

/// Internal GPS reading class
class _GPSReading {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final double speed;
  
  _GPSReading({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.speed,
  });
}

// Keep old class for backwards compatibility
class KalmanFilter {
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _variance = -1.0;
  static const double PROCESS_NOISE = 0.00001;
  static const double MIN_ACCURACY = 1.0;
  
  Map<String, double> update({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
  }) {
    final measurementVariance = pow(max(accuracy, MIN_ACCURACY), 2).toDouble();
    
    if (_variance < 0) {
      _latitude = latitude;
      _longitude = longitude;
      _variance = measurementVariance;
    } else {
      final predictedVariance = _variance + PROCESS_NOISE;
      final kalmanGain = predictedVariance / (predictedVariance + measurementVariance);
      _latitude = _latitude + kalmanGain * (latitude - _latitude);
      _longitude = _longitude + kalmanGain * (longitude - _longitude);
      _variance = (1 - kalmanGain) * predictedVariance;
    }
    
    return {'latitude': _latitude, 'longitude': _longitude, 'variance': _variance};
  }
  
  void reset() => _variance = -1.0;
  Map<String, double> get currentPosition => {'latitude': _latitude, 'longitude': _longitude, 'variance': _variance};
}
