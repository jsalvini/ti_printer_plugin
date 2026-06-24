# Validación del reporte de errores y fixes de impresión

Fecha: 2026-06-23

## Alcance

Este análisis contrasta:

- `docs/analisis_printer.md`
- `docs/fix_aplicados.md`
- el código actual de `auto_compra`
- el paquete instalado `ti_printer_plugin 1.0.11` en `C:\Users\lenovo\AppData\Local\Pub\Cache\hosted\pub.dev\ti_printer_plugin-1.0.11`

La validación fue estática. No corrí `flutter test`, `flutter analyze` ni pruebas con hardware.

## Conclusión ejecutiva

El paquete `ti_printer_plugin` sí tiene aplicados casi todos los fixes documentados en `fix_aplicados.md`, y eso deja la base nativa bastante más sólida que la descrita en el incidente original.

El problema pendiente está principalmente del lado app:

- `FIX 01`, `FIX 03` y `FIX 05` están efectivamente implementados.
- `FIX 02` quedó mal resuelto: la rama de "mismo dispositivo" no hace short-circuit, limpia estado interno y vuelve a intentar `openUsbPort(...)`.
- `FIX 04` está sólo parcial: el intérprete `TM-T20IIIL` sigue devolviendo `PrinterStatus.withLimitedSensors(...)` con `hasPaper: true`.
- `FIX 06`, `FIX 07`, `FIX 08`, `FIX 09`, `FIX 11` y `FIX 12` siguen faltando o sólo tienen mitigaciones parciales.

En términos operativos, el reporte original ya no describe correctamente el estado del plugin, pero todavía sí describe varios riesgos reales de la app.

## Resultado por bloque

### 1. Plugin `ti_printer_plugin`

#### Verificados como ajustados

Los siguientes puntos sí aparecen implementados en `ti_printer_plugin 1.0.11` y coinciden con `docs/fix_aplicados.md`:

| Hallazgo | Estado | Evidencia |
| --- | --- | --- |
| `PLG-01` | Ajustado | `windows/ti_printer_plugin.cpp:53` inicializa `hUsb_(INVALID_HANDLE_VALUE)` |
| `PLG-02` | Ajustado | `windows/ti_printer_plugin.cpp` y `linux/ti_printer_plugin.cc:179-224` ya devuelven todos los bytes leídos |
| `PLG-03` | Ajustado | `windows/ti_printer_plugin.cpp:447-457`, `574-605` usa `FILE_FLAG_OVERLAPPED`, timeout y `CancelIoEx` |
| `PLG-04` | Ajustado | `lib/esc_pos_utils_platform/src/qrcode.dart:73-77` calcula `pL/pH` con split de 16 bits |
| `PLG-05` | Ajustado | `qrcode.dart:67` usa `utf8.encode(text)` |
| `PLG-06` | Ajustado | `generator.dart:512` concatena `bytes += beep(...)` |
| `PLG-07` | Ajustado | `generator.dart` refleja el arreglo del wrap en `oldRrow` |
| `PLG-09` | Ajustado | `generator.dart:133` protege `text.isEmpty` |
| `PLG-10` | Ajustado | `generator.dart:166` contiene la versión corregida de `_intLowHigh(...)` |
| `PLG-11 / PLG-12` | Ajustado | `generator.dart` contiene limpieza del flow de `row()` y comentario del round-trip removido |
| `PLG-13` | Ajustado | `generator.dart:1095` deja `dstW ??= ... ? dst.width : src.width` |
| `PLG-15` | Ajustado | `windows/ti_printer_plugin.cpp:496-540` implementa loop de escritura parcial |
| `PLG-19` | Ajustado | `windows/ti_printer_plugin.cpp:394-400` usa `MultiByteToWideChar` |
| `PLG-21` | Ajustado | `windows/ti_printer_plugin.cpp:61-62` y `475+` usan `CloseUsbPort()` en forma simétrica |
| `PLG-22` | Ajustado | `windows/ti_printer_plugin.cpp:316-317` documenta y remueve el uso muerto de `OVERLAPPED` en serial |

