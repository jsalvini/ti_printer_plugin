## 1.0.14

- **Carga correcta de `CapabilityProfile` desde assets del paquete:**
  - `CapabilityProfile.load()` y `CapabilityProfile.getAvailableProfiles()` ahora resuelven `capabilities.json` usando la clave de asset del paquete `packages/ti_printer_plugin/assets/resources/capabilities.json`.
  - La app consumidora ya no necesita declarar ni copiar `assets/resources/capabilities.json` en su propio `pubspec.yaml`.
  - Agregada prueba unitaria para validar la carga del perfil y el listado de perfiles usando un mock del canal de assets.

- **Ejemplo desacoplado de internals:**
  - `example/lib/logic/printer_controller.dart` y `example/lib/logic/ticket_builder.dart` ahora importan `package:ti_printer_plugin/esc_pos_utils_platform/esc_pos_utils_platform.dart` en lugar de rutas `src/...`.
  - La documentación aclara que el barrel público es la forma recomendada de consumir la librería ESC/POS incluida en el plugin.

## 1.0.13

- **Reestructuración de directorios:**
  - La librería `esc_pos_utils_platform` se movió de `example/lib/` a `lib/` (raíz del plugin), junto con `assets/resources/capabilities.json`.
  - Actualizadas todas las importaciones en la app de ejemplo para usar `package:ti_printer_plugin/...`.
  - El plugin ahora incluye la librería ESC/POS como parte de su propia API.

## 1.0.12

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

- **Linux `list_usb_printers()` — PLG-18 (VID/PID desde sysfs):**
  - Nuevas funciones helper `resolve_sysfs_path()` y `read_vid_pid_from_sysfs()`.
  - Cada dispositivo ahora resuelve VID/PID real recorriendo `/sys/dev/char/<major>:<minor>` y caminando hacia arriba en el árbol sysfs hasta encontrar `idVendor`/`idProduct`.
  - `displayName` se genera como `"USB Printer (VID:0xPPPP, PID:0xPPPP)"` si se encontraron VID/PID.
  - Sin dependencias externas (solo POSIX: `stat`, `realpath`, `ifstream`, `snprintf`).

- **Reestructuración del plugin:**
  - La librería `esc_pos_utils_platform` se movió del plugin (`lib/`) a la app de ejemplo (`example/lib/`). El plugin ahora es más liviano y solo contiene la capa de comunicación nativa.
  - Se eliminaron dependencias y archivos no utilizados del plugin.

- **API simplificada (Dart + nativo) — PLG-14:**
  - `readStatusUsb(Uint8List command)` y `readStatusSerial(Uint8List command)` ahora aceptan `Uint8List` directamente (ya no requiere `Map {"command": ...}`).
  - Actualizados `lib/ti_printer_plugin_method_channel.dart`, `windows/ti_printer_plugin.cpp` y `linux/ti_printer_plugin.cc`.

- **PLG-08 — Encoding respeta codeTable:**
  - Agregado mapa `_codePageMaps` con 9 code pages (CP437, CP850, CP858, CP860, CP863, CP865, CP852, CP857, ISO_8859-15).
  - `_encode()` consulta `_codeTable ?? _styles.codeTable` para seleccionar el mapa activo.

- **PLG-17 — Linux serial retorna NotImplemented:**
  - `openSerialPort`/`closeSerialPort`/`sendCommandToSerial`/`readStatusSerial` usan `fl_method_not_implemented_response_new()`.

- **PLG-20 — Capabilities duplicado eliminado:**
  - Eliminados `assets/resources/capabilities.json` y `lib/resources/capabilities.json` de la raíz del plugin.
  - Conservado `example/assets/resources/capabilities.json` como única copia canónica.

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
  - `PrinterState.usbPrinters` actualizado a `List<PrinterDeviceInfo>`.
  - `PrinterState.selectedUsbPrinter` actualizado a `PrinterDeviceInfo?`.
  - Logs de `refreshUsbPrinters()` muestran `resolvedDisplayName` e `instanceId` de cada impresora.
  - `DropdownButtonFormField` usa `p.resolvedDisplayName` como texto visible.
  - `TicketBuilder` ahora usa rutas relativas para importar `esc_pos_utils_platform`.
  - Agregados assets `assets/logo.png` y `assets/resources/capabilities.json` en el ejemplo.
  - Mejorado `PrinterStatusInterpreter` con interpretación robusta de flags de estado DLE EOT.
  - Actualizado `image_utils.dart` con corrección en el cálculo de `dstW`.

- **Correcciones en Linux:**
  - `readStatusUsb` alineado con Windows: acepta `Uint8List` directamente.
  - Manejo robusto de errores en escritura USB (`send_command_to_usb` con reintento en `EINTR` y detección de `ENODEV`/`EIO`/`EBADF`).

- **Actualización de documentación:**
  - README, CHANGELOG y `doc/fixes_aplicados_pendientes.md` actualizados con todos los cambios.
  - Renombrado `docs/` → `doc/` para cumplir convención de pub.dev.

## 1.0.11

- Update documentación

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

## 1.0.9

- Se corrige en Windows `MissingPluginException` para `closeUsbPort` en el canal `ti_printer_plugin`.

## 1.0.8

- Se corrige `MissingPluginException` para `closeUsbPort` en el canal `ti_printer_plugin`.

## 1.0.7

- Se agrega soporte para `closeUsbPort`.

## 1.0.6

- Se corrigen errores para publicacion y validacion en pub.dev.

## 1.0.5

- Se agrega soporte para Linux.

## 1.0.4

- Se eliminan trazas de comandos ESC/POS en consola dentro de `ReadStatusUsb`.

## 1.0.3

- Se corrige el manejo de `error` y `error_code` en `ti_printer_plugin.cpp`.

## 1.0.2

- Se comentan salidas por consola en `ti_printer_plugin`.

## 1.0.1

- Se eliminan salidas de log.

## 1.0.0

- Versión inicial del plugin.
