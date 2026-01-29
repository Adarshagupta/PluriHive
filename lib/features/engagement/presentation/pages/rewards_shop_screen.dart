import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/rewards_shop_service.dart';
import '../../../game/presentation/bloc/game_bloc.dart';

class RewardsShopScreen extends StatefulWidget {
  const RewardsShopScreen({
    super.key,
    required this.shopService,
  });

  final RewardsShopService shopService;

  @override
  State<RewardsShopScreen> createState() => _RewardsShopScreenState();
}

class _RewardsShopScreenState extends State<RewardsShopScreen> {
  RewardType _selectedType = RewardType.marker;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Rewards Shop',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: BlocBuilder<GameBloc, GameState>(
        builder: (context, state) {
          final points = state is GameLoaded ? state.stats.totalPoints : 0;
          final availablePoints = widget.shopService.availablePoints(points);
          return Column(
            children: [
              _buildPointsBanner(availablePoints, points),
              const SizedBox(height: 12),
              _buildTypeToggle(),
              const SizedBox(height: 12),
              Expanded(
                child: _buildItemsList(availablePoints, points),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPointsBanner(int availablePoints, int totalPoints) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.stars,
              color: Color(0xFF16A34A),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Points',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  availablePoints.toString(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total $totalPoints • Spent ${widget.shopService.spentPoints}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _selectedType == RewardType.marker ? 'Markers' : 'Badges',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTypeChip(RewardType.marker, 'Markers', Icons.blur_circular),
          const SizedBox(width: 10),
          _buildTypeChip(RewardType.badge, 'Badges', Icons.emoji_events),
        ],
      ),
    );
  }

  Widget _buildTypeChip(RewardType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsList(int availablePoints, int totalPoints) {
    final items = _selectedType == RewardType.marker
        ? widget.shopService.markerItems
        : widget.shopService.badgeItems;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = items[index];
        final unlocked = widget.shopService.isUnlocked(item.id);
        final selected = (_selectedType == RewardType.marker &&
                widget.shopService.selectedMarkerId == item.id) ||
            (_selectedType == RewardType.badge &&
                widget.shopService.selectedBadgeId == item.id);
        final canUnlock = availablePoints >= item.cost;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: selected ? item.color : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: item.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                item: item,
                unlocked: unlocked,
                selected: selected,
                canUnlock: canUnlock,
                points: totalPoints,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required RewardItem item,
    required bool unlocked,
    required bool selected,
    required bool canUnlock,
    required int points,
  }) {
    if (selected) {
      return _pill('Selected', const Color(0xFF16A34A));
    }

    if (unlocked) {
      return ElevatedButton(
        onPressed: () async {
          if (_selectedType == RewardType.marker) {
            await widget.shopService.selectMarker(item.id);
          } else {
            await widget.shopService.selectBadge(item.id);
          }
          setState(() {});
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        child: const Text('Use'),
      );
    }

    return ElevatedButton(
      onPressed: canUnlock
          ? () async {
              final unlockedNow =
                  await widget.shopService.unlock(item, points);
              if (unlockedNow) {
                if (_selectedType == RewardType.marker) {
                  await widget.shopService.selectMarker(item.id);
                } else {
                  await widget.shopService.selectBadge(item.id);
                }
                setState(() {});
              }
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: canUnlock ? item.color : const Color(0xFFE2E8F0),
        foregroundColor: canUnlock ? Colors.white : const Color(0xFF94A3B8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
      ),
      child: Text('${item.cost} pts'),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
