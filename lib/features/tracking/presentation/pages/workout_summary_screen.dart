import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:video_player/video_player.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final double distanceKm;
  final int territoriesCaptured;
  final int pointsEarned;
  final Duration duration;
  final double avgSpeed;
  final int steps;
  final List<LatLng>? routePoints;
  final Set<Polygon>? territories;
  final DateTime workoutDate;
  final String? videoPath;

  WorkoutSummaryScreen({
    super.key,
    required this.distanceKm,
    required this.territoriesCaptured,
    required this.pointsEarned,
    required this.duration,
    required this.avgSpeed,
    this.steps = 0,
    this.routePoints,
    this.territories,
    DateTime? workoutDate,
    this.videoPath,
  }) : workoutDate = workoutDate ?? DateTime.now();

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with TickerProviderStateMixin {
  final GlobalKey _summaryKey = GlobalKey();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isSharing = false;
  
  AnimationController? _routeAnimController;
  double _routeProgress = 0.0;
  List<LatLng> _animatedRoutePoints = [];
  
  VideoPlayerController? _videoController;
  bool _useVideoPlayback = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    
    // Initialize video player if video path is provided
    if (widget.videoPath != null && File(widget.videoPath!).existsSync()) {
      _initializeVideoPlayer();
    } else {
      // Fallback to route animation
      _initializeRouteAnimation();
    }
  }
  
  void _initializeVideoPlayer() async {
    _videoController = VideoPlayerController.file(File(widget.videoPath!));
    await _videoController!.initialize();
    setState(() {
      _useVideoPlayback = true;
    });
    
    // Start playing at 3x speed after a brief delay
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted && _videoController != null) {
        _videoController!.setPlaybackSpeed(3.0);
        _videoController!.play();
      }
    });
  }
  
  void _initializeRouteAnimation() {
    // Route animation controller
    _routeAnimController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    
    _routeAnimController!.addListener(() {
      if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
        setState(() {
          _routeProgress = _routeAnimController!.value;
          int pointsToShow = (_routeProgress * widget.routePoints!.length).round();
          _animatedRoutePoints = widget.routePoints!.sublist(0, pointsToShow.clamp(0, widget.routePoints!.length));
        });
      }
    });
    
    // Start route animation after a brief delay
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _routeAnimController?.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _routeAnimController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _captureAndShare() async {
    setState(() => _isSharing = true);

    try {
      // Wait a bit to ensure everything is rendered
      await Future.delayed(Duration(milliseconds: 100));
      
      // Capture the widget as an image
      final RenderRepaintBoundary boundary = _summaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/workout_summary_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      print('Image saved to: ${file.path}');
      print('File exists: ${await file.exists()}');
      
      // Share with subject
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: '🏃 Captured ${widget.territoriesCaptured} territories and ran ${widget.distanceKm.toStringAsFixed(2)} km on Plurihive! 💪\n\n#Plurihive #Running #Fitness',
        subject: 'My Plurihive Workout',
      );
      
      print('Share result: $result');
    } catch (e, stackTrace) {
      print('Error sharing: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
  
  Future<void> _shareVideo() async {
    if (widget.videoPath == null || !File(widget.videoPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isSharing = true);
    
    try {
      final result = await Share.shareXFiles(
        [XFile(widget.videoPath!)],
        text: '🏃 Captured ${widget.territoriesCaptured} territories and ran ${widget.distanceKm.toStringAsFixed(2)} km on Plurihive! 💪\n\n#Plurihive #Running #Fitness',
        subject: 'My Plurihive Workout Video',
      );
      
      print('Video share result: $result');
    } catch (e) {
      print('Error sharing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Workout Complete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Center(
                        child: RepaintBoundary(
                          key: _summaryKey,
                          child: _buildSummaryCard(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Share button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSharing ? null : _captureAndShare,
                          icon: _isSharing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.share_rounded, color: Colors.white),
                          label: Text(
                            _isSharing ? 'Preparing...' : 'Share Workout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF7B68EE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Share video button (if video is available)
                      if (widget.videoPath != null && File(widget.videoPath!).existsSync())
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isSharing ? null : _shareVideo,
                              icon: _isSharing
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(Icons.video_library_rounded, color: Colors.white),
                              label: Text(
                                _isSharing ? 'Preparing...' : 'Share Video (3x Speed)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFE91E63),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      // Share text only (for testing)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _isSharing ? null : () async {
                            await Share.share(
                              '🏃 Captured ${widget.territoriesCaptured} territories and ran ${widget.distanceKm.toStringAsFixed(2)} km on Plurihive! 💪\n\n#Plurihive #Running #Fitness',
                              subject: 'My Plurihive Workout',
                            );
                          },
                          icon: Icon(Icons.text_fields, color: Colors.white70),
                          label: Text(
                            'Share Text Only',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white24, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Done button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white38, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 0.75,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Full-size map
              if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
                _buildCompactMap()
              else
                Container(color: Colors.grey.shade300),

              // Subtle gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                    stops: [0.0, 0.15, 0.7, 1.0],
                  ),
                ),
              ),

              // Top-left: Date
              Positioned(
                top: 20,
                left: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(widget.workoutDate).toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d').format(widget.workoutDate),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // Top-right: Distance
              Positioned(
                top: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.distanceKm.toStringAsFixed(2),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(
                            'km',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'DISTANCE',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom stats row
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: _buildBottomStat(_formatDuration(widget.duration), 'TIME')),
                    SizedBox(width: 8),
                    Flexible(child: _buildBottomStat('${widget.territoriesCaptured}', 'ZONES')),
                    SizedBox(width: 8),
                    Flexible(child: _buildBottomStat('${widget.pointsEarned}', 'PTS')),
                    SizedBox(width: 8),
                    Flexible(child: _buildBottomStat('${widget.avgSpeed.toStringAsFixed(1)}', 'KM/H')),
                    SizedBox(width: 8),
                    Flexible(child: _buildBottomStat('${widget.steps}', 'STEPS')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCompactMap() {
    // Show video player if video is available
    if (_useVideoPlayback && _videoController != null && _videoController!.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }
    
    // Fallback to map animation
    if (widget.routePoints == null || widget.routePoints!.isEmpty) {
      return SizedBox.shrink();
    }

    double minLat = widget.routePoints!.first.latitude;
    double maxLat = widget.routePoints!.first.latitude;
    double minLng = widget.routePoints!.first.longitude;
    double maxLng = widget.routePoints!.first.longitude;

    for (var point in widget.routePoints!) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 14),
      polylines: {
        if (_animatedRoutePoints.isNotEmpty)
          Polyline(
            polylineId: PolylineId('route'),
            points: _animatedRoutePoints,
            color: Color(0xFF7B68EE),
            width: 4,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      },
      markers: _animatedRoutePoints.isNotEmpty ? {
        Marker(
          markerId: MarkerId('current_position'),
          position: _animatedRoutePoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      } : {},
      polygons: _routeProgress > 0.8 ? (widget.territories ?? {}) : {},
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      zoomGesturesEnabled: false,
      scrollGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }
}
