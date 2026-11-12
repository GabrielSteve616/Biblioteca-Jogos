class Game {
  Game({
    required this.id,
    required this.title,
    this.platform = 'PS4',
    List<String>? additionalPlatforms,
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
  }) : additionalPlatforms = additionalPlatforms ?? [],
       created = created ?? DateTime.now();

  static const platforms = [
    'PS1',
    'PS2',
    'PS3',
    'PS4',
    'PS5',
    'Steam',
    'Android',
  ];
  static const unassigned = 'Sem plataforma definida';
  List<String> additionalPlatforms;
  List<String> get assignedPlatforms =>
      {if (platform.isNotEmpty) platform, ...additionalPlatforms}.toList();
  set assignedPlatforms(Iterable<String> values) {
    final next = values.toSet().toList();
    if (next.any((p) => !platforms.contains(p))) {
      throw const FormatException('Plataforma inválida.');
    }
    platform = next.isEmpty ? '' : next.first;
    additionalPlatforms = next.skip(1).toList();
  }

  String get platformLabel =>
      assignedPlatforms.isEmpty ? unassigned : assignedPlatforms.join(' • ');
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
    'additionalPlatforms': additionalPlatforms,
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
    final extra = j['additionalPlatforms'] ?? <String>[];
    if (extra is! List ||
        extra.any((p) => p is! String || !platforms.contains(p)) ||
        extra.toSet().length != extra.length ||
        extra.contains(platform) ||
        (platform.isEmpty && extra.isNotEmpty)) {
      throw const FormatException('Coleções inválidas.');
    }
    if ((platform.isNotEmpty && !platforms.contains(platform)) ||
        id.isEmpty ||
        title.trim().isEmpty) {
      throw const FormatException('Jogo inválido no arquivo.');
    }
    return Game(
      id: id,
      title: title,
      platform: platform,
      additionalPlatforms: List<String>.from(extra),
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
