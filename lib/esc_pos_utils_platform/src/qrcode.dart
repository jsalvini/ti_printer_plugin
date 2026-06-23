/*
 * esc_pos_utils
 * Created by Andrey U.
 *
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 *
 * PATCHED:
 *   - FIX #4: codificación pL/pH correcta para payloads > 252 bytes.
 *   - FIX #5: utf8.encode en lugar de latin1.encode (QR carga binario; URLs
 *     con caracteres fuera de Latin-1 ya no tiran ArgumentError, y los
 *     lectores móviles decodifican UTF-8 por estándar).
 */

import 'dart:convert';

import 'commands.dart';

class QRSize {
  const QRSize(this.value);
  final int value;

  static const size1 = QRSize(0x01);
  static const size2 = QRSize(0x02);
  static const size3 = QRSize(0x03);
  static const size4 = QRSize(0x04);
  static const size5 = QRSize(0x05);
  static const size6 = QRSize(0x06);
  static const size7 = QRSize(0x07);
  static const size8 = QRSize(0x08);
}

/// QR Correction level
class QRCorrection {
  const QRCorrection._internal(this.value);
  final int value;

  /// Level L: Recovery Capacity 7%
  static const L = QRCorrection._internal(48);

  /// Level M: Recovery Capacity 15%
  static const M = QRCorrection._internal(49);

  /// Level Q: Recovery Capacity 25%
  static const Q = QRCorrection._internal(50);

  /// Level H: Recovery Capacity 30%
  static const H = QRCorrection._internal(51);
}

class QRCode {
  List<int> bytes = <int>[];

  QRCode(String text, QRSize size, QRCorrection level) {
    // FN 167. QR Code: Set the size of module
    // pL pH cn fn n
    bytes += cQrHeader.codeUnits + [0x03, 0x00, 0x31, 0x43] + [size.value];

    // FN 169. QR Code: Select the error correction level
    // pL pH cn fn n
    bytes += cQrHeader.codeUnits + [0x03, 0x00, 0x31, 0x45] + [level.value];

    // FN 180. QR Code: Store the data in the symbol storage area
    // FIX #5: utf8.encode soporta cualquier carácter (URLs con tilde, emoji,
    // etc.). La versión anterior usaba latin1.encode y tiraba ArgumentError
    // ante cualquier carácter fuera de 0x00-0xFF.
    final List<int> textBytes = utf8.encode(text);

    // FIX #4: pL = (len + 3) & 0xFF, pH = ((len + 3) >> 8) & 0xFF.
    // La versión anterior hardcodeaba pH = 0x00 y ponía textBytes.length + 3
    // en pL → overflow silencioso para payloads > 252 bytes (URLs largas de
    // ARCA, links con muchos parámetros, etc.).
    final int storeLen = textBytes.length + 3;
    final int storePL = storeLen & 0xFF;
    final int storePH = (storeLen >> 8) & 0xFF;
    // pL pH cn fn m
    bytes += cQrHeader.codeUnits + [storePL, storePH, 0x31, 0x50, 0x30];
    bytes += textBytes;

    // FN 182. QR Code: Transmit the size information of the symbol data in the symbol storage area
    // pL pH cn fn m
    bytes += cQrHeader.codeUnits + [0x03, 0x00, 0x31, 0x52, 0x30];

    // FN 181. QR Code: Print the symbol data in the symbol storage area
    // pL pH cn fn m
    bytes += cQrHeader.codeUnits + [0x03, 0x00, 0x31, 0x51, 0x30];
  }
}
