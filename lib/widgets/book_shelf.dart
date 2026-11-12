import 'dart:io';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/case_profile.dart';
import '../services/collection_store.dart';

/// Responsive shelves with readable, upright spines and continuous boards.
class BookShelf extends StatelessWidget {
  const BookShelf({
    super.key,
    required this.games,
    required this.store,
    required this.onOpen,
    this.onPlatforms,
    this.onReorder,
  });
  final List<Game> games;
  final CollectionStore store;
  final ValueChanged<Game> onOpen;
  final ValueChanged<Game>? onPlatforms;
  final void Function(Game, Game)? onReorder;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = ((constraints.maxWidth - 40) / 53).floor().clamp(1, 24);
      return ListView.builder(
        key: const ValueKey('book-shelves'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: (games.length / columns).ceil(),
        itemBuilder: (context, row) => Column(
          children: [
            Container(
              height: 250,
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xff080d15), Color(0xff17212b)],
                ),
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: Colors.white.withValues(alpha: .08),
                    width: 5,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final game in games.skip(row * columns).take(columns))
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: DragTarget<Game>(
                        onWillAcceptWithDetails: (d) =>
                            d.data.id != game.id && onReorder != null,
                        onAcceptWithDetails: (d) =>
                            onReorder?.call(d.data, game),
                        builder: (context, candidates, rejected) =>
                            LongPressDraggable<Game>(
                              key: ValueKey('shelf-${game.id}'),
                              data: game,
                              feedback: Material(
                                color: Colors.transparent,
                                child: _Spine(
                                  game: game,
                                  store: store,
                                  onTap: () {},
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: .3,
                                child: _Spine(
                                  game: game,
                                  store: store,
                                  onTap: () {},
                                ),
                              ),
                              child: _Spine(
                                game: game,
                                store: store,
                                onTap: () => onOpen(game),
                                onPlatforms: onPlatforms == null
                                    ? null
                                    : () => onPlatforms!(game),
                              ),
                            ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              height: 13,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xff52717b),
                    Color(0xff263a46),
                    Color(0xff101a23),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xaa000000),
                    blurRadius: 12,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

class _Spine extends StatelessWidget {
  const _Spine({
    required this.game,
    required this.store,
    required this.onTap,
    this.onPlatforms,
  });
  final Game game;
  final CollectionStore store;
  final VoidCallback onTap;
  final VoidCallback? onPlatforms;
  @override
  Widget build(BuildContext context) {
    final profile = CaseProfile.forPlatform(game.platform);
    final height = game.platform == 'PS1'
        ? 170.0
        : game.platform == 'PS2' || game.platform == 'Steam'
        ? 230.0
        : 212.0;
    return Semantics(
      button: true,
      label: '${game.title}, ${game.platformLabel}',
      child: Tooltip(
        message: game.title,
        triggerMode: TooltipTriggerMode.manual,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(3),
            child: Container(
              width: 45,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: profile.shell,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.white.withValues(alpha: .18)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(3, 0),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (game.front.isNotEmpty)
                    Positioned.fill(
                      child: Image.file(
                        File(store.thumb(game.front)),
                        fit: BoxFit.cover,
                        color: const Color(0xbb14202c),
                        colorBlendMode: BlendMode.srcOver,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                    ),
                  Column(
                    children: [
                      Container(
                        height: 27,
                        color: profile.brand,
                        alignment: Alignment.center,
                        child: Text(
                          game.platform.isEmpty ? '?' : game.platform,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: profile.ink,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                game.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        game.platinum
                            ? Icons.workspace_premium
                            : game.favorite
                            ? Icons.star
                            : Icons.sports_esports,
                        size: 15,
                        color: game.platinum
                            ? Colors.lightBlueAccent
                            : Colors.white70,
                      ),
                      if (onPlatforms != null)
                        SizedBox(
                          width: 32,
                          height: 28,
                          child: PopupMenuButton<String>(
                            tooltip: 'Opções de ${game.title}',
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: const Icon(
                              Icons.more_horiz,
                              color: Colors.white,
                            ),
                            onSelected: (_) => onPlatforms!(),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'platforms',
                                child: Text('Plataformas'),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 10),
                    ],
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: .40),
                              Colors.white.withValues(alpha: .12),
                              Colors.transparent,
                              Colors.black.withValues(alpha: .55),
                            ],
                            stops: const [0, .15, .65, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
