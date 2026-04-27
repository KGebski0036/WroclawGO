import 'dart:async';

import 'package:flutter/material.dart';

import '../core/widgets/avatar_preview.dart';
import '../models/ranking_models.dart';
import 'user_profile_screen.dart';
import '../services/ranking_service.dart';
import '../state/app_session.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({required this.session, super.key});

  final AppSession session;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  static const int _pageSize = 20;

  final RankingService _rankingService = RankingService();
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _pendingLikes = <int>{};

  Timer? _searchDebounce;
  Timer? _pollTimer;

  List<LeaderboardUser> _users = const <LeaderboardUser>[];
  bool _loading = true;
  String? _error;
  bool _likedOnly = false;
  int _currentPage = 1;
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchLeaderboard(showLoading: true));
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_fetchLeaderboard());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalPages {
    final pages = (_totalUsers / _pageSize).ceil();
    return pages < 1 ? 1 : pages;
  }

  bool get _canGoPrev => _currentPage > 1;
  bool get _canGoNext => _currentPage < _totalPages;

  bool _isSelf(LeaderboardUser user) {
    final currentUsername = widget.session.user?.username ?? '';
    if (currentUsername.isEmpty) {
      return false;
    }
    return user.username.toLowerCase() == currentUsername.toLowerCase();
  }

  Future<void> _fetchLeaderboard({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final response = await widget.session.withAuthorizedRequest(
        (accessToken) => _rankingService.fetchLeaderboard(
          accessToken: accessToken,
          page: _currentPage,
          pageSize: _pageSize,
          search: _searchController.text,
          likedOnly: _likedOnly,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _users = response.results;
        _totalUsers = response.count;
        _loading = false;
        _error = null;
      });

      if (_currentPage > _totalPages) {
        setState(() {
          _currentPage = _totalPages;
        });
        unawaited(_fetchLeaderboard(showLoading: true));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Failed to load leaderboard.';
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPage = 1;
      });
      unawaited(_fetchLeaderboard(showLoading: true));
    });
  }

  Future<void> _toggleFavorite(LeaderboardUser user) async {
    if (_isSelf(user) || _pendingLikes.contains(user.id)) {
      return;
    }

    setState(() {
      _pendingLikes.add(user.id);
      _error = null;
    });

    try {
      final response = await widget.session.withAuthorizedRequest(
        (accessToken) => _rankingService.toggleFavorite(
          username: user.username,
          accessToken: accessToken,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        user.isLiked = response.isLiked;
        user.favoritesCount = response.favoritesCount;
      });

      if (_likedOnly && !response.isLiked) {
        await _fetchLeaderboard(showLoading: true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not update favorites right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _pendingLikes.remove(user.id);
        });
      }
    }
  }

  void _openUserProfile(LeaderboardUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            UserProfileScreen(session: widget.session, username: user.username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Ranking'),
        actions: [
          IconButton(
            onPressed: () => widget.session.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'Search username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('View:'),
                      const SizedBox(width: 8),
                      DropdownButton<bool>(
                        value: _likedOnly,
                        items: const [
                          DropdownMenuItem<bool>(
                            value: false,
                            child: Text('All Users'),
                          ),
                          DropdownMenuItem<bool>(
                            value: true,
                            child: Text('Liked Users'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _likedOnly = value;
                            _currentPage = 1;
                          });
                          unawaited(_fetchLeaderboard(showLoading: true));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (!_loading)
              Expanded(
                child: _users.isEmpty
                    ? Center(
                        child: Text(
                          _likedOnly
                              ? 'No liked users matched your search.'
                              : 'No users matched your search.',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchLeaderboard(showLoading: false),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                onTap: () => _openUserProfile(user),
                                leading: Text(
                                  '#${user.rank}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                title: Row(
                                  children: [
                                    AvatarPreview(
                                      items: user.equippedItems,
                                      size: 44,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(user.username),
                                          Text(
                                            '${user.points} pts • Lv ${user.level}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          Text(
                                            'Liked by ${user.favoritesCount}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: _isSelf(user)
                                    ? const SizedBox(width: 24)
                                    : IconButton(
                                        onPressed:
                                            _pendingLikes.contains(user.id)
                                            ? null
                                            : () => _toggleFavorite(user),
                                        tooltip: user.isLiked
                                            ? 'Unlike user'
                                            : 'Like user',
                                        icon: Text(
                                          user.isLiked ? '♥' : '♡',
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            if (!_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: _canGoPrev
                          ? () {
                              setState(() {
                                _currentPage -= 1;
                              });
                              unawaited(_fetchLeaderboard(showLoading: true));
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    Text('Page $_currentPage / $_totalPages'),
                    OutlinedButton(
                      onPressed: _canGoNext
                          ? () {
                              setState(() {
                                _currentPage += 1;
                              });
                              unawaited(_fetchLeaderboard(showLoading: true));
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
