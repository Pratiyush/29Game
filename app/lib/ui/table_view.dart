import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Card;

import '../engine/action.dart';
import '../engine/cards.dart';
import '../engine/view.dart';
import '../net/session.dart';
import 'card_sprite.dart';
import 'theme.dart';

/// The card table. Everything is driven by the latest [PlayerView] from the host.
/// Seats are drawn relative to you: you at the bottom, play passes to the right (as in 29).
class TableView extends StatefulWidget {
  const TableView({super.key, required this.session, required this.view, required this.onLeave});

  final TableSession session;
  final PlayerView view;
  final VoidCallback onLeave;

  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  /// Keep a finished trick on the table briefly so everyone sees who won it.
  bool _holdLastTrick = false;
  Timer? _holdTimer;

  PlayerView get v => widget.view;
  TableSession get session => widget.session;

  @override
  void didUpdateWidget(TableView old) {
    super.didUpdateWidget(old);
    if (v.round == old.view.round && v.tricksPlayed > old.view.tricksPlayed) {
      _holdTimer?.cancel();
      _holdLastTrick = true;
      _holdTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _holdLastTrick = false);
      });
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  int rel(int seat) => (seat - v.seat + 4) % 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cardW = min(84.0, c.maxWidth / 5.4);
        final showingLast = v.trick.isEmpty && _holdLastTrick && v.lastTrick.isNotEmpty;
        final roundDone = v.phase == Phase.roundOver || v.phase == Phase.matchOver;
        final trick = roundDone ? const <PlayedCard>[] : (showingLast ? v.lastTrick : v.trick);
        return Column(
          children: [
            _Hud(view: v, session: session, onLeave: widget.onLeave),
            Expanded(
              child: Stack(
                children: [
                  Align(alignment: Alignment.topCenter, child: _seat(2)),
                  Align(alignment: Alignment.centerLeft, child: _seat(3)),
                  Align(alignment: Alignment.centerRight, child: _seat(1)),
                  Center(
                    child: _TrickArea(
                      trick: trick,
                      winner: showingLast ? v.lastTrickWinner : -1,
                      rel: rel,
                      cardW: cardW * 0.85,
                      round: v.round,
                    ),
                  ),
                  if (roundDone)
                    Center(
                      child: _RoundSummary(view: v, session: session),
                    ),
                ],
              ),
            ),
            _ActionBar(view: v, session: session),
            _Hand(view: v, cardW: cardW, onTap: _tapCard),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _seat(int relative) {
    final seat = (v.seat + relative) % 4;
    return _SeatBadge(view: v, session: session, seat: seat, vertical: relative != 2);
  }

  void _tapCard(String code) {
    if (!v.myTurn) return;
    if (v.phase == Phase.chooseTrump && v.legal.trumpCards.contains(code)) {
      session.act(ChooseTrumpAction(Card.parse(code)));
    } else if (v.phase == Phase.playing && v.legal.cards.contains(code)) {
      session.act(PlayAction(Card.parse(code)));
    }
  }
}

// ------------------------------------------------------------------ HUD

class _Hud extends StatelessWidget {
  const _Hud({required this.view, required this.session, required this.onLeave});

  final PlayerView view;
  final TableSession session;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final us = v.myTeam, them = 1 - v.myTeam;
    final small = Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70);
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          IconButton(
            onPressed: onLeave,
            icon: const Icon(Icons.close),
            tooltip: 'Leave',
            visualDensity: VisualDensity.compact,
          ),
          _ScorePill(label: 'Us', score: v.matchScore[us], points: v.teamPoints[us], color: AppColors.usTeam),
          const SizedBox(width: 6),
          _ScorePill(label: 'Them', score: v.matchScore[them], points: v.teamPoints[them], color: AppColors.themTeam),
          Expanded(
            child: v.bidder == -1
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Bid ${v.highestBid}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(session.seatName(v.bidder), style: small, overflow: TextOverflow.ellipsis),
                      if (v.target != 0 && v.target != v.highestBid)
                        Text('Target ${v.target}', style: small, overflow: TextOverflow.ellipsis),
                    ],
                  ),
          ),
          const SizedBox(width: 10),
          _TrumpIndicator(view: v),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.score, required this.points, required this.color});

  final String label;
  final int score;
  final int points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            '$label ${score > 0 ? '+' : ''}$score',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          Text('$points pts', style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _TrumpIndicator extends StatelessWidget {
  const _TrumpIndicator({required this.view});

  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    if (v.bidder == -1 || v.phase == Phase.bidding) return const SizedBox(width: 32);
    if (v.trumpRevealed && v.trump != null) {
      final suit = Suit.fromCode(v.trump!);
      return Tooltip(
        message: 'Trump revealed',
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white,
          child: Text(
            suit.symbol,
            style: TextStyle(fontSize: 24, color: suit.isRed ? Colors.red.shade700 : Colors.black),
          ),
        ),
      );
    }
    final hidden = v.hiddenTrump;
    return Tooltip(
      message: hidden != null ? 'Your hidden trump' : 'Trump is hidden',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CardSprite(code: hidden, width: 28),
          Text(hidden != null ? 'yours' : 'hidden', style: const TextStyle(fontSize: 9, color: Colors.white70)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ seats

class _SeatBadge extends StatelessWidget {
  const _SeatBadge({required this.view, required this.session, required this.seat, required this.vertical});

  final PlayerView view;
  final TableSession session;
  final int seat;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final info = session.room?.seats[seat];
    final active = v.turn == seat;
    final color = teamColor(seat, v.seat);
    final name = info?.name ?? 'Seat ${seat + 1}';
    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.gold : color.withValues(alpha: 0.6),
        boxShadow: active ? const [BoxShadow(color: AppColors.gold, blurRadius: 14)] : null,
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.ink,
        foregroundColor: color,
        child: info?.bot ?? false
            ? const Icon(Icons.smart_toy)
            : Text(name.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name.length > 12 ? '${name.substring(0, 11)}…' : name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (seat == v.dealer) const _Chip('D', tooltip: 'Dealer'),
            if (seat == v.bidder && v.phase != Phase.bidding) const _Chip('★', tooltip: 'Bidder'),
            if (info != null && !info.connected) const Icon(Icons.wifi_off, size: 12, color: Colors.white54),
            _MiniHand(count: v.handCounts[seat]),
          ],
        ),
      ],
    );
    final bubble = _BidBubble(view: v, seat: seat);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: [bubble, avatar, label])
          : Row(mainAxisSize: MainAxisSize.min, children: [avatar, const SizedBox(width: 6), label, bubble]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.tooltip});

  final String text;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.ink, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _MiniHand extends StatelessWidget {
  const _MiniHand({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14.0 + max(0, count - 1) * 3,
      height: 18,
      child: Stack(
        children: [for (var i = 0; i < count; i++) Positioned(left: i * 3.0, child: const CardSprite(width: 13))],
      ),
    );
  }
}

