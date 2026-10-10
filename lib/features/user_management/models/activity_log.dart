/// Actions tracées dans le journal d'activité.
class LogAction {
  static const login = 'LOGIN';
  static const logout = 'LOGOUT';
  static const loginFailed = 'LOGIN_FAILED';
  static const register = 'REGISTER';
  static const updateProfile = 'UPDATE_PROFILE';
  static const changePassword = 'CHANGE_PASSWORD';
  static const resetPassword = 'RESET_PASSWORD';
  static const createUser = 'CREATE_USER';
  static const changeRole = 'CHANGE_ROLE';
  static const blockUser = 'BLOCK_USER';
  static const unblockUser = 'UNBLOCK_USER';
  static const deleteUser = 'DELETE_USER';
  static const availability = 'AVAILABILITY';
  static const resetCodeSent = 'RESET_CODE_SENT';
  static const biometricLogin = 'BIOMETRIC_LOGIN';
  static const googleLogin = 'GOOGLE_LOGIN';
  static const accountLocked = 'ACCOUNT_LOCKED';
  static const emailVerified = 'EMAIL_VERIFIED';
  static const twoFactorLogin = 'TWO_FACTOR_LOGIN';
  static const twoFactorSetting = 'TWO_FACTOR_SETTING';
  static const sessionExpired = 'SESSION_EXPIRED';
  static const referral = 'REFERRAL';
  static const deleteOwnAccount = 'DELETE_OWN_ACCOUNT';
  static const exportData = 'EXPORT_DATA';
  static const bulkEmail = 'BULK_EMAIL';
  static const uploadDocument = 'UPLOAD_DOCUMENT';

  /// Actions affichées dans « Historique des connexions ».
  static const loginActions = [
    login, biometricLogin, googleLogin, twoFactorLogin, loginFailed, accountLocked,
  ];

  static const all = [
    login, logout, loginFailed, register, updateProfile, changePassword,
    resetPassword, createUser, changeRole, blockUser, unblockUser,
    deleteUser, availability, resetCodeSent, biometricLogin, googleLogin,
    accountLocked, emailVerified, twoFactorLogin, twoFactorSetting,
    sessionExpired, referral, deleteOwnAccount, exportData, bulkEmail,
    uploadDocument,
  ];
}

class ActivityLog {
  final int? id;
  final int? userId;
  final String action;
  final String? details;
  final DateTime date;

  /// Rempli par jointure (affichage dans le journal admin).
  final String? userEmail;

  const ActivityLog({
    this.id,
    this.userId,
    required this.action,
    this.details,
    required this.date,
    this.userEmail,
  });

  factory ActivityLog.fromMap(Map<String, Object?> m) => ActivityLog(
        id: m['id'] as int?,
        userId: m['user_id'] as int?,
        action: m['action'] as String,
        details: m['details'] as String?,
        date: DateTime.parse(m['date'] as String),
        userEmail: m['email'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'action': action,
        'details': details,
        'date': date.toIso8601String(),
      };
}
