import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../../../../core/models/geo_types.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/route_preview.dart';
import '../../domain/entities/position.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final double distanceKm;
  final int territoriesCaptured;
  final int pointsEarned;
  final Duration duration;
  final double avgSpeed;
  final int steps;
  final List<LatLng>? routePoints;
  final List<Position>? routePositions;
  final Set<Polygon>? territories;
  final DateTime workoutDate;
  final String? videoPath;
  final String? mapSnapshotBase64;

  WorkoutSummaryScreen({
    super.key,
    required this.distanceKm,
    required this.territoriesCaptured,
    required this.pointsEarned,
    required this.duration,
    required this.avgSpeed,
    this.steps = 0,
    this.routePoints,
    this.routePositions,
    this.territories,
    DateTime? workoutDate,
    this.videoPath,
    this.mapSnapshotBase64,
  }) : workoutDate = workoutDate ?? DateTime.now();

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with TickerProviderStateMixin {
  static const double _storyAspectRatio = 9 / 16;
  static const double _storyMaxWidth = 360;
  final GlobalKey _summaryKey = GlobalKey();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _chartController;
  late Animation<double> _chartAnimation;
  bool _isSharing = false;
  int _selectedStyle = 0;
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _customBackgroundBytes;
  String? _customBackgroundPath;
  bool _isPickingBackground = false;

  AnimationController? _routeAnimController;
  double _routeProgress = 0.0;
  List<LatLng> _animatedRoutePoints = [];

  VideoPlayerController? _videoController;
  bool _useVideoPlayback = false;
  Uint8List? _snapshotBytes;
  List<double> _paceSeries = [];
  List<double> _splitPaces = [];
  double _paceMin = 0;
  double _paceMax = 0;
  mapbox.MapboxMap? _replayMapboxMap;
  mapbox.PolylineAnnotationManager? _replayPolylineManager;
  List<LatLng> _replayRoute = [];
  List<mapbox.Point> _replayRoutePoints = [];
  int _replaySession = 0;
  double _replayZoom = 16.0;

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

    _chartController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOutCubic,
    );
    _prepareRecapSeries();
    _prepareReplayRoute();
    _chartController.forward();

    if (widget.mapSnapshotBase64 != null &&
        widget.mapSnapshotBase64!.isNotEmpty) {
      try {
        _snapshotBytes = base64Decode(widget.mapSnapshotBase64!);
      } catch (e) {
        print('Failed to decode map snapshot: $e');
      }
    }

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
          int pointsToShow =
              (_routeProgress * widget.routePoints!.length).round();
          _animatedRoutePoints = widget.routePoints!
              .sublist(0, pointsToShow.clamp(0, widget.routePoints!.length));
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
    _replaySession++;
    _controller.dispose();
    _chartController.dispose();
    _routeAnimController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  void _prepareRecapSeries() {
    final positions = widget.routePositions;
    if (positions == null || positions.length < 2) {
      return;
    }

    const double segmentTargetMeters = 200;
    const double splitTargetMeters = 1000;
    double segmentMeters = 0;
    Duration segmentTime = Duration.zero;
    double splitMeters = 0;
    Duration splitTime = Duration.zero;
    final paceSamples = <double>[];
    final splitPaces = <double>[];

    for (int i = 1; i < positions.length; i++) {
      final prev = positions[i - 1];
      final current = positions[i];
      final dt = current.timestamp.difference(prev.timestamp);
      if (dt.inMilliseconds <= 0) {
        continue;
      }

      final distance = geo.Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );
      if (distance <= 0) {
        continue;
      }

      segmentMeters += distance;
      segmentTime += dt;
      splitMeters += distance;
      splitTime += dt;

      if (segmentMeters >= segmentTargetMeters) {
        paceSamples.add(_paceFrom(segmentTime, segmentMeters));
        segmentMeters = 0;
        segmentTime = Duration.zero;
      }

      if (splitMeters >= splitTargetMeters) {
        splitPaces.add(_paceFrom(splitTime, splitMeters));
        splitMeters = 0;
        splitTime = Duration.zero;
        if (splitPaces.length >= 6) {
          break;
        }
      }
    }

    if (segmentMeters > 0 && segmentTime.inSeconds > 0) {
      paceSamples.add(_paceFrom(segmentTime, segmentMeters));
    }

    if (splitMeters > 0 && splitTime.inSeconds > 0 && splitPaces.length < 6) {
      splitPaces.add(_paceFrom(splitTime, splitMeters));
    }

    final downsampled = _downsample(paceSamples, 24);
    if (downsampled.isNotEmpty) {
      _paceSeries = downsampled;
      _paceMin = downsampled.reduce(min);
      _paceMax = downsampled.reduce(max);
      if ((_paceMax - _paceMin).abs() < 0.05) {
        _paceMax += 0.1;
        _paceMin = (_paceMin - 0.1).clamp(0.1, _paceMax);
      }
    }

    if (splitPaces.isNotEmpty) {
      _splitPaces = splitPaces;
    }
  }

  double _paceFrom(Duration time, double meters) {
    if (meters <= 0) return 0;
    final minutes = time.inSeconds / 60.0;
    final km = meters / 1000.0;
    if (km <= 0) return 0;
    return minutes / km;
  }

  List<double> _downsample(List<double> values, int maxSamples) {
    if (values.length <= maxSamples) return values;
    final step = (values.length / maxSamples).ceil();
    final sampled = <double>[];
    for (int i = 0; i < values.length; i += step) {
      sampled.add(values[i]);
    }
    return sampled;
  }

  void _prepareReplayRoute() {
    final points = widget.routePoints;
    if (points == null || points.length < 2) {
      _replayRoute = [];
      _replayRoutePoints = [];
      return;
    }

    final sampled = _downsampleRoute(points, 100);
    _replayRoute = sampled;
    _replayRoutePoints = sampled.map(_mapboxPointFromLatLng).toList();
  }

  List<LatLng> _downsampleRoute(List<LatLng> points, int maxSamples) {
    if (points.length <= maxSamples) return List<LatLng>.from(points);
    final sampled = <LatLng>[];
    final lastIndex = points.length - 1;
    for (int i = 0; i < maxSamples; i++) {
      final t = i / (maxSamples - 1);
      final index = (t * lastIndex).round();
      sampled.add(points[index]);
    }
    return sampled;
  }

  mapbox.Point _mapboxPointFromLatLng(LatLng latLng) {
    return mapbox.Point(
      coordinates: mapbox.Position(latLng.longitude, latLng.latitude),
    );
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLon = (to.longitude - from.longitude) * pi / 180;
    final y = sin(dLon) * cos(lat2);
    final x =
        cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  Future<void> _setupReplayMap() async {
    if (_replayMapboxMap == null || _replayRoutePoints.length < 2) return;
    await _ensureReplayPolylineManager(reset: true);
    await _replayPolylineManager?.deleteAll();
    await _replayPolylineManager?.create(
      mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString.fromPoints(points: _replayRoutePoints),
        lineColor: const Color(0xFF0E9FA0).value,
        lineWidth: 4.0,
      ),
    );
    await _fitReplayBounds();
    _startReplayFlythrough();
  }

  Future<void> _ensureReplayPolylineManager({bool reset = false}) async {
    if (_replayMapboxMap == null) return;
    if (reset) {
      _replayPolylineManager = null;
    }
    _replayPolylineManager ??=
        await _replayMapboxMap!.annotations.createPolylineAnnotationManager();
  }

  Future<void> _fitReplayBounds() async {
    if (_replayMapboxMap == null || _replayRoute.isEmpty) return;
    double minLat = _replayRoute.first.latitude;
    double maxLat = _replayRoute.first.latitude;
    double minLng = _replayRoute.first.longitude;
    double maxLng = _replayRoute.first.longitude;

    for (final point in _replayRoute) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final latPadding = (maxLat - minLat) * 0.12;
    final lngPadding = (maxLng - minLng) * 0.12;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    final camera = await _replayMapboxMap!.cameraForCoordinateBounds(
      mapbox.CoordinateBounds(
        southwest: _mapboxPointFromLatLng(bounds.southwest),
        northeast: _mapboxPointFromLatLng(bounds.northeast),
        infiniteBounds: false,
      ),
      mapbox.MbxEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
      null,
      null,
      null,
      null,
    );

    final baseZoom = camera.zoom ?? 16.0;
    _replayZoom = baseZoom.clamp(14.8, 17.2).toDouble();
    await _replayMapboxMap!.easeTo(
      mapbox.CameraOptions(
        center: camera.center ?? _replayRoutePoints.first,
        zoom: _replayZoom,
        bearing: camera.bearing ?? 0,
        pitch: 60,
      ),
      mapbox.MapAnimationOptions(duration: 700),
    );
  }

  Future<void> _startReplayFlythrough() async {
    if (_replayMapboxMap == null || _replayRoute.length < 2) return;
    final session = ++_replaySession;
    const pitch = 60.0;
    final duration = Duration(milliseconds: 520);

    for (int i = 1; i < _replayRoute.length; i++) {
      if (!mounted || session != _replaySession) return;
      final prev = _replayRoute[i - 1];
      final current = _replayRoute[i];
      final bearing = _bearingBetween(prev, current);
      await _replayMapboxMap!.easeTo(
        mapbox.CameraOptions(
          center: _replayRoutePoints[i],
          zoom: _replayZoom,
          pitch: pitch,
          bearing: bearing,
        ),
        mapbox.MapAnimationOptions(duration: duration.inMilliseconds),
      );
    }

    if (!mounted || session != _replaySession) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted && session == _replaySession) {
      _startReplayFlythrough();
    }
  }

  String _formatPace(double pace) {
    if (pace <= 0 || pace.isInfinite || pace.isNaN) {
      return '--';
    }
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    final paddedSeconds = seconds.toString().padLeft(2, '0');
    return '$minutes:$paddedSeconds /km';
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
      final file = File(
          '${tempDir.path}/workout_summary_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      print('Image saved to: ${file.path}');
      print('File exists: ${await file.exists()}');

      // Share with subject
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Captured ${widget.territoriesCaptured} territories and ran ${widget.distanceKm.toStringAsFixed(2)} km on Plurihive.\n\n#Plurihive #Running #Fitness',
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
        text:
            'Captured ${widget.territoriesCaptured} territories and ran ${widget.distanceKm.toStringAsFixed(2)} km on Plurihive.\n\n#Plurihive #Running #Fitness',
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
    final hasVideo =
        widget.videoPath != null && File(widget.videoPath!).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6F0),
      body: Stack(
        children: [
          // Soft background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF2E7),
                  Color(0xFFEAF7FF),
                  Color(0xFFF6F1FF),
                ],
              ),
            ),
          ),
          // Decorative blobs
          Positioned(
            top: -120,
            left: -80,
            child: _buildGlowBlob(const Color(0xFFFFC6A8), 240),
          ),
          Positioned(
            bottom: -140,
            right: -90,
            child: _buildGlowBlob(const Color(0xFFB5E5FF), 260),
          ),
          Positioned(
            top: 140,
            right: -60,
            child: _buildGlowBlob(const Color(0xFFCBB7FF), 180),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF1C1C1C),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Workout Complete',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1C1C1C),
                              ),
                            ),
                            Text(
                              'Share your run in one tap',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B6B6B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 6),
                            _buildRecapSection(),
                            const SizedBox(height: 12),
                            _buildSectionHeader(
                              title: 'Share cards',
                              subtitle: 'Pick a style to share',
                            ),
                            const SizedBox(height: 8),
                            _buildStyleSelector(),
                            if (_selectedStyle == 3) ...[
                              const SizedBox(height: 10),
                              _buildCustomBackgroundControls(),
                            ],
                            const SizedBox(height: 12),
                            Center(
                              child: RepaintBoundary(
                                key: _summaryKey,
                                child: _buildSummaryCard(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: Column(
                    children: [
                      _buildGradientButton(
                        label: _isSharing ? 'Preparing...' : 'Share Workout',
                        icon: _isSharing
                            ? Icons.hourglass_top_rounded
                            : Icons.share_rounded,
                        isLoading: _isSharing,
                        onPressed: _isSharing ? null : _captureAndShare,
                        colors: const [
                          Color(0xFF4FC3F7),
                          Color(0xFF4DB6AC),
                        ],
                      ),
                      if (hasVideo) ...[
                        const SizedBox(height: 12),
                        _buildGradientButton(
                          label: _isSharing
                              ? 'Preparing...'
                              : 'Share Video (3x Speed)',
                          icon: _isSharing
                              ? Icons.hourglass_top_rounded
                              : Icons.movie_creation_rounded,
                          isLoading: _isSharing,
                          onPressed: _isSharing ? null : _shareVideo,
                          colors: const [
                            Color(0xFFFF8A65),
                            Color(0xFFFFB74D),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSharing
                                  ? null
                                  : () async {
                                      await Share.share(
                                        '''Captured ${widget.territoriesCaptured} territories and ran ${widget.distanceKm.toStringAsFixed(2)} km on Plurihive.

#Plurihive #Running #Fitness''',
                                        subject: 'My Plurihive Workout',
                                      );
                                    },
                              icon: const Icon(
                                Icons.text_fields_rounded,
                                size: 18,
                                color: Color(0xFF6B6B6B),
                              ),
                              label: Text(
                                'Text only',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B6B6B),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(
                                  color: Color(0xFF1C1C1C),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Done',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1C1C1C),
                                ),
                              ),
                            ),
                          ),
                        ],
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
    switch (_selectedStyle) {
      case 1:
        return _buildSummaryCardTicket();
      case 2:
        return _buildSummaryCardPlayful();
      case 3:
        return _buildSummaryCardCustom();
      default:
        return _buildSummaryCardClassic();
    }
  }

  Widget _buildStoryFrame({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _storyMaxWidth),
        child: AspectRatio(
          aspectRatio: _storyAspectRatio,
          child: child,
        ),
      ),
    );
  }

  Widget _buildSummaryCardClassic() {
    final dateLabel = DateFormat('EEE, MMM d').format(widget.workoutDate);
    final timeLabel = DateFormat('h:mm a').format(widget.workoutDate);

    return _buildStoryFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight = constraints.maxHeight * 0.44;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                children: [
                  SizedBox(
                    height: mapHeight,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: widget.routePoints != null &&
                                  widget.routePoints!.isNotEmpty
                              ? _buildCompactMap()
                              : _buildMapPlaceholder(),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.25),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.35),
                                ],
                                stops: const [0.0, 0.25, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _buildBadge('Plurihive Run'),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: _buildBadge(dateLabel, isLight: true),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.directions_run_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Route captured',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildHeroMetric(
                            value: widget.distanceKm.toStringAsFixed(2),
                            unit: 'km',
                            label: 'Distance',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildHeroMetric(
                            value: _formatDuration(widget.duration),
                            unit: '',
                            label: 'Time',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.6,
                      children: [
                        _buildMetricTile(
                          icon: Icons.map_rounded,
                          value: '${widget.territoriesCaptured}',
                          label: 'Zones',
                          color: const Color(0xFF4DB6AC),
                        ),
                        _buildMetricTile(
                          icon: Icons.star_rounded,
                          value: '${widget.pointsEarned}',
                          label: 'Points',
                          color: const Color(0xFFFFB74D),
                        ),
                        _buildMetricTile(
                          icon: Icons.speed_rounded,
                          value: widget.avgSpeed.toStringAsFixed(1),
                          label: 'Avg km/h',
                          color: const Color(0xFF64B5F6),
                        ),
                        _buildMetricTile(
                          icon: Icons.directions_walk_rounded,
                          value: '${widget.steps}',
                          label: 'Steps',
                          color: const Color(0xFFFF8A65),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Plurihive',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1C1C1C),
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStyleSelector() {
    final options = [
      {
        'label': 'Classic',
        'icon': Icons.layers_rounded,
        'colors': [const Color(0xFF4FC3F7), const Color(0xFFFFC6A8)],
      },
      {
        'label': 'Ticket',
        'icon': Icons.local_activity_rounded,
        'colors': [const Color(0xFFFFB74D), const Color(0xFF81C784)],
      },
      {
        'label': 'Playful',
        'icon': Icons.auto_awesome_rounded,
        'colors': [const Color(0xFFCBB7FF), const Color(0xFFFF8A65)],
      },
      {
        'label': _customBackgroundBytes != null ? 'Custom' : 'Add photo',
        'icon': Icons.photo_rounded,
        'colors': [const Color(0xFF0F172A), const Color(0xFF475569)],
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(options.length, (index) {
          final option = options[index];
          final isSelected = _selectedStyle == index;
          final colors = option['colors'] as List<Color>;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _selectedStyle = index;
                  });
                  if (index == 3 && _customBackgroundBytes == null) {
                    _pickCustomBackground();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1C1C1C)
                          : const Color(0xFFE0E0E0),
                      width: isSelected ? 1.4 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            option['icon'] as IconData,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        option['label'] as String,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _pickCustomBackground() async {
    if (_isPickingBackground) return;
    setState(() => _isPickingBackground = true);
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _customBackgroundBytes = bytes;
        _customBackgroundPath = file.path;
        _selectedStyle = 3;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingBackground = false);
      }
    }
  }

  void _clearCustomBackground() {
    setState(() {
      _customBackgroundBytes = null;
      _customBackgroundPath = null;
    });
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomBackgroundControls() {
    final hasImage =
        _customBackgroundPath != null || _customBackgroundBytes != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (hasImage) ...[
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _customBackgroundPath != null
                  ? Image.file(
                      File(_customBackgroundPath!),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : (_customBackgroundBytes != null
                      ? Image.memory(
                          _customBackgroundBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        )
                      : const SizedBox.shrink()),
            ),
          ],
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isPickingBackground ? null : _pickCustomBackground,
              icon: Icon(
                Icons.photo_library_rounded,
                size: 18,
                color: _isPickingBackground
                    ? const Color(0xFFB0B0B0)
                    : const Color(0xFF1C1C1C),
              ),
              label: Text(
                _isPickingBackground
                    ? 'Loading...'
                    : hasImage
                        ? 'Change photo'
                        : 'Choose photo',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isPickingBackground
                      ? const Color(0xFFB0B0B0)
                      : const Color(0xFF1C1C1C),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (hasImage) ...[
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _clearCustomBackground,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Color(0xFFE11D48),
              ),
              label: Text(
                'Remove',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE11D48),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecapSection() {
    const accent = Color(0xFF0E9FA0);
    final paceMinPerKm = widget.distanceKm > 0
        ? (widget.duration.inSeconds / 60.0) / widget.distanceKm
        : 0.0;
    final stepsPerKm = widget.distanceKm > 0
        ? (widget.steps / widget.distanceKm).round()
        : 0;
    final dateLabel = DateFormat('EEE, MMM d - h:mm a').format(widget.workoutDate);

    final inlineStats = [
      _InlineStat(
        label: 'Steps',
        value: widget.steps.toString(),
      ),
      _InlineStat(
        label: 'Steps/km',
        value: stepsPerKm.toString(),
      ),
      _InlineStat(
        label: 'Avg speed',
        value: '${widget.avgSpeed.toStringAsFixed(1)} km/h',
      ),
      _InlineStat(
        label: 'Territories',
        value: widget.territoriesCaptured.toString(),
      ),
      _InlineStat(
        label: 'Points',
        value: widget.pointsEarned.toString(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Run recap',
          subtitle: dateLabel,
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPrimaryMetric(
                      label: 'Distance',
                      unit: 'km',
                      value: widget.distanceKm,
                      formatter: (value) => value.toStringAsFixed(2),
                    ),
                  ),
                  _buildMetricDivider(),
                  Expanded(
                    child: _buildPrimaryMetric(
                      label: 'Time',
                      unit: '',
                      value: widget.duration.inSeconds.toDouble(),
                      formatter: (value) =>
                          _formatDuration(Duration(seconds: value.round())),
                    ),
                  ),
                  _buildMetricDivider(),
                  Expanded(
                    child: _buildPrimaryMetric(
                      label: 'Avg pace',
                      unit: '',
                      value: paceMinPerKm,
                      formatter: _formatPace,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 12),
              Column(
                children: List.generate(
                  (inlineStats.length / 2).ceil(),
                  (rowIndex) {
                    final start = rowIndex * 2;
                    final left = inlineStats[start];
                    final right = start + 1 < inlineStats.length
                        ? inlineStats[start + 1]
                        : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(child: _buildInlineStat(left, accent)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: right != null
                                ? _buildInlineStat(right, accent)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildInsightsSection(),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildReplaySection(),
        ),
      ],
    );
  }

  Widget _buildInsightsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInsightHeader(
            title: 'Pace trend',
            subtitle: _paceSeries.isNotEmpty
                ? 'Smoother pace = steadier run'
                : 'Need GPS samples to chart pace',
          ),
          const SizedBox(height: 10),
          _buildPaceChart(),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 14),
          _buildInsightHeader(
            title: 'Split pace',
            subtitle: _splitPaces.isNotEmpty
                ? 'Avg pace per km'
                : 'Splits will appear on longer runs',
          ),
          const SizedBox(height: 10),
          _buildSplitChart(),
        ],
      ),
    );
  }

  Widget _buildInsightHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildPaceChart() {
    if (_paceSeries.length < 2) {
      return _buildChartEmptyState('Not enough data points');
    }

    return SizedBox(
      height: 140,
      child: AnimatedBuilder(
        animation: _chartAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _PaceLinePainter(
              values: _paceSeries,
              minValue: _paceMin,
              maxValue: _paceMax,
              progress: _chartAnimation.value,
              lineColor: const Color(0xFF0E9FA0),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSplitChart() {
    if (_splitPaces.isEmpty) {
      return _buildChartEmptyState('No split data yet');
    }

    final speeds = _splitPaces
        .map((pace) => pace > 0 ? 60 / pace : 0)
        .toList();
    final maxSpeed = speeds.reduce(max).clamp(0.1, 100);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_splitPaces.length, (index) {
          final speed = speeds[index];
          final heightFactor = (speed / maxSpeed).clamp(0.1, 1.0);
          return Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: heightFactor),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 90 * value,
                      width: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E9FA0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${index + 1} km',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      _formatPace(_splitPaces[index]),
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChartEmptyState(String label) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildReplaySection() {
    final hasRoute = _replayRoutePoints.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInsightHeader(
          title: '3D route replay',
          subtitle: hasRoute
              ? 'Mapbox flythrough of your route'
              : 'Need route data for replay',
        ),
        const SizedBox(height: 10),
        hasRoute ? _buildReplayMap() : _buildReplayPlaceholder(),
      ],
    );
  }

  Widget _buildReplayMap() {
    final initialCenter = _replayRoutePoints.isNotEmpty
        ? _replayRoutePoints.first
        : mapbox.Point(coordinates: mapbox.Position(0, 0));
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 190,
        child: IgnorePointer(
          child: mapbox.MapWidget(
            cameraOptions: mapbox.CameraOptions(
              center: initialCenter,
              zoom: 15.5,
              pitch: 60,
            ),
            styleUri: mapbox.MapboxStyles.STANDARD,
            onMapCreated: (mapbox.MapboxMap controller) async {
              _replayMapboxMap = controller;
              await _setupReplayMap();
            },
            onStyleLoadedListener: (_) {
              _setupReplayMap();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReplayPlaceholder() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          'Replay will appear after a tracked run',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryMetric({
    required String label,
    required String unit,
    required double value,
    required String Function(double) formatter,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    formatter(animatedValue),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      unit,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildInlineStat(_InlineStat stat, Color accent) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                stat.label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCardTicket() {
    final dateLabel = DateFormat('EEE, MMM d').format(widget.workoutDate);
    final timeLabel = DateFormat('h:mm a').format(widget.workoutDate);

    return _buildStoryFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight = constraints.maxHeight * 0.36;
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF5),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFF0E1D1), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RUN TICKET',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: const Color(0xFF1C1C1C),
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: mapHeight,
                    width: double.infinity,
                    child: widget.routePoints != null &&
                            widget.routePoints!.isNotEmpty
                        ? _buildCompactMap()
                        : _buildMapPlaceholder(),
                  ),
                  const SizedBox(height: 10),
                  _buildPerforationRow(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildHeroMetric(
                            value: widget.distanceKm.toStringAsFixed(2),
                            unit: 'km',
                            label: 'Distance',
                          ),
                        ),
                        Expanded(
                          child: _buildHeroMetric(
                            value: _formatDuration(widget.duration),
                            unit: '',
                            label: 'Time',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildTicketPill(
                          icon: Icons.star_rounded,
                          label: '${widget.pointsEarned} pts',
                          color: const Color(0xFFFFB74D),
                        ),
                        _buildTicketPill(
                          icon: Icons.map_rounded,
                          label: '${widget.territoriesCaptured} zones',
                          color: const Color(0xFF81C784),
                        ),
                        _buildTicketPill(
                          icon: Icons.speed_rounded,
                          label: '${widget.avgSpeed.toStringAsFixed(1)} km/h',
                          color: const Color(0xFF64B5F6),
                        ),
                        _buildTicketPill(
                          icon: Icons.directions_walk_rounded,
                          label: '${widget.steps} steps',
                          color: const Color(0xFFFF8A65),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Plurihive',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1C1C1C),
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCardPlayful() {
    final dateLabel = DateFormat('MMM d').format(widget.workoutDate);

    return _buildStoryFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight = constraints.maxHeight * 0.34;
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFE7D6),
                  Color(0xFFDAD4FF),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Playful Run',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1C1C1C),
                          ),
                        ),
                        _buildBadge(dateLabel, isLight: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: mapHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white70, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: widget.routePoints != null &&
                                widget.routePoints!.isNotEmpty
                            ? _buildCompactMap()
                            : _buildMapPlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: _buildHeroMetric(
                              value: widget.distanceKm.toStringAsFixed(2),
                              unit: 'km',
                              label: 'Distance',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: _buildHeroMetric(
                              value: _formatDuration(widget.duration),
                              unit: '',
                              label: 'Time',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildFunChip(
                            Icons.star_rounded, '${widget.pointsEarned} pts'),
                        _buildFunChip(Icons.map_rounded,
                            '${widget.territoriesCaptured} zones'),
                        _buildFunChip(Icons.speed_rounded,
                            '${widget.avgSpeed.toStringAsFixed(1)} km/h'),
                        _buildFunChip(
                            Icons.directions_walk_rounded, '${widget.steps} steps'),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPerforationRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Color(0xFFFDF6F0),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dotCount = (constraints.maxWidth / 10).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(dotCount, (_) {
                    return Container(
                      width: 6,
                      height: 1.4,
                      color: const Color(0xFFE0D6C7),
                    );
                  }),
                );
              },
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Color(0xFFFDF6F0),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B6B6B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.35),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: size * 0.6,
            spreadRadius: size * 0.05,
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required List<Color> colors,
    bool isLoading = false,
  }) {
    final isDisabled = onPressed == null;
    final gradientColors = isDisabled
        ? [const Color(0xFFE0E0E0), const Color(0xFFBDBDBD)]
        : colors;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMetric({
    required String value,
    required String unit,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1C),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  unit,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B6B6B),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B6B6B),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B6B6B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, {bool isLight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(0.9) : Colors.black54,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isLight ? const Color(0xFF1C1C1C) : Colors.white,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.map_rounded,
                size: 28,
                color: Color(0xFF8FA3B8),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Map snapshot unavailable',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8FA3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMap() {
    // Show video player if video is available
    if (_useVideoPlayback &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    // Fallback to map animation
    if (widget.routePoints == null || widget.routePoints!.isEmpty) {
      return SizedBox.shrink();
    }

    final routePoints = _animatedRoutePoints.isNotEmpty
        ? _animatedRoutePoints
        : widget.routePoints!;
    final overlayTerritories =
        _routeProgress > 0.8 ? widget.territories : null;

    return RoutePreview(
      routePoints: routePoints,
      polygons: overlayTerritories,
      snapshotBytes: _snapshotBytes,
      lineColor: const Color(0xFFFF8A65),
      lineWidth: 4,
      showStartEnd: _animatedRoutePoints.isEmpty,
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/logo.png',
            width: 18,
            height: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            'PluriHive',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomBackgroundImage() {
    if (_customBackgroundPath != null) {
      return Image.file(
        File(_customBackgroundPath!),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildCustomBackgroundFallback(),
      );
    }
    if (_customBackgroundBytes != null) {
      return Image.memory(
        _customBackgroundBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildCustomBackgroundFallback(),
      );
    }
    return _buildCustomBackgroundFallback();
  }

  Widget _buildCustomBackgroundFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_rounded,
              color: Colors.white70,
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(
              'Add your background',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap choose photo below',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildRoutePatternPreview() {
    final hasRoute =
        widget.routePoints != null && widget.routePoints!.isNotEmpty;
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: hasRoute
            ? CustomPaint(
                painter: _RoutePatternPainter(
                  points: widget.routePoints!,
                  lineColor: const Color(0xFF0E9FA0),
                ),
              )
            : Center(
                child: Text(
                  'Route pattern unavailable',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCardCustom() {
    final dateLabel = DateFormat('EEE, MMM d').format(widget.workoutDate);
    final paceMinPerKm = widget.distanceKm > 0
        ? (widget.duration.inSeconds / 60.0) / widget.distanceKm
        : 0.0;
    final paceLabel = _formatPace(paceMinPerKm);
    final hasImage =
        _customBackgroundPath != null || _customBackgroundBytes != null;

    return _buildStoryFrame(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned.fill(
                child: hasImage
                    ? _buildCustomBackgroundImage()
                    : _buildCustomBackgroundFallback(),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.45),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    _buildLogoBadge(),
                    const Spacer(),
                    _buildBadge(dateLabel, isLight: true),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Run recap',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildOverlayStat(
                              label: 'Distance',
                              value:
                                  '${widget.distanceKm.toStringAsFixed(2)} km',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildOverlayStat(
                              label: 'Pace',
                              value: paceLabel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildOverlayStat(
                              label: 'Time',
                              value: _formatDuration(widget.duration),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Running pattern',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildRoutePatternPreview(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineStat {
  final String label;
  final String value;

  const _InlineStat({
    required this.label,
    required this.value,
  });
}

class _PaceLinePainter extends CustomPainter {
  final List<double> values;
  final double minValue;
  final double maxValue;
  final double progress;
  final Color lineColor;

  _PaceLinePainter({
    required this.values,
    required this.minValue,
    required this.maxValue,
    required this.progress,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final padding = 8.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    final gridPaint = Paint()
      ..color = lineColor.withOpacity(0.12)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = padding + (chartHeight / 4) * i;
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y),
          gridPaint);
    }

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final dx = padding + (chartWidth * (i / (values.length - 1)));
      final normalized =
          (values[i] - minValue) / (maxValue - minValue == 0 ? 1 : maxValue - minValue);
      final dy = padding + chartHeight * (1 - normalized);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final drawPath = Path();
    for (final metric in metrics) {
      drawPath.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(drawPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PaceLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.values != values ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor;
  }
}

class _RoutePatternPainter extends CustomPainter {
  final List<LatLng> points;
  final Color lineColor;

  _RoutePatternPainter({
    required this.points,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    double width = (maxLng - minLng).abs();
    double height = (maxLat - minLat).abs();
    if (width == 0) width = 0.000001;
    if (height == 0) height = 0.000001;

    const padding = 8.0;
    final drawWidth = size.width - padding * 2;
    final drawHeight = size.height - padding * 2;

    Offset mapPoint(LatLng point) {
      final x = ((point.longitude - minLng) / width) * drawWidth + padding;
      final y = ((maxLat - point.latitude) / height) * drawHeight + padding;
      return Offset(x, y);
    }

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final offset = mapPoint(points[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = lineColor;
    canvas.drawPath(path, linePaint);

    if (points.length >= 2) {
      final start = mapPoint(points.first);
      final end = mapPoint(points.last);
      final startPaint = Paint()..color = lineColor.withOpacity(0.9);
      final endPaint = Paint()..color = lineColor.withOpacity(0.9);
      canvas.drawCircle(start, 3.5, startPaint);
      canvas.drawCircle(end, 3.5, endPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePatternPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
