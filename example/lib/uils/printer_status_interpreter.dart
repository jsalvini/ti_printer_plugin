import 'dart:developer';
import 'dart:typed_data';

class PrinterStatusInterpreter {
  static void interpretOfflineCauseStatus(
      Uint8List statusBytes, Function(bool, bool, bool, bool) updateState) {
    if (statusBytes.isEmpty) {
      log('No se pudo obtener el estado de causa de desconexión.');
      return;
    }

    int status = statusBytes[0]; // El primer byte contiene el estado

    bool coverOpen = (status & 0x04) != 0; // Bit 2: Cubierta abierta
    bool paperFeedActive =
        (status & 0x08) != 0; // Bit 3: Alimentación de papel activa
    bool paperEndStop = (status & 0x20) != 0; // Bit 5: Parada por fin de papel
    bool errorOccurred = (status & 0x40) != 0; // Bit 6: Error ocurrido

    // Mostrar el estado en la consola
    log('(n = 2) - Estado de causa de desconexión:\n');
    log('Cubierta abierta: $coverOpen');
    log('Alimentación de papel activa: $paperFeedActive');
    log('Parada por fin de papel: $paperEndStop');
    log('Error ocurrido: $errorOccurred');
    updateState(coverOpen, paperFeedActive, paperEndStop, errorOccurred);
  }

  static void interpretErrorCauseStatus(
      Uint8List statusBytes, Function(bool, bool, bool, bool) updateState) {
    if (statusBytes.isEmpty) {
      log('No se pudo obtener el estado de causa de error.');
      return;
    }

    int status = statusBytes[0]; // El primer byte contiene el estado

    bool recoverableError = (status & 0x04) != 0; // Bit 2: Error recuperable
    bool cutterError = (status & 0x08) != 0; // Bit 3: Error del cortador
    bool unrecoverableError =
        (status & 0x20) != 0; // Bit 5: Error no recuperable
    bool autoRecoverableError =
        (status & 0x40) != 0; // Bit 6: Error auto-recuperable

    // Mostrar el estado en la consola
    log('(n = 3) - Estado de causa de error:');
    log('Error recuperable: $recoverableError');
    log('Error del cortador: $cutterError');
    log('Error no recuperable: $unrecoverableError');
    log('Error auto-recuperable: $autoRecoverableError');
  }

  static void interpretRollPaperSensorStatus(
      Uint8List statusBytes, Function(bool, bool) updateState) {
    if (statusBytes.isEmpty) {
      log('No se pudo obtener el estado del sensor de papel.');
      return;
    }

    int status = statusBytes[0]; // El primer byte contiene el estado

    bool paperNearEnd = (status & 0x0C) != 0; // Bits 2-3: Papel cerca del fin
    bool paperPresent = (status & 0x60) ==
        0; // Bits 5-6: Papel presente (0 = presente, 1 = no hay papel)

    // Mostrar el estado en la consola
    log('(n = 4) - Estado del sensor de papel:\n');
    log('Papel cerca del fin: $paperNearEnd');
    log('Papel presente: $paperPresent');
    updateState(paperNearEnd, paperPresent);
  }

  static void interpretOnlinePrinterStatus(
      Uint8List statusBytes, Function(bool, bool, bool, bool) updateState) {
    if (statusBytes.isEmpty) {
      log('No se pudo obtener el estado de la impresora.');
      return;
    }

    int status = statusBytes[0]; // El primer byte contiene el estado

    // Interpretar los bits del estado según el manual ESC/POS para n = 1
    bool pin3High = (status & 0x04) !=
        0; // Bit 2: Pin 3 del conector de desconexión del cajón
    bool printerOnline =
        (status & 0x08) == 0; // Bit 3: Impresora en línea (0 = En línea)
    bool waitingRecovery =
        (status & 0x20) != 0; // Bit 5: Esperando recuperación en línea
    bool paperFeedPressed =
        (status & 0x40) != 0; // Bit 6: Botón de alimentación de papel pulsado

    // Mostrar el estado en la consola
    log('(n = 1) - Estado online de la impresora:\n');
    log('Cajón: $pin3High');
    log('Impresora en línea: $printerOnline');
    log('Esperando recuperación en línea: $waitingRecovery');
    log('Botón de alimentación de papel pulsado: $paperFeedPressed');
  }
}
