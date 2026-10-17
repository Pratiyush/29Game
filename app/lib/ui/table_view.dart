import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Card;

import '../engine/action.dart';
import '../engine/cards.dart';
import '../engine/view.dart';
import '../net/emotes.dart';
import '../net/session.dart';
import '../prefs.dart';
import 'avatar.dart';
import 'card_sprite.dart';
import 'feel.dart';
import 'theme.dart';

/// The card table. Everything is driven by the latest [PlayerView] from the host.
/// Seats are drawn relative to you: you at the bottom, partner opposite, play passes to the right.
class TableView extends StatefulWidget {
  const TableView({super.key, required this.session, required this.view, required this.onLeave});

  final TableSession session;
  final PlayerView view;
  final VoidCallback onLeave;

  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> with TickerProviderStateMixin {
  /// Heartbeat behind the active seat's ring.
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  /// Runs once per completed trick: hold the four cards, then sweep them to the winner.
  late final AnimationController _collect = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  bool _showingLastTrick = false;

  /// Emoji / phrase currently floating over each seat.
  final Map<int, String> _emotes = {};
  final Map<int, Timer> _emoteTimers = {};
  StreamSubscription<EmoteEvent>? _emoteSub;

  Announcement? _announcement;
  Timer? _announcementTimer;

  /// Bumped to replay the confetti; null hides it.
  int? _confetti;
  bool _bigConfetti = false;

  PlayerView get v => widget.view;

  TableSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    _emoteSub = session.emotes.listen(_showEmote);
    Sfx.deal();
  }

