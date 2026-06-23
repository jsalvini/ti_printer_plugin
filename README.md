# ti_printer_plugin

Plugin de Flutter para impresión en **impresoras térmicas ESC/POS** por **USB** con soporte para:

- 🟦 **Windows**
- 🐧 **Linux**

Incluye:

- Capa nativa en C/C++ (Windows y Linux) usando **MethodChannel**.
- Librería ESC/POS integrada (`esc_pos_utils_platform`) para generar tickets.
- Una **aplicación de ejemplo** en la carpeta `example/` que muestra cómo consumir el plugin:
  - Monitor de estado en tiempo real (online/offline, papel, tapa).
  - Construcción de ticket con logo, encabezado, detalle, totales y código QR.
  - Consola de logs en UI.

> ⚠️ Importante:  
> Todo lo que está dentro de la carpeta `example/` **no forma parte del plugin** publicado.  
> Es solo una app de referencia para mostrar una posible integración.

---

## Índice

- [Características](#características)
- [Plataformas soportadas](#plataformas-soportadas)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Arquitectura](#arquitectura)
  - [Plugin (paquete `ti_printer_plugin`)](#plugin-paquete-ti_printer_plugin)
    - [Capa Dart](#capa-dart)
    - [Capa nativa Windows](#capa-nativa-windows)
    - [Capa nativa-linux](#capa-nativa-linux)
  - [Aplicación de ejemplo (`example/`)](#aplicación-de-ejemplo-example)
- [API Dart](#api-dart)
  - [Detección y conexión USB](#detección-y-conexión-usb)
  - [Lectura de estado ESC-POS](#lectura-de-estado-esc-pos)
  - [Impresión de datos crudos](#impresión-de-datos-crudos)
- [Construcción de tickets ESC/POS (ejemplo)](#construcción-de-tickets-escpos-ejemplo)
- [Monitor de estado en tiempo real (ejemplo)](#monitor-de-estado-en-tiempo-real-ejemplo)
- [Ejemplo de uso en Flutter](#ejemplo-de-uso-en-flutter)
- [Permisos en Linux](#permisos-en-linux)
- [Desarrollo y estructura de carpetas](#desarrollo-y-estructura-de-carpetas)
- [Problemas conocidos / troubleshooting](#problemas-conocidos--troubleshooting)
- [Licencia](#licencia)

---

## Características

- 🔌 Detección de impresoras USB (Windows y Linux).
- 🖨️ Apertura y cierre de puerto USB.
- 🧰 Soporte de puerto serial disponible actualmente solo en Windows.
- 🧾 Envío de comandos ESC/POS "raw" a la impresora.
- ↔️ Las lecturas de estado USB/serial devuelven todos los bytes recibidos; no se truncan al primer byte.
- 📡 Lectura de estado de impresora usando comandos **DLE EOT**:
  - `DLE EOT 1` – estado online.
  - `DLE EOT 4` – sensor de papel.
  - `DLE EOT 2` – causas de offline (tapa abierta, error, etc.).
- API simple en Dart basada en `MethodChannel`.
- **Opcional (en example/):**
  - `PrinterController`, `PrinterState`, `TicketBuilder` y helpers para:
    - Interpretar estados ESC/POS.
    - Generar tickets completos.
    - Monitorear estado en tiempo real.

---

## Plataformas soportadas

- **Windows**:
  - Plugin nativo en C++ (archivos en `windows/`).
  - `getUsbPrinters()` devuelve `DeviceInstanceId` de dispositivos filtrados por servicio `usbprint`.
  - Soporte para impresoras USB raw y puertos seriales (`COMx`).
  - USB abierto con `FILE_FLAG_OVERLAPPED` para lecturas con timeout y escrituras no bloqueantes.
  - `SendCommandToUsb()` reintenta escrituras parciales hasta enviar todo el buffer o fallar.
  - Lectura de estado ESC/POS por USB y serial, devolviendo todos los bytes recibidos.

- **Linux**:
  - Plugin nativo en C++ (archivo principal: `linux/ti_printer_plugin.cc`).
  - `getUsbPrinters()` devuelve rutas de dispositivo candidatas, por ejemplo:
    - `/dev/usb/lp*`
    - `/dev/ttyUSB*`
    - `/dev/ttyACM*`
  - Escritura bloqueante a los dispositivos (`open` + `write` + `fsync`).
  - Si `write` falla con `ENODEV`, `EIO` o `EBADF`, el descriptor se cierra y el plugin considera el dispositivo desconectado.
  - Lectura de estados ESC/POS por USB con `select` + `read`, devolviendo todos los bytes recibidos.
  - La API serial de Dart existe, pero actualmente en Linux responde `false` o `Uint8List` vacio segun el metodo.

> **Nota:** Android, iOS y Web no están soportados por este plugin.

---

## Requisitos

- Flutter (canal stable, versión reciente).
- Para **Linux**:
  - Toolchain de C++ (g++, clang, etc.).
  - Paquetes de desarrollo de GTK3 (requeridos por `flutter_linux`).
  - Permisos de acceso a dispositivos `/dev/usb/lp*` / `/dev/ttyUSB*` / `/dev/ttyACM*`.

---

## Instalación

En `pubspec.yaml` de tu aplicación:

```yaml
dependencies:
  # Si está publicado en pub.dev:
  # ti_printer_plugin: ^1.0.10

  # O como dependencia de Git:
  ti_printer_plugin:
    git:
      url: https://github.com/jsalvini/ti_printer_plugin.git
```

Luego:

```bash
flutter pub get
```

En Linux/Windows, Flutter generará automáticamente los enlaces del plugin al compilar.

---

## Arquitectura

La arquitectura se divide en dos capas principales:

1. **Plugin** (`lib/`, `windows/`, `linux/`):  
   Es lo que se publica y lo que tu aplicación va a consumir.
2. **Aplicación de ejemplo** (`example/`):  
   Solo sirve como referencia de cómo usar el plugin. No es parte de la API pública.

### Plugin (paquete `ti_printer_plugin`)

#### Capa Dart

Dentro de `lib/` (raíz del plugin):

- `ti_printer_plugin.dart`  
  API de alto nivel que tu app importa, por ejemplo:

  ```dart
  import 'package:ti_printer_plugin/ti_printer_plugin.dart';
  ```

- `ti_printer_plugin_method_channel.dart`  
  Implementación concreta usando:

  ```dart
  const MethodChannel('ti_printer_plugin');
  ```

- `ti_printer_plugin_platform_interface.dart`  
  Define la interfaz abstracta que `MethodChannelTiPrinterPlugin` implementa.  
  Permite:
  - Crear otras implementaciones (ej: mocks para tests).
  - Mantener tipado y contrato de la API.

La API expone métodos como:

- `Future<String> getPlatformVersion()`
- `Future<List<String>> getUsbPrinters()`
- `Future<bool> openUsbPort(String deviceInstanceId)`
- `Future<bool> closeUsbPort()`
- `Future<bool> sendCommandToUsb(Uint8List data)`
- `Future<Uint8List> readStatusUsb(Uint8List command)`
- `Future<bool> openSerialPort(String port, int baudRate)`
- `Future<bool> closeSerialPort()`
- `Future<bool> sendCommandToSerial(Uint8List data)`
- `Future<Uint8List> readStatusSerial(Uint8List command)`

### Contrato de respuestas

- `getUsbPrinters()` devuelve identificadores listos para reutilizar en `openUsbPort()`: `DeviceInstanceId` en Windows y rutas `/dev/...` en Linux.
- Los métodos booleanos (`openUsbPort`, `closeUsbPort`, `sendCommandToUsb`, `openSerialPort`, `closeSerialPort`, `sendCommandToSerial`, etc.) devuelven `true` en éxito y `false` en fallo o si la capacidad no está soportada en la plataforma actual.
- Los métodos `readStatusUsb` y `readStatusSerial` devuelven un `Uint8List` con todos los bytes recibidos cuando la impresora responde.
- Si no hay respuesta antes del timeout, ocurre un error nativo o la capacidad no está soportada, las lecturas de estado devuelven un `Uint8List` vacío.

#### Capa nativa Windows

Carpeta `windows/` (plugin, no example):

- `ti_printer_plugin.cpp`
- `ti_printer_plugin_c_api.cpp`
- `ti_printer_plugin.h`
- `CMakeLists.txt`

Responsabilidades:

- Implementar las funciones que el `MethodChannel` invoca:

  - `getPlatformVersion`
  - `getUsbPrinters`
  - `openUsbPort`
  - `closeUsbPort`
  - `sendCommandToUsb`
  - `readStatusUsb`
  - `openSerialPort`
  - `readStatusSerial`
  - etc.

- Gestionar en C++:

  - Apertura/cierre de puerto USB/serie.
  - Envío de bytes ESC/POS.
  - Escritura USB overlapped con timeout y reintento en caso de escritura parcial.
  - Lectura de estado desde la impresora y conversión a bytes completos que se devuelven a Dart.

#### Capa nativa Linux

Carpeta `linux/` (plugin, no example):

- `CMakeLists.txt`
- `ti_printer_plugin.cc`
- `include/ti_printer_plugin/ti_printer_plugin.h`
- `ti_printer_plugin_private.h`

Responsabilidades principales de `ti_printer_plugin.cc`:

- Enumerar posibles impresoras:

  ```cpp
  static std::vector<std::string> list_usb_printers() {
    std::vector<std::string> paths;
    add_dev_entries_with_prefix("/dev/usb", "lp", paths);
    add_dev_entries_with_prefix("/dev", "ttyUSB", paths);
    add_dev_entries_with_prefix("/dev", "ttyACM", paths);
    return paths;
  }
  ```

- Abrir/cerrar puerto:

  ```cpp
  static bool open_usb_port(TiPrinterPlugin* self,
                            const std::string& device_path);
  static bool close_usb_port(TiPrinterPlugin* self);
  ```

- Enviar datos:

  ```cpp
  static bool send_command_to_usb(TiPrinterPlugin* self,
                                  const uint8_t* data,
                                  size_t length);
  ```

  - Usa `write` en modo bloqueante.
  - En caso de errores como `ENODEV`, `EIO` o `EBADF`, cierra el descriptor y lo marca en `-1` para indicar que el dispositivo ya no está disponible.

- Leer estado ESC/POS:

  ```cpp
  static std::vector<uint8_t> read_status_usb(
      TiPrinterPlugin* self,
      const std::vector<uint8_t>& command);
  ```

  - Envía el comando ESC/POS (por ejemplo DLE EOT n).
  - Espera hasta 500 ms con `select`.
  - Si hay datos, devuelve todos los bytes leidos.
  - Si no hay respuesta o hay error, devuelve un `vector` vacío.

- Integrarse con Flutter por medio de `FlMethodChannel`:

  - `getPlatformVersion`
  - `getUsbPrinters`
  - `openUsbPort`
  - `closeUsbPort`
  - `sendCommandToUsb`
  - `readStatusUsb`

### Aplicación de ejemplo (`example/`)

La carpeta `example/` contiene una **app Flutter separada** que:

- Declara dependencia al plugin `ti_printer_plugin`.
- Implementa su propia lógica de dominio.
- Muestra cómo:
  - Listar impresoras.
  - Seleccionar una impresora.
  - Abrir/cerrar puerto.
  - Monitorear el estado en tiempo real.
  - Construir y enviar un ticket.

Algunos archivos relevantes (solo ejemplo, **no forman parte del plugin**):

- `example/lib/logic/printer_controller.dart`  
  Orquesta el uso de la API del plugin para:

  - Monitorizar estado.
  - Guardar el estado en un `PrinterState`.
  - Generar logs para la UI.

- `example/lib/logic/ticket_builder.dart`  
  Construye secuencias de bytes ESC/POS usando la librería `esc_pos_utils_platform` (incluida en el plugin, pero el builder es puro ejemplo).

- `example/lib/models/printer_state.dart`  
  Modelo de estado inmutable (con Equatable).

- `example/lib/uils/printer_status_interpreter.dart`  
  Traduce el byte de respuesta ESC/POS (estado) a flags booleanos.

Puedes tomar el código del example como referencia para tu propia app, pero no es parte de la API pública del plugin.

---

## API Dart

La API del plugin se expone a través de `TiPrinterPlugin` (en `lib/ti_printer_plugin.dart`).

### Detección y conexión USB

```dart
import 'package:ti_printer_plugin/ti_printer_plugin.dart';

final plugin = TiPrinterPlugin();

// Obtener versión de la plataforma
final version = await plugin.getPlatformVersion();

// Listar impresoras USB disponibles
final printers = await plugin.getUsbPrinters(); // List<String>
// Windows: DeviceInstanceId, Linux: rutas /dev/...

// Abrir un puerto USB con el identificador devuelto por getUsbPrinters()
final ok = await plugin.openUsbPort(printers.first);

// Cerrar el puerto USB
final closed = await plugin.closeUsbPort();
```

### Conexión serial (solo Windows)

```dart
final plugin = TiPrinterPlugin();

final opened = await plugin.openSerialPort('COM3', 9600);
if (!opened) {
  throw Exception('No se pudo abrir el puerto serial');
}

final sent = await plugin.sendCommandToSerial(Uint8List.fromList([0x1B, 0x40]));
if (!sent) {
  throw Exception('No se pudo enviar comando por serial');
}

await plugin.closeSerialPort();
```

> En Linux estos metodos existen en Dart para mantener el contrato cruzado,
> pero hoy responden como capacidad no soportada.

### Lectura de estado ESC-POS

La API expone métodos para leer el estado enviando comandos ESC/POS (DLE EOT).  
Desde tu app podés usar cualquier librería para generar esos comandos ESC/POS.  
En el ejemplo se usa `esc_pos_utils_platform`:

```dart
final profile = await CapabilityProfile.load();
final generator = Generator(PaperSize.mm80, profile);

// DLE EOT 1 – online status
final cmdOnline = Uint8List.fromList(generator.status());
final rspOnline = await plugin.readStatusUsb(cmdOnline);

// DLE EOT 4 – sensor de papel
final cmdPaper = Uint8List.fromList(generator.paperSensorStatus());
final rspPaper = await plugin.readStatusUsb(cmdPaper);

// DLE EOT 2 – offline cause
final cmdOffline = Uint8List.fromList(generator.offLineStatus());
final rspOffline = await plugin.readStatusUsb(cmdOffline);

if (rspOnline.isEmpty) {
  // Sin respuesta dentro del timeout, error nativo o capacidad no soportada.
}

// Si la impresora devuelve mas de un byte, el plugin entrega la respuesta completa.
```

Lo que hagas con esos bytes de respuesta (interpretar flags, actualizar UI, etc.) ya es responsabilidad de tu aplicación.  
El código de ejemplo (`PrinterStatusInterpreter`) muestra una posible forma de hacerlo.

### Impresión de datos crudos

Si ya tienes tus bytes ESC/POS construidos (por ejemplo un ticket):

```dart
final Uint8List data = Uint8List.fromList([...]);
final bool ok = await plugin.sendCommandToUsb(data);
if (ok != true) {
  throw Exception('Error enviando datos a la impresora USB');
}
```

---

## Construcción de tickets ESC/POS (ejemplo)

El plugin **no obliga** a usar una forma particular de construir tickets.
En la app de ejemplo se incluye `TicketBuilder` para mostrar una posible implementación.

Ejemplo (adaptado a tu app):

```dart
final profile = await CapabilityProfile.load();
final builder = TicketBuilder(profile);

final bytes = await builder.buildTicket(
  items: items,                // List<Item> (modelo propio de tu app)
  nroReferencia: '000123',
  total: total,
  efectivo: efectivo,
  cambio: cambio,
  qrData: 'https://mi-app/…',  // contenido del QR
);

// Enviar a la impresora
await plugin.sendCommandToUsb(Uint8List.fromList(bytes));
```

El `TicketBuilder` de la app de ejemplo:

1. Añade un logo.
2. Imprime encabezado de comercio (nombre, CUIT, dirección, etc.).
3. Imprime líneas de detalle (items).
4. Imprime totales con formato destacado.
5. Genera un código QR y lo renderiza como imagen ESC/POS.
6. Añade un pie de ticket y un corte de papel.

Puedes copiar ese enfoque y adaptarlo a las necesidades de tu negocio,  
o construir tus propios bytes ESC/POS desde cero.

---

## Monitor de estado en tiempo real (ejemplo)

El plugin ofrece los bloques básicos (lectura de estado vía `readStatusUsb`).  
En la app de ejemplo se construye un **monitor** que, cada cierto intervalo, hace:

1. Envía `DLE EOT 1` para saber si la impresora está online.
2. Envía `DLE EOT 4` para saber el estado del papel.
3. Envía `DLE EOT 2` para obtener causas de offline.
4. Interpreta los bytes con un helper (`PrinterStatusInterpreter`).
5. Actualiza un `PrinterState` y notifica a la UI.

Ese monitor está implementado en `PrinterController.startUsbAutoMonitor` dentro de `example/` y usa un `Timer.periodic`.  
En tu aplicación podés reutilizar el enfoque o implementar tu propia lógica de monitoreo.

---

## Ejemplo de uso en Flutter

Un patrón típico (similar al example) sería:

```dart
class MyPrinterScreen extends StatefulWidget {
  const MyPrinterScreen({super.key});

  @override
  State<MyPrinterScreen> createState() => _MyPrinterScreenState();
}

class _MyPrinterScreenState extends State<MyPrinterScreen> {
  late final PrinterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PrinterController(TiPrinterPlugin());
    _controller.initPlatform();
    _controller.refreshUsbPrinters();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Scaffold(
          appBar: AppBar(title: const Text('Estado impresora')),
          body: Column(
            children: [
              // Dropdown de impresoras
              DropdownButton<String>(
                value: state.selectedUsbPrinter,
                hint: const Text('Seleccione impresora USB'),
                items: state.usbPrinters
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p),
                      ),
                    )
                    .toList(),
                onChanged: _controller.updateSelectedUsb,
              ),

              // Botones de acciones
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _controller.startUsbAutoMonitor,
                    child: const Text('Iniciar monitor'),
                  ),
                  ElevatedButton(
                    onPressed: _controller.checkUsbStatus,
                    child: const Text('Check status'),
                  ),
                ],
              ),

              // Estado en iconos (ejemplo)
              Row(
                children: [
                  Icon(
                    Icons.power,
                    color: state.enLineaUsb ? Colors.green : Colors.red,
                  ),
                  Icon(
                    Icons.print,
                    color:
                        state.papelPresenteUsb ? Colors.green : Colors.orange,
                  ),
                  Icon(
                    Icons.warning,
                    color:
                        state.tapaAbiertaUsb ? Colors.red : Colors.transparent,
                  ),
                ],
              ),

              // Logs (scrollable)
              Expanded(
                child: ListView.builder(
                  itemCount: state.logs.length,
                  itemBuilder: (context, index) {
                    return Text(state.logs[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

> De nuevo: este patrón viene del example y es solo una guía.  
> En tu app podés usar Riverpod, BLoC, MobX, etc.

---

## Permisos en Linux

En Linux es habitual que el acceso a `/dev/usb/lp*` (y similares) requiera permisos adicionales.

Opciones típicas:

- Ejecutar la app con permisos elevados (no recomendado en producción).
- Agregar tu usuario al grupo que tiene acceso al dispositivo (por ejemplo `lp`).
- Crear una regla `udev` que ajuste los permisos del dispositivo.

Si ves errores como:

```text
No se pudo abrir /dev/usb/lp1: Permission denied
```

revisá los permisos con:

```bash
ls -l /dev/usb/lp*
```

y ajustalos según la política de tu sistema.

---

## Desarrollo y estructura de carpetas

Estructura típica del repo:

```text
ti_printer_plugin/
├── lib/
│   ├── ti_printer_plugin.dart
│   ├── ti_printer_plugin_method_channel.dart
│   └── ti_printer_plugin_platform_interface.dart
├── linux/
│   ├── CMakeLists.txt
│   ├── include/
│   │   └── ti_printer_plugin/
│   │       └── ti_printer_plugin.h
│   ├── ti_printer_plugin.cc
│   └── ti_printer_plugin_private.h
├── windows/
│   ├── CMakeLists.txt
│   ├── ti_printer_plugin.cpp
│   ├── ti_printer_plugin_c_api.cpp
│   └── ti_printer_plugin.h
└── example/
    ├── lib/
    │   ├── logic/
    │   │   ├── printer_controller.dart
    │   │   └── ticket_builder.dart
    │   ├── models/
    │   │   └── printer_state.dart
    │   ├── uils/
    │   │   ├── printer_status_interpreter.dart
    │   │   └── image_utils.dart
    │   └── main.dart
    └── linux/
        └── ...
```

> Todo lo que está dentro de `example/` es una APP de demostración, no parte del plugin.

---

## Problemas conocidos / troubleshooting

- **Solo se imprime el código QR, pero no el texto / logo (usando el ejemplo):**
  - Asegurate de **no** reasignar la lista de comandos ESC/POS dentro de los helpers.
  - Usar siempre `command.addAll(...)` en `TicketBuilder` en vez de `command += ...` dentro de los métodos helper.

- **Error al escribir en USB: `No existe el dispositivo`:**
  - La impresora se apagó / desconectó.
  - En Linux, si `write` falla con `ENODEV`, `EIO` o `EBADF`, el plugin cierra el descriptor y `readStatusUsb` empieza a devolver vacío.
  - El monitor de la app de ejemplo lo interpreta como offline y se detiene.
  - Para reconectar: encender impresora, `getUsbPrinters()`, `openUsbPort()`, reanudar tu lógica de monitoreo.

- **Permisos en Linux:**
  - Ver sección [Permisos en Linux](#permisos-en-linux).

- **Las lecturas de estado devuelven vacío pero la app no se cuelga:**
  - Es el comportamiento esperado ante timeout, falta de respuesta o capacidad no soportada.
  - En Windows, `ReadStatusUsb()` cancela la lectura pendiente tras ~500 ms para evitar bloqueos indefinidos.
  - En Linux, `select()` espera hasta 500 ms y luego devuelve vacío si no hubo respuesta.

- **No se ven logs nativos en la app:**
  - Los logs nativos (`g_printerr`, `printf`, `OutputDebugStringA`) se ven en la consola o debugger donde lanzás `flutter run`.
  - La consola de la app de ejemplo (UI) muestra solo los logs que se agregan desde Dart.

---

## Licencia

Agregá aquí la licencia que corresponda, por ejemplo MIT, Apache 2.0, etc.

```text
Copyright (c) 2025 José Salvini

Se concede permiso por la presente, libre de cargos, a cualquier persona que obtenga
una copia de este software y de los archivos de documentación asociados (el "Software"),
para utilizar el Software sin restricción, incluyendo sin limitación los derechos
a usar, copiar, modificar, fusionar, publicar, distribuir, sublicenciar y/o vender
copias del Software, y a permitir a las personas a las que se les proporcione el
Software que lo hagan.

```