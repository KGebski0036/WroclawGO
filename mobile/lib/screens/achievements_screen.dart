import 'dart:async';

import 'package:flutter/material.dart';

import '../models/achievement_models.dart';
import '../services/achievement_service.dart';
import '../state/app_session.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({required this.session, super.key});

  final AppSession session;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementService _achievementService = AchievementService();

  List<Achievement> _allAchievements = const <Achievement>[];
  final Set<int> _earnedIds = <int>{};
  final Map<int, UserAchievement> _earnedById = <int, UserAchievement>{};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.session.withAuthorizedRequest((
        accessToken,
      ) async {
        final all = await _achievementService.fetchAllAchievements(accessToken);
        final earned = await _achievementService.fetchEarnedAchievements(
          accessToken,
        );
        return _AchievementData(all: all, earned: earned);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _allAchievements = data.all;
        _earnedIds
          ..clear()
          ..addAll(data.earned.map((ua) => ua.achievement.id));
        _earnedById
          ..clear()
          ..addEntries(
            data.earned.map(
              (ua) => MapEntry<int, UserAchievement>(ua.achievement.id, ua),
            ),
          );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Failed to load achievements.';
      });
    }
  }

  bool _isEarned(int id) => _earnedIds.contains(id);

  String? _earnedDateLabel(int id) {
    final earnedAt = _earnedById[id]?.earnedAt;
    if (earnedAt == null) {
      return null;
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day = earnedAt.day.toString().padLeft(2, '0');
    final month = months[earnedAt.month - 1];
    final year = earnedAt.year;
    return '$day $month $year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            onPressed: () => widget.session.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _allAchievements.length,
                  itemBuilder: (context, index) {
                    final achievement = _allAchievements[index];
                    final earned = _isEarned(achievement.id);
                    final earnedDate = _earnedDateLabel(achievement.id);

                    return Card(
                      color: earned ? Colors.amber.shade50 : null,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  earned ? '★' : '🔒',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                Text('+${achievement.pointsReward} pts'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              achievement.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              achievement.description,
                              style: TextStyle(
                                color: earned
                                    ? Colors.black87
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              earned ? 'Earned $earnedDate' : 'Locked',
                              style: TextStyle(
                                color: earned
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _AchievementData {
  _AchievementData({required this.all, required this.earned});

  final List<Achievement> all;
  final List<UserAchievement> earned;
}