  @override
  void didUpdateWidget(TableView old) {
    super.didUpdateWidget(old);
    final o = old.view;
    if (v.round == o.round && v.tricksPlayed > o.tricksPlayed) {
      setState(() => _showingLastTrick = true);
      _collect.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _showingLastTrick = false);
      });
    }
    _feel(o, v);
  }

  /// Turns state changes into sound, haptics and announcements.
  void _feel(PlayerView o, PlayerView n) {
    if (n.round != o.round) {
      Sfx.deal();
      return;
    }
    if (n.bids.length > o.bids.length) Sfx.bid();
    if (n.trick.length > o.trick.length || n.tricksPlayed > o.tricksPlayed) {
      Sfx.playCard();
      if (n.tricksPlayed > o.tricksPlayed) Future.delayed(const Duration(milliseconds: 650), Sfx.trick);
    }
    if (n.myTurn && !o.myTurn) {
      Sfx.turn();
      Haptics.tap();
    }
    if (n.phase == Phase.playing && o.phase == Phase.chooseTrump && n.bidder != n.seat) {
      _announce(
        Announcement('${session.seatName(n.bidder)} chose trump', 'It stays face down until someone asks for it'),
      );
    }
    if (n.trumpRevealed && !o.trumpRevealed && n.trump != null) {
      Sfx.reveal();
      Haptics.play();
      final suit = Suit.fromCode(n.trump!);
      _announce(
        Announcement(
          'Trump revealed',
          '${suit.name[0].toUpperCase()}${suit.name.substring(1)} are trumps now',
          icon: _SuitChip(suit: suit),
        ),
      );
    }
    if (n.pairShownBy != -1 && o.pairShownBy == -1) {
      Sfx.pair();
      Haptics.play();
      final ours = n.pairShownBy % 2 == n.myTeam;
      _announce(
        Announcement(
          'Pair! ${session.seatName(n.pairShownBy)} shows K + Q',
          'Target is now ${n.target}',
          icon: const Icon(Icons.favorite_rounded, color: Color(0xFFE85D75)),
          color: ours ? C.us : C.them,
        ),
      );
    }
    final ended = (n.phase == Phase.roundOver || n.phase == Phase.matchOver) && o.phase == Phase.playing;
    if (ended && n.lastRound != null) {
      final r = n.lastRound!;
      final weWon = r.success == (r.bidder % 2 == n.myTeam);
      final matchWon = n.phase == Phase.matchOver && n.matchWinner == n.myTeam;
      try {
        Prefs.instance.recordDeal(session.room?.code ?? 'local', n);
      } catch (_) {}
      if (weWon) {
        Sfx.win();
        Haptics.big();
        setState(() {
          _confetti = (_confetti ?? 0) + 1;
          _bigConfetti = matchWon;
        });
      } else {
        Sfx.lose();
      }
    }
  }

  void _announce(Announcement a) {
    _announcementTimer?.cancel();
    setState(() => _announcement = a);
    _announcementTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _announcement = null);
    });
  }

  void _showEmote(EmoteEvent e) {
    _emoteTimers[e.seat]?.cancel();
    setState(() => _emotes[e.seat] = e.emote);
    _emoteTimers[e.seat] = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _emotes.remove(e.seat));
    });
  }

  Future<void> _openEmotes() async {
    final e = await showDialog<String>(context: context, builder: (_) => const _EmotePicker());
    if (e != null) {
      session.emote(e);
      Haptics.tap();
    }
  }

  void _openLastHand() {
    if (v.lastTrick.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => _LastHandDialog(view: v, session: session),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _collect.dispose();
    _emoteSub?.cancel();
    for (final t in _emoteTimers.values) {
      t.cancel();
    }
    _announcementTimer?.cancel();
    super.dispose();
  }

  /// 0 = me, 1 = right opponent, 2 = partner, 3 = left opponent.
  int rel(int seat) => (seat - v.seat + 4) % 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // The game is played in landscape (see lib/main.dart); portrait still lays out correctly.
        final wide = c.maxWidth > c.maxHeight;
        final roundDone = v.phase == Phase.roundOver || v.phase == Phase.matchOver;
        final trick = roundDone ? const <PlayedCard>[] : (_showingLastTrick && v.trick.isEmpty ? v.lastTrick : v.trick);
        final cardW = wide
            ? max(48.0, min(86.0, min((c.maxHeight - 196) / CardSprite.aspect, (c.maxWidth - 230) / 7.2)))
            : min(74.0, (c.maxWidth - 28) / 5.2);
        return Stack(
          children: [
            if (wide) _wideBody(c, trick, roundDone, cardW) else _tallBody(trick, roundDone, cardW),
            if (v.phase == Phase.chooseTrump && v.myTurn)
              Align(
                alignment: wide ? const Alignment(0, 0.05) : const Alignment(0, 0.05),
                child: _TrumpPicker(view: v, onPick: _tapCard),
              ),
            if (_announcement != null)
              Positioned(
                top: wide ? 6 : 64,
                left: 0,
                right: 0,
                child: Center(child: AnnouncementBanner(announcement: _announcement!)),
              ),
            if (roundDone) _RoundSummary(view: v, session: session),
            if (_confetti != null)
              Positioned.fill(
                child: Confetti(key: ValueKey(_confetti), big: _bigConfetti),
              ),
          ],
        );
      },
    );
  }

  Widget _tallBody(List<PlayedCard> trick, bool roundDone, double cardW) {
    return Column(
      children: [
        _Scoreboard(view: v, session: session, onLeave: widget.onLeave),
        Expanded(
          child: _table(trick: trick, roundDone: roundDone, cardW: cardW, wide: false),
        ),
        Row(
          children: [
            const SizedBox(width: 6),
            _RoundButton(icon: Icons.emoji_emotions_rounded, tooltip: 'React', onTap: _openEmotes),
            Expanded(
              child: _ActionBar(view: v, session: session),
            ),
            _RoundButton(
              icon: Icons.history_rounded,
              tooltip: 'Last hand',
              onTap: v.lastTrick.isEmpty ? null : _openLastHand,
            ),
            const SizedBox(width: 6),
          ],
        ),
        _Hand(view: v, cardW: cardW, onTap: _tapCard),
        const SizedBox(height: 6),
      ],
    );
  }

  /// Landscape: the table fills the screen and the hand is dealt over its lower edge, with
  /// your seat and the action buttons in the free space either side.
  Widget _wideBody(BoxConstraints c, List<PlayedCard> trick, bool roundDone, double cardW) {
    final handH = cardW * CardSprite.aspect + 16;
    const scoreH = 56.0;
    final sideGap = max(96.0, c.maxWidth * 0.13);
    return Stack(
      children: [
        Positioned(
          top: scoreH,
          left: 0,
          right: 0,
          bottom: handH * 0.52,
          child: _table(trick: trick, roundDone: roundDone, cardW: cardW, wide: true),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _Scoreboard(view: v, session: session, onLeave: widget.onLeave, compact: true),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: handH + 8,
          child: Center(
            child: _ActionBar(view: v, session: session, compact: true),
          ),
        ),
        Positioned(
          left: sideGap,
          right: sideGap,
          bottom: 6,
          height: handH,
          child: _Hand(view: v, cardW: cardW, onTap: _tapCard),
        ),
        Positioned(left: 6, bottom: 10, child: _seatPod(v.seat, _Place.bottom, compact: true)),
        Positioned(
          left: 10,
          bottom: 78,
          child: _RoundButton(icon: Icons.emoji_emotions_rounded, tooltip: 'React', onTap: _openEmotes),
        ),
        Positioned(
          right: 12,
          bottom: 16,
          child: _LastHandButton(enabled: v.lastTrick.isNotEmpty, onTap: _openLastHand),
        ),
      ],
    );
  }

  /// The felt oval with the seats on its rail and the trick in the middle.
  Widget _table({required List<PlayedCard> trick, required bool roundDone, required double cardW, required bool wide}) {
    return LayoutBuilder(
      builder: (context, table) {
        // The seats sit on the rail, so the stack is exactly the size of the table. Keep the oval
        // from stretching into an egg on tall screens or a pancake on wide ones.
        final size = wide
            ? Size(min(table.maxWidth - 8, table.maxHeight * 2.3), table.maxHeight)
            : Size(table.maxWidth - 8, min(table.maxHeight, table.maxWidth * 1.55));
        return Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const TableSurface(),
                _seatPod(_seatAt(2), _Place.top, compact: wide),
                _seatPod(_seatAt(3), _Place.left, compact: wide, y: wide ? -0.34 : -0.02),
                _seatPod(_seatAt(1), _Place.right, compact: wide, y: wide ? -0.34 : -0.02),
                if (!wide) _seatPod(v.seat, _Place.bottom),
                Align(
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (trick.isEmpty && !roundDone)
                        _CenterPlaque(view: v, session: session, showingSweep: _showingLastTrick),
                      _Trick(
                        trick: trick,
                        winner: _showingLastTrick ? v.lastTrickWinner : -1,
                        showWinner: _showingLastTrick,
                        rel: rel,
                        cardW: cardW * (wide ? 0.62 : 0.8),
                        spreadY: wide ? 0.5 : 0.52,
                        collect: _collect,
                        round: v.round,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _seatPod(int seat, _Place place, {bool compact = false, double? y}) => _SeatPod(
    view: v,
    session: session,
    seat: seat,
    place: place,
    pulse: _pulse,
    compact: compact,
    y: y,
    emote: _emotes[seat],
  );

  int _seatAt(int relative) => (v.seat + relative) % 4;

  void _tapCard(String code) {
    if (!v.myTurn) return;
    if (v.phase == Phase.chooseTrump && v.legal.trumpCards.contains(code)) {
      Haptics.play();
      session.act(ChooseTrumpAction(Card.parse(code)));
    } else if (v.phase == Phase.playing && v.legal.cards.contains(code)) {
      Haptics.play();
      session.act(PlayAction(Card.parse(code)));
    }
  }
}

// ------------------------------------------------------------------ scoreboard

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.view, required this.session, required this.onLeave, this.compact = false});

  final PlayerView view;
  final TableSession session;
  final VoidCallback onLeave;

  /// Landscape: one row only, so the table keeps the height.
  final bool compact;

  /// Landscape gives the chips a fixed width so the contract line can share the row.
  static Widget _chipSlot(bool compact, Widget chip) =>
      compact ? SizedBox(width: 132, child: chip) : Expanded(child: chip);

  @override
  Widget build(BuildContext context) {
    final v = view;
    final us = v.myTeam;
    final them = 1 - us;
    // Once the contract is set, each side races to its own number: the bidders to the target,
    // the defenders to one more than the bidders can afford to lose.
    int? needed(int team) {
      if (v.bidder == -1 || v.phase == Phase.bidding || v.target == 0) return null;
      return team == v.bidder % 2 ? v.target : 29 - v.target;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onLeave,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: C.muted,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Leave table',
                ),
                _chipSlot(
                  compact,
                  _TeamChip(
                    label: 'US',
                    color: C.us,
                    matchScore: v.matchScore[us],
                    points: v.teamPoints[us],
                    needed: needed(us),
                  ),
                ),
                const SizedBox(width: 8),
                _chipSlot(
                  compact,
                  _TeamChip(
                    label: 'THEM',
                    color: C.them,
                    matchScore: v.matchScore[them],
                    points: v.teamPoints[them],
                    needed: needed(them),
                  ),
                ),
                if (compact && v.bidder != -1 && v.phase != Phase.bidding)
                  Expanded(
                    child: _ContractLine(view: v, session: session),
                  ),
                const SizedBox(width: 10),
                _TrumpBadge(view: v),
              ],
            ),
            if (!compact && v.bidder != -1 && v.phase != Phase.bidding) ...[
              const SizedBox(height: 5),
              _ContractLine(view: v, session: session),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  const _TeamChip({
    required this.label,
    required this.color,
    required this.matchScore,
    required this.points,
    this.needed,
  });

  final String label;
  final Color color;
  final int matchScore;
  final int points;

  /// Points this side needs to win the deal; null before the contract is set.
  final int? needed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                label,
                style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.3),
              ),
              const Spacer(),
              Text(
                '${matchScore > 0 ? '+' : ''}$matchScore',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800, height: 1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _PointsBar(points: points, of: needed ?? 28, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                '$points',
                style: TextStyle(
                  color: needed != null && points >= needed! ? color : C.cream,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('/${needed ?? 28}', style: const TextStyle(color: C.faint, fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Progress towards the points this team needs (or towards 28 before the contract is set).
class _PointsBar extends StatelessWidget {
  const _PointsBar({required this.points, required this.of, required this.color});

  final int points;
  final int of;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.08)),
            FractionallySizedBox(
              widthFactor: (points / of).clamp(0.0, 1.0),
              child: AnimatedContainer(duration: const Duration(milliseconds: 350), color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractLine extends StatelessWidget {
  const _ContractLine({required this.view, required this.session});

  final PlayerView view;
  final TableSession session;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final ours = v.bidder % 2 == v.myTeam;
    final parts = [
      'bid ${v.highestBid}',
      if (v.target != 0 && v.target != v.highestBid) 'target ${v.target}',
      if (v.phase == Phase.playing) 'trick ${min(v.tricksPlayed + 1, 8)}/8',
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.gavel_rounded, size: 11, color: ours ? C.us : C.them),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '${session.seatName(v.bidder)} · ${parts.join(' · ')}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _TrumpBadge extends StatelessWidget {
  const _TrumpBadge({required this.view});

  final PlayerView view;

  @override
  Widget build(BuildContext context) {
    final v = view;
    if (v.bidder == -1 || v.phase == Phase.bidding) {
      return const SizedBox(width: 38, height: 44);
    }
    if (v.trumpRevealed && v.trump != null) {
      final suit = Suit.fromCode(v.trump!);
      return Tooltip(
        message: 'Trump: ${suit.name}',
        child: Container(
          width: 38,
          height: 44,
          decoration: BoxDecoration(
            color: C.cream,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: C.gold.withValues(alpha: 0.35), blurRadius: 10)],
          ),
          alignment: Alignment.center,
          child: Text(
            suit.symbol,
            style: TextStyle(
              fontSize: 24,
              height: 1,
              color: suit.isRed ? const Color(0xFFC62828) : const Color(0xFF1B1B1B),
            ),
          ),
        ),
      );
    }
    final hidden = v.hiddenTrump;
    return Tooltip(
      message: hidden != null ? 'Your hidden trump' : 'Trump is face down',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CardSprite(code: hidden, width: 28, elevation: 0.5),
          const SizedBox(height: 1),
          Text(hidden != null ? 'yours' : 'hidden', style: const TextStyle(fontSize: 8, color: C.faint, height: 1)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ seats

enum _Place { top, left, right, bottom }

class _SeatPod extends StatelessWidget {
  const _SeatPod({
    required this.view,
    required this.session,
    required this.seat,
    required this.place,
    required this.pulse,
    this.compact = false,
    this.y,
    this.emote,
  });

  final PlayerView view;
  final TableSession session;
  final int seat;
  final _Place place;
  final Animation<double> pulse;

  /// A reaction to float above the portrait.
  final String? emote;

  /// Landscape: smaller avatars so four seats and a trick fit in a short table.
  final bool compact;

  /// Overrides where a side seat sits vertically on the rail.
  final double? y;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final me = seat == v.seat;
    final info = session.room?.seats[seat];
    final active = v.turn == seat;
    final color = teamColor(seat, v.seat);
    // Bots are marked with a tag rather than a "(bot)" suffix, so names stay short.
    final name = me ? 'You' : (info?.name ?? 'Seat ${seat + 1}').replaceAll(' (bot)', '');

    final double size = compact ? (me ? 40 : 46) : (me ? 40 : 52);
    final portrait = _Avatar(
      name: name,
      avatar: info?.avatar ?? -1,
      color: color,
      active: active,
      dimmed: info != null && !info.connected,
      pulse: pulse,
      size: size,
    );
    // Opponents' remaining cards fan out beside their portrait, as on a real table.
    final avatar = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (!me)
          Positioned(
            left: place == _Place.right ? -size * 0.42 : null,
            right: place == _Place.right ? null : -size * 0.42,
            top: size * 0.12,
            child: _CardFan(count: v.handCounts[seat], mirrored: place == _Place.right),
          ),
        portrait,
        if (emote != null)
          Positioned(
            bottom: size + 2,
            child: _EmoteBubble(text: emote!),
          ),
      ],
    );

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: C.ink.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: (active ? C.gold : color).withValues(alpha: 0.5)),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: active ? C.goldBright : C.cream,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info?.bot ?? false) const _Badge('BOT', tip: 'Computer player'),
            if (seat == v.dealer) const _Badge('D', tip: 'Dealer'),
            if (seat == v.bidder && v.phase != Phase.bidding) const _Badge('★', tip: 'Took the contract', gold: true),
            if (info != null && !info.connected)
              const Padding(
                padding: EdgeInsets.only(right: 3),
                child: Icon(Icons.wifi_off_rounded, size: 11, color: C.faint),
              ),
          ],
        ),
      ],
    );

    final bubble = _BidBubble(view: v, seat: seat);

    final Widget pod = place == _Place.bottom
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [avatar, const SizedBox(width: 8), label, const SizedBox(width: 6), bubble],
          )
        : SizedBox(
            width: compact ? 86 : 92,
            child: Column(mainAxisSize: MainAxisSize.min, children: [avatar, const SizedBox(height: 5), label, bubble]),
          );

    final alignment = switch (place) {
      _Place.top => const Alignment(0, -1),
      _Place.left => Alignment(-1, y ?? -0.02),
      _Place.right => Alignment(1, y ?? -0.02),
      _Place.bottom => const Alignment(-0.92, 1),
    };

    // In the landscape bottom row the pod is placed by the parent, not on the rail.
    if (place == _Place.bottom && compact) {
      return Padding(padding: const EdgeInsets.only(left: 4, bottom: 10), child: pod);
    }
    return Align(
      alignment: alignment,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), child: pod),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.avatar,
    required this.color,
    required this.active,
    required this.dimmed,
    required this.pulse,
    required this.size,
  });

  final String name;
  final int avatar;
  final Color color;
  final bool active;
  final bool dimmed;
  final Animation<double> pulse;
  final double size;

  @override
  Widget build(BuildContext context) {
    final face = AvatarPortrait(
      avatar: avatar,
      name: name,
      size: size,
      ring: active ? C.goldBright : color,
      ringWidth: active ? 3 : 2.2,
      dimmed: dimmed,
    );
    if (!active) return face;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = Curves.easeOut.transform(pulse.value);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size * (1 + 0.45 * t),
              height: size * (1 + 0.45 * t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: C.gold.withValues(alpha: 0.55 * (1 - t)), width: 2),
              ),
            ),
            child!,
          ],
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: C.gold.withValues(alpha: 0.45), blurRadius: 16)],
        ),
        child: face,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.tip, this.gold = false});

  final String text;
  final String tip;
  final bool gold;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: Container(
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: gold ? C.gold : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: gold ? C.ink : C.cream, fontSize: 9, height: 1.3, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// An opponent's face-down cards, fanned behind their portrait.
class _CardFan extends StatelessWidget {
  const _CardFan({required this.count, this.mirrored = false});

  final int count;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    const w = 18.0;
    if (count == 0) return const SizedBox(width: w, height: w * CardSprite.aspect);
    return SizedBox(
      width: w + 16,
      height: w * CardSprite.aspect + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: (mirrored ? count - 1 - i : i) * 2.0,
              top: 2,
              child: Transform.rotate(
                angle: (i - (count - 1) / 2) * 0.13 * (mirrored ? -1 : 1),
                alignment: Alignment.bottomCenter,
                child: const CardSprite(width: w, elevation: 0.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmoteBubble extends StatelessWidget {
  const _EmoteBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isEmoji = text.runes.length <= 2;
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isEmoji ? 8 : 10, vertical: isEmoji ? 2 : 5),
        decoration: BoxDecoration(
          color: C.cream,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: isEmoji ? 22 : 12, fontWeight: FontWeight.w700, color: C.ink, height: 1.2),
        ),
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
    final bidding = view.phase == Phase.bidding || view.phase == Phase.chooseTrump;
    final mine = view.bids.where((b) => b.seat == seat);
    if (!bidding || mine.isEmpty) return const SizedBox.shrink();
    final last = mine.last;
    final passed = last.value == null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: passed ? Colors.white.withValues(alpha: 0.12) : C.cream,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        passed ? 'Pass' : '${last.value}',
        style: TextStyle(color: passed ? C.muted : C.ink, fontWeight: FontWeight.w700, fontSize: 11.5, height: 1.2),
      ),
    );
  }
}

