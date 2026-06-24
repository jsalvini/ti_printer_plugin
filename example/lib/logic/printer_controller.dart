// example/lib/logic/printer_controller.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ti_printer_plugin/ti_printer_plugin.dart';
import 'package:ti_printer_plugin_example/ui/item.dart';
import 'package:ti_printer_plugin_example/uils/printer_status_interpreter.dart';

import 'package:ti_printer_plugin/esc_pos_utils_platform/src/barcode.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/enums.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/generator.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/pos_column.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/pos_styles.dart';
import '../models/printer_state.dart';
import 'ticket_builder.dart';

class PrinterController extends ChangeNotifier {
  final TiPrinterPlugin _plugin;

  PrinterController(this._plugin);

  PrinterState _state = const PrinterState();
  PrinterState get state => _state;

  CapabilityProfile? _profile;
  TicketBuilder? _ticketBuilder;

  Generator? _statusGenerator;

  Timer? _usbMonitorTimer;
  bool _usbPolling = false;
  bool get isUsbMonitoring => _usbMonitorTimer != null;

  // ===== Helpers internos =====

  Future<Generator> _getStatusGenerator() async {
    _profile ??= await CapabilityProfile.load();
    _statusGenerator ??= Generator(PaperSize.mm80, _profile!);
    return _statusGenerator!;
  }

  Future<void> _pollUsbStatusOnce() async {
    // Si no hay impresora seleccionada, nada que hacer
    if (_state.selectedUsbPrinter == null) {
      return;
    }

    final generator = await _getStatusGenerator();

    bool enLinea = _state.enLineaUsb;
    bool tapaAbierta = _state.tapaAbiertaUsb;
    bool papelNearEnd = _state.papelPorAcabarseUsb;
    bool papelPresente = _state.papelPresenteUsb;

    // ===== 1) DLE EOT 1 – online status =====
    final onlineCmd = Uint8List.fromList(generator.status());
    _addLog('[USB] CMD online: ${_bytesToHex(onlineCmd)}');
    final onlineRsp = await _plugin.readStatusUsb(onlineCmd);

    if (onlineRsp.isEmpty) {
      _addLog(
        '[USB] sin respuesta de impresora (posible apagada/desconectada), marcando como offline',
      );

      _update((s) => s.copyWith(
            enLineaUsb: false,
            tapaAbiertaUsb: true, // asumimos "no OK"
            papelPorAcabarseUsb: true,
            papelPresenteUsb: false,
          ));

      // opcional: detenemos el monitor para no seguir spameando
      stopUsbMonitor();
      return;
    }

    _addLog('[USB] RSP online: ${_bytesToHex(onlineRsp)}');
    PrinterStatusInterpreter.interpretOnlinePrinterStatus(
      onlineRsp,
      (coverOpen, feed, paperEnd, error) {
        enLinea = !error;
        // aquí no sabemos tapa/papel, eso viene en otros comandos
      },
    );

    // ===== 2) DLE EOT 4 – roll paper sensor =====
    final paperCmd = Uint8List.fromList(generator.paperSensorStatus());
    _addLog('[USB] CMD paper: ${_bytesToHex(paperCmd)}');
    final paperRsp = await _plugin.readStatusUsb(paperCmd);
    if (paperRsp.isNotEmpty) {
      _addLog('[USB] RSP paper: ${_bytesToHex(paperRsp)}');
      PrinterStatusInterpreter.interpretRollPaperSensorStatus(
        paperRsp,
        (nearEnd, present) {
          papelNearEnd = nearEnd;
          papelPresente = present;
        },
      );
    }

    // ===== 3) DLE EOT 2 – offline cause =====
    final offCmd = Uint8List.fromList(generator.offLineStatus());
    _addLog('[USB] CMD offline: ${_bytesToHex(offCmd)}');
    final offRsp = await _plugin.readStatusUsb(offCmd);
    if (offRsp.isNotEmpty) {
      _addLog('[USB] RSP offline: ${_bytesToHex(offRsp)}');
      PrinterStatusInterpreter.interpretOfflineCauseStatus(
        offRsp,
        (coverOpen, feed, paperEnd, error) {
          tapaAbierta = coverOpen;
          if (error) enLinea = false;
        },
      );
    }

    // Actualizamos todo en un solo batch
    _update((s) => s.copyWith(
          enLineaUsb: enLinea,
          tapaAbiertaUsb: tapaAbierta,
          papelPorAcabarseUsb: papelNearEnd,
          papelPresenteUsb: papelPresente,
        ));
  }

