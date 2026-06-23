import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ti_printer_plugin/ti_printer_plugin.dart';
import 'package:ti_printer_plugin/ti_printer_plugin_method_channel.dart';
import 'package:ti_printer_plugin/ti_printer_plugin_platform_interface.dart';

class MockTiPrinterPluginPlatform
    with MockPlatformInterfaceMixin
    implements TiPrinterPluginPlatform {
  @override
  Future<String> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> openSerialPort(String portName, int baudRate) =>
      Future.value(false);

  @override
  Future<bool> closeSerialPort() => Future.value(false);

  @override
  Future<bool> openUsbPort(String deviceInstanceId) => Future.value(true);

  @override
  Future<List<String>> getUsbPrinters() =>
      Future.value(<String>['USB001']);

  @override
  Future<Uint8List> readStatusSerial(Uint8List command) =>
      Future.value(Uint8List.fromList(<int>[0x12]));

  @override
  Future<Uint8List> readStatusUsb(Uint8List command) =>
      Future.value(Uint8List.fromList(<int>[0x16]));

  @override
  Future<bool> sendCommandToSerial(Uint8List command) => Future.value(true);

  @override
  Future<bool> sendCommandToUsb(Uint8List command) => Future.value(true);

  @override
  Future<bool> closeUsbPort() => Future.value(true);
}

void main() {
  final TiPrinterPluginPlatform initialPlatform =
      TiPrinterPluginPlatform.instance;

  test('$MethodChannelTiPrinterPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTiPrinterPlugin>());
  });

  test('plugin delegates to platform implementation', () async {
    final TiPrinterPlugin tiPrinterPlugin = TiPrinterPlugin();
    final MockTiPrinterPluginPlatform fakePlatform =
        MockTiPrinterPluginPlatform();
    TiPrinterPluginPlatform.instance = fakePlatform;

    expect(await tiPrinterPlugin.getPlatformVersion(), '42');
    expect(await tiPrinterPlugin.openUsbPort('USB001'), isTrue);
    expect(await tiPrinterPlugin.closeUsbPort(), isTrue);
    expect(await tiPrinterPlugin.getUsbPrinters(), <String>['USB001']);
    expect(
      await tiPrinterPlugin.readStatusUsb(Uint8List.fromList(<int>[0x10])),
      Uint8List.fromList(<int>[0x16]),
    );
  });
}
