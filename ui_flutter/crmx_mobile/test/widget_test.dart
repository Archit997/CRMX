import 'package:crmx_mobile/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CRMX app renders auth screen', (tester) async {
    await tester.pumpWidget(const CRMXMobileApp());
    await tester.pumpAndSettle();

    expect(find.text('CRMX'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('POC users'), findsOneWidget);
  });
}