// ------------------------------------------------------------------ trick

class _Trick extends StatelessWidget {
  const _Trick({
    required this.trick,
    required this.winner,
    required this.showWinner,
    required this.rel,
    required this.cardW,
    required this.spreadY,
    required this.collect,
    required this.round,
  });

  final List<PlayedCard> trick;
  final int winner;
  final bool showWinner;
  final int Function(int) rel;
  final double cardW;
  final double spreadY;
  final Animation<double> collect;
  final int round;

  /// Where each seat's card sits relative to the centre: me below, partner above, opponents at the sides.
  static const _dirs = [Offset(0, 1), Offset(1, 0), Offset(0, -1), Offset(-1, 0)];

  @override
  Widget build(BuildContext context) {
    final h = cardW * CardSprite.aspect;
    final spread = Offset(cardW * 0.95, h * spreadY);
    return IgnorePointer(
      child: SizedBox(
        width: cardW * 3.6,
        height: h * 2.3,
        child: AnimatedBuilder(
          animation: collect,
          builder: (context, _) {
            // After a short hold, the trick slides to whoever won it and fades.
            final sweep = showWinner
                ? Curves.easeInCubic.transform(((collect.value - 0.62) / 0.38).clamp(0.0, 1.0))
                : 0.0;
            final toWinner = winner >= 0 ? _dirs[rel(winner)] : Offset.zero;
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                for (final p in trick)
                  _TrickCard(
                    key: ValueKey('$round-${p.card}'),
                    card: p.card,
                    dir: _dirs[rel(p.seat)],
                    spread: spread,
                    cardW: cardW,
                    won: showWinner && p.seat == winner,
                    sweep: sweep,
                    toWinner: toWinner,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrickCard extends StatelessWidget {
  const _TrickCard({
    super.key,
    required this.card,
    required this.dir,
    required this.spread,
    required this.cardW,
    required this.won,
    required this.sweep,
    required this.toWinner,
  });

  final String card;
  final Offset dir;
  final Offset spread;
  final double cardW;
  final bool won;
  final double sweep;
  final Offset toWinner;

  @override
  Widget build(BuildContext context) {
    final resting = Offset(dir.dx * spread.dx, dir.dy * spread.dy);
    final gathered = Offset(toWinner.dx * spread.dx * 3.2, toWinner.dy * spread.dy * 3.2);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, deal, child) {
        // Deal in from the player's side, then sweep away to the winner.
        final pos = Offset.lerp(resting * 3.4, resting, deal)! + (gathered - resting) * sweep;
        return Transform.translate(
          offset: pos,
          child: Opacity(opacity: (1 - sweep * 1.9).clamp(0.0, 1.0), child: child),
        );
      },
      child: Transform.rotate(
        angle: dir.dx * 0.1 + dir.dy * 0.04,
        child: CardSprite(code: card, width: cardW, highlighted: won, elevation: won ? 2 : 1.2),
      ),
    );
  }
}

/// Fills the middle of the table when no cards are out: the live auction, or who took
/// the last trick. Keeps the felt informative instead of empty.
class _CenterPlaque extends StatelessWidget {
  const _CenterPlaque({required this.view, required this.session, required this.showingSweep});

  final PlayerView view;
  final TableSession session;
  final bool showingSweep;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final (String caption, String value) = switch (v.phase) {
      Phase.bidding when v.bidder == -1 => ('AUCTION', 'No bids yet'),
      Phase.bidding => ('HIGHEST BID', '${v.highestBid} \u00b7 ${session.seatName(v.bidder)}'),
      Phase.chooseTrump => ('TRUMP', 'Being chosen\u2026'),
      _ when v.lastTrickWinner >= 0 => ('TRICK ${v.tricksPlayed}', '${session.seatName(v.lastTrickWinner)} won it'),
      _ => ('', ''),
    };
    if (value.isEmpty) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: showingSweep ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: C.ink.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: C.gold.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              caption,
              style: const TextStyle(color: C.faint, fontSize: 9, letterSpacing: 2.2, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: C.cream, fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ actions

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.view, required this.session, this.compact = false});

  final PlayerView view;
  final TableSession session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final mine = v.myTurn;
    final turnName = v.turn >= 0 ? session.seatName(v.turn) : '';
    final Widget child;
    switch (v.phase) {
      case Phase.bidding when mine:
        child = _BidStrip(view: v, session: session);
      case Phase.bidding:
        // Landscape: the pulsing ring on the seat already says whose turn it is, and the felt
        // under this bar is where cards land, so stay out of the way.
        if (compact) return const SizedBox.shrink();
        child = _Waiting('$turnName is bidding');
      case Phase.chooseTrump when mine:
        child = const _Prompt('Pick a card to hide as trump', icon: Icons.visibility_off_rounded, strong: true);
      case Phase.chooseTrump:
        if (compact) return const SizedBox.shrink();
        child = _Waiting('$turnName is choosing trump');
      case Phase.playing when mine:
        child = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!v.legal.canRevealTrump && !v.legal.canShowPair)
              const _Prompt('Your turn', icon: Icons.touch_app_rounded, strong: true),
            if (v.legal.canRevealTrump)
              FilledButton.icon(
                onPressed: () => session.act(const RevealTrumpAction()),
                icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
                label: const Text('Ask for trump'),
              ),
            if (v.legal.canShowPair) ...[
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => session.act(const ShowPairAction()),
                icon: const Icon(Icons.favorite_rounded, size: 18),
                label: const Text('Show pair'),
              ),
            ],
          ],
        );
      case Phase.playing:
        if (compact) return const SizedBox.shrink();
        child = _Waiting(
          v.pairShownBy != -1 && v.tricksPlayed < 8
              ? '$turnName to play · pair by ${session.seatName(v.pairShownBy)}'
              : '$turnName to play',
        );
      case Phase.roundOver || Phase.matchOver:
        child = const SizedBox.shrink();
    }
    return SizedBox(
      height: compact ? 44 : 54,
      child: Center(child: child),
    );
  }
}