  Future<void> startUsbAutoMonitor({
    Duration interval = const Duration(seconds: 3),
  }) async {
    if (_usbMonitorTimer != null) return; // ya está corriendo

    // 1) Asegurarnos de tener impresora seleccionada y puerto abierto
    if (_state.selectedUsbPrinter == null) {
      await refreshUsbPrinters();
    }
    if (_state.selectedUsbPrinter == null) {
      _addLog('No hay impresoras USB disponibles para monitorizar');
      return;
    }

    await openSelectedUsb();

    // 2) Primer poll inmediato
    await _pollUsbStatusOnce();

    // 3) Timer periódico
    _usbMonitorTimer = Timer.periodic(interval, (_) async {
      if (_usbPolling) return;
      _usbPolling = true;
      try {
        await _pollUsbStatusOnce();
      } finally {
        _usbPolling = false;
      }
    });

    _addLog('Monitor USB iniciado (intervalo ${interval.inSeconds}s)');
  }

  void stopUsbMonitor() {
    _usbMonitorTimer?.cancel();
    _usbMonitorTimer = null;
    _addLog('Monitor USB detenido');
  }

  @override
  void dispose() {
    stopUsbMonitor();
    super.dispose();
  }

  void _update(PrinterState Function(PrinterState) updater) {
    final newState = updater(_state);
    if (newState == _state) return;
    _state = newState;
    notifyListeners();
  }

  void _addLog(String msg) {
    final ts = DateTime.now();
    final line = '[${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}] $msg';
    _update((s) => s.copyWith(logs: [...s.logs, line]));
    debugPrint(msg);
  }

  String _bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  Future<TicketBuilder> _getTicketBuilder() async {
    if (_ticketBuilder != null) return _ticketBuilder!;
    _profile ??= await CapabilityProfile.load();
    _ticketBuilder = TicketBuilder(_profile!);
    return _ticketBuilder!;
  }

  // ===== API pública que usará la UI =====

  Future<void> initPlatform() async {
    final version = await _plugin.getPlatformVersion();
    _addLog('Platform: $version');
  }

  // --- Serial ---

  Future<void> openSerialPort(String port, int baudRate) async {
    final result = await _plugin.openSerialPort(port, baudRate);
    _addLog('openSerialPort($port, $baudRate): $result');

    _update((s) => s.copyWith(isSerialOpen: result));

    if (!result) {
      _addLog(
        '[SERIAL] apertura no disponible o fallida en la plataforma actual',
      );
    }
  }

  Future<void> closeSerialPort() async {
    final result = await _plugin.closeSerialPort();
    _addLog('closeSerialPort: $result');
    _update((s) => s.copyWith(isSerialOpen: !result));
  }

  Future<void> checkSerialStatus() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    _addLog(
      '[SERIAL] si la plataforma no soporta serial, las lecturas devolveran bytes vacios',
    );

    // DLE EOT 1
    final statusCmd = Uint8List.fromList(generator.status());
    _addLog('[SERIAL] CMD online: ${_bytesToHex(statusCmd)}');
    final online = await _plugin.readStatusSerial(statusCmd);

    if (online.isNotEmpty) {
      _addLog('[SERIAL] RSP online: ${_bytesToHex(online)}');
      PrinterStatusInterpreter.interpretOnlinePrinterStatus(
        online,
        (coverOpen, feed, paperEnd, error) {
          _update((s) => s.copyWith(
                enLineaSerial: !error,
                tapaAbiertaSerial: coverOpen,
              ));
        },
      );
    }

    // DLE EOT 4 – papel
    final paperCmd = Uint8List.fromList(generator.paperSensorStatus());
    _addLog('[SERIAL] CMD paper: ${_bytesToHex(paperCmd)}');
    final paper = await _plugin.readStatusSerial(paperCmd);
    if (paper.isNotEmpty) {
      _addLog('[SERIAL] RSP paper: ${_bytesToHex(paper)}');
      PrinterStatusInterpreter.interpretRollPaperSensorStatus(
        paper,
        (nearEnd, present) {
          _update((s) => s.copyWith(
                papelPorAcabarseSerial: nearEnd,
                papelPresenteSerial: present,
              ));
        },
      );
    }

