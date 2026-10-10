import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/features/user_management/services/password_hasher.dart';

void main() {
  test('Le hachage du mot de passe est vérifiable', () {
    final salt = PasswordHasher.generateSalt();
    final h = PasswordHasher.hash('Admin@123', salt);
    expect(PasswordHasher.verify('Admin@123', salt, h), isTrue);
    expect(PasswordHasher.verify('mauvais', salt, h), isFalse);
  });

  test('Règles du mot de passe', () {
    expect(PasswordHasher.validate('court'), isNotNull);
    expect(PasswordHasher.validate('Motdepasse1'), isNull);
  });
}