class _BidStrip extends StatelessWidget {
  const _BidStrip({required this.view, required this.session});

  final PlayerView view;
  final TableSession session;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          if (view.legal.canPass)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => session.act(const PassAction()),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: C.faint),
                  ),
                  child: const Text(
                    'Pass',
                    style: TextStyle(color: C.muted, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ),
          for (final b in view.legal.bids)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                onTap: () => session.act(BidAction(b)),
                child: Container(
                  width: 46,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C.goldBright, C.gold]),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(color: C.gold.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    '$b',
                    style: const TextStyle(color: C.ink, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt(this.text, {required this.icon, this.strong = false});

  final String text;
  final IconData icon;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: strong ? C.gold : C.faint),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: strong ? C.goldBright : C.muted,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}

class _Waiting extends StatelessWidget {
  const _Waiting(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.6, color: C.faint)),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: C.muted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    ],
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
    final arcK = cardW * 0.016;
    final maxArc = n <= 1 ? 0.0 : pow((n - 1) / 2, 2) * arcK;
    return SizedBox(
      height: cardW * CardSprite.aspect + 36,
      child: LayoutBuilder(
        builder: (context, c) {
          final step = n <= 1 ? 0.0 : min(cardW * 0.88, (c.maxWidth - 40 - cardW) / (n - 1));
          final total = cardW + step * max(0, n - 1);
          final left = (c.maxWidth - total) / 2;
          // Anchor the fan to the bottom of whatever room we were given, keeping a little
          // headroom so a playable card can lift without being clipped.
          final base = max(0.0, c.maxHeight - cardW * CardSprite.aspect - maxArc - 2);
          final lift = min(13.0, base);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                _HandCard(
                  code: v.hand[i],
                  index: i,
                  count: n,
                  left: left + i * step,
                  top: base,
                  arcK: arcK,
                  lift: lift,
                  cardW: cardW,
                  playable: playable.contains(v.hand[i]),
                  anyPlayable: playable.isNotEmpty,
                  // Ring the legal cards only when some card is illegal, so gold always means a choice.
                  restricted: playable.isNotEmpty && playable.length < n,
                  onTap: onTap,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({
    required this.code,
    required this.index,
    required this.count,
    required this.left,
    required this.top,
    required this.arcK,
    required this.lift,
    required this.cardW,
    required this.playable,
    required this.anyPlayable,
    required this.restricted,
    required this.onTap,
  });

  final String code;
  final int index;
  final int count;
  final double left;
  final double top;
  final double arcK;
  final double lift;
  final double cardW;
  final bool playable;
  final bool anyPlayable;
  final bool restricted;
  final void Function(String code) onTap;

  @override
  Widget build(BuildContext context) {
    final offset = index - (count - 1) / 2;
    // Fan: the cards arc down from the middle and tilt outwards; playable ones lift.
    final arc = offset * offset * arcK;
    return AnimatedPositioned(
      key: ValueKey(code),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: left,
      top: top + arc - (playable ? lift : 0),
      child: Semantics(
        button: true,
        enabled: playable,
        label: 'card ${_spoken(code)}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onTap(code),
          child: Transform.rotate(
            angle: offset * 0.04,
            alignment: Alignment.bottomCenter,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CardSprite(
                  code: code,
                  width: cardW,
                  dimmed: anyPlayable && !playable,
                  highlighted: playable && restricted,
                  elevation: playable ? 2 : 0.6,
                ),
                if (_points > 0 && _showPoints)
                  Positioned(
                    left: cardW * 0.08,
                    top: -8,
                    child: _PointsBadge(points: _points),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int get _points => Card.parse(code).points;

  static bool get _showPoints {
    try {
      return Prefs.instance.showPoints;
    } catch (_) {
      return true;
    }
  }

  static String _spoken(String code) {
    final c = Card.parse(code);
    return '${c.rank.label} of ${c.suit.name}';
  }
}

/// The card's value in 29 (J 3, 9 2, A 1, 10 1), shown above it in your hand.
class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [C.goldBright, C.gold]),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))],
    ),
    child: Text(
      '$points',
      style: const TextStyle(color: C.ink, fontSize: 10, fontWeight: FontWeight.w800, height: 1.2),
    ),
  );
}

// ------------------------------------------------------------------ table controls

class _SuitChip extends StatelessWidget {
  const _SuitChip({required this.suit, this.size = 30});

  final Suit suit;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size * 1.15,
    decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(6)),
    alignment: Alignment.center,
    child: Text(
      suit.symbol,
      style: TextStyle(
        fontSize: size * 0.7,
        height: 1,
        color: suit.isRed ? const Color(0xFFC8222C) : const Color(0xFF181A1E),
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: C.ink.withValues(alpha: 0.7),
      shape: CircleBorder(
        side: BorderSide(color: C.gold.withValues(alpha: onTap == null ? 0.15 : 0.5)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 21, color: onTap == null ? C.faint : C.goldBright),
        ),
      ),
    ),
  );
}

