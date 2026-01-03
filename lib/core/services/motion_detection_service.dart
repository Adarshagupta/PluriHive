import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Advanced motion detection service using accelerometer and gyroscope
/// Detects steps, motion type, and activity state
class MotionDetectionService {
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  
  // Step detection
  int _stepCount = 0;
  double _lastAccelMagnitude = 0.0;
  DateTime? _lastStepTime;
  bool _isPeakDetected = false;
  
  // Motion classification
  MotionType _currentMotionType = MotionType.stationary;
  double _averageAcceleration = 0.0;
  List<double> _accelHistory = [];
  
  // Gyroscope data for rotation detection
  double _rotationRate = 0.0;
  
  // Callbacks
  Function(int steps)? onStepDetected;
  Function(MotionType type)? onMotionTypeChanged;
  Function(double confidence)? onMotionConfidence;
  
  // Configuration
  static const double STEP_THRESHOLD = 12.0; // m/s² threshold for step
  static const int MIN_STEP_DELAY_MS = 200; // Minimum time between steps
  static const int MAX_STEP_DELAY_MS = 2000; // Maximum time for step sequence
  static const int HISTORY_SIZE = 20; // Number of readings to keep
  
  void startDetection() {
    _stepCount = 0;
    _accelHistory.clear();
    
    // Start accelerometer monitoring (100 Hz sampling)
    _accelSubscription = accelerometerEvents.listen(
      _processAccelerometerData,
      onError: (error) => print('Accelerometer error: $error'),
    );
    
    // Start gyroscope monitoring
    _gyroSubscription = gyroscopeEvents.listen(
      _processGyroscopeData,
      onError: (error) => print('Gyroscope error: $error'),
    );
  }
  
  void stopDetection() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelHistory.clear();
  }
  
  void _processAccelerometerData(AccelerometerEvent event) {
    // Calculate magnitude of acceleration vector
    final magnitude = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
    
    // Add to history for motion classification
    _accelHistory.add(magnitude);
    if (_accelHistory.length > HISTORY_SIZE) {
      _accelHistory.removeAt(0);
    }
    
    // Calculate average acceleration
    if (_accelHistory.isNotEmpty) {
      _averageAcceleration = _accelHistory.reduce((a, b) => a + b) / _accelHistory.length;
    }
    
    // Detect steps using peak detection algorithm
    _detectStep(magnitude);
    
    // Classify motion type
    _classifyMotion();
  }
  
  void _processGyroscopeData(GyroscopeEvent event) {
    // Calculate rotation rate
    _rotationRate = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
  }
  
  void _detectStep(double magnitude) {
    final now = DateTime.now();
    
    // Check if enough time has passed since last step
    if (_lastStepTime != null) {
      final timeSinceLastStep = now.difference(_lastStepTime!).inMilliseconds;
      if (timeSinceLastStep < MIN_STEP_DELAY_MS) {
        return; // Too soon for another step
      }
    }
    
    // Peak detection algorithm
    final delta = magnitude - _lastAccelMagnitude;
    
    if (!_isPeakDetected && delta > 0 && magnitude > STEP_THRESHOLD) {
      // Rising edge - potential peak
      _isPeakDetected = true;
    } else if (_isPeakDetected && delta < 0) {
      // Falling edge - peak detected, count as step
      _stepCount++;
      _lastStepTime = now;
      _isPeakDetected = false;
      
      onStepDetected?.call(_stepCount);
    }
    
    _lastAccelMagnitude = magnitude;
  }
  
  void _classifyMotion() {
    if (_accelHistory.length < HISTORY_SIZE) return;
    
    // Calculate variance for motion detection
    final variance = _calculateVariance(_accelHistory);
    final mean = _averageAcceleration;
    
    MotionType newType;
    double confidence;
    
    // Advanced motion classification
    if (variance < 1.0 && _rotationRate < 0.5) {
      // Low variance and low rotation = stationary
      newType = MotionType.stationary;
      confidence = 0.95;
    } else if (variance < 3.0 && mean < 11.0) {
      // Low variance, moderate acceleration = walking
      newType = MotionType.walking;
      confidence = 0.85;
    } else if (variance >= 3.0 && variance < 8.0 && mean >= 11.0 && mean < 13.0) {
      // Moderate variance and acceleration = jogging
      newType = MotionType.jogging;
      confidence = 0.80;
    } else if (variance >= 8.0 || mean >= 13.0) {
      // High variance or acceleration = running
      newType = MotionType.running;
      confidence = 0.85;
    } else {
      // Undefined motion
      newType = MotionType.moving;
      confidence = 0.60;
    }
    
    if (newType != _currentMotionType) {
      _currentMotionType = newType;
      onMotionTypeChanged?.call(newType);
    }
    
    onMotionConfidence?.call(confidence);
  }
  
  double _calculateVariance(List<double> data) {
    if (data.isEmpty) return 0.0;
    
    final mean = data.reduce((a, b) => a + b) / data.length;
    final squaredDiffs = data.map((x) => pow(x - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / data.length;
  }
  
  int get stepCount => _stepCount;
  MotionType get currentMotionType => _currentMotionType;
  double get averageAcceleration => _averageAcceleration;
  
  void resetSteps() {
    _stepCount = 0;
  }
}

enum MotionType {
  stationary,
  walking,
  jogging,
  running,
  moving, // Undefined movement
}
