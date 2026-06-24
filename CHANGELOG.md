## 1.0.0

- Versión inicial del plugin.

## 1.0.1

- Se eliminan salidas de log.

## 1.0.2

- Se comentan salidas por consola en `ti_printer_plugin`.

## 1.0.3

- Se corrige el manejo de `error` y `error_code` en `ti_printer_plugin.cpp`.

## 1.0.4

- Se eliminan trazas de comandos ESC/POS en consola dentro de `ReadStatusUsb`.

## 1.0.5

- Se agrega soporte para Linux.

## 1.0.6

- Se corrigen errores para publicacion y validacion en pub.dev.

## 1.0.7

- Se agrega soporte para `closeUsbPort`.

## 1.0.8

- Se corrige `MissingPluginException` para `closeUsbPort` en el canal `ti_printer_plugin`.

## 1.0.9

- Se corrige en Windows `MissingPluginException` para `closeUsbPort` en el canal `ti_printer_plugin`.

## 1.0.10

- Windows `windows/ti_printer_plugin.cpp`
  - PLG-01: `hUsb_` inicializado en `INVALID_HANDLE_VALUE`.
  - PLG-02: `ReadStatusUsb` y `ReadStatusSerial` devuelven todos los bytes.
  - PLG-03: USB abierto con `FILE_FLAG_OVERLAPPED` e I/O async con timeout y `CancelIoEx`.
  - PLG-15: `SendCommandToUsb` con loop por escritura parcial.
  - PLG-19: Conversión UTF-8 -> UTF-16 con `MultiByteToWideChar`.
  - PLG-21: El destructor usa `CloseUsbPort()` de forma simétrica.
  - PLG-22: Se remueve `OVERLAPPED` muerto de `SendCommandToSerial`.
- Linux `linux/ti_printer_plugin.cc`
  - PLG-02: `read_status_usb` devuelve todos los bytes leídos.
- Dart `lib/esc_pos_utils_platform/src/generator.dart`
  - PLG-06: `beep()` recursivo concatena retornos.
  - PLG-07: `oldRrow` concatena el wrap.
  - PLG-08: Se agrega comentario detallado sobre la limitación de `codeTable`.
  - PLG-09: `_getLexemes("")` protegido.
  - PLG-10: `_intLowHigh` con paréntesis correctos.
  - PLG-11 / PLG-12: Limpieza de dead code en `row()` y eliminación del round-trip `bytes -> String -> trim`.
  - PLG-13: `drawImage` sin asignación dentro del ternario.
- Dart `lib/esc_pos_utils_platform/src/qrcode.dart`
  - PLG-04: `pL` / `pH` con split de 16 bits para soportar payloads mayores a 252 bytes.
  - PLG-05: `utf8.encode` en lugar de `latin1.encode`.

## 1.0.11

- Update docuemntación

## 1.0.12

- **Reestructuración del plugin:**
  - La librería `esc_pos_utils_platform` se movió del plugin (`lib/`) a la app de ejemplo (`example/lib/`). El plugin ahora es más liviano y solo contiene la capa de comunicación nativa.
  - Se eliminaron dependencias y archivos no utilizados del plugin.

- **API simplificada (Dart + nativo):**
  - `readStatusUsb(Uint8List command)` ahora acepta `Uint8List` directamente (ya no requiere `Map {"command": ...}`).
  - `readStatusSerial(Uint8List command)` idem.
  - Actualizados `lib/ti_printer_plugin_method_channel.dart`, `windows/ti_printer_plugin.cpp` y `linux/ti_printer_plugin.cc` para reflejar el cambio.

- **Logo printing (example):**
  - Corregido error que imprimía un rectángulo negro en lugar del logo.
  - `_createLogo()` + `imageRaster()` reemplazado por `_buildLogoBytes()` que construye un bitmap 1-bit manualmente (pixel por pixel) y lo envía con el comando raw `GS v 0`.
  - Se ignoran píxeles transparentes (alpha <= 128) y se calcula luminancia correcta con pesos RGB.
  - Se corrigió el uso de `getBytes()` para leer datos de píxeles, evitando inconsistencias con `getPixel()`.

