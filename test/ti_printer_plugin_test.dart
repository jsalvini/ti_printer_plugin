import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ti_printer_plugin/ti_printer_plugin.dart';
import 'package:ti_printer_plugin/ti_printer_plugin_platform_interface.dart';
import 'package:ti_printer_plugin/ti_printer_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTiPrinterPluginPlatform
    with MockPlatformInterfaceMixin
    implements TiPrinterPluginPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool?> openSerialPort(String portName, int baudRate) {
    throw UnimplementedError();
  }

  @override
  Future<bool?> closeSerialPort() {
    throw UnimplementedError();
  }

  @override
  Future<bool> openUsbPort(String portName) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> readStatusSerial(Uint8List command) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getUsbPrinters() {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> readStatusUsb(Uint8List command) {
    throw UnimplementedError();
  }

  @override
  Future<bool?> sendCommandToSerial(Uint8List command) {
    throw UnimplementedError();
  }

  @override
  Future<bool?> sendCommandToUsb(Uint8List command) {
    throw UnimplementedError();
  }

  @override
  Future<bool?> closeUsbPort() {
    throw UnimplementedError();
  }
}

void main() {
  final TiPrinterPluginPlatform initialPlatform =
      TiPrinterPluginPlatform.instance;

  test('$MethodChannelTiPrinterPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTiPrinterPlugin>());
  });

  test('getPlatformVersion', () async {
    TiPrinterPlugin tiPrinterPlugin = TiPrinterPlugin();
    MockTiPrinterPluginPlatform fakePlatform = MockTiPrinterPluginPlatform();
    TiPrinterPluginPlatform.instance = fakePlatform;

    expect(await tiPrinterPlugin.getPlatformVersion(), '42');
  });
}
