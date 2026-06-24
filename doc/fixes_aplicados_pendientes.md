# Fixes aplicados y pendientes · ti_printer_plugin

Basado en `doc/analisis_printer.md` (22 hallazgos PLG-01 a PLG-22) y trabajo de sesiones de corrección.

---

## PLG-01 a PLG-15, PLG-19, PLG-21, PLG-22 — Aplicados en entrega base v1.0.11

Estos 18 fixes ya estaban aplicados antes de las sesiones de corrección actuales.

| ID | Archivo | Problema |
|---|---|---|
| PLG-01 | `windows/ti_printer_plugin.cpp:53` | `hUsb_` no inicializado en constructor |
| PLG-02 | `windows/ti_printer_plugin.cpp` / `linux/ti_printer_plugin.cc:179-224` | Lectura de estado truncada a 1 byte |
| PLG-03 | `windows/ti_printer_plugin.cpp:447-457,574-605` | ReadFile USB sin timeout (síncrono bloqueante) |
| PLG-04 | `lib/src/qrcode.dart:73-77` | QR limitado a 252 bytes (pL/pH sin split 16-bit) |
| PLG-05 | `lib/src/qrcode.dart:67` | QR usa latin1.encode en vez de utf8.encode |
| PLG-06 | `lib/src/generator.dart:512` | beep() recursivo descarta retorno |
| PLG-07 | `lib/src/generator.dart` | oldRrow() pierde wrap de columnas |
| PLG-09 | `lib/src/generator.dart:133` | _getLexemes("") tira RangeError |
| PLG-10 | `lib/src/generator.dart:166` | _intLowHigh paréntesis mal en cota máxima |
| PLG-11 | `lib/src/generator.dart` | Dead code en row() por refactor anterior |
| PLG-12 | `lib/src/generator.dart` | Round-trip bytes → string → bytes innecesario |
| PLG-13 | `lib/src/generator.dart:1095` | drawImage sin dstW usa src.width incorrecto |
| PLG-15 | `windows/ti_printer_plugin.cpp:496-540` | SendCommandToUsb sin loop de escritura parcial |
| PLG-19 | `windows/ti_printer_plugin.cpp:394-400` | string→wstring byte-a-byte (solo ASCII) |
| PLG-21 | `windows/ti_printer_plugin.cpp:61-62,475+` | Destructor asimétrico (CloseHandle sin init check) |
| PLG-22 | `windows/ti_printer_plugin.cpp:316-317` | OVERLAPPED muerto en serial |

---

## PLG-20 — Resuelto en sesión actual

**Estado:** Aplicado

**Archivos:**
- Eliminado `assets/resources/capabilities.json` (raíz del plugin)
- Eliminado `lib/resources/capabilities.json` (raíz del plugin)
- Conservado `example/assets/resources/capabilities.json` como única copia canónica
- `example/pubspec.yaml:68`: declarado asset `assets/resources/capabilities.json`
- `example/lib/esc_pos_utils_platform/src/capability_profile.dart:24,59`: ruta cambiada de `packages/ti_printer_plugin/resources/...` a `assets/resources/capabilities.json`

**Impacto:** `flutter analyze` sin errores. Los assets viven solo en `/example`, sin referencias en el pubspec del plugin raíz.

**PLG-20 original:** capabilities.json duplicado en 3 lugares (raíz/assets, raíz/lib, example/assets) con contenidos posiblemente divergentes.

---

## PLG-08 — Resuelto en sesión actual

**Estado:** Aplicado

**Archivo:** `example/lib/esc_pos_utils_platform/src/generator.dart`

**Problema original:** `_encode()` ignoraba el `codeTable` del `PosStyles` y siempre usaba `latin1.encode`, generando bytes incorrectos para acentos con CP437 (ñ → ±, ° → ░).

**Solución:**
- Agregado mapa `_codePageMaps` con 9 code pages (CP437, CP850, CP858, CP860, CP863, CP865, CP852, CP857, ISO_8859-15)
- `_encode()` consulta `_codeTable ?? _styles.codeTable` para seleccionar el mapa activo
- Caracteres ASCII (< 128) pasan directo; no-ASCII se buscan en el mapa; fallback a `latin1.encode` y luego a `0x3F` ('?')
- Corregidas claves duplicadas en CP857 (0x00AA/0x00BA) y CP865 (0x00D2)

