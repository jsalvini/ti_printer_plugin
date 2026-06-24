import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ti_printer_plugin/ti_printer_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelTiPrinterPlugin platform = MethodChannelTiPrinterPlugin();
  const MethodChannel channel = MethodChannel('ti_printer_plugin');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => '42',
    );

    expect(await platform.getPlatformVersion(), '42');
  });

  test('openUsbPort returns bool from native layer', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      expect(methodCall.method, 'openUsbPort');
      expect(methodCall.arguments, <String, dynamic>{
        'deviceInstanceId': 'USB001',
      });
      return true;
    });

    expect(await platform.openUsbPort('USB001'), isTrue);
  });

  test('closeUsbPort returns false on platform exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      throw PlatformException(code: 'ERROR', message: 'close failed');
    });

    expect(await platform.closeUsbPort(), isFalse);
  });

  test('readStatusUsb returns bytes from native layer', () async {
    final Uint8List expected = Uint8List.fromList(<int>[0x10, 0x04, 0x01]);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      expect(methodCall.method, 'readStatusUsb');
      expect(methodCall.arguments, Uint8List.fromList(<int>[0x10, 0x04, 0x01]));
      return expected;
    });

    expect(
      await platform.readStatusUsb(Uint8List.fromList(<int>[0x10, 0x04, 0x01])),
      expected,
    );
  });

  test('readStatusUsb normalizes native errors to empty bytes', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      throw PlatformException(code: 'ERROR', message: 'no status');
    });

    expect(await platform.readStatusUsb(Uint8List.fromList(<int>[0x10])), isEmpty);
  });

  test('openSerialPort returns false on missing implementation', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      throw MissingPluginException('unsupported');
    });

    expect(await platform.openSerialPort('COM3', 9600), isFalse);
  });
}
