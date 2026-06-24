// example/lib/models/printer_state.dart
import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:ti_printer_plugin/printer_device_info.dart';

@immutable
class PrinterState extends Equatable {
  final bool enLineaSerial;
  final bool tapaAbiertaSerial;
  final bool papelPorAcabarseSerial;
  final bool papelPresenteSerial;
  final bool isSerialOpen;

  final bool enLineaUsb;
  final bool tapaAbiertaUsb;
  final bool papelPorAcabarseUsb;
  final bool papelPresenteUsb;
  final bool isUsbOpen;

  final List<PrinterDeviceInfo> usbPrinters;
  final PrinterDeviceInfo? selectedUsbPrinter;
  final List<String> logs;

  const PrinterState({
    this.enLineaSerial = false,
    this.tapaAbiertaSerial = true,
    this.papelPorAcabarseSerial = true,
    this.papelPresenteSerial = false,
    this.isSerialOpen = false,
    this.enLineaUsb = false,
    this.tapaAbiertaUsb = true,
    this.papelPorAcabarseUsb = true,
    this.papelPresenteUsb = false,
    this.isUsbOpen = false,
    this.usbPrinters = const [],
    this.selectedUsbPrinter,
    this.logs = const [],
  });

  PrinterState copyWith({
    bool? enLineaSerial,
    bool? tapaAbiertaSerial,
    bool? papelPorAcabarseSerial,
    bool? papelPresenteSerial,
    bool? isSerialOpen,
    bool? enLineaUsb,
    bool? tapaAbiertaUsb,
    bool? papelPorAcabarseUsb,
    bool? papelPresenteUsb,
    bool? isUsbOpen,
    List<PrinterDeviceInfo>? usbPrinters,
    PrinterDeviceInfo? selectedUsbPrinter,
    List<String>? logs,
  }) {
    return PrinterState(
      enLineaSerial: enLineaSerial ?? this.enLineaSerial,
      tapaAbiertaSerial: tapaAbiertaSerial ?? this.tapaAbiertaSerial,
      papelPorAcabarseSerial:
          papelPorAcabarseSerial ?? this.papelPorAcabarseSerial,
      papelPresenteSerial: papelPresenteSerial ?? this.papelPresenteSerial,
      isSerialOpen: isSerialOpen ?? this.isSerialOpen,
      enLineaUsb: enLineaUsb ?? this.enLineaUsb,
      tapaAbiertaUsb: tapaAbiertaUsb ?? this.tapaAbiertaUsb,
      papelPorAcabarseUsb: papelPorAcabarseUsb ?? this.papelPorAcabarseUsb,
      papelPresenteUsb: papelPresenteUsb ?? this.papelPresenteUsb,
      isUsbOpen: isUsbOpen ?? this.isUsbOpen,
      usbPrinters: usbPrinters ?? this.usbPrinters,
      selectedUsbPrinter: selectedUsbPrinter ?? this.selectedUsbPrinter,
      logs: logs ?? this.logs,
    );
  }

  @override
  List<Object?> get props => [
        enLineaSerial,
        tapaAbiertaSerial,
        papelPorAcabarseSerial,
        papelPresenteSerial,
        isSerialOpen,
        enLineaUsb,
        tapaAbiertaUsb,
        papelPorAcabarseUsb,
        papelPresenteUsb,
        isUsbOpen,
        usbPrinters,
        selectedUsbPrinter,
        logs,
      ];
}
