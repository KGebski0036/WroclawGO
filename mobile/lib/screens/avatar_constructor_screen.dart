import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/widgets/network_item_image.dart';
import '../core/widgets/avatar_preview.dart';
import '../models/avatar_models.dart';
import '../services/avatar_service.dart';
import '../state/app_session.dart';

class AvatarConstructorScreen extends StatefulWidget {
  const AvatarConstructorScreen({required this.session, super.key});

  final AppSession session;

  @override
  State<AvatarConstructorScreen> createState() =>
      _AvatarConstructorScreenState();
}

class _AvatarConstructorScreenState extends State<AvatarConstructorScreen> {
  final AvatarService _avatarService = AvatarService();

  bool _loading = true;
  String? _errorMessage;
  String? _successMessage;
  int? _equippingItemId;
  String? _removingSlot;

  List<AvatarItem> _unlockedItems = const <AvatarItem>[];
  List<UserEquippedAvatarItem> _equippedItems =
      const <UserEquippedAvatarItem>[];

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
        final unlocked = await _avatarService.fetchUnlockedItems(accessToken);
        final equipped = await _avatarService.fetchEquippedItems(accessToken);
        return _ConstructorData(
          unlockedItems: unlocked,
          equippedItems: equipped,
        );
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _unlockedItems = data.unlockedItems;
        _equippedItems = data.equippedItems;
        _loading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load avatar constructor.';
      });
    }
  }

  bool _isEquipped(AvatarItem item) {
    return _equippedItems.any((equipped) => equipped.item.id == item.id);
  }

  String? _equippedItemNameForSlot(String slot) {
    for (final equipped in _equippedItems) {
      if (equipped.slot == slot) {
        return equipped.item.name;
      }
    }
    return null;
  }

  Future<void> _equipItem(AvatarItem item) async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _equippingItemId = item.id;
    });

    try {
      await widget.session.withAuthorizedRequest(
        (accessToken) => _avatarService.equipItem(item.id, accessToken),
      );
      await _loadData(showLoading: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = '${item.name} equipped.';
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
          _equippingItemId = null;
        });
      }
    }
  }

  Future<void> _removeSlot(String slot) async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _removingSlot = slot;
    });

    try {
      await widget.session.withAuthorizedRequest(
        (accessToken) => _avatarService.unequipSlot(slot, accessToken),
      );
      await _loadData(showLoading: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = '${_avatarService.slotLabel(slot)} removed.';
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
          _removingSlot = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _avatarService.groupItemsByTag(_unlockedItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatar Constructor'),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current look',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            AvatarPreview(
                              items: _avatarService.sortEquippedItems(
                                _equippedItems,
                              ),
                              size: 140,
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
                    for (final slot in AvatarService.slotOrder)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _avatarService.slotLabel(slot),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        'Equipped: ${_equippedItemNameForSlot(slot) ?? 'none'}',
                                      ),
                                    ],
                                  ),
                                ),
                                if (_avatarService.canUnequipSlot(slot))
                                  OutlinedButton(
                                    onPressed: _removingSlot == slot
                                        ? null
                                        : () => _removeSlot(slot),
                                    child: Text(
                                      _removingSlot == slot
                                          ? 'Removing...'
                                          : 'Remove item',
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if ((grouped[slot] ?? const <AvatarItem>[]).isEmpty)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'No owned items in this section yet.',
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                itemCount: grouped[slot]!.length,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 0.72,
                                    ),
                                itemBuilder: (context, index) {
                                  final item = grouped[slot]![index];
                                  final equipped = _isEquipped(item);
                                  final isEquipping =
                                      _equippingItemId == item.id;

                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: NetworkItemImage(
                                              url: AppConfig.staticUrlForPath(
                                                item.svgPath,
                                              ),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(equipped ? 'Equipped' : 'Equip'),
                                          const SizedBox(height: 6),
                                          FilledButton(
                                            onPressed: isEquipping
                                                ? null
                                                : () => _equipItem(item),
                                            child: isEquipping
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Text(
                                                    equipped
                                                        ? 'Equipped'
                                                        : 'Equip',
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
}

class _ConstructorData {
  _ConstructorData({required this.unlockedItems, required this.equippedItems});

  final List<AvatarItem> unlockedItems;
  final List<UserEquippedAvatarItem> equippedItems;
}
