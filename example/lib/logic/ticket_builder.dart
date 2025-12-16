// example/lib/logic/ticket_builder.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/enums.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/generator.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/pos_column.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/pos_styles.dart';
import 'package:ti_printer_plugin_example/item.dart';
import 'package:ti_printer_plugin_example/uils/image_utils.dart';

class TicketBuilder {
  final CapabilityProfile profile;
  late final Generator printer;

  TicketBuilder(this.profile) {
    printer = Generator(PaperSize.mm80, profile);
  }

  /// Aquí pegas la lógica de armado de ticket que antes estaba en sendDataUsb
  /// pero devolviendo la lista de bytes.
  Future<List<int>> buildTicket({
    required List<Item> items,
    required String nroReferencia,
    required double total,
    required double efectivo,
    required double cambio,
    required String qrData,
  }) async {
    List<int> command = [];

    // 1. Header
    _createHeader(command);

    _createDetailTicket(
      command,
      '99',
      '89',
      '00788',
      'CAJERO SUPER',
      '123456',
    );

    // 2. Detalle items
    _createItems(command, items);

    // 3. Totales
    _createTotalTicket(
      command,
      items,
      nroReferencia,
      total,
      efectivo,
      cambio,
    );

    // 4. QR
    final qrImg = await _generateQR(qrData);
    command += printer.imageRaster(qrImg, align: PosAlign.center);

    // 5. Pie del ticket
    _createFooter(command);

    // 6. Corte
    command += printer.cut();

    return command;
  }

  void _createFooter(List<int> command) {
    // Pie de página
    command += printer.hr();
    command += printer.text(
      '¡Gracias por su compra!',
      styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'),
    );
  }

  // === A partir de aquí trasladas tal cual tus helpers privados ===

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

  void _createHeader(List<int> command) async {
    const pathLogo = 'assets/dino_logo_bg.png';
    final logoImage = await _createLogo(pathLogo);

    command = [];

    if (logoImage != null) {
      //bytes += generator.feed(1);
      command += printer.imageRaster(logoImage, align: PosAlign.center);
      command += printer.feed(1);
    }

    // Cabecera comprobante
    command += printer.text(
      'DINOSAURIO S.A',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 1,
    );

    command += printer.text(
      'CUIT Nro: 30-69847147-2',
      styles: const PosStyles(align: PosAlign.left),
    );
    command += printer.text(
      'ING. BRUTOS: 9043011028',
      styles: const PosStyles(align: PosAlign.left),
    );
    command += printer.text(
      'COD.VALID.RENTAS: 20000005668804',
      styles: const PosStyles(align: PosAlign.left),
    );
    command += printer.text(
      'INICIO ACT.: 03/12/2003',
      styles: const PosStyles(align: PosAlign.left),
    );

    command += printer.text(
      'DOM.FISC: Rodriguez del Busto 4086',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );
    command += printer.row([
      PosColumn(
          text: 'Alto Verde',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'CP: 5009',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    command += printer.row([
      PosColumn(
          text: 'Cordoba Capital',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Cordoba',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    command += printer.text(
      'TEL: 0351-5261500',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );
    command += printer.text(
      'DOM.COM: Rodriguez del Busto 4086',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );
    command += printer.row([
      PosColumn(
          text: 'Alto Verde',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'CP: 5009',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    command += printer.row([
      PosColumn(
          text: 'Cordoba Capital',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Cordoba',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    command += printer.text(
      'IVA RESPONSABLE INSCRIPTO',
      styles: const PosStyles(align: PosAlign.left),
    );
  }

  Future<img.Image?> _createLogo(String path) async {
    final ByteData data = await rootBundle.load(path);
    img.Image? logoImage;

    if (data.lengthInBytes > 0) {
      final Uint8List imageBytes = data.buffer.asUint8List();
      final decodedImage = img.decodeImage(imageBytes)!;
      img.Image thumbnail = img.copyResize(
        decodedImage,
        height: 130,
      );
      img.Image originalImg =
          img.copyResize(decodedImage, width: 380, height: 130);
      img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));
      var padding = (originalImg.width - thumbnail.width) / 2;

      drawImage(originalImg, thumbnail, dstX: padding.toInt());
      logoImage = img.grayscale(originalImg);
    }
    return logoImage;
  }

  void _createItems(List<int> command, List<Item> items) {
    // Items comprobante
    command += printer.hr();
    command += printer.row([
      PosColumn(
        text: 'Item',
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
    ]);

    for (var item in items) {
      command += printer.row([
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
          text: '\$${item.precio}',
          width: 3,
          styles: const PosStyles(align: PosAlign.left),
        ),
      ]);
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
    // Detalle comprobante
    command += printer.row([
      PosColumn(
          text: 'Negocio: $negocio',
          width: 4,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: '- POS: $negocio',
          width: 4,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: '- PV: $puntoVenta',
          width: 4,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    command += printer.row([
      PosColumn(
          text: 'Cajero: $cajero',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Legajo: $legajo',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);

    command += printer.row([
      PosColumn(
          text: 'Fecha: ${DateFormat('dd/MM/yy').format(DateTime.now())}',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Hora: ${DateFormat('HH:mm').format(DateTime.now())}',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    command += printer.hr();
    command += printer.text(
      'FACTURA B',
      styles: const PosStyles(align: PosAlign.left),
    );
  }

  void _createTotalTicket(
    List<int> command,
    List<Item> items,
    String nroReferencia,
    double total,
    double efectivo,
    double cambio,
  ) {
    // Total
    final subTotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.cantidad * item.precio),
    );
    const descuentos = 0;
    // Descuentos y subtotal
    command += printer.hr();
    command += printer.row([
      PosColumn(
          text: 'NroRef:',
          width: 3,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: nroReferencia,
          width: 3,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Items:',
          width: 3,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: '${items.length}',
          width: 3,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);

    command += printer.row([
      PosColumn(
          text: 'DESCUENTOS POR PROMOCIONES',
          width: 8,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: '\$${descuentos.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);

    var total = subTotal - descuentos;

    command += printer.hr();
    command += printer.row([
      PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: '\$${total.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);

    // Método de pago
    command += printer.hr();
    command += printer.text(
      'Método de pago: Efectivo',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );

    // Información del cliente
    command += printer.text(
      'Cliente: Juan Pérez',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );
    command += printer.text(
      'Número de cliente: 12345',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );
  }
}
