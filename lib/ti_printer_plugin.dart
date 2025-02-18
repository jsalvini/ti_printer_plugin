import 'dart:typed_data';

import 'ti_printer_plugin_platform_interface.dart';

class TiPrinterPlugin {
  Future<String?> getPlatformVersion() {
    return TiPrinterPluginPlatform.instance.getPlatformVersion();
  }

  Future<bool?> openSerialPort(String portName, int baudRate) {
    return TiPrinterPluginPlatform.instance.openSerialPort(portName, baudRate);
  }

  Future<bool?> closeSerialPort() {
    return TiPrinterPluginPlatform.instance.closeSerialPort();
  }

  Future<Uint8List?> readStatusSerial(Uint8List command) {
    return TiPrinterPluginPlatform.instance.readStatusSerial(command);
  }

  Future<bool?> sendCommandToSerial(Uint8List command) async {
    return TiPrinterPluginPlatform.instance.sendCommandToSerial(command);
  }

  Future<List<String>> getUsbPrinters() {
    return TiPrinterPluginPlatform.instance.getUsbPrinters();
  }

  Future<bool?> openUsbPort(String deviceInstanceId) {
    return TiPrinterPluginPlatform.instance.openUsbPort(deviceInstanceId);
  }

  Future<Uint8List?> readStatusUsb(Uint8List command) {
    return TiPrinterPluginPlatform.instance.readStatusUsb(command);
  }

  Future<bool?> sendCommandToUsb(Uint8List command) async {
    return TiPrinterPluginPlatform.instance.sendCommandToUsb(command);
  }
}
