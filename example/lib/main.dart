import 'package:flutter/material.dart';
import 'package:ti_printer_plugin_example/printer_status_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        //appBar: AppBar(title: const Text('Estado de la impresora')),
        body: PrinterStatusWiew(),
      ),
    );
  }
}
/*
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _tiPrinterPlugin = TiPrinterPlugin();
  List<int> bytes = [];
  late CapabilityProfile profile;
  late Generator printer;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    openPort();
  }

  void listUSBPort() async {
    try {
      List<String> usbPorts = await _tiPrinterPlugin.listUsbPorts();

      if (usbPorts.isEmpty) {
        log('No se encontraron puertos USB.');
      } else {
        for (var port in usbPorts) {
          log('Puerto USB detectado: $port');
        }
      }
    } catch (e) {
      log('Error al listar puertos USB: $e');
    }
  }

  Future<void> initPlatformState() async {
    profile = await CapabilityProfile.load();
    printer = Generator(PaperSize.mm80, profile);

    String platformVersion;
    try {
      platformVersion = await _tiPrinterPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void openPort() async {
    try {
      final result = await _tiPrinterPlugin.openSerialPort('COM10', 9600);
      log('Result openPort: $result');
    } catch (e) {
      log('Error al abrir el puerto serial: $e');
    }
  }

  void closePort() async {
    try {
      final result = await _tiPrinterPlugin.closeSerialPort();
      log('Result closePort: $result');
    } catch (e) {
      log('Error al cerrar el puerto serial: $e');
    }
  }

  void printerStatus() async {
    Uint8List? status = await _tiPrinterPlugin.getStatus();
    log("Estado de la impresora: $status");
    //if (status != null) interpretPrinterStatus(status);
  }

  void printerOfflineStatus() async {
    Uint8List? status = await _tiPrinterPlugin.getOfflineStatus();
    log("Estado de la impresora: $status");
    //if (status != null) interpretOfflineCauseStatus(status);
  }

  void printerCauseStatus() async {
    Uint8List? status = await _tiPrinterPlugin.getCauseStatus();
    log("Estado de la impresora: $status");
    //if (status != null) interpretErrorCauseStatus(status);
  }

  void printerRollPaperStatus() async {
    Uint8List? status = await _tiPrinterPlugin.getRollPaperStatus();
    log("Estado de la impresora: $status");
    //if (status != null) interpretRollPaperSensorStatus(status);
  }

  void sendDataTicket() async {
    //List<int> escPosCommand = [0x1B, 0x40, 0x0A]; // Comandos ESC/POS

    //List<int> escPosCommand = await generarTicket();
    List<int> escPosCommand = await _generateTicket();
    // Convertir List<int> a Uint8List
    Uint8List byteData = Uint8List.fromList(escPosCommand);
    bool? success = await _tiPrinterPlugin.sendCommand(byteData);

    if (success!) {
      log("Ticket enviado correctamente al puerto serial.");
    } else {
      log("Error al enviar ticket al puerto serial.");
    }
  }

  Future<List<int>> getStatusPrinter() async {
    List<int> bytes = [];
    bytes.addAll(printer.status());
    return bytes;
  }

  Future<List<int>> generarTicket() async {
    List<int> bytes = [];

    bytes += printer.text('Bold text', styles: const PosStyles(bold: true));
    bytes +=
        printer.text('Reverse text', styles: const PosStyles(reverse: true));
    bytes += printer.text('Underlined text',
        styles: const PosStyles(underline: true), linesAfter: 1);
    bytes += printer.text('Align left',
        styles: const PosStyles(align: PosAlign.left));
    bytes += printer.text('Align center',
        styles: const PosStyles(align: PosAlign.center));
    bytes += printer.text('Align right',
        styles: const PosStyles(align: PosAlign.right), linesAfter: 1);

    bytes += printer.row([
      PosColumn(
        text: 'col3',
        width: 3,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'col6',
        width: 6,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'col3',
        width: 3,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
    ]);

    bytes += printer.text('Text size 200%',
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ));

    // Print barcode
    final List<int> barData = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 4];
    bytes += printer.barcode(Barcode.upcA(barData));

    bytes += printer.feed(2);
    bytes += printer.cut();
    return bytes;
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
    bytes += printer.text(
      'DINOSAURIO S.A',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 1,
    );

    bytes += printer.text(
      'CUIT Nro: 30-69847147-2',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += printer.text(
      'ING. BRUTOS: 9043011028',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += printer.text(
      'COD.VALID.RENTAS: 20000005668804',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += printer.text(
      'INICIO ACT.: 03/12/2003',
      styles: const PosStyles(align: PosAlign.left),
    );

    bytes += printer.text(
      'DOM.FISC: Rodriguez del Busto 4086',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );
    bytes += printer.row([
      PosColumn(
          text: 'Alto Verde',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'CP: 5009',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    bytes += printer.row([
      PosColumn(
          text: 'Cordoba Capital',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Cordoba',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    bytes += printer.text(
      'TEL: 0351-5261500',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );
    bytes += printer.text(
      'DOM.COM: Rodriguez del Busto 4086',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );
    bytes += printer.row([
      PosColumn(
          text: 'Alto Verde',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'CP: 5009',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    bytes += printer.row([
      PosColumn(
          text: 'Cordoba Capital',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Cordoba',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    bytes += printer.text(
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
    bytes += printer.row([
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
    bytes += printer.row([
      PosColumn(
          text: 'Cajero: $cajero',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Legajo: $legajo',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);

    bytes += printer.row([
      PosColumn(
          text: 'Fecha: ${DateFormat('dd/MM/yy').format(DateTime.now())}',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'Hora: ${DateFormat('HH:mm').format(DateTime.now())}',
          width: 6,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);
    bytes += printer.hr();
    bytes += printer.text(
      'FACTURA B',
      styles: const PosStyles(align: PosAlign.left),
    );
  }

  void _createItems(List<Item> items) {
    // Items comprobante
    bytes += printer.hr();
    bytes += printer.row([
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
      bytes += printer.row([
        PosColumn(
          text: item.producto,
          width: 6,
          styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        PosColumn(
          text: '${item.cantidad}',
          width: 2,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: '\$${item.precio}',
          width: 4,
          styles: const PosStyles(align: PosAlign.left),
        ),
      ]);
    }
  }

  Future<List<int>> _generateTicket() async {
    // TODO: PARAMETRIZAR IMAGEN LOGO
    const pathLogo = 'assets/dino_logo_bg.png';
    final logoImage = await _createLogo(pathLogo);

    if (logoImage != null) {
      //bytes += generator.feed(1);
      bytes += printer.imageRaster(logoImage, align: PosAlign.center);
      bytes += printer.feed(1);
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

    final List<Item> items = [
      Item(producto: 'Sussex OF-RC', cantidad: 2.0000, precio: 1999.0000),
      Item(producto: 'PAPEL HIGI OF-', cantidad: 1.0000, precio: 2740.0000),
      Item(producto: 'PALTA TORRE X', cantidad: 1.0000, precio: 517.86),
      Item(producto: 'DORITOS QU', cantidad: 1.0000, precio: 4123.0000),
      Item(producto: 'CE OF-', cantidad: 1.0000, precio: 2848.0000),
      Item(producto: 'BLS CAM.CBA.N', cantidad: 1.0000, precio: 50.00),
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
    bytes += printer.hr();
    bytes += printer.row([
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

    bytes += printer.row([
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

    bytes += printer.hr();
    bytes += printer.row([
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
    bytes += printer.hr();
    bytes += printer.text(
      'Método de pago: Efectivo',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );

    // Información del cliente
    bytes += printer.text(
      'Cliente: Juan Pérez',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );
    bytes += printer.text(
      'Número de cliente: 12345',
      styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252'),
    );

    String qrData =
        "https://www.afip.gob.ar/fe/qr/?p=eyJ2ZXIiOjEsImZlY2hhIjoiMjAyNC0wOC0wOCIsImN1aXQiOjMwNjEyOTI5NDU1LCJwdG9WdGEiOjMwNDIsInRpcG9DbXAiOjYsIm5yb0NtcCI6NDY2MTEsImltcG9ydGUiOjEwNDk1NjYsIm1vbmVkYSI6IlBFUyIsImN0eiI6MSwidGlwb0RvY1JlYyI6OTksIm5yb0RvY1JlYyI6MCwidGlwb0NvZEF1dCI6IkUiLCJjb2RBdXQiOjc0MzI1Nzk4NDM5OTQzfQ==";
    const double qrSize = 300;

    img.Image imgQR = await _generateQR(qrData, qrSize);

    bytes += printer.feed(1);
    bytes += printer.imageRaster(imgQR, align: PosAlign.center);
    bytes += printer.feed(1);

    // Pie de página
    bytes += printer.hr();
    bytes += printer.text(
      '¡Gracias por su compra!',
      styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'),
    );
    bytes.addAll(printer.cut());

    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin app'),
        ),
        body: Center(
          child: Column(
            children: [
              Text('Platoforma: $_platformVersion\n'),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: printerStatus,
                child: const Text('Estado impresora'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: printerOfflineStatus,
                child: const Text('Estado offline'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: printerCauseStatus,
                child: const Text('Estado causa'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: printerRollPaperStatus,
                child: const Text('Estado rollo papel'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: sendDataTicket,
                child: const Text('Imprimir ticket'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: closePort,
                child: const Text('Cerrar puerto'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: listUSBPort,
                child: const Text('Listar puertos USB'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/