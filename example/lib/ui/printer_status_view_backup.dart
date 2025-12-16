import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/enums.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/src/generator.dart';
import 'package:ti_printer_plugin/ti_printer_plugin.dart';
import 'package:ti_printer_plugin_example/uils/printer_status_interpreter.dart';

class PrinterStatusWiewBackup extends StatefulWidget {
  const PrinterStatusWiewBackup({super.key});

  @override
  PrinterStatusWiewBackupState createState() => PrinterStatusWiewBackupState();
}

class PrinterStatusWiewBackupState extends State<PrinterStatusWiewBackup> {
  final TiPrinterPlugin tiPrinterPlugin = TiPrinterPlugin();
  late CapabilityProfile profile;
  late Generator printer;
  List<int> command = [];

  bool enLineaSerial = false;
  bool tapaAbiertaSerial = true;
  bool papelPorAcabarseSerial = true;
  bool papelPresenteSerial = false;

  bool enLineaUsb = false;
  bool tapaAbiertaUsb = true;
  bool papelPorAcabarseUsb = true;
  bool papelPresenteUsb = false;

  // NUEVO: lista de impresoras USB disponibles y la seleccionada
  List<String> _usbPrinters = [];
  String? _selectedUsbPrinter;

  String _platformVersion = 'Unknown';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();

    if (Platform.isWindows) {
      // Solo Windows tiene serial implementado (por ahora)
      openSerialPort();
      checkSerialStatus();
    }