#### Pendientes o parciales en plugin

| Hallazgo | Estado | Observación |
| --- | --- | --- |
| `PLG-08` | Parcial | Se agregó documentación sobre la limitación, pero `generator.dart:120` sigue usando `latin1.encode(text)` y no respeta realmente el `codeTable` activo |
| `PLG-14` | Pendiente | En `lib/ti_printer_plugin_method_channel.dart:33-39` `sendCommandToSerial/Usb` mandan `Uint8List` directo, mientras `readStatusSerial/Usb` mandan `{ 'command': ... }`; la inconsistencia sigue presente |

#### Lectura global del plugin

El plugin quedó bastante alineado con el reporte en la parte crítica de I/O nativo y QR. La deuda real que sigue viva está en la capa Dart del plugin:

- encoding real por `codeTable`
- consistencia del contrato del `MethodChannel`

Esas dos deudas siguen siendo válidas del reporte original, pero no son hoy el cuello principal del incidente de campo frente a lo que todavía falta en la app.

### 2. Fixes de app `auto_compra`

#### Matriz de estado

| Fix | Estado | Diagnóstico |
| --- | --- | --- |
| `FIX 01` | Ajustado | `_safeCloseUsbPort()` sí llama `await _plugin.closeUsbPort()` en `lib/services/printer/usb_printer_service.dart:348-350` |
| `FIX 02` | Parcial / incorrecto | La rama "mismo dispositivo" en `usb_printer_service.dart:132-145` no hace short-circuit real; limpia `_currentConfig` y `_interpreter`, y luego vuelve a ejecutar `openUsbPort(...)` |
| `FIX 03` | Ajustado | `serial_printer_service.dart:232` usa `sendCommandToSerial(...)` y `_safeCloseSerialPort()` sí llama `closeSerialPort()` |
| `FIX 04` | Parcial | `tmt20iiil_status_interpreter.dart` recibe `paperResponse`, pero nunca lo usa en la lógica; todas las salidas siguen pasando por `PrinterStatus.withLimitedSensors(...)` |
| `FIX 05` | Ajustado | `printer_bloc.dart:1425-1427`, `1730` usa `_confirmPrintedAfterSend()` antes de declarar éxito |
| `FIX 06` | Parcial | Se agregó confirmación post-envío y algunas guardas de UI, pero no existe un modelo de idempotencia por voucher con estado persistente o IDs confirmados |
| `FIX 07` | Faltante | `usb_printer_service.dart` y `serial_printer_service.dart` no envuelven `readStatus...` ni `sendCommand...` con `.timeout(...)` |
| `FIX 08` | Faltante | `testConnection()` sigue abriendo/cerrando puertos sin respetar si existe una conexión activa |
| `FIX 09` | Faltante | No se invalida `_lastDeviceCheck` dentro de `checkStatus()` ante respuesta vacía o fallo de comunicación |
| `FIX 10` | Ajustado indirectamente | Los logs de cierre ahora son veraces porque `FIX 01/03` sí cerraron puertos realmente |
| `FIX 11` | Faltante / parcial | Siguen el spin-wait falso y el listener con posible acumulación; además `withLimitedSensors` sigue activo |
| `FIX 12` | Faltante | `UsbPrinterService` y `SerialPrinterService` siguen creando `TiPrinterPlugin()` propio; la factory no inyecta una instancia única |

#### Detalle por fix

##### `FIX 01` ajustado

El reporte pedía habilitar el cierre real del puerto USB. Eso ya está resuelto:

- `lib/services/printer/usb_printer_service.dart:348-350`

Impacto:

- este punto del reporte original ya no está pendiente
- los logs `"Puerto USB cerrado correctamente"` ahora sí reflejan una acción real

##### `FIX 02` parcial e incorrecto

El objetivo del fix era evitar reabrir el mismo device si ya estaba conectado. El código actual no cumple eso:

- `lib/services/printer/usb_printer_service.dart:132-145`

Comportamiento actual:

