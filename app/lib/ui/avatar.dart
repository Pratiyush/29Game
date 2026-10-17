import 'package:flutter/material.dart';

import '../net/emotes.dart';
import 'theme.dart';

String avatarAsset(int index) => 'assets/avatars/a${index.toString().padLeft(2, '0')}.png';

/// A round portrait in a ring: gold when it is this player's turn, team colour otherwise.
/// Falls back to the first letter of the name when there is no portrait.
class AvatarPortrait extends StatelessWidget {
  const AvatarPortrait({
    super.key,
    required this.avatar,
    required this.name,
    required this.size,
    this.ring = C.gold,
    this.ringWidth = 2.5,
    this.dimmed = false,
  });

  final int avatar;
  final String name;
  final double size;
  final Color ring;
  final double ringWidth;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final valid = avatar >= 0 && avatar < avatarCount;
    final fallback = Container(
      color: C.ink,
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(color: ring, fontWeight: FontWeight.w700, fontSize: size * 0.4),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(ring, Colors.white, 0.35)!, ring, Color.lerp(ring, Colors.black, 0.35)!],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: ClipOval(
        child: ColorFiltered(
          colorFilter: dimmed
              ? const ColorFilter.mode(Color(0x99000000), BlendMode.darken)
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: valid
              ? Image.asset(
                  avatarAsset(avatar),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stack) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}

/// Grid of portraits to choose from; returns the chosen index.
Future<int?> pickAvatar(BuildContext context, int current) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: C.panelSolid,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose your avatar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < avatarCount; i++)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, i),
                    child: AvatarPortrait(
                      avatar: i,
                      name: '',
                      size: 60,
                      ring: i == current ? C.goldBright : C.faint,
                      ringWidth: i == current ? 3.5 : 1.5,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
