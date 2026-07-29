import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

void main() {
  runApp(const BolichesApp());
}

class BolichesApp extends StatelessWidget {
  const BolichesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boliches Sunmi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.pink),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _estado = 'Tocá el botón para imprimir una prueba.';
  bool _ocupado = false;

  Future<void> _imprimirPrueba() async {
    setState(() {
      _ocupado = true;
      _estado = 'Imprimiendo...';
    });
    try {
      const divisor = '--------------------------------'; // 32 caracteres (57mm)

      await SunmiPrinter.printText(
        'WIKEND',
        style: SunmiTextStyle(
          bold: true,
          align: SunmiPrintAlign.CENTER,
          fontSize: 42,
        ),
      );
      await SunmiPrinter.printText(
        'BOLICHES SOFT',
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 26),
      );
      await SunmiPrinter.printText(divisor,
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(
        'PRUEBA DE IMPRESION',
        style: SunmiTextStyle(
          bold: true,
          align: SunmiPrintAlign.CENTER,
          fontSize: 30,
        ),
      );
      await SunmiPrinter.printText(
        'Si ves esto en papel,\nla impresora funciona!',
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.printText(divisor,
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText(
        DateTime.now().toString().substring(0, 19),
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 22),
      );
      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.cutPaper();

      setState(() => _estado = 'Listo. ¿Salió el papel impreso?');
    } catch (e) {
      setState(() => _estado = 'ERROR: $e');
    } finally {
      setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boliches · Prueba Sunmi'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _estado,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _ocupado ? null : _imprimirPrueba,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                backgroundColor: const Color(0xFFFF2E88),
                foregroundColor: Colors.white,
              ),
              child: const Text('IMPRIMIR PRUEBA',
                  style: TextStyle(fontSize: 22)),
            ),
          ],
        ),
      ),
    );
  }
}
