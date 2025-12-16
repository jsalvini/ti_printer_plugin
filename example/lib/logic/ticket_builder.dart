// example/lib/logic/ticket_builder.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
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
    const pathLogo = 'assets/logo_bg.png';
    final logoImage = await _createLogo(pathLogo);

    if (logoImage != null) {
      command.addAll(printer.imageRaster(logoImage, align: PosAlign.center));
      command.addAll(printer.feed(1));
    }

    // Cabecera comprobante (lo que ya tenías)
    command.addAll(printer.text(
      'DINOSAURIO S.A',
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
      'Razon social: DINOSAURIO S.A',
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
