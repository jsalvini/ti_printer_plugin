// example/lib/ui/printer_status_view.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ti_printer_plugin/ti_printer_plugin.dart';
import 'package:ti_printer_plugin_example/ui/item.dart';

import '../logic/printer_controller.dart';
import '../models/printer_state.dart';

class PrinterStatusView extends StatefulWidget {
  const PrinterStatusView({super.key});

  @override
  State<PrinterStatusView> createState() => _PrinterStatusViewState();
}

class _PrinterStatusViewState extends State<PrinterStatusView> {
  late final PrinterController _controller;

  final _serialPortController = TextEditingController(text: 'COM1');
  final _serialBaudController = TextEditingController(text: '9600');

  @override
  void initState() {
    super.initState();
    _controller = PrinterController(TiPrinterPlugin());
    _controller.initPlatform();
    if (Platform.isWindows || Platform.isLinux) {
      _controller.startUsbAutoMonitor();
    }
  }

  @override
  void dispose() {
    _serialPortController.dispose();
    _serialBaudController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text('TIPrinter', overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () async {
                  try {
                    await _controller.initPlatform();
                  } catch (_) {}
                },
                tooltip: 'Platform version',
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 600.0,
                    minHeight: constraints.maxHeight,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildUsbCard(state),
                        const SizedBox(height: 12),
                        _buildSerialCard(state),
                        const SizedBox(height: 12),
                        _buildConsoleCard(state),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ===== USB Section =====

  Widget _buildUsbCard(PrinterState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.usb, 'USB', state.enLineaUsb, state.isUsbOpen),
            const Divider(),
            if (state.usbPrinters.isNotEmpty) ...[
              DropdownButtonFormField<PrinterDeviceInfo>(
                key: ValueKey(state.usbPrinters.length),
                initialValue: state.selectedUsbPrinter,
                decoration: const InputDecoration(
                  labelText: 'Impresora',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: state.usbPrinters
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.resolvedDisplayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => _controller.updateSelectedUsb(v),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('Listar', Icons.refresh,
                    () => _exec(_controller.refreshUsbPrinters)),
                _btn(
                    'Abrir',
                    Icons.play_arrow,
                    state.isUsbOpen
                        ? null
                        : () => _exec(_controller.openSelectedUsb)),
                _btn(
                    'Cerrar',
                    Icons.stop,
                    !state.isUsbOpen
                        ? null
                        : () => _exec(_controller.closeUsbPort)),
                _btn('Estado', Icons.info,
                    () => _exec(_controller.checkUsbStatus)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('Imprimir Ticket', Icons.receipt,
                    () => _exec(_printTicket)),
                _btn('Test Page', Icons.bug_report,
                    () => _exec(_controller.printTestPage)),
              ],
            ),
            const SizedBox(height: 8),
            _statusRow(state.enLineaUsb, state.papelPresenteUsb,
                state.tapaAbiertaUsb, state.papelPorAcabarseUsb),
          ],
        ),
      ),
    );
  }

  // ===== Serial Section =====

  Widget _buildSerialCard(PrinterState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.settings_ethernet, 'Serial',
                state.enLineaSerial, state.isSerialOpen),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serialPortController,
                    decoration: const InputDecoration(
                      labelText: 'Puerto',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _serialBaudController,
                    decoration: const InputDecoration(
                      labelText: 'Baud',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn(
                    'Abrir',
                    Icons.play_arrow,
                    state.isSerialOpen
                        ? null
                        : () => _exec(() => _controller.openSerialPort(
                            _serialPortController.text,
                            int.parse(_serialBaudController.text)))),
                _btn(
                    'Cerrar',
                    Icons.stop,
                    !state.isSerialOpen
                        ? null
                        : () => _exec(_controller.closeSerialPort)),
                _btn('Estado', Icons.info,
                    () => _exec(_controller.checkSerialStatus)),
              ],
            ),
            const SizedBox(height: 8),
            _statusRow(state.enLineaSerial, state.papelPresenteSerial,
                state.tapaAbiertaSerial, state.papelPorAcabarseSerial),
          ],
        ),
      ),
    );
  }

  // ===== Console =====

  Widget _buildConsoleCard(PrinterState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, size: 20),
                const SizedBox(width: 8),
                const Text('Consola',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Limpiar'),
                  onPressed: () => _controller.clearLogs(),
                ),
              ],
            ),
            const Divider(),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: state.logs.isEmpty
                  ? const Text(
                      'Consola vacía',
                      style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'monospace',
                          fontSize: 12),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.logs.length,
                      itemBuilder: (context, index) {
                        final line = state.logs[index];
                        return Text(
                          line,
                          style: TextStyle(
                            color: _logColor(line),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Shared Widgets =====

  Widget _sectionHeader(IconData icon, String title, bool online, bool isOpen) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (isOpen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Abierto',
                style: TextStyle(fontSize: 11, color: Colors.green)),
          ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              online ? 'Online' : 'Offline',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _statusRow(bool online, bool papelPresente, bool tapaAbierta,
      bool papelPorAcabarse) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _chip(online, 'En línea', 'Fuera de línea'),
        _chip(papelPresente, 'Papel OK', 'Sin papel'),
        _chip(!tapaAbierta, 'Tapa cerrada', 'Tapa abierta'),
        _chip(!papelPorAcabarse, 'Papel suficiente', 'Papel por acabarse'),
      ],
    );
  }

  Widget _chip(bool ok, String okText, String failText) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.error,
          size: 14,
          color: ok ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 4),
        Text(
          ok ? okText : failText,
          style: TextStyle(fontSize: 11, color: ok ? Colors.green : Colors.red),
        ),
      ],
    );
  }

  Color _logColor(String line) {
    if (line.contains('[USB]')) return Colors.lightBlue;
    if (line.contains('[SERIAL]')) return Colors.orangeAccent;
    if (line.contains('Error') ||
        line.contains('error') ||
        line.contains('Exception') ||
        line.contains('fallida') ||
        line.contains('Falló')) {
      return Colors.redAccent;
    }
    return Colors.greenAccent;
  }

  // ===== Actions =====

  Future<void> _printTicket() async {
    final items = <Item>[
      Item(producto: 'PRODUCTO A', cantidad: 2, precio: 1500),
      Item(producto: 'PRODUCTO B', cantidad: 1, precio: 2500),
      Item(producto: 'PRODUCTO C', cantidad: 3, precio: 800),
    ];
    await _controller.printUsbTicket(
      items: items,
      nroReferencia: '0001',
      total: 100,
      efectivo: 100,
      cambio: 0,
      qrData:
          'https://www.afip.gob.ar/fe/qr/?p=eyJ2ZXIiOjEsImZlY2hhIjoiMjAyNC0wOC0wOCIsImN1aXQiOjMwNjEyOTI5NDU1LCJwdG9WdGEiOjMwNDIsInRpcG9DbXAiOjYsIm5yb0NtcCI6NDY2MTEsImltcG9ydGUiOjEwNDk1NjYsIm1vbmVkYSI6IlBFUyIsImN0eiI6MSwidGlwb0RvY1JlYyI6OTksIm5yb0RvY1JlYyI6MCwidGlwb0NvZEF1dCI6IkUiLCJjb2RBdXQiOjc0MzI1Nzk4NDM5OTQzfQ==',
    );
  }

  Future<void> _exec(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    }
  }
}