/// Bottom-right corner of the landscape table: a face-down card you tap to see the last trick.
class _LastHandButton extends StatelessWidget {
  const _LastHandButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.4,
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(angle: -0.12, child: const CardSprite(width: 34, elevation: 0.6)),
              Transform.rotate(angle: 0.1, child: const CardSprite(width: 34, elevation: 1)),
              const Icon(Icons.history_rounded, color: C.goldBright, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Last hand',
            style: TextStyle(fontSize: 10, color: C.muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _LastHandDialog extends StatelessWidget {
  const _LastHandDialog({required this.view, required this.session});

  final PlayerView view;
  final TableSession session;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final points = v.lastTrick.fold<int>(0, (s, p) => s + Card.parse(p.card).points);
    return Dialog(
      backgroundColor: C.panelSolid,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Trick ${v.tricksPlayed}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${session.seatName(v.lastTrickWinner)} took it \u00b7 $points ${points == 1 ? 'point' : 'points'}',
              style: const TextStyle(color: C.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in v.lastTrick)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      children: [
                        CardSprite(code: p.card, width: 58, highlighted: p.seat == v.lastTrickWinner),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 66,
                          child: Text(
                            session.seatName(p.seat),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: p.seat == v.lastTrickWinner ? C.goldBright : C.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}

class _EmotePicker extends StatelessWidget {
  const _EmotePicker();

  @override
  Widget build(BuildContext context) {
    final emoji = allowedEmotes.where((e) => e.runes.length <= 2).toList();
    final phrases = allowedEmotes.where((e) => e.runes.length > 2).toList();
    return Dialog(
      backgroundColor: C.panelSolid,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in emoji)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => Navigator.pop(context, e),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in phrases)
                    ActionChip(
                      label: Text(p),
                      onPressed: () => Navigator.pop(context, p),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      side: BorderSide(color: C.gold.withValues(alpha: 0.35)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choosing trump the way the top apps do it: pick a suit. The lowest card of that suit is
/// hidden face down (tapping a card in your hand still works for picking a specific one).
class _TrumpPicker extends StatelessWidget {
  const _TrumpPicker({required this.view, required this.onPick});

  final PlayerView view;
  final void Function(String code) onPick;

  @override
  Widget build(BuildContext context) {
    final options = view.legal.trumpCards.map(Card.parse).toList();
    return Panel(
      color: C.panelSolid,
      radius: AppRadius.lg,
      border: C.gold.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('You won the bid at ${view.highestBid}', style: const TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 2),
          const Text('Choose trump', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final suit in Suit.values)
                Builder(
                  builder: (context) {
                    final held = options.where((c) => c.suit == suit).toList()
                      ..sort((a, b) => a.rank.power - b.rank.power);
                    final enabled = held.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Opacity(
                        opacity: enabled ? 1 : 0.3,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: enabled ? () => onPick(held.first.code) : null,
                          child: Column(
                            children: [
                              _SuitChip(suit: suit, size: 46),
                              const SizedBox(height: 5),
                              Text(
                                enabled ? '${held.length} held' : 'none',
                                style: const TextStyle(fontSize: 10.5, color: C.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Its lowest card goes face down. Or tap a card in your hand.',
            style: TextStyle(fontSize: 11, color: C.faint),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ round summary

class _RoundSummary extends StatelessWidget {
  const _RoundSummary({required this.view, required this.session});

  final PlayerView view;
  final TableSession session;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final r = v.lastRound;
    if (r == null) return const SizedBox.shrink();
    final weBid = r.bidder % 2 == v.myTeam;
    final weWon = r.success == weBid;
    final matchOver = v.phase == Phase.matchOver;
    final matchWon = v.matchWinner == v.myTeam;
    final accent = matchOver ? (matchWon ? C.good : C.bad) : (weWon ? C.good : C.bad);

    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Panel(
          color: C.panelSolid,
          radius: AppRadius.lg,
          border: accent.withValues(alpha: 0.5),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (matchOver) ...[GoldText(matchWon ? 'You win!' : 'You lose', size: 30), const SizedBox(height: 10)],
              Text(
                '${session.seatName(r.bidder)} bid ${r.bid}${r.target != r.bid ? ' · target ${r.target}' : ''}',
                style: const TextStyle(color: C.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _PointsColumn(label: 'US', points: v.teamPoints[v.myTeam], color: C.us),
                  Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
                  _PointsColumn(label: 'THEM', points: v.teamPoints[1 - v.myTeam], color: C.them),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${r.success ? 'Contract made' : 'Contract failed'}  ${r.delta > 0 ? '+' : ''}${r.delta}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              _MatchPips(score: v.matchScore[v.myTeam], color: C.us, label: 'US'),
              const SizedBox(height: 6),
              _MatchPips(score: v.matchScore[1 - v.myTeam], color: C.them, label: 'THEM'),
              const SizedBox(height: 16),
              if (matchOver)
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to menu'))
              else
                const Text('Next deal starting…', style: TextStyle(color: C.faint, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsColumn extends StatelessWidget {
  const _PointsColumn({required this.label, required this.points, required this.color});

  final String label;
  final int points;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4),
        ),
        Text(
          '$points',
          style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w700, height: 1.2),
        ),
        const Text('card points', style: TextStyle(color: C.faint, fontSize: 10)),
      ],
    ),
  );
}

/// Match score as six pips per team: first to +6 wins the match, -6 loses it.
class _MatchPips extends StatelessWidget {
  const _MatchPips({required this.score, required this.color, required this.label});

  final int score;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(color: C.faint, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        for (var i = 1; i <= 6; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: score >= i ? color : Colors.transparent,
              border: Border.all(color: score <= -i ? C.bad.withValues(alpha: 0.7) : color.withValues(alpha: 0.35)),
            ),
          ),
        SizedBox(
          width: 26,
          child: Text(
            '${score > 0 ? '+' : ''}$score',
            textAlign: TextAlign.right,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
