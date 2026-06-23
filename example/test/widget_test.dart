import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ti_printer_plugin_example/main.dart';

void main() {
  testWidgets('renders printer status example without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Estado impresora'), findsOneWidget);
    expect(find.text('Estado impresora USB'), findsOneWidget);
    expect(find.text('Consola'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
