import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/widgets/network_item_image.dart';
import '../models/avatar_models.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../state/app_session.dart';

class AvatarShopScreen extends StatefulWidget {
  const AvatarShopScreen({required this.session, super.key});

  final AppSession session;

  @override
  State<AvatarShopScreen> createState() => _AvatarShopScreenState();
}

class _AvatarShopScreenState extends State<AvatarShopScreen> {
  final AvatarService _avatarService = AvatarService();
  final AuthService _authService = AuthService();

  bool _loading = true;
  String? _errorMessage;
  String? _successMessage;
  int? _purchasingItemId;

  List<AvatarItem> _allItems = const <AvatarItem>[];
  Set<int> _ownedIds = <int>{};
  int _points = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData(showLoading: true));
  }

  Future<void> _loadData({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final data = await widget.session.withAuthorizedRequest((
        accessToken,
      ) async {
        final allItems = await _avatarService.fetchAllItems(accessToken);
        final unlocked = await _avatarService.fetchUnlockedItems(accessToken);
        final currentUser = await _authService.fetchCurrentUser(accessToken);

        return _ShopData(
          allItems: allItems,
          ownedIds: unlocked.map((item) => item.id).toSet(),
          points: currentUser.points,
        );
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _allItems = data.allItems;
        _ownedIds = data.ownedIds;
        _points = data.points;
        _loading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load avatar shop.';
      });
    }
  }

  Future<void> _buyItem(AvatarItem item) async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _purchasingItemId = item.id;
    });

    try {
      await widget.session.withAuthorizedRequest(
        (accessToken) => _avatarService.purchaseItem(item.id, accessToken),
      );

      await widget.session.reloadCurrentUser();
      await _loadData(showLoading: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = '${item.name} has been added to your constructor.';
      });
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _purchasingItemId = null;
        });
      }
    }
  }

  bool _isOwned(int itemId) => _ownedIds.contains(itemId);

  bool _canBuy(AvatarItem item) {
    return !_isOwned(item.id) && _points >= item.cost;
  }

  String _buttonLabel(AvatarItem item) {
    if (_isOwned(item.id)) {
      return 'Owned';
    }
    if (_points < item.cost) {
      return 'Not enough points';
    }
    return 'Buy';
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _avatarService.groupItemsByTag(_allItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatar Shop'),
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
            : RefreshIndicator(
                onRefresh: () => _loadData(showLoading: false),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Available points'),
                            Text(
                              '$_points',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_errorMessage == null) const SizedBox(height: 6),
                    for (final slot in AvatarService.slotOrder)
                      _ShopSection(
                        title: _avatarService.slotLabel(slot),
                        items: grouped[slot] ?? const <AvatarItem>[],
                        isOwned: _isOwned,
                        canBuy: _canBuy,
                        buyingItemId: _purchasingItemId,
                        buttonLabel: _buttonLabel,
                        onBuy: _buyItem,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ShopSection extends StatelessWidget {
  const _ShopSection({
    required this.title,
    required this.items,
    required this.isOwned,
    required this.canBuy,
    required this.buyingItemId,
    required this.buttonLabel,
    required this.onBuy,
  });

  final String title;
  final List<AvatarItem> items;
  final bool Function(int itemId) isOwned;
  final bool Function(AvatarItem item) canBuy;
  final int? buyingItemId;
  final String Function(AvatarItem item) buttonLabel;
  final Future<void> Function(AvatarItem item) onBuy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text('${items.length} item(s)'),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('No items in this category.'),
              ),
            )
          else
            GridView.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final buying = buyingItemId == item.id;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: NetworkItemImage(
                            url: AppConfig.staticUrlForPath(item.svgPath),
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text('${item.cost} pts'),
                        if (item.isDefault)
                          Text(
                            'Default',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else if (isOwned(item.id))
                          Text(
                            'Owned',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 6),
                        FilledButton(
                          onPressed: buying || !canBuy(item)
                              ? null
                              : () => onBuy(item),
                          child: buying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(buttonLabel(item)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ShopData {
  _ShopData({
    required this.allItems,
    required this.ownedIds,
    required this.points,
  });

  final List<AvatarItem> allItems;
  final Set<int> ownedIds;
  final int points;
}
