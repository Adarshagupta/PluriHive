import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../tracking/domain/entities/activity.dart';
import '../../../tracking/data/datasources/activity_local_data_source.dart';
import '../../../../core/services/tracking_api_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import 'package:intl/intl.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  late final TrackingApiService _apiService;
  final ActivityLocalDataSource _localDataSource = ActivityLocalDataSourceImpl();
  List<Activity> _activities = [];
  bool _isLoading = true;
  final Map<String, GoogleMapController> _mapControllers = {};
  
  @override
  void initState() {
    super.initState();
    _apiService = di.getIt<TrackingApiService>();
    _loadActivities();
  }
  
  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      // Try to load from backend first
      try {
        final activitiesData = await _apiService.getUserActivities();
        final backendActivities = activitiesData.map((data) => Activity.fromJson(data)).toList();
        
        if (backendActivities.isNotEmpty) {
          setState(() {
            _activities = backendActivities;
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        print('⚠️ Could not load from backend: $e');
      }
      
      // Fallback to local storage
      final localActivities = await _localDataSource.getAllActivities();
      setState(() {
        _activities = localActivities;
        _isLoading = false;
      });
      print('📱 Loaded ${localActivities.length} activities from local storage');
    } catch (e) {
      print('❌ Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  double get _totalDistance => _activities.fold(0.0, (sum, a) => sum + a.distanceMeters / 1000);
  int get _totalActivities => _activities.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF667EEA)),
              ),
            )
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.directions_run,
                          size: 80,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No activities yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start tracking your runs to see them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadActivities,
                  color: Color(0xFF667EEA),
                  child: CustomScrollView(
                    slivers: [
                      // Compact Professional Header
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        backgroundColor: Colors.white,
                        toolbarHeight: 70,
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activity History',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '$_totalActivities workouts • ${_totalDistance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Activities List
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final activity = _activities[index];
                            return _ActivityItem(
                              activity: activity,
                              isFirst: index == 0,
                              onShare: () => _shareActivity(activity),
                              onMapCreated: (controller) {
                                _mapControllers[activity.id] = controller;
                              },
                            );
                          },
                          childCount: _activities.length,
                        ),
                      ),
                      // Bottom padding
                      SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),
                ),
    );
  }
  
  void _shareActivity(Activity activity) async {
    final date = DateFormat('MMM d, yyyy').format(activity.startTime);
    final time = DateFormat('h:mm a').format(activity.startTime);
    final distance = (activity.distanceMeters / 1000).toStringAsFixed(2);
    final duration = _formatDuration(activity.duration);
    final speed = activity.averageSpeed.toStringAsFixed(1);
    
    final shareText = '''
🏃‍♂️ PluriHive Activity - $date

📍 Distance: $distance km
⏱️ Time: $duration
⚡ Avg Speed: $speed km/h
🔥 Calories: ${activity.caloriesBurned} cal
${activity.territoriesCaptured > 0 ? '🏴 Territories: ${activity.territoriesCaptured}\n' : ''}${activity.pointsEarned > 0 ? '⭐ Points: ${activity.pointsEarned}\n' : ''}
Started at $time

#PluriHive #Fitness #Running
''';
    
    try {
      // Try to capture map screenshot
      final mapController = _mapControllers[activity.id];
      if (mapController != null) {
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Preparing map screenshot...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(Duration(milliseconds: 500));
        
        final imageBytes = await mapController.takeSnapshot();
        if (imageBytes != null) {
          // Save to temporary file
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/plurihive_activity_${activity.id}.png');
          await file.writeAsBytes(imageBytes);
          
          // Share with image
          await Share.shareXFiles(
            [XFile(file.path)],
            text: shareText,
            subject: 'My PluriHive Activity',
          );
          
          // Clean up
          await file.delete();
          return;
        }
      }
    } catch (e) {
      print('Error capturing map screenshot: $e');
    }
    
    // Fallback to text only
    Share.share(shareText, subject: 'My PluriHive Activity');
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _ActivityItem extends StatelessWidget {
  final Activity activity;
  final bool isFirst;
  final VoidCallback onShare;
  final Function(GoogleMapController) onMapCreated;
  
  const _ActivityItem({
    required this.activity,
    this.isFirst = false,
    required this.onShare,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: isFirst ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header (if different from previous)
          Padding(
            padding: EdgeInsets.fromLTRB(24, isFirst ? 0 : 24, 24, 12),
            child: Text(
              DateFormat('EEEE, MMMM d, yyyy').format(activity.startTime),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
          // 3D Map with Route
          if (activity.route.isNotEmpty)
            _Route3DMap(
              activity: activity,
              onShare: onShare,
              onMapCreated: onMapCreated,
            ),
          // Additional stats section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CompactStat(
                  icon: Icons.local_fire_department,
                  value: '${activity.caloriesBurned}',
                  label: 'cal',
                  color: Color(0xFFEF4444),
                ),
                if (activity.territoriesCaptured > 0)
                  _CompactStat(
                    icon: Icons.flag,
                    value: '${activity.territoriesCaptured}',
                    label: 'areas',
                    color: Color(0xFF8B5CF6),
                  ),
                if (activity.pointsEarned > 0)
                  _CompactStat(
                    icon: Icons.stars,
                    value: '${activity.pointsEarned}',
                    label: 'pts',
                    color: Color(0xFFFCD34D),
                  ),
                if (activity.capturedAreaSqMeters != null)
                  _CompactStat(
                    icon: Icons.map,
                    value: '${(activity.capturedAreaSqMeters! / 1000).toStringAsFixed(1)}',
                    label: 'km²',
                    color: Color(0xFF06B6D4),
                  ),
              ],
            ),
          ),
          // Divider
          Container(
            height: 1,
            color: Color(0xFFE5E7EB),
          ),
        ],
      ),
    );
  }
}