**Impacto:** `flutter analyze` sin errores. Sin nuevas dependencias. Code pages asiáticos (CP932, CP874, TCVN) quedan fuera de alcance.

---

## PLG-17 — Resuelto en sesión actual

**Estado:** Aplicado

**Archivo:** `linux/ti_printer_plugin.cc:254-260`

**Problema original:** `openSerialPort`/`closeSerialPort`/`sendCommandToSerial`/`readStatusSerial` devolvían `false` o lista vacía silenciosamente en Linux, indistinguible de "operación falló".

**Solución:** Reemplazados los 4 handlers por `fl_method_not_implemented_response_new()`. El caller recibe `MissingPluginException` y puede distinguir "no implementado en esta plataforma" de "error real".

---

## PLG-16 — Resuelto en sesión actual

**Estado:** Aplicado

**Archivos:**
- `windows/ti_printer_plugin.cpp:614-753` — `ListUsbInstance()` con Camino A + B
- `lib/printer_device_info.dart` — Nuevo modelo `PrinterDeviceInfo`
- `lib/ti_printer_plugin_method_channel.dart` — Parseo de `List<Map>` → `List<PrinterDeviceInfo>`
- `windows/ti_printer_plugin.h` — Struct `PrinterDeviceInfo` nativa
- `linux/ti_printer_plugin.cc` — `list_usb_printers()` adaptado a `PrinterDeviceInfo`

### Solución aplicada

**Camino A — Fallback por `GUID_DEVCLASS_PRINTER`:**

Segunda pasada en `ListUsbInstance()` que enumera dispositivos de clase `GUID_DEVCLASS_PRINTER` (`<devguid.h>`), capturando impresoras con drivers propietarios (Epson, Star, Bixolon, etc.). Se aplica dedup contra la primera pasada por `instanceId`.

**Camino B — API con `PrinterDeviceInfo`:**

`getUsbPrinters()` ahora devuelve `List<PrinterDeviceInfo>` con:
- `instanceId` — DeviceInstanceId de Windows o ruta `/dev/...` en Linux
- `displayName` — Nombre original desde Windows (SPDRP_FRIENDLYNAME / SPDRP_DEVICEDESC)
- `vid`, `pid` — Extraídos del `instanceId` mediante parseo de `VID_xxxx`/`PID_xxxx`

**Refactor adicional:**
- Helpers estáticos (`parseHexFromInstanceId`, `getDisplayName`, `buildPrinterInfo`) reemplazados por lambdas inline dentro de `ListUsbInstance()`, eliminando posibles bugs de linking.
- `OutputDebugStringA` agregado para depurar fallos de `SetupDiGetClassDevs` y `CM_Get_Device_ID` en tiempo real vía DebugView.

**En los clientes:**

```dart
final printers = await plugin.getUsbPrinters();
for (final p in printers) {
  print(p.instanceId);    // USB\VID_04B8&PID_0E03\...
  print(p.displayName);   // EPSON TM-T20 (desde Windows)
  print(p.vid);           // 0x04B8
  print(p.pid);           // 0x0E03
}
await plugin.openUsbPort(printers.first.instanceId);
```

### Breaking change

`getUsbPrinters()` cambió de `Future<List<String>>` a `Future<List<PrinterDeviceInfo>>`. Los callers deben migrar de:

```dart
final printers = await plugin.getUsbPrinters(); // List<String>
await plugin.openUsbPort(printers.first);        // String directo
```

a:

```dart
final printers = await plugin.getUsbPrinters(); // List<PrinterDeviceInfo>
await plugin.openUsbPort(printers.first.instanceId); // .instanceId
```

---

## PLG-14 — Resuelto en sesión actual

**Estado:** Aplicado

**Archivos:** `lib/ti_printer_plugin_method_channel.dart`, `windows/ti_printer_plugin.cpp`, `linux/ti_printer_plugin.cc`