- **Compatibilidad con CMake >= 4.0 (Windows):**
  - Agregado `set(CMAKE_POLICY_VERSION_MINIMUM 3.5)` en `windows/CMakeLists.txt` antes de `FetchContent_MakeAvailable(googletest)`, resolviendo el error `Compatibility with CMake < 3.5 has been removed`.

- **Mejoras en la app de ejemplo:**
  - `PrinterState` y `PrinterLogEntry` ahora usan `Equatable` para comparaciones correctas.
  - Agregado `PrinterStatusView` con UI de monitoreo en tiempo real (online, papel, tapa, logs).
  - `TicketBuilder` ahora usa rutas relativas para importar `esc_pos_utils_platform`.
  - Actualizada la UI para mostrar estado detallado de la impresora.
  - Agregados assets `assets/logo.png` y `assets/resources/capabilities.json` en el ejemplo.
  - Mejorado `PrinterStatusInterpreter` con interpretación robusta de flags de estado DLE EOT.
  - Actualizado `image_utils.dart` con corrección en el cálculo de `dstW` (se eliminó asignación dentro del ternario).

- **Correcciones en Linux:**
  - `readStatusUsb` alineado con Windows: acepta `Uint8List` directamente.
  - Manejo robusto de errores en escritura USB (`send_command_to_usb` con reintento en `EINTR` y detección de `ENODEV`/`EIO`/`EBADF`).

- **Actualización de documentación:**
  - README actualizado con la nueva estructura, API, troubleshooting para logo negro y error de CMake.
  - Corregidos typos y desactualizaciones en la documentación existente.

## 1.0.13

- **API breaking: `getUsbPrinters()` ahora retorna `List<PrinterDeviceInfo>` en lugar de `List<String>`:**
  - Nuevo modelo `PrinterDeviceInfo` con `instanceId`, `displayName`, `vid`, `pid`.
  - `openUsbPort()` ahora requiere `device.instanceId` en vez del string directo.
  - `PrinterDeviceInfo.resolvedDisplayName`: getter que busca el VID/PID en la base de datos de impresoras conocidas y retorna un nombre legible.
  - Parseo de VID/PID desde el `instanceId` nativo (formato `USB\VID_xxxx&PID_xxxx\...`).

- **Nuevo `lib/database_printer.dart`:**
  - Clase `KnownUsbPrinter` y lista `knownThermalUsbPrinters` con +30 entradas (Epson, Star, Bixolon, Citizen, Zebra, TSC, DYMO, genéricas POS58/POS80, Gprinter, Rongta).
  - Función `lookupPrinterInfo(vid, pid)` para búsqueda programática.
  - Exportado desde `ti_printer_plugin.dart`.

- **Windows `ListUsbInstance()` — PLG-16 (Camino A + B):**
  - Camino A: Segunda pasada con `GUID_DEVCLASS_PRINTER` para capturar impresoras con drivers propietarios (Epson, Star, Bixolon), con dedup contra la primera pasada.
  - Camino B: Retorna `vector<PrinterDeviceInfo>` con `instanceId`, `displayName`, `vid`, `pid`.
  - Helpers estáticos reemplazados por lambdas inline para eliminar posibles bugs de linking.
  - `OutputDebugStringA` agregado para depurar fallos de `SetupDiGetClassDevs` y `CM_Get_Device_ID`.

- **Mejoras en la app de ejemplo:**
  - `PrinterState.usbPrinters` actualizado a `List<PrinterDeviceInfo>`.
  - `PrinterState.selectedUsbPrinter` actualizado a `PrinterDeviceInfo?`.
  - Logs de `refreshUsbPrinters()` muestran `resolvedDisplayName` e `instanceId` de cada impresora.
  - `DropdownButtonFormField` usa `p.resolvedDisplayName` como texto visible.