// 3D Map Widget with Route Visualization
class _Route3DMap extends StatefulWidget {
  final Activity activity;
  final VoidCallback onShare;
  final Function(GoogleMapController) onMapCreated;
  
  const _Route3DMap({
    required this.activity,
    required this.onShare,
    required this.onMapCreated,
  });

  @override
  State<_Route3DMap> createState() => _Route3DMapState();
}

class _Route3DMapState extends State<_Route3DMap> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  void _setupMap() {
    final route = widget.activity.route;
    if (route.isEmpty) return;

    // Create polyline for the route
    _polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        points: route.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        color: Color(0xFF667EEA),
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );

    // Add start marker
    _markers.add(
      Marker(
        markerId: MarkerId('start'),
        position: LatLng(route.first.latitude, route.first.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Start'),
      ),
    );

    // Add end marker
    _markers.add(
      Marker(
        markerId: MarkerId('end'),
        position: LatLng(route.last.latitude, route.last.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'End'),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    widget.onMapCreated(controller);
    _animate3DView();
  }

  void _animate3DView() async {
    await Future.delayed(Duration(milliseconds: 500));
    if (_mapController == null) return;

    final route = widget.activity.route;
    if (route.isEmpty) return;

    // Calculate bounds
    double minLat = route.first.latitude;
    double maxLat = route.first.latitude;
    double minLng = route.first.longitude;
    double maxLng = route.first.longitude;

    for (var pos in route) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    // Animate to 3D view with tilt and bearing
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: center,
          zoom: 16.5, // Zoomed out to show more of the route
          tilt: 45.0, // 3D tilt angle
          bearing: 30.0, // Rotate view
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activity.route.isEmpty) {
      return Container(
        height: 300,
        color: Color(0xFFF3F4F6),
        child: Center(
          child: Icon(Icons.map, size: 48, color: Color(0xFF9CA3AF)),
        ),
      );
    }

    final route = widget.activity.route;
    final center = LatLng(route.first.latitude, route.first.longitude);

    return Stack(
      children: [
        Container(
          height: 300,
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: 13.5,
              tilt: 45.0,
              bearing: 30.0,
            ),
            polylines: _polylines,
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            zoomGesturesEnabled: true,
          ),
        ),
        // Gradient overlay at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),
        // Time badge and Share button
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Share button
              GestureDetector(
                onTap: widget.onShare,
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFF667EEA).withOpacity(0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.share, size: 18, color: Colors.white),
                ),
              ),
              SizedBox(width: 8),
              // Time badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      DateFormat('h:mm a').format(widget.activity.startTime),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 3D Badge
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFF667EEA).withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  '3D VIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Main stats overlay
        Positioned(
          bottom: 20,
          left: 24,
          right: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _OverlayStat(
                icon: Icons.straighten,
                value: '${(widget.activity.distanceMeters / 1000).toStringAsFixed(2)}',
                label: 'km',
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              _OverlayStat(
                icon: Icons.timer,
                value: _formatDuration(widget.activity.duration),
                label: '',
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              _OverlayStat(
                icon: Icons.speed,
                value: '${widget.activity.averageSpeed.toStringAsFixed(1)}',
                label: 'km/h',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _OverlayStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  
  const _OverlayStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.white),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  
  const _CompactStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
