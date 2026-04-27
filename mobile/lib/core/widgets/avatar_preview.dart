import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../models/avatar_models.dart';
import '../../services/avatar_service.dart';
import 'network_item_image.dart';

class AvatarPreview extends StatelessWidget {
  const AvatarPreview({
    required this.items,
    this.size = 56,
    this.borderColor,
    super.key,
  });

  final List<UserEquippedAvatarItem> items;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final avatarService = AvatarService();
    final sorted = avatarService.sortEquippedItems(items);

    if (sorted.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor ?? Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.person_outline, color: Colors.grey.shade500),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final equipped in sorted)
              NetworkItemImage(
                url: AppConfig.staticUrlForPath(equipped.item.svgPath),
                fit: BoxFit.cover,
                loadingSize: 12,
                fallback: Container(color: Colors.transparent),
              ),
          ],
        ),
      ),
    );
  }
}