class _BidBubble extends StatelessWidget {
  const _BidBubble({required this.view, required this.seat});

  final PlayerView view;
  final int seat;

  @override
  Widget build(BuildContext context) {
    if (view.phase != Phase.bidding && view.phase != Phase.chooseTrump) return const SizedBox(height: 22);
    final mine = view.bids.where((b) => b.seat == seat);
    if (mine.isEmpty) return const SizedBox(height: 22);
    final last = mine.last;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: last.value == null ? Colors.white24 : Colors.white,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        last.value?.toString() ?? 'Pass',
        style: TextStyle(
          color: last.value == null ? Colors.white : AppColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ trick

class _TrickArea extends StatelessWidget {
  const _TrickArea({
    required this.trick,
    required this.winner,
    required this.rel,
    required this.cardW,
    required this.round,
  });

  final List<PlayedCard> trick;
  final int winner;
  final int Function(int) rel;
  final double cardW;
  final int round;

  static const _dirs = [Offset(0, 1), Offset(1, 0), Offset(0, -1), Offset(-1, 0)];

  @override
  Widget build(BuildContext context) {
    final w = cardW * 3.2, h = cardW * CardSprite.aspect * 2.3;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final p in trick)
            TweenAnimationBuilder<double>(
              key: ValueKey('$round-${p.card}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                final d = _dirs[rel(p.seat)];
                final near = Offset(d.dx * cardW * 0.75, d.dy * cardW * 0.62);
                final far = Offset(d.dx * w, d.dy * h);
                return Transform.translate(offset: Offset.lerp(far, near, t)!, child: child);
              },
              child: Transform.rotate(
                angle: (rel(p.seat) - 1.5) * 0.08,
                child: CardSprite(code: p.card, width: cardW, highlighted: p.seat == winner),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ actions

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.view, required this.session});

  final PlayerView view;
  final TableSession session;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final mine = v.myTurn;
    final turnName = v.turn >= 0 ? session.seatName(v.turn) : '';
    Widget child;
    switch (v.phase) {
      case Phase.bidding when mine:
        child = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (v.legal.canPass)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(onPressed: () => session.act(const PassAction()), child: const Text('Pass')),
                ),
              for (final b in v.legal.bids)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(48, 44),
                    ),
                    onPressed: () => session.act(BidAction(b)),
                    child: Text('$b'),
                  ),
                ),
            ],
          ),
        );
      case Phase.bidding:
        child = _Prompt('$turnName is bidding…');
      case Phase.chooseTrump when mine:
        child = _Prompt('You won at ${v.highestBid}! Tap a card to hide it face down as trump.', strong: true);
      case Phase.chooseTrump:
        child = _Prompt('$turnName is choosing trump…');
      case Phase.playing when mine:
        child = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _Prompt('Your turn', strong: true),
            if (v.legal.canRevealTrump) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => session.act(const RevealTrumpAction()),
                icon: const Icon(Icons.visibility),
                label: const Text('Ask for trump'),
              ),
            ],
            if (v.legal.canShowPair) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => session.act(const ShowPairAction()),
                icon: const Icon(Icons.favorite),
                label: const Text('Show pair'),
              ),
            ],
          ],
        );
      case Phase.playing:
        child = _Prompt(
          v.pairShownBy != -1 && v.tricksPlayed < 8
              ? '$turnName to play · pair shown by ${session.seatName(v.pairShownBy)}'
              : '$turnName to play',
        );
      case Phase.roundOver || Phase.matchOver:
        child = const SizedBox.shrink();
    }
    return SizedBox(height: 56, child: Center(child: child));
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: strong ? AppColors.gold : Colors.white70,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
  );
}

