import 'package:flutter/material.dart';

import '../core/widgets/avatar_preview.dart';
import '../models/ranking_models.dart';
import '../services/ranking_service.dart';
import '../state/app_session.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.session,
    required this.username,
    super.key,
  });

  final AppSession session;
  final String username;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final RankingService _rankingService = RankingService();

  PublicUserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await widget.session.withAuthorizedRequest(
        (accessToken) => _rankingService.fetchUserProfile(
          username: widget.username,
          accessToken: accessToken,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Failed to load user profile.';
      });
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Unknown date';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year;
    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            : profile == null
            ? const Center(child: Text('No profile data.'))
            : RefreshIndicator(
                onRefresh: _loadProfile,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            AvatarPreview(
                              items: profile.equippedItems,
                              size: 92,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.username,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Rank #${profile.rank} • Lv ${profile.level}',
                                  ),
                                  Text('${profile.points} pts'),
                                  Text('Liked by ${profile.favoritesCount}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Visited attractions: ${profile.visitedTotal}',
                            ),
                            Text('Achievements: ${profile.achievementsTotal}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Achievements',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (profile.achievements.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No achievements yet.'),
                        ),
                      )
                    else
                      for (final earned in profile.achievements)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  earned.achievement.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(earned.achievement.description),
                                const SizedBox(height: 4),
                                Text(
                                  'Earned: ${_formatDate(earned.earnedAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
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
