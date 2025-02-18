import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ti_printer_plugin/ti_printer_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelTiPrinterPlugin platform = MethodChannelTiPrinterPlugin();
  const MethodChannel channel = MethodChannel('ti_printer_plugin');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
