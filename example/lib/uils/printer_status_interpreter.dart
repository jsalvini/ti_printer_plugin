import 'dart:typed_data';

class PrinterStatusInterpreter {
  /// DLE EOT 1 - Printer status (n = 1)
  /// Para Epson TM-T88V y familia.
  static void interpretOnlinePrinterStatus(
    Uint8List status,
    void Function(
            bool coverOpen, bool paperFeedButton, bool paperEndStop, bool error)
        cb,
  ) {
    if (status.isEmpty) {
      // si no hay respuesta, mejor no afirmar nada
      cb(false, false, false, true); // tratar como error
      return;
    }

    final int b = status[0];

    // bit 3 = 0 -> online, 1 -> offline
    final bool offline = (b & 0x08) != 0;
    final bool error = offline; // aquí solo sabemos online/offline

    // DLE EOT 1 NO trae tapa ni papel, eso lo sacamos de otros estados.
    cb(false, false, false, error);
  }

  /// DLE EOT 2 - Offline cause status (n = 2)
  static void interpretOfflineCauseStatus(
    Uint8List status,
    void Function(
            bool coverOpen, bool paperFeedButton, bool paperEndStop, bool error)
        cb,
  ) {
    if (status.isEmpty) {
      cb(false, false, false, true);
      return;
    }

    final int b = status[0];

    // bit 2: 1 = tapa abierta
    final bool coverOpen = (b & 0x04) != 0;
    // bit 3: 1 = papel se está alimentando con botón FEED
    final bool paperFeedButton = (b & 0x08) != 0;
    // bit 5: 1 = impresión detenida por fin de papel
    final bool paperEndStop = (b & 0x20) != 0;
    // bit 6: 1 = error
    final bool error = (b & 0x40) != 0;

    cb(coverOpen, paperFeedButton, paperEndStop, error);
  }

  /// DLE EOT 4 - Roll paper sensor status (n = 4)
  /// Devuelve nearEnd (papel por acabarse) y present (hay papel).
  static void interpretRollPaperSensorStatus(
    Uint8List status,
    void Function(bool nearEnd, bool present) cb,
  ) {
    if (status.isEmpty) {
      cb(false, false);
      return;
    }

    final int b = status[0];

    // bits 5–6: 11 = sin papel (paper end)
    final bool paperEnd = (b & 0x60) == 0x60;

    // bits 2–3: 11 = near-end; pero SOLO tiene sentido si no estamos ya en paper-end.
    final bool nearEnd = !paperEnd && (b & 0x0C) == 0x0C;

    final bool present = !paperEnd;

    cb(nearEnd, present);
  }
}