// ------------------------------------------------------------------ hand

class _Hand extends StatelessWidget {
  const _Hand({required this.view, required this.cardW, required this.onTap});

  final PlayerView view;
  final double cardW;
  final void Function(String code) onTap;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final playable = !v.myTurn
        ? const <String>[]
        : v.phase == Phase.chooseTrump
        ? v.legal.trumpCards
        : v.legal.cards;
    final n = v.hand.length;
    return LayoutBuilder(
      builder: (context, c) {
        final avail = c.maxWidth - 24;
        final step = n <= 1 ? 0.0 : min(cardW * 0.92, (avail - cardW) / (n - 1));
        final total = cardW + step * max(0, n - 1);
        final h = cardW * CardSprite.aspect + 26;
        return SizedBox(
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                _handCard(v.hand[i], i, n, step, (c.maxWidth - total) / 2, playable, v.myTurn),
            ],
          ),
        );
      },
    );
  }

  Widget _handCard(String code, int i, int n, double step, double left, List<String> playable, bool myTurn) {
    final mid = (n - 1) / 2;
    final canPlay = playable.contains(code);
    final lift = canPlay ? 0.0 : 14.0;
    return AnimatedPositioned(
      key: ValueKey(code),
      duration: const Duration(milliseconds: 200),
      left: left + i * step,
      top: lift + (i - mid) * (i - mid) * 1.2,
      child: GestureDetector(
        onTap: () => onTap(code),
        child: Semantics(
          button: true,
          enabled: canPlay,
          label: 'card ${_spoken(code)}',
          excludeSemantics: true,
          child: Transform.rotate(
            angle: (i - mid) * 0.045,
            alignment: Alignment.bottomCenter,
            child: CardSprite(
              code: code,
              width: cardW,
              dimmed: myTurn && playable.isNotEmpty && !canPlay,
              highlighted: canPlay,
            ),
          ),
        ),
      ),
    );
  }

  static String _spoken(String code) {
    final c = Card.parse(code);
    return '${c.rank.label} of ${c.suit.name}';
  }
}

// ------------------------------------------------------------------ round summary

class _RoundSummary extends StatelessWidget {
  const _RoundSummary({required this.view, required this.session});

  final PlayerView view;
  final TableSession session;

  @override
  Widget build(BuildContext context) {
    final r = view.lastRound;
    if (r == null) return const SizedBox.shrink();
    final usBid = r.bidder % 2 == view.myTeam;
    final matchOver = view.phase == Phase.matchOver;
    final weWon = view.matchWinner == view.myTeam;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (matchOver)
            Text(
              weWon ? 'You win the match!' : 'Opponents win the match',
              style: text.headlineSmall?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900),
            ),
          Text(
            '${session.seatName(r.bidder)} bid ${r.bid}${r.target != r.bid ? ' (target ${r.target})' : ''}',
            style: text.titleMedium,
          ),
          const SizedBox(height: 6),
          Text('${usBid ? 'Your team' : 'Opponents'} took ${r.bidderTeamPoints} points', style: text.bodyLarge),
          const SizedBox(height: 6),
          Text(
            r.success ? 'Contract made  ${r.delta > 0 ? '+' : ''}${r.delta}' : 'Contract failed  ${r.delta}',
            style: text.titleLarge?.copyWith(
              color: r.success == usBid ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Match: Us ${view.matchScore[view.myTeam]}  ·  Them ${view.matchScore[1 - view.myTeam]}',
            style: text.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (matchOver)
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to menu'))
          else
            const Text('Next deal starting…', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
