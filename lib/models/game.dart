class Game {
  Game({
    required this.id,
    required this.title,
    this.platform = 'PS4',
    this.front = '',
    this.sourceId = '',
    this.back = '',
    this.disc = '',
    this.description = '',
    this.genre = '',
    this.year = '',
    this.rating = '',
    this.players = '',
    this.notes = '',
    this.finished = false,
    this.platinum = false,
    this.complete = false,
    this.favorite = false,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  static const platforms = [
    'PS1',
    'PS2',
    'PS3',
    'PS4',
    'PS5',
    'Steam',
    'Android',
  ];
  String id, title, platform, front, back, disc, sourceId;
  String description, genre, year, rating, players, notes;
  bool finished, platinum, complete, favorite;
  DateTime created;

  factory Game.empty() =>
      Game(id: DateTime.now().microsecondsSinceEpoch.toString(), title: '');
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'platform': platform,
    'front': front,
    'sourceId': sourceId,
    'back': back,
    'disc': disc,
    'description': description,
    'genre': genre,
    'year': year,
    'rating': rating,
    'players': players,
    'notes': notes,
    'finished': finished,
    'platinum': platinum,
    'complete': complete,
    'favorite': favorite,
    'created': created.toIso8601String(),
  };

  factory Game.fromJson(Map<String, dynamic> j) {
    String text(String key, [String fallback = '']) {
      final value = j[key] ?? fallback;
      if (value is! String) throw FormatException('Campo inválido: $key');
      return value;
    }

    bool flag(String key) {
      final value = j[key] ?? false;
      if (value is! bool) throw FormatException('Estado inválido: $key');
      return value;
    }

    final platform = text('platform', 'PS4');
    final id = text('id');
    final title = text('title');
    if (!platforms.contains(platform) || id.isEmpty || title.trim().isEmpty) {
      throw const FormatException('Jogo inválido no arquivo.');
    }
    return Game(
      id: id,
      title: title,
      platform: platform,
      front: text('front'),
      sourceId: text('sourceId'),
      back: text('back'),
      disc: text('disc'),
      description: text('description'),
      genre: text('genre'),
      year: text('year'),
      rating: text('rating'),
      players: text('players'),
      notes: text('notes'),
      finished: flag('finished'),
      platinum: flag('platinum'),
      complete: flag('complete'),
      favorite: flag('favorite'),
      created: DateTime.parse(text('created')),
    );
  }
  Game copy() => Game.fromJson(toJson());
}
