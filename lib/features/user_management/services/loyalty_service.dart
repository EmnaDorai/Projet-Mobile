import '../dao/history_repository.dart';
import '../dao/user_dao.dart';

enum LoyaltyLevel { bronze, argent, or }

extension LoyaltyLevelX on LoyaltyLevel {
  String get label => switch (this) {
        LoyaltyLevel.bronze => 'Bronze',
        LoyaltyLevel.argent => 'Argent',
        LoyaltyLevel.or => 'Or',
      };

  /// Points minimum pour atteindre ce niveau.
  int get minPoints => switch (this) {
        LoyaltyLevel.bronze => 0,
        LoyaltyLevel.argent => 200,
        LoyaltyLevel.or => 500,
      };
}

class LoyaltyInfo {
  final int pointsCommandes; // 1 point par dinar dépensé
  final int pointsBonus; // parrainage
  final int nbCommandes;
  final String? codeParrainage;
  final int filleuls;
  const LoyaltyInfo({
    required this.pointsCommandes,
    required this.pointsBonus,
    required this.nbCommandes,
    required this.codeParrainage,
    required this.filleuls,
  });

  int get total => pointsCommandes + pointsBonus;

  LoyaltyLevel get level => total >= LoyaltyLevel.or.minPoints
      ? LoyaltyLevel.or
      : total >= LoyaltyLevel.argent.minPoints
          ? LoyaltyLevel.argent
          : LoyaltyLevel.bronze;

  LoyaltyLevel? get nextLevel => switch (level) {
        LoyaltyLevel.bronze => LoyaltyLevel.argent,
        LoyaltyLevel.argent => LoyaltyLevel.or,
        LoyaltyLevel.or => null,
      };

  /// Progression (0 → 1) vers le niveau suivant.
  double get progress {
    final next = nextLevel;
    if (next == null) return 1;
    final from = level.minPoints;
    return ((total - from) / (next.minPoints - from)).clamp(0, 1).toDouble();
  }
}

/// Programme de fidélité : points calculés à partir de l'historique des
/// commandes (module Commandes) + points bonus de parrainage.
class LoyaltyService {
  Future<LoyaltyInfo> get(int userId) async {
    final stats = await HistoryRepository().getClientStats(userId);
    final ref = await UserDao().referralInfo(userId);
    return LoyaltyInfo(
      pointsCommandes: stats.totalDepense.floor(),
      pointsBonus: ref.bonus,
      nbCommandes: stats.nbCommandes,
      codeParrainage: ref.code,
      filleuls: ref.filleuls,
    );
  }
}
