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
import 'package:google_fonts/google_fonts.dart';

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
  int _selectedStyle = 0;

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
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
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
                            _buildStyleSelector(),
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
      default:
        return _buildSummaryCardClassic();
    }
  }

  Widget _buildSummaryCardClassic() {
    final dateLabel = DateFormat('EEE, MMM d').format(widget.workoutDate);
    final timeLabel = DateFormat('h:mm a').format(widget.workoutDate);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 260,
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
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

  Widget _buildSummaryCardTicket() {
    final dateLabel = DateFormat('EEE, MMM d').format(widget.workoutDate);
    final timeLabel = DateFormat('h:mm a').format(widget.workoutDate);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            mainAxisSize: MainAxisSize.min,
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
                height: 210,
                width: double.infinity,
                child:
                    widget.routePoints != null && widget.routePoints!.isNotEmpty
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
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
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
      ),
    );
  }

  Widget _buildSummaryCardPlayful() {
    final dateLabel = DateFormat('MMM d').format(widget.workoutDate);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              mainAxisSize: MainAxisSize.min,
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
                  height: 180,
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
              ],
            ),
          ),
        ),
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
            color: Color(0xFFFF8A65),
            width: 4,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      },
      markers: _animatedRoutePoints.isNotEmpty
          ? {
              Marker(
                markerId: MarkerId('current_position'),
                position: _animatedRoutePoints.last,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange),
              ),
            }
          : {},
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
