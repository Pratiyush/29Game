import 'package:flutter/material.dart' hide Card;

import '../engine/cards.dart';
import 'theme.dart';

/// Renders a card from its sprite in assets/cards/<code>.png (or back.png when [code] is null).
/// Replace those PNGs with new art (any size, 140x190 aspect) and nothing else needs to change.
/// If an image is missing, a simple vector card is drawn instead.
class CardSprite extends StatelessWidget {
  const CardSprite({
    super.key,
    this.code,
    required this.width,
    this.dimmed = false,
    this.highlighted = false,
    this.elevation = 1,
  });

  static const aspect = 190 / 140;

  final String? code;
  final double width;

  /// Greyed out: a card that cannot be played right now.
  final bool dimmed;

  /// Ringed in gold: playable, or the card that won the trick.
  final bool highlighted;

  /// 0 = flat (cards fanned in a hand), 1 = normal, 2 = lifted off the table.
  final double elevation;

  static String assetFor(String? code) => 'assets/cards/${code ?? 'back'}.png';

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width * 0.075);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      height: width * aspect,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18 + 0.12 * elevation),
            blurRadius: 3 + 7 * elevation,
            offset: Offset(0, 1 + 2.5 * elevation),
          ),
          if (highlighted) BoxShadow(color: C.gold.withValues(alpha: 0.55), blurRadius: 14, spreadRadius: -1),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        color: dimmed ? const Color(0x7A06130D) : null,
        border: highlighted
            ? Border.all(color: C.goldBright, width: width * 0.028)
            : Border.all(color: Colors.black.withValues(alpha: 0.18), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          assetFor(code),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => _VectorCard(code: code, width: width),
        ),
      ),
    );
  }
}

class _VectorCard extends StatelessWidget {
  const _VectorCard({required this.code, required this.width});

  final String? code;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (code == null) {
      return const ColoredBox(color: Color(0xFF2B5C9E));
    }
    final card = Card.parse(code!);
    final color = card.suit.isRed ? const Color(0xFFC62828) : const Color(0xFF212121);
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(width * 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.rank.label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: width * 0.24, height: 1),
            ),
            Text(
              card.suit.symbol,
              style: TextStyle(color: color, fontSize: width * 0.2, height: 1),
            ),
            const Spacer(),
            Center(
              child: Text(
                card.suit.symbol,
                style: TextStyle(color: color, fontSize: width * 0.45),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Preloads all card sprites so the first deal does not flicker.
Future<void> precacheCards(BuildContext context) async {
  await Future.wait([
    for (final c in Card.deck) precacheImage(AssetImage(CardSprite.assetFor(c.code)), context),
    precacheImage(AssetImage(CardSprite.assetFor(null)), context),
  ]);
}
