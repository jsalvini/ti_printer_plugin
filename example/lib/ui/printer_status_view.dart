// example/lib/ui/printer_status_view.dart

import 'package:flutter/material.dart';
import 'package:ti_printer_plugin/ti_printer_plugin.dart';
import 'package:ti_printer_plugin_example/item.dart';

import '../logic/printer_controller.dart';
import '../models/printer_state.dart';

class PrinterStatusView extends StatefulWidget {
  const PrinterStatusView({super.key});

  @override
  State<PrinterStatusView> createState() => _PrinterStatusViewState();
}

class _PrinterStatusViewState extends State<PrinterStatusView> {
  late final PrinterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PrinterController(TiPrinterPlugin());
    _controller.initPlatform();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final PrinterState state = _controller.state;

        return Scaffold(
          appBar: AppBar(title: const Text('Estado impresora')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //Expanded(child: _buildSerialCard(state)),
                    //const SizedBox(width: 16),
                    Expanded(
                      child: _buildUsbCard(state),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildConsole(state.logs),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI Serial ---

  /*Widget _buildSerialCard(PrinterState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Estado impresora serial',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _statusRow(state.enLineaSerial, 'Impresora en línea',
                'Impresora fuera de línea'),
            _statusRow(
                !state.tapaAbiertaSerial, 'Tapa cerrada', 'Tapa abierta'),
            _statusRow(!state.papelPorAcabarseSerial, 'Papel OK',
                'Papel por acabarse'),
            _statusRow(
                state.papelPresenteSerial, 'Papel OK', 'Papel no disponible'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: Platform.isWindows
                  ? () async {
                      try {
                        await _controller.checkSerialStatus();
                      } catch (e) {
                        _showError(e);
                      }
                    }
                  : null,
              child: const Text('Verificar estado impresora'),
            ),
          ],
        ),
      ),
    );
  }*/

  // --- UI USB ---

  Widget _buildUsbCard(PrinterState state) {
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Estado impresora USB',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _statusRow(state.enLineaUsb, 'Impresora en línea',
                'Impresora fuera de línea'),
            _statusRow(!state.tapaAbiertaUsb, 'Tapa cerrada', 'Tapa abierta'),
            _statusRow(
                !state.papelPorAcabarseUsb, 'Papel OK', 'Papel por acabarse'),
            _statusRow(
                state.papelPresenteUsb, 'Papel OK', 'Papel no disponible'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _controller.refreshUsbPrinters();
                } catch (e) {
                  _showError(e);
                }
              },
              child: const Text('Listar impresoras'),
            ),
            const SizedBox(height: 8),
            if (state.usbPrinters.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: state.selectedUsbPrinter,
                decoration: const InputDecoration(
                  labelText: 'Seleccionar impresora USB',
                  border: OutlineInputBorder(),
                ),
                items: state.usbPrinters
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  _controller
                      .updateSelectedUsb(value); // puedes agregar este método
                },
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _controller.openSelectedUsb();

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Puerto USB abierto'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  _showError(e);
                }
              },
              child: const Text('Abrir puerto'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _controller.checkUsbStatus();
                } catch (e) {
                  _showError(e);
                }
              },
              child: const Text('Verificar estado impresora'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  // aquí armas tus items de prueba

                  String qrData =
                      "https://www.afip.gob.ar/fe/qr/?p=eyJ2ZXIiOjEsImZlY2hhIjoiMjAyNC0wOC0wOCIsImN1aXQiOjMwNjEyOTI5NDU1LCJwdG9WdGEiOjMwNDIsInRpcG9DbXAiOjYsIm5yb0NtcCI6NDY2MTEsImltcG9ydGUiOjEwNDk1NjYsIm1vbmVkYSI6IlBFUyIsImN0eiI6MSwidGlwb0RvY1JlYyI6OTksIm5yb0RvY1JlYyI6MCwidGlwb0NvZEF1dCI6IkUiLCJjb2RBdXQiOjc0MzI1Nzk4NDM5OTQzfQ==";
                  await _controller.printUsbTicket(
                    items: items,
                    nroReferencia: '0001',
                    total: 100,
                    efectivo: 100,
                    cambio: 0,
                    qrData: qrData,
                  );
                } catch (e) {
                  _showError(e);
                }
              },
              child: const Text('Imprimir ticket'),
            ),
          ],
        ),
      ),
    );
  }

  // --- consola de logs ---

  Widget _buildConsole(List<String> logs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Consola',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              padding: const EdgeInsets.all(8),
              child: logs.isEmpty
                  ? const Text(
                      'Consola vacía',
                      style: TextStyle(color: Colors.white70),
                    )
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) => Text(
                        logs[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(bool ok, String okText, String failText) {
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.error,
            color: ok ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Text(ok ? okText : failText),
      ],
    );
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}
