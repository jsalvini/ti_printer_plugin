// example/lib/logic/ticket_builder.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image/image.dart' as img;

import 'package:ti_printer_plugin_example/ui/item.dart';
import 'package:ti_printer_plugin_example/uils/image_utils.dart';

import 'package:ti_printer_plugin/esc_pos_utils_platform/esc_pos_utils_platform.dart';

class TicketBuilder {
  final CapabilityProfile profile;
  late final Generator printer;

  TicketBuilder(this.profile) {
    printer = Generator(PaperSize.mm80, profile);
  }

  Future<List<int>> buildTicket({
    required List<Item> items,
    required String nroReferencia,
    required double total,
    required double efectivo,
    required double cambio,
    required String qrData,
  }) async {
    List<int> command = [];

    // 1. Header (ahora sí esperamos a que cargue el logo)
    await _createHeader(command);

    // 2. Datos fijos de detalle (negocio, pos, etc.)
    _createDetailTicket(
      command,
      '99',
      '89',
      '00788',
      'CAJERO SUPER',
      '123456',
    );

    // 3. Items
    _createItems(command, items);

    // 4. Totales
    _createTotalTicket(
      command,
      items,
      nroReferencia,
      total,
      efectivo,
      cambio,
    );

    // 5. QR
    final qrImg = await _generateQR(qrData);
    command.addAll(printer.imageRaster(qrImg, align: PosAlign.center));

    // 6. Pie
    _createFooter(command);

    // 7. Corte
    command.addAll(printer.cut());

    return command;
  }

  void _createFooter(List<int> command) {
    command.addAll(printer.hr());
    command.addAll(printer.text(
      '¡Gracias por su compra!',
      styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'),
    ));
  }

  Future<img.Image> _generateQR(String data) async {
    const double qrSize = 300;
    final uiImg = await QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
    ).toImageData(qrSize);

    final dir = await getTemporaryDirectory();
    final pathName = '${dir.path}/qr_tmp.png';
    final qrFile = File(pathName);
    await qrFile.writeAsBytes(uiImg!.buffer.asUint8List());

    final imageBytes = qrFile.readAsBytesSync();
    final decodedImage = img.decodeImage(imageBytes)!;

