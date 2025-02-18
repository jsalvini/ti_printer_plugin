import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/enums.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/generator.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/pos_column.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/pos_styles.dart';
import 'package:ti_printer_plugin/ti_printer_plugin.dart';
import 'package:ti_printer_plugin_example/item.dart';
import 'package:ti_printer_plugin_example/uils/image_utils.dart';
import 'package:ti_printer_plugin_example/uils/printer_status_interpreter.dart';
import 'package:image/image.dart' as img;

class PrinterStatusWiew extends StatefulWidget {
  const PrinterStatusWiew({super.key});

  @override
  PrinterStatusWiewState createState() => PrinterStatusWiewState();
}

class PrinterStatusWiewState extends State<PrinterStatusWiew> {
  final TiPrinterPlugin tiPrinterPlugin = TiPrinterPlugin();
  late CapabilityProfile profile;
  late Generator printer;
  List<int> command = [];

  bool enLineaSerial = false;
  bool tapaAbiertaSerial = true;
  bool papelPorAcabarseSerial = true;
  bool papelPresenteSerial = false;

  bool enLineaUsb = false;
  bool tapaAbiertaUsb = true;
  bool papelPorAcabarseUsb = true;
  bool papelPresenteUsb = false;

  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
    openSerialPort();
    openUSBPort();
    checkSerialStatus();
    checkUsbStatus();
  }

  Future<void> initPlatformState() async {
    profile = await CapabilityProfile.load();
    printer = Generator(PaperSize.mm80, profile);

    String platformVersion;
    try {
      platformVersion = await tiPrinterPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void openSerialPort() async {
    try {
      final result = await tiPrinterPlugin.openSerialPort('COM10', 9600);

      log('Result openPort: $result');
    } catch (e) {
      log('Error al abrir el puerto serial: $e');
    }
  }

  // Función para verificar el estado de la impresora serial
  Future<void> checkSerialStatus() async {
    profile = await CapabilityProfile.load();
    printer = Generator(PaperSize.mm80, profile);
    Uint8List byteData;

    command = [];
    // Obtener el estado general de la impresora (n = 1 para Printer status)
    command.addAll(printer.status());
    byteData = Uint8List.fromList(command);

    Uint8List? onLinePrinterStatus =
        await tiPrinterPlugin.readStatusSerial(byteData);

    if (onLinePrinterStatus != null) {
      PrinterStatusInterpreter.interpretOnlinePrinterStatus(onLinePrinterStatus,
          (coverOpenStatus, paperFeed, paperEnd, error) {
        setState(() {
          enLineaSerial = !error;
        });
      });
      // Obtener el estado del sensor de papel (n = 4 para roll paper sensor)
      command = [];
      command.addAll(printer.paperSensorStatus());
      byteData = Uint8List.fromList(command);

      Uint8List? paperStatus = await tiPrinterPlugin.readStatusSerial(byteData);
      if (paperStatus != null) {
        PrinterStatusInterpreter.interpretRollPaperSensorStatus(paperStatus,
            (nearEnd, present) {
          setState(() {
            papelPorAcabarseSerial = nearEnd;
            papelPresenteSerial = present;
          });
        });
      }
    }
    command = [];
    // Obtener el estado general de la impresora (n = 2 para offline cause)
    command.addAll(printer.offLineStatus());

    byteData = Uint8List.fromList(command);

    Uint8List? offlineCauseStatus =
        await tiPrinterPlugin.readStatusSerial(byteData);

    //log(offlineCauseStatus.toString());

    if (offlineCauseStatus != null) {
      PrinterStatusInterpreter.interpretOfflineCauseStatus(offlineCauseStatus,
          (coverOpenStatus, paperFeed, paperEnd, error) {
        setState(() {
          tapaAbiertaSerial = coverOpenStatus;
          enLineaSerial = !error;
        });
      });
      // Obtener el estado del sensor de papel (n = 4 para roll paper sensor)
      command = [];
      command.addAll(printer.paperSensorStatus());
      byteData = Uint8List.fromList(command);

      Uint8List? paperStatus = await tiPrinterPlugin.readStatusSerial(byteData);
      if (paperStatus != null) {
        PrinterStatusInterpreter.interpretRollPaperSensorStatus(paperStatus,
            (nearEnd, present) {
          setState(() {
            papelPorAcabarseSerial = nearEnd;
            papelPresenteSerial = present;
          });
        });
      }
    } else {
      setState(() {
        enLineaSerial = false;
        tapaAbiertaSerial = true;
        papelPorAcabarseSerial = true;
        papelPresenteSerial = false;
      });
    }
  }

  void listUSBPort() async {
    try {
      final result = await tiPrinterPlugin.getUsbPrinters();

      log('Result list USB Port: $result');
    } catch (e) {
      log('Error al listar impresoras USB: $e');
    }
  }

  void openUSBPort() async {
    try {
      // Reemplaza \ con \\
      const deviceInstanceId = 'USB\\VID_067B&PID_2305\\5&3B800540&1&9';
      //String formattedInstanceId = deviceInstanceId.replaceAll(r'\', r'\\');

      final result = await tiPrinterPlugin.openUsbPort(deviceInstanceId);

      log('Result openPort USB: $result');
    } catch (e) {
      log('Error al abrir el puerto USB: $e');
    }
  }

  // Función para verificar el estado de la impresora USB
  Future<void> checkUsbStatus() async {
    profile = await CapabilityProfile.load();
    printer = Generator(PaperSize.mm80, profile);
    Uint8List byteData;

    command = [];
    // Obtener el estado general de la impresora (n = 1 para Printer status)
    command.addAll(printer.status());
    byteData = Uint8List.fromList(command);

    Uint8List? onLinePrinterStatus =
        await tiPrinterPlugin.readStatusUsb(byteData);

    if (onLinePrinterStatus != null) {
      PrinterStatusInterpreter.interpretOnlinePrinterStatus(onLinePrinterStatus,
          (coverOpenStatus, paperFeed, paperEnd, error) {
        setState(() {
          enLineaUsb = !error;
        });
      });
      // Obtener el estado del sensor de papel (n = 4 para roll paper sensor)
      command = [];
      command.addAll(printer.paperSensorStatus());
      byteData = Uint8List.fromList(command);

      Uint8List? paperStatus = await tiPrinterPlugin.readStatusUsb(byteData);
      if (paperStatus != null) {
        PrinterStatusInterpreter.interpretRollPaperSensorStatus(paperStatus,
            (nearEnd, present) {
          setState(() {
            papelPorAcabarseUsb = nearEnd;
            papelPresenteUsb = present;
          });
        });
      }
    }
    command = [];
    // Obtener el estado general de la impresora (n = 2 para offline cause)
    command.addAll(printer.offLineStatus());

    byteData = Uint8List.fromList(command);

    Uint8List? offlineCauseStatus =
        await tiPrinterPlugin.readStatusUsb(byteData);

    //log(offlineCauseStatus.toString());

    if (offlineCauseStatus != null) {
      PrinterStatusInterpreter.interpretOfflineCauseStatus(offlineCauseStatus,
          (coverOpenStatus, paperFeed, paperEnd, error) {
        setState(() {
          tapaAbiertaUsb = coverOpenStatus;
          enLineaUsb = !error;
        });
      });
      // Obtener el estado del sensor de papel (n = 4 para roll paper sensor)
      command = [];
      command.addAll(printer.paperSensorStatus());
      byteData = Uint8List.fromList(command);

      Uint8List? paperStatus = await tiPrinterPlugin.readStatusUsb(byteData);
      if (paperStatus != null) {
        PrinterStatusInterpreter.interpretRollPaperSensorStatus(paperStatus,
            (nearEnd, present) {
          setState(() {
            papelPorAcabarseUsb = nearEnd;
            papelPresenteUsb = present;
          });
        });
      }
    } else {
      setState(() {
        enLineaUsb = false;
        tapaAbiertaUsb = true;
        papelPorAcabarseUsb = true;
        papelPresenteUsb = false;
      });
    }
  }

  void sendDataUsb() async {
    List<int> escPosCommand = await _generateTicket();
    // Convertir List<int> a Uint8List
    Uint8List byteData = Uint8List.fromList(escPosCommand);
    bool? success = await tiPrinterPlugin.sendCommandToUsb(byteData);

    if (success!) {
      log("Ticket enviado correctamente al puerto USB.");
    } else {
      log("Error al enviar ticket al puerto USB.");
    }
  }

  void sendDataSerial() async {
    List<int> escPosCommand = await _generateTicket();
    // Convertir List<int> a Uint8List
    Uint8List byteData = Uint8List.fromList(escPosCommand);
    bool? success = await tiPrinterPlugin.sendCommandToSerial(byteData);

    if (success!) {
      log("Ticket enviado correctamente al puerto serial.");
    } else {
      log("Error al enviar ticket al puerto serial.");
    }
  }

  Future<img.Image> _generateQR(String qrData, double qrSize) async {
    // 1. Generar codigo QR
    final uiImg = await QrPainter(
      data: qrData,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      version: QrVersions.auto,
      gapless: false,
    ).toImageData(qrSize);

    // 2. Guardar la imagen en un archivo temporal
    final dir = await getTemporaryDirectory();
    final pathName = '${dir.path}/qr_tmp.png';
    // Escribe la imagen QR como archivo temporal
    final qrFile = File(pathName);
    await qrFile.writeAsBytes(uiImg!.buffer.asUint8List());

    // 3. Leer la imagen desde la ubicación temporal
    final imageBytes = qrFile.readAsBytesSync();
    final decodedImage = img.decodeImage(imageBytes)!;

    // 4. Procesar la imagen, crear miniaturas, original y aplicar relleno/blanco
    img.Image thumbnail = img.copyResize(decodedImage, height: 300);
    img.Image originalImg =
        img.copyResize(decodedImage, width: 300, height: 300);
    img.fill(originalImg, color: img.ColorRgb8(255, 255, 255));

    drawImage(originalImg, thumbnail);

    var grayscaleImage = img.grayscale(originalImg);

    return grayscaleImage;
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

  void _createHeader() {
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

  void _createDetailTicket({
    required String negocio,
    required String pos,
    required String puntoVenta,
    required String cajero,
    required String legajo,
  }) {
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

  void _createItems(List<Item> items) {
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

  Future<List<int>> _generateTicket() async {
    // TODO: PARAMETRIZAR IMAGEN LOGO
    const pathLogo = 'assets/dino_logo_bg.png';
    final logoImage = await _createLogo(pathLogo);

    command = [];

    if (logoImage != null) {
      //bytes += generator.feed(1);
      command += printer.imageRaster(logoImage, align: PosAlign.center);
      command += printer.feed(1);
    }

    _createHeader();
    // TODO: VER OBTENCION DATOS
    _createDetailTicket(
      negocio: '99',
      pos: '89',
      puntoVenta: '00788',
      cajero: 'CAJERO SUPER',
      legajo: '123456',
    );

    /*final List<Item> items = [
      Item(producto: 'Sussex OF-RC', cantidad: 2.0000, precio: 1999.0000),
      Item(producto: 'PAPEL HIGI OF-', cantidad: 1.0000, precio: 2740.0000),
      Item(producto: 'PALTA TORRE X', cantidad: 1.0000, precio: 517.86),
      Item(producto: 'DORITOS QU', cantidad: 1.0000, precio: 4123.0000),
      Item(producto: 'CE OF-', cantidad: 1.0000, precio: 2848.0000),
      Item(producto: 'BLS CAM.CBA.N', cantidad: 1.0000, precio: 50.00),
    ];*/

    final List<Item> items = [
      Item(producto: 'Sussex OF-RC', cantidad: 2.0000, precio: 1999.0000),
      Item(producto: 'PAPEL HIGI OF-', cantidad: 1.0000, precio: 2740.0000),
      Item(producto: 'PALTA TORRE X', cantidad: 1.0000, precio: 517.86),
      Item(producto: 'DORITOS QU', cantidad: 1.0000, precio: 4123.0000),
      Item(producto: 'CE OF-', cantidad: 1.0000, precio: 2848.0000),
      Item(producto: 'BLS CAM.CBA.N', cantidad: 1.0000, precio: 50.00),
      Item(producto: 'CHOCOLATE MOUS', cantidad: 3.0000, precio: 123.45),
      Item(producto: 'YOGURT NATURAL', cantidad: 5.0000, precio: 60.20),
      Item(producto: 'PAN INTEGRAL', cantidad: 2.0000, precio: 75.00),
      Item(producto: 'QUESO RALLADO', cantidad: 4.0000, precio: 320.99),
      Item(producto: 'MERMELADA FRESA', cantidad: 2.0000, precio: 185.50),
      Item(producto: 'PASTA PENNE', cantidad: 1.0000, precio: 150.30),
      Item(producto: 'ZAPALLO OF-', cantidad: 1.5000, precio: 89.75),
      Item(producto: 'JABÓN LÍQUIDO', cantidad: 3.0000, precio: 215.40),
      Item(producto: 'SODA LIMÓN', cantidad: 6.0000, precio: 60.00),
      Item(producto: 'LECHE ENTERA', cantidad: 8.0000, precio: 190.80),
      Item(producto: 'GASEOSA COLA', cantidad: 2.0000, precio: 45.90),
      Item(producto: 'HARINA DE TRIGO', cantidad: 1.0000, precio: 120.00),
      Item(producto: 'GEL DE DUCHA', cantidad: 2.0000, precio: 340.70),
      Item(producto: 'ACEITE DE OLIVA', cantidad: 1.0000, precio: 500.00),
      Item(producto: 'PAPAS FRITAS', cantidad: 2.0000, precio: 230.00),
      Item(producto: 'CAFÉ MOLIDO', cantidad: 3.0000, precio: 550.50),
      Item(producto: 'GALLETAS CHOC', cantidad: 5.0000, precio: 75.20),
      Item(producto: 'CEREAL MULTI', cantidad: 1.0000, precio: 295.00),
      Item(producto: 'JAMÓN IBERICO', cantidad: 0.5000, precio: 1500.00),
      Item(producto: 'TOALLAS COCINA', cantidad: 2.0000, precio: 65.00),
      Item(producto: 'PAÑUELOS DESC.', cantidad: 3.0000, precio: 85.50),
      Item(producto: 'TÉ VERDE', cantidad: 4.0000, precio: 130.00),
      Item(producto: 'MAYONESA LIGHT', cantidad: 2.0000, precio: 200.75),
      Item(producto: 'PASTILLAS MENTOL', cantidad: 10.0000, precio: 12.00),
      Item(producto: 'LIMONADA CASERA', cantidad: 6.0000, precio: 240.00),
      Item(producto: 'ARROZ JAZMÍN', cantidad: 2.0000, precio: 350.20),
      Item(producto: 'TOMATES CHERRY', cantidad: 1.5000, precio: 60.50),
      Item(producto: 'SALSA SOYA', cantidad: 2.0000, precio: 190.00),
      Item(producto: 'ESPAGUETIS', cantidad: 1.0000, precio: 180.25),
      Item(producto: 'CREMA DE MANÍ', cantidad: 3.0000, precio: 475.60),
      Item(producto: 'SARDINAS ENLATADAS', cantidad: 5.0000, precio: 220.75),
      Item(producto: 'DESODORANTE SPRAY', cantidad: 2.0000, precio: 300.99),
      Item(producto: 'ATÚN DESMENUZADO', cantidad: 3.0000, precio: 220.00),
      Item(producto: 'GOMA DE MASCAR', cantidad: 20.0000, precio: 15.50),
      Item(producto: 'PASTELERÍA INTEGRAL', cantidad: 2.0000, precio: 375.00),
      Item(producto: 'VINAGRE DE MANZANA', cantidad: 1.0000, precio: 90.00),
      Item(producto: 'ZANAHORIAS FRESCAS', cantidad: 1.5000, precio: 95.00),
      Item(producto: 'PECHUGA DE POLLO', cantidad: 2.0000, precio: 780.90),
      Item(producto: 'ESPUMA AFEITAR', cantidad: 1.0000, precio: 210.00),
      Item(producto: 'DETERGENTE LÍQUIDO', cantidad: 3.0000, precio: 650.25),
      Item(producto: 'CERVEZAS ARTESANALES', cantidad: 4.0000, precio: 280.40),
      Item(producto: 'JABÓN EN BARRA', cantidad: 10.0000, precio: 18.50),
      Item(producto: 'PAN MOLDE INTEGRAL', cantidad: 2.0000, precio: 150.30),
      Item(producto: 'LECHUGA AMERICANA', cantidad: 1.0000, precio: 75.40),
    ];

    _createItems(items);

    // Total
    final subTotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.cantidad * item.precio),
    );
    const descuentos = 0;

    int nroReferencia = 625856;
    // Descuentos y subtotal
    command += printer.hr();
    command += printer.row([
      PosColumn(
          text: 'NroRef:',
          width: 3,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: '$nroReferencia',
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

    String qrData =
        "https://www.afip.gob.ar/fe/qr/?p=eyJ2ZXIiOjEsImZlY2hhIjoiMjAyNC0wOC0wOCIsImN1aXQiOjMwNjEyOTI5NDU1LCJwdG9WdGEiOjMwNDIsInRpcG9DbXAiOjYsIm5yb0NtcCI6NDY2MTEsImltcG9ydGUiOjEwNDk1NjYsIm1vbmVkYSI6IlBFUyIsImN0eiI6MSwidGlwb0RvY1JlYyI6OTksIm5yb0RvY1JlYyI6MCwidGlwb0NvZEF1dCI6IkUiLCJjb2RBdXQiOjc0MzI1Nzk4NDM5OTQzfQ==";
    const double qrSize = 300;

    img.Image imgQR = await _generateQR(qrData, qrSize);

    command += printer.feed(1);
    command += printer.imageRaster(imgQR, align: PosAlign.center);
    command += printer.feed(1);

    // Pie de página
    command += printer.hr();
    command += printer.text(
      '¡Gracias por su compra!',
      styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'),
    );
    command.addAll(printer.cut());

    return command;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Column(
          children: [
            Card(
              surfaceTintColor: Colors.blueAccent,
              elevation: 3,
              shadowColor: Colors.black,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: Text(
                    'Plataforma: $_platformVersion',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                direction: Axis.horizontal,
                spacing: 20, // Espacio horizontal entre las columnas
                runSpacing: 20, // Espacio vertical entre filas
                children: [
                  Card(
                    elevation: 3,
                    surfaceTintColor: Colors.amberAccent,
                    shadowColor: Colors.black,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width > 600
                          ? MediaQuery.of(context).size.width *
                              0.45 // 45% del ancho si la pantalla es grande
                          : MediaQuery.of(context).size.width *
                              1.0, // 100% del ancho si la pantalla es estrecha
                      child: ListView(
                        shrinkWrap:
                            true, // Permite que el ListView tome solo el espacio necesario
                        physics:
                            const NeverScrollableScrollPhysics(), // Desactiva el scroll para que no interfiera con el Wrap
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'Estado impresora serial',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaSerial
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: enLineaSerial ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              'Impresora ${enLineaSerial ? 'en línea' : 'fuera de línea'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaSerial
                                  ? (tapaAbiertaSerial
                                      ? Icons.warning
                                      : Icons.check)
                                  : Icons.warning,
                              color: enLineaSerial
                                  ? (tapaAbiertaSerial
                                      ? Colors.red
                                      : Colors.green)
                                  : Colors.red,
                            ),
                            title: Text(
                              'Tapa ${enLineaSerial ? (tapaAbiertaSerial ? 'abierta' : 'cerrada') : 'no disponible'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaSerial
                                  ? (papelPresenteSerial
                                      ? Icons.check
                                      : Icons.warning)
                                  : Icons.warning,
                              color: enLineaSerial
                                  ? (papelPresenteSerial
                                      ? Colors.green
                                      : Colors.red)
                                  : Colors.red,
                            ),
                            title: Text(
                              'Papel ${enLineaSerial ? (papelPresenteSerial ? 'OK' : 'agotado') : 'no disponible'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaSerial
                                  ? papelPresenteSerial
                                      ? (papelPorAcabarseSerial
                                          ? Icons.warning
                                          : Icons.check)
                                      : Icons.warning
                                  : Icons.warning,
                              color: enLineaSerial
                                  ? papelPresenteSerial
                                      ? (papelPorAcabarseSerial
                                          ? Colors.orange
                                          : Colors.green)
                                      : Colors.red
                                  : Colors.red,
                            ),
                            title: Text(
                              'Papel ${enLineaSerial ? papelPresenteSerial ? (papelPorAcabarseSerial ? 'cerca de acabarse' : 'OK') : 'no disponible' : 'no disponible'}',
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: checkSerialStatus,
                            child: const Text('Verificar estado impresora'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: openSerialPort,
                            child: const Text('Abrir puerto'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: sendDataSerial,
                            child: const Text('Imprimir ticket'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 3,
                    surfaceTintColor: Colors.redAccent,
                    shadowColor: Colors.black,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width > 600
                          ? MediaQuery.of(context).size.width *
                              0.45 // 45% del ancho si la pantalla es grande
                          : MediaQuery.of(context).size.width *
                              1.0, // 100% del ancho si la pantalla es estrecha
                      child: ListView(
                        shrinkWrap:
                            true, // Permite que el ListView tome solo el espacio necesario
                        physics:
                            const NeverScrollableScrollPhysics(), // Desactiva el scroll para que no interfiera con el Wrap
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'Estado impresora USB',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaUsb ? Icons.cloud_done : Icons.cloud_off,
                              color: enLineaUsb ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              'Impresora ${enLineaUsb ? 'en línea' : 'fuera de línea'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaUsb
                                  ? (tapaAbiertaUsb
                                      ? Icons.warning
                                      : Icons.check)
                                  : Icons.warning,
                              color: enLineaUsb
                                  ? (tapaAbiertaUsb ? Colors.red : Colors.green)
                                  : Colors.red,
                            ),
                            title: Text(
                              'Tapa ${enLineaUsb ? (tapaAbiertaUsb ? 'abierta' : 'cerrada') : 'no disponible'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaUsb
                                  ? (papelPresenteUsb
                                      ? Icons.check
                                      : Icons.warning)
                                  : Icons.warning,
                              color: enLineaUsb
                                  ? (papelPresenteUsb
                                      ? Colors.green
                                      : Colors.red)
                                  : Colors.red,
                            ),
                            title: Text(
                              'Papel ${enLineaUsb ? (papelPresenteUsb ? 'OK' : 'agotado') : 'no disponible'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaUsb
                                  ? papelPresenteUsb
                                      ? (papelPorAcabarseUsb
                                          ? Icons.warning
                                          : Icons.check)
                                      : Icons.warning
                                  : Icons.warning,
                              color: enLineaUsb
                                  ? papelPresenteUsb
                                      ? (papelPorAcabarseUsb
                                          ? Colors.orange
                                          : Colors.green)
                                      : Colors.red
                                  : Colors.red,
                            ),
                            title: Text(
                              'Papel ${enLineaUsb ? papelPresenteUsb ? (papelPorAcabarseUsb ? 'cerca de acabarse' : 'OK') : 'no disponible' : 'no disponible'}',
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: listUSBPort,
                            child: const Text('Listar impresoras'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: openUSBPort,
                            child: const Text('Abrir puerto'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: checkUsbStatus,
                            child: const Text('Verificar estado impresora'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: sendDataUsb,
                            child: const Text('Imprimir ticket'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
