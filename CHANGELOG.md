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
