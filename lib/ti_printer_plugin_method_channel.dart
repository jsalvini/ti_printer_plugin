import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'printer_device_info.dart';
import 'ti_printer_plugin_platform_interface.dart';

/// An implementation of [TiPrinterPluginPlatform] that uses method channels.
class MethodChannelTiPrinterPlugin extends TiPrinterPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ti_printer_plugin');

  @override
  Future<String> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version ?? 'Unknown';
  }

  @override
  Future<bool> openSerialPort(String portName, int baudRate) {
    return _invokeBoolMethod('openSerialPort', {
      'portName': portName,
      'baudRate': baudRate,
    });
  }

  @override
  Future<bool> closeSerialPort() {
    return _invokeBoolMethod('closeSerialPort');
  }

  @override
  Future<bool> sendCommandToSerial(Uint8List command) {
    return _invokeBoolMethod('sendCommandToSerial', command);
  }

  @override
  Future<bool> sendCommandToUsb(Uint8List command) {
    return _invokeBoolMethod('sendCommandToUsb', command);
  }

  @override
  Future<Uint8List> readStatusSerial(Uint8List command) {
    return _invokeBytesMethod('readStatusSerial', command);
  }

  @override
  Future<List<PrinterDeviceInfo>> getUsbPrinters() async {
    try {
      final List<dynamic>? list =
          await methodChannel.invokeMethod<List<dynamic>>('getUsbPrinters');
      if (list == null) return const [];
      return list
          .map((e) =>
              PrinterDeviceInfo.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<bool> openUsbPort(String deviceInstanceId) {
    return _invokeBoolMethod('openUsbPort', {
      'deviceInstanceId': deviceInstanceId,
    });
  }

  @override
  Future<bool> closeUsbPort() {
    return _invokeBoolMethod('closeUsbPort');
  }

  @override
  Future<Uint8List> readStatusUsb(Uint8List command) {
    return _invokeBytesMethod('readStatusUsb', command);
  }

  Future<bool> _invokeBoolMethod(String method, [dynamic arguments]) async {
    try {
      return await methodChannel.invokeMethod<bool>(method, arguments) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Uint8List> _invokeBytesMethod(
      String method, [dynamic arguments]) async {
    try {
      return await methodChannel.invokeMethod<Uint8List>(method, arguments) ??
          Uint8List(0);
    } on PlatformException {
      return Uint8List(0);
    } on MissingPluginException {
      return Uint8List(0);
    }
  }
}