    // DLE EOT 2 – offline cause
    final offCmd = Uint8List.fromList(generator.offLineStatus());
    _addLog('[SERIAL] CMD offline: ${_bytesToHex(offCmd)}');
    final off = await _plugin.readStatusSerial(offCmd);
    if (off.isNotEmpty) {
      _addLog('[SERIAL] RSP offline: ${_bytesToHex(off)}');
      PrinterStatusInterpreter.interpretOfflineCauseStatus(
        off,
        (coverOpen, feed, paperEnd, error) {
          _update((s) => s.copyWith(
                tapaAbiertaSerial: coverOpen,
                enLineaSerial: !error,
              ));
        },
      );
    }
  }

  // --- USB ---

  Future<void> refreshUsbPrinters() async {
    final printers = await _plugin.getUsbPrinters();
    for (final p in printers) {
      _addLog('[USB]  ${p.resolvedDisplayName}  instanceId=${p.instanceId}');
    }
    if (printers.isEmpty) {
      _addLog('USB printers: (none)');
    }

    _update((s) => s.copyWith(
          usbPrinters: printers,
          selectedUsbPrinter: printers.isNotEmpty
              ? (s.selectedUsbPrinter != null &&
                      printers.contains(s.selectedUsbPrinter)
                  ? s.selectedUsbPrinter
                  : printers.first)
              : null,
        ));
  }

  Future<void> openSelectedUsb() async {
    final device = _state.selectedUsbPrinter;
    if (device == null) {
      _addLog('openSelectedUsb: no device selected');
      throw Exception('No hay impresora USB seleccionada');
    }
    final result = await _plugin.openUsbPort(device.instanceId);
    _addLog('openUsbPort(instanceId=${device.instanceId}): $result');

    _update((s) => s.copyWith(isUsbOpen: result));

    if (!result) {
      throw Exception('No se pudo abrir el puerto USB seleccionado');
    }
  }

  Future<void> closeUsbPort() async {
    if (isUsbMonitoring) {
      stopUsbMonitor();
    }
    final result = await _plugin.closeUsbPort();
    _addLog('closeUsbPort: $result');
    _update((s) => s.copyWith(isUsbOpen: !result));
  }

  Future<void> checkUsbStatus() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    // DLE EOT 1 – online
    final statusCmd = Uint8List.fromList(generator.status());
    _addLog('[USB] CMD online: ${_bytesToHex(statusCmd)}');
    final online = await _plugin.readStatusUsb(statusCmd);

    if (online.isNotEmpty) {
      _addLog('[USB] RSP online: ${_bytesToHex(online)}');
      PrinterStatusInterpreter.interpretOnlinePrinterStatus(
        online,
        (coverOpen, feed, paperEnd, error) {
          _update((s) => s.copyWith(
                enLineaUsb: !error,
                tapaAbiertaUsb: coverOpen,
              ));
        },
      );
    }

    // DLE EOT 4 – papel
    final paperCmd = Uint8List.fromList(generator.paperSensorStatus());
    _addLog('[USB] CMD paper: ${_bytesToHex(paperCmd)}');
    final paper = await _plugin.readStatusUsb(paperCmd);
    if (paper.isNotEmpty) {
      _addLog('[USB] RSP paper: ${_bytesToHex(paper)}');
      PrinterStatusInterpreter.interpretRollPaperSensorStatus(
        paper,
        (nearEnd, present) {
          _update((s) => s.copyWith(
                papelPorAcabarseUsb: nearEnd,
                papelPresenteUsb: present,
              ));
        },
      );
    }

    // DLE EOT 2 – offline cause
    final offCmd = Uint8List.fromList(generator.offLineStatus());
    _addLog('[USB] CMD offline: ${_bytesToHex(offCmd)}');
    final off = await _plugin.readStatusUsb(offCmd);
    if (off.isNotEmpty) {
      _addLog('[USB] RSP offline: ${_bytesToHex(off)}');
      PrinterStatusInterpreter.interpretOfflineCauseStatus(
        off,
        (coverOpen, feed, paperEnd, error) {
          _update((s) => s.copyWith(
                tapaAbiertaUsb: coverOpen,
                enLineaUsb: !error,
              ));
        },
      );
    }
  }

  // --- Impresión de página de prueba ---

  Future<void> printTestPage() async {
    final wasMonitoring = isUsbMonitoring;
    if (wasMonitoring) stopUsbMonitor();

    try {
      final profile = await CapabilityProfile.load();
      final gen = Generator(PaperSize.mm80, profile);
      final bytes = <int>[];

      bytes.addAll(gen.reset());
      bytes.addAll(gen.text('PAGINA DE PRUEBA ESC/POS',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )));
      bytes.addAll(gen.feed(1));

      bytes.addAll(gen.text('=======================',
          styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(gen.feed(1));

      bytes.addAll(gen.text('TEXTOS:',
          styles: const PosStyles(bold: true, underline: true)));
      bytes.addAll(gen.text('Normal (size 1)'));
      bytes.addAll(gen.text('Doble altura',
          styles: const PosStyles(height: PosTextSize.size2)));
      bytes.addAll(gen.text('Doble ancho',
          styles: const PosStyles(width: PosTextSize.size2)));
      bytes.addAll(gen.text('Doble todo',
          styles: const PosStyles(
              height: PosTextSize.size2, width: PosTextSize.size2)));
      bytes.addAll(gen.feed(1));

      bytes.addAll(gen.text('ESTILOS:',
          styles: const PosStyles(bold: true, underline: true)));
      bytes.addAll(gen.text('Negrita', styles: const PosStyles(bold: true)));
      bytes.addAll(
          gen.text('Subrayado', styles: const PosStyles(underline: true)));
      bytes.addAll(
          gen.text('Invertido', styles: const PosStyles(reverse: true)));
      bytes.addAll(gen.feed(1));

      bytes.addAll(gen.text('ALINEACION:',
          styles: const PosStyles(bold: true, underline: true)));
      bytes.addAll(
          gen.text('Izquierda', styles: const PosStyles(align: PosAlign.left)));
      bytes.addAll(
          gen.text('Centro', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(
          gen.text('Derecha', styles: const PosStyles(align: PosAlign.right)));
      bytes.addAll(gen.feed(1));

      bytes.addAll(gen.text('CARACTERES ESPECIALES:',
          styles: const PosStyles(bold: true, underline: true)));
      bytes.addAll(gen.text('àÀ éÉ èÈ êÊ ñÑ üÜ çÇ',
          styles: const PosStyles(codeTable: 'CP1252')));
      bytes.addAll(gen.text('ñandú, pingüino, corazón',
          styles: const PosStyles(codeTable: 'CP1252')));
      bytes.addAll(gen.feed(1));

      bytes.addAll(gen.hr());
      bytes.addAll(gen.text('COLUMNAS:',
          styles: const PosStyles(bold: true, underline: true)));
      bytes.addAll(gen.row([
        PosColumn(text: 'Col1', width: 4),
        PosColumn(
            text: 'Col2',
            width: 4,
            styles: const PosStyles(align: PosAlign.center)),
        PosColumn(
            text: 'Col3',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      bytes.addAll(gen.row([
        PosColumn(text: 'Item A', width: 8),
        PosColumn(
            text: '\$1.50',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      bytes.addAll(gen.feed(1));

      bytes.addAll(gen.hr());
      bytes.addAll(gen.text('CODIGO DE BARRAS:',
          styles: const PosStyles(bold: true, underline: true)));
      bytes
          .addAll(gen.barcode(Barcode.upcA([1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 4])));
      bytes.addAll(gen.feed(1));

      bytes.addAll(gen.text('CODIGO QR:',
          styles: const PosStyles(bold: true, underline: true)));
      bytes.addAll(gen.qrcode('https://github.com/ti-printer-plugin'));
      bytes.addAll(gen.feed(2));

      bytes.addAll(gen.text('Fin de pagina de prueba',
          styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(gen.feed(2));
      bytes.addAll(gen.cut());

      _addLog('TestPage bytes: ${bytes.length}');
      final data = Uint8List.fromList(bytes);
      final ok = await _plugin.sendCommandToUsb(data);
      _addLog('sendCommandToUsb (test): $ok');
      if (!ok) throw Exception('Falló el envío de la página de prueba');
    } finally {
      if (wasMonitoring) startUsbAutoMonitor();
    }
  }

  // --- Impresión de ticket por USB ---

  Future<void> printUsbTicket({
    required List<Item> items,
    required String nroReferencia,
    required double total,
    required double efectivo,
    required double cambio,
    required String qrData,
  }) async {
    final wasMonitoring = isUsbMonitoring;
    if (wasMonitoring) {
      stopUsbMonitor();
    }

    try {
      final builder = await _getTicketBuilder();
      final bytes = await builder.buildTicket(
        items: items,
        nroReferencia: nroReferencia,
        total: total,
        efectivo: efectivo,
        cambio: cambio,
        qrData: qrData,
      );

      _addLog('Ticket bytes length: ${bytes.length}');
      final data = Uint8List.fromList(bytes);
      final ok = await _plugin.sendCommandToUsb(data);
      _addLog('sendCommandToUsb: $ok (len=${bytes.length})');

      if (!ok) {
        throw Exception('Falló el envío a la impresora USB');
      }
    } finally {
      if (wasMonitoring) {
        startUsbAutoMonitor();
      }
    }
  }

  void updateSelectedUsb(PrinterDeviceInfo? value) {
    _update(
      (s) => s.copyWith(selectedUsbPrinter: value),
    );
  }

  void clearLogs() {
    _update((s) => s.copyWith(logs: []));
  }
}
