// example/lib/logic/printer_controller.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/enums.dart';
import 'package:ti_printer_plugin/ti_printer_plugin.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/generator.dart';
import 'package:ti_printer_plugin_example/item.dart';
import 'package:ti_printer_plugin_example/uils/printer_status_interpreter.dart';

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

    if (onlineRsp == null || onlineRsp.isEmpty) {
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
    if (paperRsp != null && paperRsp.isNotEmpty) {
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
    if (offRsp != null && offRsp.isNotEmpty) {
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
    final version = await _plugin.getPlatformVersion() ?? 'Unknown';
    _addLog('Platform: $version');
  }

  // --- Serial ---

  Future<void> openSerialPort(String port, int baudRate) async {
    final result = await _plugin.openSerialPort(port, baudRate);
    _addLog('openSerialPort($port, $baudRate): $result');
  }

  Future<void> checkSerialStatus() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    // DLE EOT 1
    final statusCmd = Uint8List.fromList(generator.status());
    _addLog('[SERIAL] CMD online: ${_bytesToHex(statusCmd)}');
    final online = await _plugin.readStatusSerial(statusCmd);

    if (online != null && online.isNotEmpty) {
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
    if (paper != null && paper.isNotEmpty) {
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
    if (off != null && off.isNotEmpty) {
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
    _addLog('USB printers: $printers');

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
    final result = await _plugin.openUsbPort(device);
    _addLog('openUsbPort($device): $result');
  }

  Future<void> checkUsbStatus() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    // DLE EOT 1 – online
    final statusCmd = Uint8List.fromList(generator.status());
    _addLog('[USB] CMD online: ${_bytesToHex(statusCmd)}');
    final online = await _plugin.readStatusUsb(statusCmd);

    if (online != null && online.isNotEmpty) {
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
    if (paper != null && paper.isNotEmpty) {
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
    if (off != null && off.isNotEmpty) {
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

      if (ok != true) {
        throw Exception('Falló el envío a la impresora USB');
      }
    } finally {
      if (wasMonitoring) {
        startUsbAutoMonitor();
      }
    }
  }

  void updateSelectedUsb(String? value) {
    _update(
      (s) => s.copyWith(selectedUsbPrinter: value),
    );
  }
}
