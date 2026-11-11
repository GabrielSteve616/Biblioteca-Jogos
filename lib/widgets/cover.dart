import 'dart:io';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../services/collection_store.dart';
import '../theme/cyber_theme.dart';
import 'progress_stickers.dart';

class Cover extends StatelessWidget {
  const Cover({
    super.key,
    required this.game,
    required this.store,
    this.thumbnail = true,
  });
  final Game game;
  final CollectionStore store;
  final bool thumbnail;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff154451), Color(0xff171727)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.sports_esports_outlined,
            size: 36,
            color: Cyber.cyan,
          ),
          const SizedBox(height: 12),
          Text(
            game.title.isEmpty ? 'Sua próxima história' : game.title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return CustomPaint(
      foregroundPainter: CornerStickersPainter(game),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Cyber.cyan.withValues(alpha: .06), blurRadius: 14),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Cyber.cyan.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: platformColor(game.platform),
                border: Border(
                  bottom: BorderSide(color: Cyber.cyan.withValues(alpha: .5)),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                game.platform,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: game.front.isEmpty
                  ? fallback()
                  : Image.file(
                      File(
                        thumbnail
                            ? store.thumb(game.front)
                            : store.path(game.front),
                      ),
                      fit: BoxFit.cover,
                      cacheWidth: thumbnail ? 240 : 1000,
                      errorBuilder: (_, _, _) => fallback(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Color platformColor(String platform) => switch (platform) {
  'PS1' => const Color(0xff505d6d),
  'PS2' => const Color(0xff172f67),
  'PS5' => const Color(0xff526379),
  'Android' => const Color(0xff25333f),
  'PS3' => const Color(0xff24252d),
  'PS4' => const Color(0xff075bb5),
  _ => const Color(0xff153d52),
};

class ProgressBadges extends StatelessWidget {
  const ProgressBadges({super.key, required this.game});
  final Game game;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 5,
    runSpacing: 4,
    children: [
      if (game.favorite)
        const Icon(Icons.favorite, size: 15, color: Color(0xffff879e)),
      if (game.finished)
        const Icon(Icons.check_circle, size: 15, color: Color(0xff78dfb2)),
      if (game.platinum)
        const Icon(Icons.emoji_events, size: 15, color: Color(0xffc4d9ed)),
      if (game.complete)
        const Text(
          '100%',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xffedcd88),
            fontWeight: FontWeight.bold,
          ),
        ),
    ],
  );
}
