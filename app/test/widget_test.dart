import 'package:flutter_test/flutter_test.dart';
import 'package:nova_vpn_app/app.dart';

void main() {
  testWidgets('NOVA VPN app renders its branded shell', (tester) async {
    await tester.pumpWidget(const NovaVpnApp());
    await tester.pump();
    expect(find.text('NOVA VPN'), findsOneWidget);
  });
}