    img.Image thumbnail = img.copyResize(decodedImage, height: 300);
    img.Image originalImg =
        img.copyResize(decodedImage, width: 300, height: 300);
    img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));

    drawImage(originalImg, thumbnail);

    var grayscaleImage = img.grayscale(originalImg);
    final bytes = img.encodePng(grayscaleImage);
    return img.decodePng(bytes)!;
  }

  Future<void> _createHeader(List<int> command) async {
    final logoBytes = await _buildLogoBytes();

    if (logoBytes != null) {
      command.addAll(printer.setStyles(
        const PosStyles(align: PosAlign.center),
      ));
      command.addAll(logoBytes);
      command.addAll(printer.feed(1));
    }

    // Cabecera comprobante (lo que ya tenías)
    command.addAll(printer.text(
      'TIPRE S.A',
      styles: const PosStyles(
        fontType: PosFontType.fontA,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        align: PosAlign.center,
        underline: true,
      ),
    ));

    command.addAll(printer.text(
      'Razon social: TIPRE S.A',
      styles: const PosStyles(align: PosAlign.left),
    ));
    command.addAll(printer.text(
      'Dirección: Av. Fuerza Aérea Argentina 1700',
      styles: const PosStyles(align: PosAlign.left),
    ));
    command.addAll(printer.text(
      'CUIT: 30-50004623-7',
      styles: const PosStyles(align: PosAlign.left),
    ));
    command.addAll(printer.text(
      'IIBB: 901-427263-2',
      styles: const PosStyles(align: PosAlign.left),
    ));
    command.addAll(printer.text(
      'Inicio de actividades: 23/06/1989',
      styles: const PosStyles(align: PosAlign.left),
    ));

    command.addAll(printer.hr());
    command.addAll(printer.text(
      'IVA RESPONSABLE INSCRIPTO',
      styles: const PosStyles(align: PosAlign.left),
    ));
  }

  Future<List<int>?> _buildLogoBytes() async {
    const pathLogo = 'assets/logo.png';
    try {
      final ByteData data = await rootBundle.load(pathLogo);
      if (data.lengthInBytes == 0) return null;

      final Uint8List imageBytes = data.buffer.asUint8List();
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return null;

      const int targetHeight = 130;
      final resized = img.copyResize(decodedImage, height: targetHeight);
      final int width = resized.width;
      final int height = resized.height;
      final int paddedWidth =
          width % 8 == 0 ? width : width + (8 - width % 8);
      final int bytesPerRow = paddedWidth ~/ 8;

      final List<int> rgba = resized.getBytes(order: img.ChannelOrder.rgba);

      final bitmap = Uint8List(bytesPerRow * height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < paddedWidth; x++) {
          bool isDark = false;
          if (x < width) {
            final int idx = (y * width + x) * 4;
            final int r = rgba[idx];
            final int g = rgba[idx + 1];
            final int b = rgba[idx + 2];
            final int a = rgba[idx + 3];
            if (a > 128) {
              final int lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
              isDark = lum < 128;
            }
          }
          if (isDark) {
            final int byteIndex = y * bytesPerRow + (x ~/ 8);
            final int bitIndex = 7 - (x % 8);
            bitmap[byteIndex] |= (1 << bitIndex);
          }
        }
      }

      List<int> bytes = [];
      bytes += [0x1D, 0x76, 0x30, 0x00];
      bytes += [bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF];
      bytes += [height & 0xFF, (height >> 8) & 0xFF];
      bytes += bitmap;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _createItems(List<int> command, List<Item> items) {
    command.addAll(printer.hr());
    command.addAll(printer.row([
      PosColumn(
        text: 'Producto',
        width: 7,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: 'Cant.',
        width: 2,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: 'Precio',
        width: 3,
        styles: const PosStyles(align: PosAlign.left),
      ),
    ]));

    for (var item in items) {
      command.addAll(printer.row([
        PosColumn(
          text: item.producto,
          width: 7,
          styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        PosColumn(
          text: '${item.cantidad}',
          width: 2,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: '\$${item.precio.toStringAsFixed(2)}',
          width: 3,
          styles: const PosStyles(align: PosAlign.left),
        ),
      ]));
    }
  }

  void _createDetailTicket(
    List<int> command,
    String negocio,
    String pos,
    String puntoVenta,
    String cajero,
    String legajo,
  ) {
    command.addAll(printer.row([
      PosColumn(
          text: 'Negocio: $negocio',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'POS: $pos',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]));

    command.addAll(printer.row([
      PosColumn(
          text: 'Punto de venta: $puntoVenta',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Caja: 1',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]));

    command.addAll(printer.row([
      PosColumn(
          text: 'Cajero: $cajero',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Legajo: $legajo',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]));

    command.addAll(printer.row([
      PosColumn(
          text: 'Fecha: ${DateFormat('dd/MM/yy').format(DateTime.now())}',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Hora: ${DateFormat('HH:mm').format(DateTime.now())}',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]));
    command.addAll(printer.hr());
    command.addAll(printer.text(
      'FACTURA B',
      styles: const PosStyles(align: PosAlign.left),
    ));
  }

  void _createTotalTicket(
    List<int> command,
    List<Item> items,
    String nroReferencia,
    double total,
    double efectivo,
    double cambio,
  ) {
    final subTotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.cantidad * item.precio),
    );

    const descuentos = 0.0;
    final totalCalculado = subTotal - descuentos;

    command.addAll(printer.hr());
    command.addAll(printer.row([
      PosColumn(
          text: 'SUBTOTAL',
          width: 8,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: '\$${subTotal.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]));

    command.addAll(printer.row([
      PosColumn(
          text: 'DESCUENTOS',
          width: 8,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: '\$${descuentos.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]));

    command.addAll(printer.hr());
    command.addAll(printer.row([
      PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
      PosColumn(
          text: '\$${totalCalculado.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
    ]));

    command.addAll(printer.hr());
    command.addAll(printer.text(
      'Nro ref: $nroReferencia',
      styles: const PosStyles(align: PosAlign.left),
    ));
    command.addAll(printer.text(
      'Método de pago: Efectivo',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    ));

    command.addAll(printer.text(
      'Cliente: Juan Pérez',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    ));
    command.addAll(printer.text(
      'Número de cliente: 12345',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    ));
  }
}

