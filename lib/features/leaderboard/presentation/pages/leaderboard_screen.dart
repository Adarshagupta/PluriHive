import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/leaderboard_api_service.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/theme/app_theme.dart';

enum LeaderboardScope { global, friends, nearby }

enum LeaderboardRange { allTime, weekly, monthly }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const String _cachePrefix = 'leaderboard_cache_v2';
  late final LeaderboardApiService _apiService;
  late final SharedPreferences _prefs;

  LeaderboardScope _scope = LeaderboardScope.global;
  LeaderboardRange _range = LeaderboardRange.allTime;

  List<LeaderboardUser> _users = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isRefreshing = false;
  bool _hasCachedLeaderboard = false;

  String _selectedMetric = 'points';

  String? _locationError;
  bool _locationDeniedForever = false;
  bool _isLocating = false;
  Position? _nearbyPosition;
  final double _nearbyRadiusKm = 5;

  @override
  void initState() {
    super.initState();
    _apiService = di.getIt<LeaderboardApiService>();
    _prefs = di.getIt<SharedPreferences>();
    _loadData();
  }

  bool get _useCache => _scope == LeaderboardScope.global;

  String _cacheKey() => '$_cachePrefix:${_scope.name}:${_range.name}';

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (_useCache && !forceRefresh) {
      await _loadLeaderboardFromCache();
    }
    await _refreshLeaderboardFromBackend();
  }

  Future<void> _loadLeaderboardFromCache() async {
    try {
      final cached = _prefs.getString(_cacheKey());
      if (cached == null) {
        if (mounted) {
          setState(() {
            _isLoading = true;
            _hasError = false;
          });
        }
        return;
      }
      final decoded = jsonDecode(cached) as List<dynamic>;
      final users = decoded
          .map((u) => LeaderboardUser.fromMap(Map<String, dynamic>.from(u)))
          .toList();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _hasError = false;
      });
      _hasCachedLeaderboard = true;
    } catch (e) {
      print('Error reading leaderboard cache: $e');
    }
  }

  Future<void> _refreshLeaderboardFromBackend() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final users = await _fetchLeaderboard();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _hasError = false;
      });
      if (_useCache) {
        await _prefs.setString(
          _cacheKey(),
          jsonEncode(users.map((u) => u.toMap()).toList()),
        );
        _hasCachedLeaderboard = true;
      }
    } catch (e) {
      if (mounted && !_hasCachedLeaderboard) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<List<LeaderboardUser>> _fetchLeaderboard() async {
    final limit = _limitForRange();
    switch (_scope) {
      case LeaderboardScope.friends:
        final data = await _apiService.getFriendsLeaderboard(limit: limit);
        return data.map((u) => LeaderboardUser.fromMap(u)).toList();
      case LeaderboardScope.nearby:
        final position = await _resolveNearbyPosition();
        if (position == null) {
          return [];
        }
        final data = await _apiService.getNearbyLeaderboard(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusKm: _nearbyRadiusKm,
          limit: limit,
        );
        return data.map((u) => LeaderboardUser.fromMap(u)).toList();
      case LeaderboardScope.global:
      default:
        if (_range == LeaderboardRange.weekly) {
          final data = await _apiService.getWeeklyLeaderboard(limit: limit);
          return data.map((u) => LeaderboardUser.fromMap(u)).toList();
        }
        if (_range == LeaderboardRange.monthly) {
          final data = await _apiService.getMonthlyLeaderboard(limit: limit);
          return data.map((u) => LeaderboardUser.fromMap(u)).toList();
        }
        final data = await _apiService.getGlobalLeaderboard(limit: limit);
        return data.map((u) => LeaderboardUser.fromMap(u)).toList();
    }
  }

  int _limitForRange() {
    switch (_range) {
      case LeaderboardRange.weekly:
        return 20;
      case LeaderboardRange.monthly:
        return 50;
      case LeaderboardRange.allTime:
      default:
        return 100;
    }
  }

  Future<Position?> _resolveNearbyPosition() async {
    if (_isLocating) return _nearbyPosition;
    setState(() {
      _isLocating = true;
      _locationError = null;
      _locationDeniedForever = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationError = 'Location services are turned off.';
            _isLocating = false;
          });
        }
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permission is needed for Nearby.';
            _isLocating = false;
          });
        }
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permission is permanently denied.';
            _locationDeniedForever = true;
            _isLocating = false;
          });
        }
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return position;
      setState(() {
        _nearbyPosition = position;
        _isLocating = false;
      });
      return position;
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Unable to fetch location right now.';
          _isLocating = false;
        });
      }
      return null;
    }
  }

  void _setScope(LeaderboardScope scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _users = [];
      _hasError = false;
      _isLoading = true;
      _locationError = null;
      _hasCachedLeaderboard = false;
    });
    _loadData(forceRefresh: true);
  }

  void _setRange(LeaderboardRange range) {
    if (_range == range) return;
    setState(() {
      _range = range;
      _users = [];
      _hasError = false;
      _isLoading = true;
      _hasCachedLeaderboard = false;
    });
    _loadData(forceRefresh: true);
  }

  List<LeaderboardUser> _getSortedUsers() {
    var users = List<LeaderboardUser>.from(_users);

    switch (_selectedMetric) {
      case 'distance':
        users.sort((a, b) => b.totalDistanceKm.compareTo(a.totalDistanceKm));
        break;
      case 'territories':
        users.sort((a, b) =>
            b.totalTerritoriesCaptured.compareTo(a.totalTerritoriesCaptured));
        break;
      case 'steps':
        users.sort((a, b) => b.totalSteps.compareTo(a.totalSteps));
        break;
      default:
        users.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    }

    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildFilterSummaryBar(),
            const SizedBox(height: 8),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leaderboard',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitleText(),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _loadData(forceRefresh: true),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3FAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD6EEEE)),
              ),
              child: Icon(Icons.refresh, color: AppTheme.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSummaryBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _openFiltersSheet,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6FBFB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD6EEEE)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F7F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD6EEEE)),
                ),
                child: Icon(Icons.tune, color: AppTheme.accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_scopeLabel()} • ${_rangeLabel()} • ${_metricLabel()}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleText() {
    switch (_scope) {
      case LeaderboardScope.friends:
        return 'Your crew ranked by ${_metricLabel().toLowerCase()}';
      case LeaderboardScope.nearby:
        return 'Within ${_nearbyRadiusKm.toStringAsFixed(0)} km - ${_metricLabel().toLowerCase()}';
      case LeaderboardScope.global:
      default:
        return '${_rangeLabel()} leaders by ${_metricLabel().toLowerCase()}';
    }
  }

  String _scopeLabel() {
    switch (_scope) {
      case LeaderboardScope.friends:
        return 'Friends';
      case LeaderboardScope.nearby:
        return 'Nearby';
      case LeaderboardScope.global:
      default:
        return 'Global';
    }
  }

  String _metricLabel() {
    final label = _getMetricLabel();
    if (label.isEmpty) return 'Points';
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  String _rangeLabel() {
    switch (_range) {
      case LeaderboardRange.weekly:
        return 'Weekly';
      case LeaderboardRange.monthly:
        return 'Monthly';
      case LeaderboardRange.allTime:
      default:
        return 'All time';
    }
  }

  Widget _buildScopeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FBFB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD6EEEE)),
        ),
        child: Row(
          children: [
            _buildScopeChip(
              LeaderboardScope.global,
              'Global',
              Icons.public,
            ),
            const SizedBox(width: 6),
            _buildScopeChip(
              LeaderboardScope.friends,
              'Friends',
              Icons.group,
            ),
            const SizedBox(width: 6),
            _buildScopeChip(
              LeaderboardScope.nearby,
              'Nearby',
              Icons.place,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChip(
    LeaderboardScope scope,
    String label,
    IconData icon,
  ) {
    final isSelected = _scope == scope;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setScope(scope),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentColor
                  : const Color(0xFFDDEAEA),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildRangeChip(LeaderboardRange.allTime, 'All time'),
          const SizedBox(width: 8),
          _buildRangeChip(LeaderboardRange.weekly, 'Weekly'),
          const SizedBox(width: 8),
          _buildRangeChip(LeaderboardRange.monthly, 'Monthly'),
        ],
      ),
    );
  }

  Widget _buildRangeChip(LeaderboardRange range, String label) {
    final isSelected = _range == range;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setRange(range),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentColor
                : const Color(0xFFF4FBFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentColor
                  : const Color(0xFFDDEAEA),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FBFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD6EEEE)),
        ),
        child: Row(
          children: [
            _buildMetricChip('points', 'Points', Icons.stars),
            const SizedBox(width: 8),
            _buildMetricChip('distance', 'Distance', Icons.alt_route),
            const SizedBox(width: 8),
            _buildMetricChip('territories', 'Areas', Icons.layers),
            const SizedBox(width: 8),
            _buildMetricChip('steps', 'Steps', Icons.directions_walk),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String metric, String label, IconData icon) {
    final isSelected = _selectedMetric == metric;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mounted) {
            setState(() => _selectedMetric = metric);
            HapticFeedback.lightImpact();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentColor
                  : const Color(0xFFDDEAEA),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFiltersSheet() {
    final media = MediaQuery.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + media.viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDDEAEA)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6EEEE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scope',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildScopeSelector(),
                    const SizedBox(height: 16),
                    Text(
                      'Range',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRangeSelector(),
                    const SizedBox(height: 16),
                    Text(
                      'Metric',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMetricSelector(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLeaderboardSkeleton();
    }

    if (_scope == LeaderboardScope.nearby && _locationError != null) {
      return _buildLocationPrompt();
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load leaderboard',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadData(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final users = _getSortedUsers();
    final showTopThree = users.length >= 3;
    final rest = showTopThree ? users.sublist(3) : users;

    if (users.isEmpty) {
      return Center(
        child: Text(
          _scope == LeaderboardScope.friends
              ? 'Add friends to see this board.'
              : 'No users found',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: showTopThree ? _buildTopThree(users) : const SizedBox.shrink(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverList.separated(
              itemCount: rest.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rankOffset = showTopThree ? 4 : 1;
                return _buildUserCard(rest[index], index + rankOffset);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FEFE),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDEAEA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place, size: 36, color: AppTheme.textPrimary),
              const SizedBox(height: 12),
              Text(
                _locationError ?? 'Location required',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enable location to see nearby challengers.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLocating
                      ? null
                      : () async {
                          if (_locationDeniedForever) {
                            await Geolocator.openAppSettings();
                            return;
                          }
                          await _loadData(forceRefresh: true);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _locationDeniedForever ? 'Open Settings' : 'Enable Location',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopThree(List<LeaderboardUser> users) {
    if (users.length < 3) return const SizedBox.shrink();
    final topThree = users.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FEFE),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDDEAEA)),
        ),
        child: Row(
          children: [
            Expanded(child: _buildPodiumCard(topThree[1], 2)),
            const SizedBox(width: 12),
            Expanded(child: _buildPodiumCard(topThree[0], 1, isCenter: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildPodiumCard(topThree[2], 3)),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumCard(LeaderboardUser user, int rank,
      {bool isCenter = false}) {
    final accent = _getRankColor(rank);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(isCenter ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Container(
            width: isCenter ? 42 : 36,
            height: isCenter ? 42 : 36,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getRankEmoji(rank),
                style: TextStyle(fontSize: isCenter ? 18 : 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getMetricValue(user),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            _getMetricLabel(),
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(LeaderboardUser user, int rank) {
    final isTopThree = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FEFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTopThree
              ? _getRankColor(rank).withOpacity(0.6)
              : const Color(0xFFDDEAEA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isTopThree
                  ? _getRankColor(rank)
                  : const Color(0xFFEFF8F8),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isTopThree
                  ? Text(
                      _getRankEmoji(rank),
                      style: const TextStyle(fontSize: 16),
                    )
                  : Text(
                      '$rank',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level ${user.level} - ${user.totalTerritoriesCaptured} territories',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _getMetricValue(user),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _getMetricLabel(),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMetricValue(LeaderboardUser user) {
    switch (_selectedMetric) {
      case 'distance':
        return '${user.totalDistanceKm.toStringAsFixed(1)} km';
      case 'territories':
        return '${user.totalTerritoriesCaptured}';
      case 'steps':
        return _formatNumber(user.totalSteps);
      default:
        return '${user.totalPoints}';
    }
  }

  String _getMetricLabel() {
    switch (_selectedMetric) {
      case 'distance':
        return 'distance';
      case 'territories':
        return 'territories';
      case 'steps':
        return 'steps';
      default:
        return 'points';
    }
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return '$num';
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFBBF24);
      case 2:
        return const Color(0xFFBFD9FF);
      case 3:
        return const Color(0xFF7EDBD5);
      default:
        return const Color(0xFFEFF8F8);
    }
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '1';
      case 2:
        return '2';
      case 3:
        return '3';
      default:
        return '';
    }
  }

  Widget _buildLeaderboardSkeleton() {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => SkeletonBox(
          height: 78,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class LeaderboardUser {
  final String id;
  final String name;
  final String email;
  final int totalPoints;
  final int level;
  final double totalDistanceKm;
  final int totalSteps;
  final int totalTerritoriesCaptured;
  final int totalWorkouts;

  LeaderboardUser({
    required this.id,
    required this.name,
    required this.email,
    required this.totalPoints,
    required this.level,
    required this.totalDistanceKm,
    required this.totalSteps,
    required this.totalTerritoriesCaptured,
    required this.totalWorkouts,
  });

  factory LeaderboardUser.fromMap(Map<String, dynamic> map) {
    return LeaderboardUser(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown',
      email: map['email'] ?? '',
      totalPoints: (map['totalPoints'] ?? 0) as int,
      level: (map['level'] ?? 1) as int,
      totalDistanceKm: ((map['totalDistanceKm'] ?? 0) as num).toDouble(),
      totalSteps: (map['totalSteps'] ?? 0) as int,
      totalTerritoriesCaptured: (map['totalTerritoriesCaptured'] ?? 0) as int,
      totalWorkouts: (map['totalWorkouts'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'totalPoints': totalPoints,
      'level': level,
      'totalDistanceKm': totalDistanceKm,
      'totalSteps': totalSteps,
      'totalTerritoriesCaptured': totalTerritoriesCaptured,
      'totalWorkouts': totalWorkouts,
    };
  }
}