1. detecta que es el mismo `devicePath`
2. loguea `"Ya conectado a este dispositivo, omitiendo close..."`
3. igual limpia `_currentConfig` y `_interpreter`
4. igual llama `openUsbPort(config.devicePath!)`

Eso no es un short-circuit; es una reapertura con estado interno borrado. Este punto sigue necesitando ajuste.

##### `FIX 03` ajustado

El cambio crítico del service serial sí está:

- `lib/services/printer/serial_printer_service.dart:232`
- `lib/services/printer/serial_printer_service.dart:290-294`

Esto deja sin vigencia la parte del reporte que decía que serial seguía intentando imprimir por el método incorrecto o sin cierre real.

##### `FIX 04` parcial

Acá hay mejora, pero no cierre completo.

Mejoras presentes:

- `lib/models/printer/tmt20iiil_status_interpreter.dart` ya acepta `paperResponse`
- `StatusInterpreterFactory` sigue resolviendo `TM-T20IIIL`

Problema que sigue:

- `tmt20iiil_status_interpreter.dart:55,72,115,128` retorna siempre `PrinterStatus.withLimitedSensors(...)`
- `lib/models/printer/printer_status.dart:62-77` define `withLimitedSensors(...)` con `hasPaper: true`

Conclusión:

- el intérprete dejó de ser "ciego" sólo en la firma y en comentarios
- en la lógica efectiva todavía no corta el caso "sin papel = error" como pedía el reporte

##### `FIX 05` ajustado

La confirmación post-envío sí quedó implementada:

- `lib/viewmodels/printer/printer_bloc.dart:1425-1427`
- `lib/viewmodels/printer/printer_bloc.dart:1730`
- `lib/viewmodels/printer/printer_bloc.dart:2039-2048`

Esto corrige una parte muy importante del diagnóstico original: el bloc ya no toma `sendRawData()` como éxito definitivo sin releer estado.

##### `FIX 06` parcial

No encontré una implementación real de idempotencia por voucher en el bloc:

- no existe `VoucherJob`
- no existe mapa de vouchers confirmados
- no existe persistencia por ID de voucher en `PrinterBloc`
- el archivo `printer_bloc.dart` no tiene búsqueda por `voucher.id`, `confirmed`, `pending` o estructura equivalente

Lo que sí existe:

- confirmación post-envío antes de contar un voucher como impreso
- guardas en UI para no reenviar por taps duplicados en `lib/views/management_ticket/management_ticket_page.dart:655-686`

Eso reduce duplicaciones por interacción inmediata, pero no resuelve el caso fuerte del reporte:

- retry de proceso
- recuperación tras reconexión
- persistencia de qué voucher ya fue realmente confirmado

##### `FIX 07` faltante

El reporte pedía timeouts defensivos del lado Dart además del plugin nativo.

No están:

- `lib/services/printer/usb_printer_service.dart:225,247,251,294`
- `lib/services/printer/serial_printer_service.dart:171,175,179,232`

Ninguna de esas llamadas usa `.timeout(...)`.

Conclusión:

- la app sigue confiando completamente en que el plugin siempre responda
- este punto sigue pendiente como defensa en profundidad

##### `FIX 08` faltante

El reporte pedía que `testConnection()` no toque handles si ya hay conexión activa.

Estado actual:

- `usb_printer_service.dart:306-320` siempre intenta `openUsbPort(...)`
- `serial_printer_service.dart:244-263` siempre intenta `openSerialPort(...)`

No hay lógica que preserve la conexión activa verificando sólo presencia en lista.

##### `FIX 09` faltante

El reporte pedía invalidar cache de devices al fallar la comunicación para no esperar el ciclo de cache.

Estado actual:

- `_lastDeviceCheck = null` aparece en `usb_printer_service.dart:342`, pero no dentro del path de error de `checkStatus()`
- cuando `onlineResponse.isEmpty`, el servicio llama `_isDevicePresent(...)` con el cache vigente

Conclusión:

- la mejora de detección más rápida sigue pendiente

