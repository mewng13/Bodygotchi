// Widget test for the 보디고치 login screen.
//
// Auth is now fully local (SQLite + Google SDK), so we test the LoginPage
// widget directly — its build doesn't touch the DB until a button is tapped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bodygotchi/screens/login_page.dart';

void main() {
  testWidgets('Login page shows email + Google sign-in options',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    // Email + password fields and the primary action are present.
    expect(find.text('이메일'), findsWidgets);
    expect(find.text('비밀번호'), findsWidgets);
    expect(find.text('로그인'), findsWidgets);

    // Google sign-in is offered.
    expect(find.text('Google로 계속하기'), findsOneWidget);

    // The sign-up toggle exists.
    expect(find.text('회원가입'), findsOneWidget);
  });
}
