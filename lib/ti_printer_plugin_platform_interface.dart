import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ti_printer_plugin_method_channel.dart';

abstract class TiPrinterPluginPlatform extends PlatformInterface {
  /// Constructs a TiPrinterPluginPlatform.
  TiPrinterPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static TiPrinterPluginPlatform _instance = MethodChannelTiPrinterPlugin();

  /// The default instance of [TiPrinterPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelTiPrinterPlugin].
  static TiPrinterPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TiPrinterPluginPlatform] when
  /// they register themselves.
  static set instance(TiPrinterPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool?> openSerialPort(String portName, int baudRate) {
    throw UnimplementedError('openSerialPort() has not been implemented.');
  }

  Future<bool?> closeSerialPort() async {
    throw UnimplementedError('closeSerialPort() has not been implemented.');
  }

  Future<Uint8List?> readStatusSerial(Uint8List command) async {
    throw UnimplementedError('readStatusSerial() has not been implemented.');
  }

  Future<bool?> sendCommandToSerial(Uint8List command) async {
    throw UnimplementedError('sendCommandToSerial() has not been implemented.');
  }

  Future<bool?> sendCommandToUsb(Uint8List command) async {
    throw UnimplementedError('sendCommandToUsb() has not been implemented.');
  }

  Future<List<String>> getUsbPrinters() {
    return TiPrinterPluginPlatform.instance.getUsbPrinters();
  }

  Future<bool?> openUsbPort(String deviceInstanceId) {
    throw UnimplementedError('openUsbPort() has not been implemented.');
  }

  Future<bool?> closeUsbPort() {
    throw UnimplementedError('closeUsbPort() has not been implemented.');
  }

  Future<Uint8List?> readStatusUsb(Uint8List command) {
    throw UnimplementedError('readStatusUsb() has not been implemented.');
  }
}
