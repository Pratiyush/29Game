import 'package:flutter/material.dart' hide Card;

import '../engine/cards.dart';

/// Renders a card from its sprite in assets/cards/<code>.png (or back.png when [code] is null).
/// Replace those PNGs with new art (any size, 140x190 aspect) and nothing else needs to change.
/// If an image is missing, a simple vector card is drawn instead.
class CardSprite extends StatelessWidget {
  const CardSprite({super.key, this.code, required this.width, this.dimmed = false, this.highlighted = false});

  static const aspect = 190 / 140;

  final String? code;
  final double width;
  final bool dimmed;
  final bool highlighted;

  static String assetFor(String? code) => 'assets/cards/${code ?? 'back'}.png';

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width * 0.07);
    return Container(
      width: width,
      height: width * aspect,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: highlighted ? const Color(0xAAF2C14E) : const Color(0x66000000),
            blurRadius: highlighted ? 12 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      foregroundDecoration: dimmed ? BoxDecoration(color: const Color(0x73000000), borderRadius: radius) : null,
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
