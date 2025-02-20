import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ti_printer_plugin_platform_interface.dart';

/// An implementation of [TiPrinterPluginPlatform] that uses method channels.
class MethodChannelTiPrinterPlugin extends TiPrinterPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ti_printer_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<bool?> openSerialPort(String portName, int baudRate) async {
    try {
      final bool? result = await methodChannel.invokeMethod('openSerialPort', {
        'portName': portName,
        'baudRate': baudRate,
      });
      return result;
    } on PlatformException {
      //log("Error al abrir el puerto serial: ${e.message}");
      return false;
    }
  }

  @override
  Future<bool?> closeSerialPort() async {
    try {
      final bool? result = await methodChannel.invokeMethod('closeSerialPort');
      return result;
    } on PlatformException {
      //log("Error al cerrar el puerto serial: ${e.message}");
      return false;
    }
  }

  @override
  Future<bool?> sendCommandToSerial(Uint8List command) async {
    try {
      final bool result =
          await methodChannel.invokeMethod('sendCommandToSerial', command);
      //log('Result: $result');
      return result;
    } on PlatformException {
      //log("Error: ${e.message}");
      return false;
    }
  }

  @override
  Future<bool?> sendCommandToUsb(Uint8List command) async {
    try {
      final bool result =
          await methodChannel.invokeMethod('sendCommandToUsb', command);
      //log('Result: $result');
      return result;
    } on PlatformException {
      //log("Error: ${e.message}");
      return false;
    }
  }

  @override
  Future<Uint8List?> readStatusSerial(Uint8List command) async {
    try {
      Uint8List commandBytes = Uint8List.fromList(command);
      final Uint8List? result = await methodChannel
          .invokeMethod('readStatusSerial', {'command': commandBytes});
      /*if (result != null) {
        log('Estado de la impresora recibido: $result');
      }*/
      return result;
    } catch (e) {
      //log("Error al obtener el estado de la impresora: $e");
      return null;
    }
  }

  @override
  Future<List<String>> getUsbPrinters() async {
    try {
      final List<dynamic> printerInstances =
          await methodChannel.invokeMethod('getUsbPrinters');
      return printerInstances.cast<String>();
    } on PlatformException {
      //log("Error al abrir el puerto USB: ${e.message}");
      return [];
    }
  }

  @override
  Future<bool?> openUsbPort(String deviceInstanceId) async {
    try {
      final bool? result = await methodChannel
          .invokeMethod('openUsbPort', {'deviceInstanceId': deviceInstanceId});
      return result;
    } on PlatformException {
      //log("Error al abrir el puerto USB: ${e.message}");
      return false;
    }
  }

  @override
  Future<Uint8List?> readStatusUsb(Uint8List command) async {
    try {
      Uint8List commandBytes = Uint8List.fromList(command);
      final Uint8List? result = await methodChannel
          .invokeMethod('readStatusUsb', {'command': commandBytes});
      if (result != null) {
        //log('Estado de la impresora recibido: $result');
      }
      return result;
    } catch (e) {
      //log("Error al obtener el estado de la impresora: $e");
      return null;
    }
  }
}
