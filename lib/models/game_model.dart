enum GameCategory {
  memory,
  attention,
  mentalMath,
  problemSolving,
  iqTest,
  fun,
}

class GameModel {
  final String id;
  final String title;
  final String description;
  final GameCategory category;
  final String icon;
  final int difficulty;
  final int maxScore;
  final Map<String, dynamic>? config;

  GameModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.difficulty,
    required this.maxScore,
    this.config,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.toString(),
      'icon': icon,
      'difficulty': difficulty,
      'maxScore': maxScore,
      'config': config,
    };
  }

  factory GameModel.fromMap(Map<String, dynamic> map) {
    return GameModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: GameCategory.values.firstWhere(
        (e) => e.toString() == map['category'],
      ),
      icon: map['icon'] as String,
      difficulty: map['difficulty'] as int,
      maxScore: map['maxScore'] as int,
      config: map['config'] as Map<String, dynamic>?,
    );
  }
}
