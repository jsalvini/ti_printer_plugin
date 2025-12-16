// example/lib/models/printer_state.dart
import 'package:flutter/foundation.dart';

@immutable
class PrinterState {
  final bool enLineaSerial;
  final bool tapaAbiertaSerial;
  final bool papelPorAcabarseSerial;
  final bool papelPresenteSerial;

  final bool enLineaUsb;
  final bool tapaAbiertaUsb;
  final bool papelPorAcabarseUsb;
  final bool papelPresenteUsb;

  final List<String> usbPrinters;
  final String? selectedUsbPrinter;
  final List<String> logs;

  const PrinterState({
    this.enLineaSerial = false,
    this.tapaAbiertaSerial = true,
    this.papelPorAcabarseSerial = true,
    this.papelPresenteSerial = false,
    this.enLineaUsb = false,
    this.tapaAbiertaUsb = true,
    this.papelPorAcabarseUsb = true,
    this.papelPresenteUsb = false,
    this.usbPrinters = const [],
    this.selectedUsbPrinter,
    this.logs = const [],
  });

  PrinterState copyWith({
    bool? enLineaSerial,
    bool? tapaAbiertaSerial,
    bool? papelPorAcabarseSerial,
    bool? papelPresenteSerial,
    bool? enLineaUsb,
    bool? tapaAbiertaUsb,
    bool? papelPorAcabarseUsb,
    bool? papelPresenteUsb,
    List<String>? usbPrinters,
    String? selectedUsbPrinter,
    List<String>? logs,
  }) {
    return PrinterState(
      enLineaSerial: enLineaSerial ?? this.enLineaSerial,
      tapaAbiertaSerial: tapaAbiertaSerial ?? this.tapaAbiertaSerial,
      papelPorAcabarseSerial:
          papelPorAcabarseSerial ?? this.papelPorAcabarseSerial,
      papelPresenteSerial: papelPresenteSerial ?? this.papelPresenteSerial,
      enLineaUsb: enLineaUsb ?? this.enLineaUsb,
      tapaAbiertaUsb: tapaAbiertaUsb ?? this.tapaAbiertaUsb,
      papelPorAcabarseUsb: papelPorAcabarseUsb ?? this.papelPorAcabarseUsb,
      papelPresenteUsb: papelPresenteUsb ?? this.papelPresenteUsb,
      usbPrinters: usbPrinters ?? this.usbPrinters,
      selectedUsbPrinter: selectedUsbPrinter ?? this.selectedUsbPrinter,
      logs: logs ?? this.logs,
    );
  }
}
