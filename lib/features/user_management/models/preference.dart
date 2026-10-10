class Preference {
  final int userId;
  final String? allergies;
  final String langue;
  final bool notifications;

  const Preference({
    required this.userId,
    this.allergies,
    this.langue = 'fr',
    this.notifications = true,
  });

  factory Preference.fromMap(Map<String, Object?> m) => Preference(
        userId: m['user_id'] as int,
        allergies: m['allergies'] as String?,
        langue: m['langue'] as String,
        notifications: (m['notifications'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        'user_id': userId,
        'allergies': allergies,
        'langue': langue,
        'notifications': notifications ? 1 : 0,
      };
}