##### `FIX 10` ajustado indirectamente

Como `FIX 01` y `FIX 03` sí están, los logs de cierre:

- `usb_printer_service.dart:350-351`
- `serial_printer_service.dart:294-295`

ya no son engañosos.

##### `FIX 11` faltante / parcial

Siguen vigentes varios ítems de higiene del reporte:

- spin-wait todavía presente en `printer_bloc.dart:1283` y `1585`
- listener potencialmente acumulable en `lib/views/envases/widget/build_vale_listener.dart:112-133`
- `PrinterStatus.withLimitedSensors(...)` sigue existiendo y forzando `hasPaper: true`

No validé si `PrinterStatusHandler` sigue realmente zombi, pero al menos los puntos más explícitos del reporte no fueron limpiados por completo.

##### `FIX 12` faltante

La app sigue creando instancias separadas del plugin:

- `lib/services/printer/usb_printer_service.dart:43`
- `lib/services/printer/serial_printer_service.dart:30`

Y la factory no inyecta una instancia única de `TiPrinterPlugin`, sino que sólo cachea servicios si `reuseInstance == true`:

- `lib/models/printer/printer_service_factory.dart:22-32`
- `lib/models/printer/printer_service_factory.dart:116-119`

Esto deja vigente la observación cosmética/arquitectónica del reporte.

## Qué ya no hay que seguir reportando como pendiente

Estos puntos conviene moverlos a "resueltos" en cualquier seguimiento nuevo:

- fixes nativos críticos del plugin `PLG-01`, `PLG-02`, `PLG-03`, `PLG-15`, `PLG-19`, `PLG-21`, `PLG-22`
- fixes de QR del plugin `PLG-04`, `PLG-05`
- fixes estructurales de `generator.dart` `PLG-06`, `PLG-07`, `PLG-09`, `PLG-10`, `PLG-11`, `PLG-12`, `PLG-13`
- `FIX 01` de app
- `FIX 03` de app
- `FIX 05` de app
- `FIX 10` de app, como consecuencia de los cierres reales

## Qué falta ajustar realmente

### Prioridad alta

1. Corregir `FIX 02` en `UsbPrinterService.connect()` para que el mismo dispositivo haga return inmediato sin reabrir puerto.
2. Completar `FIX 04` para que `TM-T20IIIL` use `paperResponse` en la decisión y deje de depender de `withLimitedSensors(hasPaper: true)`.
3. Implementar `FIX 06` con idempotencia real por voucher, no sólo guardas de UI.
4. Agregar `FIX 07` con `.timeout(...)` en services Dart.
5. Resolver `FIX 08` y `FIX 09` para no romper conexión activa ni demorar detección ante fallos.

### Prioridad media

1. Limpiar `FIX 11`: spin-waits, listener de `build_vale_listener` y deprecación/remoción de `withLimitedSensors`.
2. Aplicar `FIX 12` para explicitar una instancia compartida del plugin.
3. En plugin, cerrar la deuda `PLG-08` y `PLG-14`.

## Riesgos residuales

- Aunque `FIX 05` existe, mientras `FIX 04` siga parcial el criterio de "impresión confirmada" puede seguir siendo optimista para ciertos modelos.
- Aunque hay comentarios y guardas contra duplicación, sin `FIX 06` persiste el riesgo de duplicados ante retry/reinicio.
- No encontré tests específicos que validen la nueva confirmación post-envío o la idempotencia por voucher; `test/viewmodels/printer/printer_bloc_test.dart` sigue concentrado en flujos Bluetooth generales.

## Recomendación de siguiente paso

Si querés que el seguimiento quede fiel al estado real del código, conviene tomar este orden:

1. cerrar `FIX 02`
2. cerrar `FIX 04`
3. implementar `FIX 06`
4. agregar `FIX 07/08/09`
5. dejar `FIX 11/12` y `PLG-08/14` como deuda secundaria

Con ese recorte, el reporte deja de mezclar problemas ya resueltos del plugin con los pendientes reales de la app.
