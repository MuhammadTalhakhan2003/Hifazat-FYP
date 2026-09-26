import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/api/models/user.dart';
import 'package:hifazat_app/providers/user_provider.dart';
import 'package:hifazat_app/screens/profile_screen.dart';
import 'package:provider/provider.dart';

class _FakeUserProvider extends UserProvider {
  _FakeUserProvider(this._fakeUser, this._score);

  final User _fakeUser;
  final int _score;

  @override
  User? get user => _fakeUser;

  @override
  Reputation? get reputation =>
      Reputation(userId: _fakeUser.id, username: _fakeUser.username, reputationScore: _score);

  @override
  Future<void> fetchCurrentUser({bool force = false}) async {}
}

User _user({required bool verified, bool staff = false}) => User(
      id: 1,
      username: 'OsmanBey',
      email: 'osman@example.com',
      isStaff: staff,
      profile: UserProfile(isTrustedReporter: verified),
    );

Future<void> _pump(WidgetTester tester, UserProvider provider, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<UserProvider>.value(
      value: provider,
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => ApiClient.instance.initialize());

  for (final size in const [Size(390, 844), Size(1920, 1000)]) {
    testWidgets('unverified citizen at ${size.width.toInt()}px', (tester) async {
      await _pump(tester, _FakeUserProvider(_user(verified: false), 0), size);

      expect(find.text('Not verified'), findsOneWidget);
      expect(find.text('Your account is not verified yet'), findsOneWidget);
      expect(find.text('Newcomer'), findsWidgets);
      expect(find.text('25 points to Contributor'), findsOneWidget);
    });

    testWidgets('verified admin at ${size.width.toInt()}px', (tester) async {
      await _pump(tester, _FakeUserProvider(_user(verified: true, staff: true), 120), size);

      expect(find.text('Verified reporter'), findsOneWidget);
      expect(find.text('You are a verified reporter'), findsOneWidget);
      expect(find.text('Guardian'), findsWidgets);
      expect(find.text('Administrator'), findsOneWidget);
    });
  }
}
