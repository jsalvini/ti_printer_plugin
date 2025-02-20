import 'package:flutter/material.dart';
import 'package:ti_printer_plugin_example/printer_status_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        //appBar: AppBar(title: const Text('Estado de la impresora')),
        body: PrinterStatusWiew(),
      ),
    );
  }
}