**Problema original:** Inconsistencia en argumentos de method channel: `sendCommandToSerial`/`sendCommandToUsb` mandan `Uint8List` directo, mientras `readStatusSerial`/`readStatusUsb` mandan `{ 'command': Uint8List }`.

**Solución:** Alineados los 4 métodos a usar `Uint8List` directo (sin mapa contenedor):

| Método | Antes | Después |
|---|---|---|
| `readStatusSerial` | `{'command': Uint8List}` | `Uint8List` directo |
| `readStatusUsb` | `{'command': Uint8List}` | `Uint8List` directo |
| `sendCommandToSerial` | `Uint8List` directo | sin cambio |
| `sendCommandToUsb` | `Uint8List` directo | sin cambio |

- **Dart** (`lib/ti_printer_plugin_method_channel.dart:43-46,75-78`): `readStatusSerial` y `readStatusUsb` pasan `command` directo
- **Windows** (`windows/ti_printer_plugin.cpp:122-145,199-222`): handlers cambian de `std::get_if<EncodableMap>` + extraer `"command"` → `std::get_if<vector<uint8_t>>` directo
- **Linux** (`linux/ti_printer_plugin.cc:360-404`): handler cambia de `FL_VALUE_TYPE_MAP` + `fl_value_lookup_string("command")` → `FL_VALUE_TYPE_UINT8_LIST` directo

**Impacto:** `flutter analyze` sin errores. Contrato unificado: todas las funciones que reciben un comando binario lo hacen como `Uint8List` directo.

---

## PLG-18 — Resuelto en sesión actual

**Estado:** Aplicado

**Archivo:** `linux/ti_printer_plugin.cc:79-103` — `list_usb_printers()` + helpers nuevos

**Problema original:** En Linux aparecían Arduinos, módems 4G, GPS, lectores RFID, conversores FT232/CH340 además de impresoras reales.

**Solución:**

Se agregaron dos funciones helper que resuelven VID/PID real desde sysfs para cada dispositivo encontrado:

1. **`resolve_sysfs_path(dev_path)`** — Dado `/dev/usb/lp0`, obtiene la ruta sysfs real siguiendo el symlink `/sys/dev/char/<major>:<minor>` → `/sys/devices/.../usb1/1-2:1.0/usbmisc/lp0`

2. **`read_vid_pid_from_sysfs(sysfs_path)`** — Camina hacia arriba en el árbol sysfs buscando un directorio que contenga `idVendor` e `idProduct`, y los parsea a valores enteros hexadecimales.

**En `list_usb_printers()`:**

```cpp
std::string sysfs_path = resolve_sysfs_path(path);
if (!sysfs_path.empty()) {
    auto vid_pid = read_vid_pid_from_sysfs(sysfs_path);
    info.vid = vid_pid.first;
    info.pid = vid_pid.second;
}
```

**Resultado:**
- Cada `PrinterDeviceInfo` ahora trae `vid` y `pid` reales (no hardcodeados a 0)
- `displayName` se genera como `"USB Printer (VID:0xPPPP, PID:0xPPPP)"` si se encontraron VID/PID
- Si no se encontraron (falló el acceso a sysfs), mantiene el nombre base del dispositivo (ej: `"lp0"`)
- El `resolvedDisplayName` de Dart aplica el database `knownThermalUsbPrinters` sobre estos VID/PID reales

**Impacto en el cliente:** Un Arduino en `/dev/ttyACM0` se mostrará como `"USB Printer (VID:0x2341, PID:0x0043)"` en lugar de `"ttyACM0"`, y una impresora Epson mostrará su nombre del database.

**Dependencias:** Sin nuevas dependencias externas. Usa solo POSIX (`stat`, `realpath`, `ifstream`, `snprintf`).

---

## PLG-23 — Resuelto en sesión actual

**Estado:** Aplicado

**Archivos:**
- `lib/database_printer.dart` (nuevo) — Mapeo VID/PID → nombre conocido
- `lib/printer_device_info.dart` — Getter `resolvedDisplayName`

### Problema

Los nombres de impresora devueltos por Windows (`displayName`) suelen ser genéricos o contener caracteres extraños (ej: "USB Printing Support", "Љ Љ"). No hay forma de identificar el modelo real de la impresora sin conocer su VID/PID.

