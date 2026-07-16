import 'package:flutter_test/flutter_test.dart';
import 'package:ghostnet_cyber_vpn/main.dart';

void main() {
  group('GhostNet security contract', () {
    test('API uses HTTPS', () {
      expect(apiBaseUrl.startsWith('https://'), isTrue);
    });

    test('email and Telegram username do not grant admin rights', () {
      final profile = UserProfile.fromJson(
        const {
          'id': 1,
          'email': 'baltazzap@gmail.com',
          'telegram_username': 'baltazzap',
          'is_active': true,
          'is_admin': false,
          'is_support': false,
        },
        'test-token',
      );

      expect(profile.isAdmin, isFalse);
    });

    test('server response can grant admin rights', () {
      final profile = UserProfile.fromJson(
        const {
          'id': 2,
          'email': 'admin@example.com',
          'telegram_username': 'admin',
          'is_active': true,
          'is_admin': true,
          'is_support': false,
        },
        'test-token',
      );

      expect(profile.isAdmin, isTrue);
    });
  });
}