    // USB lo usamos en ambas plataformas, pero openUSBPort
    // va a decidir qué hacer según la plataforma.
    openUSBPort();
    checkUsbStatus();
  }

  void _addLog(String message) {
    final timestamp =
        TimeOfDay.fromDateTime(DateTime.now()).format(context); // ej: 14:32

    setState(() {
      _logs.add('[$timestamp] $message');
    });

    // (útil cuando corrés con `flutter run`)
    debugPrint(message);
  }

  String _bytesToHex(Uint8List bytes) {
    // ej: "10 04 01"
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  Future<void> initPlatformState() async {
    profile = await CapabilityProfile.load();
    printer = Generator(PaperSize.mm80, profile);

    String platformVersion;
    try {
      platformVersion = await tiPrinterPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void openSerialPort() async {
    if (!Platform.isWindows) {
      log('openSerialPort: serial solo soportado en Windows actualmente');
      return;
    }

    try {
      final result = await tiPrinterPlugin.openSerialPort('COM10', 9600);
      log('Result openPort (serial): $result');
    } catch (e) {
      log('Error al abrir el puerto serial: $e');
    }
  }

  // Función para verificar el estado de la impresora serial
  Future<void> checkSerialStatus() async {
    profile = await CapabilityProfile.load();
    printer = Generator(PaperSize.mm80, profile);
    Uint8List byteData;

    command = [];
    // Obtener el estado general de la impresora (n = 1 para Printer status)
    command.addAll(printer.status());
    byteData = Uint8List.fromList(command);

    Uint8List? onLinePrinterStatus =
        await tiPrinterPlugin.readStatusSerial(byteData);

    if (onLinePrinterStatus != null) {
      PrinterStatusInterpreter.interpretOnlinePrinterStatus(onLinePrinterStatus,
          (coverOpenStatus, paperFeed, paperEnd, error) {
        setState(() {
          enLineaSerial = !error;
        });
      });
      // Obtener el estado del sensor de papel (n = 4 para roll paper sensor)
      command = [];
      command.addAll(printer.paperSensorStatus());
      byteData = Uint8List.fromList(command);

      Uint8List? paperStatus = await tiPrinterPlugin.readStatusSerial(byteData);
      if (paperStatus != null && paperStatus.isNotEmpty) {
        PrinterStatusInterpreter.interpretRollPaperSensorStatus(paperStatus,
            (nearEnd, present) {
          setState(() {
            papelPorAcabarseSerial = nearEnd;
            papelPresenteSerial = present;
          });
        });
      }
    }
    command = [];
    // Obtener el estado general de la impresora (n = 2 para offline cause)
    command.addAll(printer.offLineStatus());

    byteData = Uint8List.fromList(command);

    Uint8List? offlineCauseStatus =
        await tiPrinterPlugin.readStatusSerial(byteData);

    //log(offlineCauseStatus.toString());

    if (offlineCauseStatus != null && offlineCauseStatus.isNotEmpty) {
      PrinterStatusInterpreter.interpretOfflineCauseStatus(offlineCauseStatus,
          (coverOpenStatus, paperFeed, paperEnd, error) {
        setState(() {
          tapaAbiertaSerial = coverOpenStatus;
          enLineaSerial = !error;
        });
      });
      // Obtener el estado del sensor de papel (n = 4 para roll paper sensor)
      command = [];
      command.addAll(printer.paperSensorStatus());
      byteData = Uint8List.fromList(command);

      Uint8List? paperStatus = await tiPrinterPlugin.readStatusSerial(byteData);
      if (paperStatus != null && paperStatus.isNotEmpty) {
        PrinterStatusInterpreter.interpretRollPaperSensorStatus(paperStatus,
            (nearEnd, present) {
          setState(() {
            papelPorAcabarseSerial = nearEnd;
            papelPresenteSerial = present;
          });
        });
      }
    } else {
      setState(() {
        enLineaSerial = false;
        tapaAbiertaSerial = true;
        papelPorAcabarseSerial = true;
        papelPresenteSerial = false;
      });
    }
  }

  void listUSBPort() async {
    try {
      final result = await tiPrinterPlugin.getUsbPrinters();
      _addLog('Result list USB Port: $result');

      if (result.isEmpty) {
        // No hay impresoras: mostramos SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron impresoras USB.'),
            ),
          );
        }
      }

      setState(() {
        _usbPrinters = result;
        if (_usbPrinters.isNotEmpty) {
          if (_selectedUsbPrinter == null ||
              !_usbPrinters.contains(_selectedUsbPrinter)) {
            _selectedUsbPrinter = _usbPrinters.first;
          }
        } else {
          _selectedUsbPrinter = null;
        }
      });
    } catch (e) {
      _addLog('Error al listar impresoras USB: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al listar impresoras USB: $e'),
          ),
        );
      }
    }
  }

  void openUSBPort() async {
    try {
      String? deviceInstanceId = _selectedUsbPrinter;

      // Si no hay nada seleccionado, intentamos listar y elegir la primera
      if (deviceInstanceId == null) {
        final printers = await tiPrinterPlugin.getUsbPrinters();

        if (printers.isEmpty) {
          _addLog('openUSBPort: no se encontraron impresoras USB');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se encontraron impresoras USB para abrir.'),
              ),
            );
          }
          return;
        }

        setState(() {
          _usbPrinters = printers;
          _selectedUsbPrinter = printers.first;
        });
        deviceInstanceId = printers.first;
      }

      final result = await tiPrinterPlugin.openUsbPort(deviceInstanceId);
      _addLog('Result openPort USB: $result (device=$deviceInstanceId)');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Puerto USB abierto: $deviceInstanceId'),
          ),
        );
      }
    } catch (e) {
      _addLog('Error al abrir el puerto USB: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el puerto USB: $e'),
          ),
        );
      }
    }
  }

  // Función para verificar el estado de la impresora USB
  Future<void> checkUsbStatus() async {
    profile = await CapabilityProfile.load();
    printer = Generator(PaperSize.mm80, profile);
    Uint8List byteData;

    // ===== 1) DLE EOT 1 - Online printer status =====
    command = [];
    command.addAll(printer.status());
    byteData = Uint8List.fromList(command);

    _addLog('[USB] CMD online status (DLE EOT 1): ${_bytesToHex(byteData)}');

    Uint8List? onLinePrinterStatus =
        await tiPrinterPlugin.readStatusUsb(byteData);

    if (onLinePrinterStatus != null && onLinePrinterStatus.isNotEmpty) {
      _addLog(
        '[USB] RSP online status: ${_bytesToHex(onLinePrinterStatus)} (len=${onLinePrinterStatus.length})',
      );

      PrinterStatusInterpreter.interpretOnlinePrinterStatus(
        onLinePrinterStatus,
        (coverOpenStatus, paperFeed, paperEnd, error) {
          setState(() {
            tapaAbiertaUsb = coverOpenStatus;
            enLineaUsb = !error;
          });
        },
      );

      // ===== 2) DLE EOT 4 - Roll paper sensor =====
      command = [];
      command.addAll(printer.paperSensorStatus());
      byteData = Uint8List.fromList(command);

      _addLog('[USB] CMD paper sensor (DLE EOT 4): ${_bytesToHex(byteData)}');

      Uint8List? paperStatus = await tiPrinterPlugin.readStatusUsb(byteData);
      if (paperStatus != null && paperStatus.isNotEmpty ) {
        _addLog(
          '[USB] RSP paper sensor: ${_bytesToHex(paperStatus)} (len=${paperStatus.length})',
        );

        PrinterStatusInterpreter.interpretRollPaperSensorStatus(
          paperStatus,
          (nearEnd, present) {
            setState(() {
              papelPorAcabarseUsb = nearEnd;
              papelPresenteUsb = present;
            });
          },
        );
      }

      // ===== 3) DLE EOT 2 - Offline cause =====
      command = [];
      command.addAll(printer.offLineStatus());
      byteData = Uint8List.fromList(command);

      _addLog('[USB] CMD offline cause (DLE EOT 2): ${_bytesToHex(byteData)}');

      Uint8List? offlineCauseStatus =
          await tiPrinterPlugin.readStatusUsb(byteData);

      if (offlineCauseStatus != null && offlineCauseStatus.isNotEmpty) {
        _addLog(
          '[USB] RSP offline cause: ${_bytesToHex(offlineCauseStatus)} (len=${offlineCauseStatus.length})',
        );

        PrinterStatusInterpreter.interpretOfflineCauseStatus(
          offlineCauseStatus,
          (coverOpenStatus, paperFeed, paperEnd, error) {
            setState(() {
              tapaAbiertaUsb = coverOpenStatus;
              enLineaUsb = !error;
            });
          },
        );
      }
    } else {
      setState(() {
        enLineaUsb = false;
        tapaAbiertaUsb = true;
        papelPorAcabarseUsb = true;
        papelPresenteUsb = false;
      });
    }
  }

  void sendDataUsb() async {
    List<int> escPosCommand = await _generateTicket();
    // Convertir List<int> a Uint8List
    Uint8List byteData = Uint8List.fromList(escPosCommand);
    bool? success = await tiPrinterPlugin.sendCommandToUsb(byteData);

    if (success!) {
      _addLog("Ticket enviado correctamente al puerto USB.");
    } else {
      _addLog("Error al enviar ticket al puerto USB.");
    }
  }

  void sendDataSerial() async {
    List<int> escPosCommand = await _generateTicket();
    // Convertir List<int> a Uint8List
    Uint8List byteData = Uint8List.fromList(escPosCommand);
    bool? success = await tiPrinterPlugin.sendCommandToSerial(byteData);

    if (success!) {
      _addLog("Ticket enviado correctamente al puerto serial.");
    } else {
      _addLog("Error al enviar ticket al puerto serial.");
    }
  }





  Future<List<int>> _generateTicket() async {
   
   




    
   
    command.addAll(printer.cut());

    return command;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Column(
          children: [
            Card(
              surfaceTintColor: Colors.blueAccent,
              elevation: 3,
              shadowColor: Colors.black,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: Text(
                    'Plataforma: $_platformVersion',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                direction: Axis.horizontal,
                spacing: 20, // Espacio horizontal entre las columnas
                runSpacing: 20, // Espacio vertical entre filas
                children: [
                  Card(
                    elevation: 3,
                    surfaceTintColor: Colors.amberAccent,
                    shadowColor: Colors.black,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width > 600
                          ? MediaQuery.of(context).size.width *
                              0.45 // 45% del ancho si la pantalla es grande
                          : MediaQuery.of(context).size.width *
                              1.0, // 100% del ancho si la pantalla es estrecha
                      child: ListView(
                        shrinkWrap:
                            true, // Permite que el ListView tome solo el espacio necesario
                        physics:
                            const NeverScrollableScrollPhysics(), // Desactiva el scroll para que no interfiera con el Wrap
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'Estado impresora serial',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaSerial
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: enLineaSerial ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              'Impresora ${enLineaSerial ? 'en línea' : 'fuera de línea'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaSerial
                                  ? (tapaAbiertaSerial
                                      ? Icons.warning
                                      : Icons.check)
                                  : Icons.warning,
                              color: enLineaSerial
                                  ? (tapaAbiertaSerial
                                      ? Colors.red
                                      : Colors.green)
                                  : Colors.red,
                            ),
                            title: Text(
                              'Tapa ${enLineaSerial ? (tapaAbiertaSerial ? 'abierta' : 'cerrada') : 'no disponible'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaSerial
                                  ? (papelPresenteSerial
                                      ? Icons.check
                                      : Icons.warning)
                                  : Icons.warning,
                              color: enLineaSerial
                                  ? (papelPresenteSerial
                                      ? Colors.green
                                      : Colors.red)
                                  : Colors.red,
                            ),
                            title: Text(
                              'Papel ${enLineaSerial ? (papelPresenteSerial ? 'OK' : 'agotado') : 'no disponible'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaSerial
                                  ? papelPresenteSerial
                                      ? (papelPorAcabarseSerial
                                          ? Icons.warning
                                          : Icons.check)
                                      : Icons.warning
                                  : Icons.warning,
                              color: enLineaSerial
                                  ? papelPresenteSerial
                                      ? (papelPorAcabarseSerial
                                          ? Colors.orange
                                          : Colors.green)
                                      : Colors.red
                                  : Colors.red,
                            ),
                            title: Text(
                              'Papel ${enLineaSerial ? papelPresenteSerial ? (papelPorAcabarseSerial ? 'cerca de acabarse' : 'OK') : 'no disponible' : 'no disponible'}',
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: checkSerialStatus,
                            child: const Text('Verificar estado impresora'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: openSerialPort,
                            child: const Text('Abrir puerto'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: sendDataSerial,
                            child: const Text('Imprimir ticket'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 3,
                    surfaceTintColor: Colors.redAccent,
                    shadowColor: Colors.black,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width > 600
                          ? MediaQuery.of(context).size.width *
                              0.45 // 45% del ancho si la pantalla es grande
                          : MediaQuery.of(context).size.width *
                              1.0, // 100% del ancho si la pantalla es estrecha
                      child: ListView(
                        shrinkWrap:
                            true, // Permite que el ListView tome solo el espacio necesario
                        physics:
                            const NeverScrollableScrollPhysics(), // Desactiva el scroll para que no interfiera con el Wrap
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'Estado impresora USB',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaUsb ? Icons.cloud_done : Icons.cloud_off,
                              color: enLineaUsb ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              'Impresora ${enLineaUsb ? 'en línea' : 'fuera de línea'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaUsb
                                  ? (tapaAbiertaUsb
                                      ? Icons.warning
                                      : Icons.check)
                                  : Icons.warning,
                              color: enLineaUsb
                                  ? (tapaAbiertaUsb ? Colors.red : Colors.green)
                                  : Colors.red,
                            ),
                            title: Text(
                              'Tapa ${enLineaUsb ? (tapaAbiertaUsb ? 'abierta' : 'cerrada') : 'no disponible'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaUsb
                                  ? (papelPresenteUsb
                                      ? Icons.check
                                      : Icons.warning)
                                  : Icons.warning,
                              color: enLineaUsb
                                  ? (papelPresenteUsb
                                      ? Colors.green
                                      : Colors.red)
                                  : Colors.red,
                            ),
                            title: Text(
                              'Papel ${enLineaUsb ? (papelPresenteUsb ? 'OK' : 'agotado') : 'no disponible'}',
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              enLineaUsb
                                  ? papelPresenteUsb
                                      ? (papelPorAcabarseUsb
                                          ? Icons.warning
                                          : Icons.check)
                                      : Icons.warning
                                  : Icons.warning,
                              color: enLineaUsb
                                  ? papelPresenteUsb
                                      ? (papelPorAcabarseUsb
                                          ? Colors.orange
                                          : Colors.green)
                                      : Colors.red
                                  : Colors.red,
                            ),
                            title: Text(
                              'Papel ${enLineaUsb ? papelPresenteUsb ? (papelPorAcabarseUsb ? 'cerca de acabarse' : 'OK') : 'no disponible' : 'no disponible'}',
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: listUSBPort,
                            child: const Text('Listar impresoras'),
                          ),
                          const SizedBox(height: 10),
                          if (_usbPrinters.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: _selectedUsbPrinter,
                              decoration: const InputDecoration(
                                labelText: 'Seleccionar impresora USB',
                                border: OutlineInputBorder(),
                              ),
                              items: _usbPrinters
                                  .map(
                                    (p) => DropdownMenuItem<String>(
                                      value: p,
                                      child: Text(
                                        p,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedUsbPrinter = value;
                                });
                              },
                            ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: openUSBPort,
                            child: const Text('Abrir puerto'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: checkUsbStatus,
                            child: const Text('Verificar estado impresora'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: sendDataUsb,
                            child: const Text('Imprimir ticket'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Consola',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildLogConsole(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogConsole() {
    return Container(
      height: 200,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
      ),
      child: _logs.isEmpty
          ? const Text(
              'Consola vacía',
              style: TextStyle(color: Colors.white70),
            )
          : ListView.builder(
              // Muestra los últimos al final; podés poner reverse: true si querés al revés
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(
                  _logs[index],
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
    );
  }
}