### Solución

1. **`lib/database_printer.dart`** — Clase `KnownUsbPrinter` con `vid`, `pid`, `displayName`, `protocol`, `exactModel`. Lista `knownThermalUsbPrinters` con +30 entradas (Epson, Star, Bixolon, Citizen, Zebra, TSC, DYMO, genéricas POS58/POS80, Gprinter, etc.). Función `lookupPrinterInfo(vid, pid)` para búsqueda por VID+PID exacto.

2. **`PrinterDeviceInfo.resolvedDisplayName`** — Getter que aplica el siguiente orden de precedencia:
   - Si `(vid, pid)` está en `knownThermalUsbPrinters` → usa el nombre del database (ej: `"EPSON TM-T20"`)
   - Si no está en el database pero VID/PID > 0 → `"USB Printer (VID:0xPPPP, PID:0xPPPP)"`
   - Si VID/PID son 0 → usa el `displayName` original de Windows

3. El `displayName` original de Windows nunca se pierde; `resolvedDisplayName` es solo un getter derivado.

### Uso

```dart
// En la app:
final printers = await plugin.getUsbPrinters();
print(printers.first.resolvedDisplayName); // "EPSON TM-T20" si está en la DB
print(printers.first.displayName);         // Original de Windows (siempre disponible)

// El DropdownMenuItem de la UI usa p.resolvedDisplayName
```

### Mantenimiento

Para agregar nuevas impresoras al database, editar `lib/database_printer.dart` y agregar una entrada:

```dart
KnownUsbPrinter(
  vid: 0xXXXX,
  pid: 0xYYYY,
  displayName: 'Nombre del modelo',
  protocol: 'escpos',  // o 'zpl', 'tspl', 'dymo', etc.
),
```

---

## Resumen de estado

| ID | Prioridad | Estado | Observación |
|---|---|---|---|---|
| PLG-01 | Crítico | Aplicado v1.0.11 | |
| PLG-02 | Crítico | Aplicado v1.0.11 | |
| PLG-03 | Crítico | Aplicado v1.0.11 | |
| PLG-04 | Crítico | Aplicado v1.0.11 | |
| PLG-05 | Crítico | Aplicado v1.0.11 | |
| PLG-06 | Crítico | Aplicado v1.0.11 | |
| PLG-07 | Crítico | Aplicado v1.0.11 | |
| **PLG-08** | **Crítico** | **Aplicado (sesión actual)** | Encoding respeta codeTable |
| PLG-09 | Crítico | Aplicado v1.0.11 | |
| PLG-10 | Crítico | Aplicado v1.0.11 | |
| PLG-11 | Latente | Aplicado v1.0.11 | |
| PLG-12 | Latente | Aplicado v1.0.11 | |
| PLG-13 | Latente | Aplicado v1.0.11 | |
| **PLG-14** | **Latente** | **Aplicado (sesión actual)** | Args alineados → Uint8List directo |
| PLG-15 | Latente | Aplicado v1.0.11 | |
| **PLG-16** | **Latente** | **Aplicado (sesión actual)** | Camino A + B: GUID_DEVCLASS_PRINTER + PrinterDeviceInfo |
| **PLG-17** | **Latente** | **Aplicado (sesión actual)** | Linux serial → NotImplemented |
| **PLG-18** | **Latente** | **Aplicado (sesión actual)** | Linux VID/PID desde sysfs |
| PLG-19 | Latente | Aplicado v1.0.11 | |
| **PLG-20** | **Smell** | **Aplicado (sesión actual)** | Capabilities duplicado eliminado |
| PLG-21 | Smell | Aplicado v1.0.11 | |
| PLG-22 | Smell | Aplicado v1.0.11 | |
| **PLG-23** | **Mejora** | **Aplicado (sesión actual)** | database_printer.dart + resolvedDisplayName |

**Total:** 23 hallazgos · 18 aplicados en v1.0.11 · 7 aplicados en sesión actual (PLG-08, PLG-14, PLG-16, PLG-17, PLG-18, PLG-20, PLG-23) · 0 pendientes

*Documento generado: 2026-06-24*
