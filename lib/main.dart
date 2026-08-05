// ============================================================================
// BOLICHES SUNMI · Caja + Impresora todo en uno
// PASO 3: WebView (abre el sistema) + agente de impresion por atras.
// La impresion del navegador queda anulada; todo imprime por el agente.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image/image.dart' as img;

const supabaseUrl = 'https://gakgvcsksskzemzomhkp.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdha2d2Y3Nrc3NremVtem9taGtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3OTYxNjksImV4cCI6MjA5NzM3MjE2OX0.vtG6HJQK4HAbqwF2h4WRK-3-M-FLTa4Tv_1AkgTKkJs';

const sistemaUrl = 'https://boliches.bbnetsystem.com';
const boliche = 'WIKEND';
const divisor = '--------------------------------';

// Usuario de servicio para leer la config (logo). Igual que el agente Epson.
const terminalEmail = 'terminal@wikend.com';
const terminalPass = 'terminal123';

late final SupabaseClient supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  supabase = Supabase.instance.client;
  runApp(const BolichesApp());
}

String money(dynamic v) {
  num n = (v is num) ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
  final s = n.round().abs().toString();
  final b = StringBuffer();
  int c = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    b.write(s[i]);
    c++;
    if (c % 3 == 0 && i != 0) b.write('.');
  }
  return '\$${b.toString().split('').reversed.join()}';
}

String lr(String l, String r, [int cols = 32]) {
  final space = cols - l.length - r.length;
  if (space < 1) return '$l $r';
  return l + ' ' * space + r;
}

String fechaAhora() {
  final d = DateTime.now();
  String dd(int n) => n.toString().padLeft(2, '0');
  return '${dd(d.day)}/${dd(d.month)}/${d.year} ${dd(d.hour)}:${dd(d.minute)}';
}

class BolichesApp extends StatelessWidget {
  const BolichesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boliches Soft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.pink, scaffoldBackgroundColor: const Color(0xFF14121A)),
      home: const Arranque(),
    );
  }
}

class Arranque extends StatefulWidget {
  const Arranque({super.key});
  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final est = prefs.getString('estacion') ?? '';
    if (!mounted) return;
    if (est.isEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainScreen(estacion: est)));
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _ctrl = TextEditingController();

  Future<void> _guardar() async {
    final est = _ctrl.text.trim().toUpperCase();
    if (est.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribí un nombre de estación')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('estacion', est);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainScreen(estacion: est)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar estación'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('¿Qué estación es este Sunmi?',
                style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tiene que coincidir con el "Imprime en:" de la caja.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'ej: SUNMI 1',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF221F2B),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2E88),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text('GUARDAR Y ARRANCAR', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String estacion;
  const MainScreen({super.key, required this.estacion});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final WebViewController _web;
  Timer? _timer;
  bool _ocupado = false;
  final List<String> _logs = [];
  Uint8List? _logoBytes; // logo del ticket (mismo que las Epson, guardado en Supabase)

  @override
  void initState() {
    super.initState();
    _cargarLogo();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (u) {
          // Anula la impresion del navegador: todo imprime por el agente
          _web.runJavaScript('window.print = function(){};');
        },
      ))
      ..loadRequest(Uri.parse(sistemaUrl));

    _log('Escuchando estación ${widget.estacion}');
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) => _revisarCola());
    _revisarCola();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _log(String m) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, '${fechaAhora().substring(11)}  $m');
      if (_logs.length > 60) _logs.removeLast();
    });
  }

  // Baja el logo del sistema (tabla config, clave 'logo') = el mismo de las Epson.
  // La tabla config es privada: primero nos logueamos con terminal@wikend.com.
  Future<void> _cargarLogo() async {
    try {
      try {
        await supabase.auth.signInWithPassword(email: terminalEmail, password: terminalPass);
        _log('Login OK (terminal)');
      } catch (e) {
        _log('No pude loguear para el logo: $e');
      }
      final r = await supabase.from('config').select('valor').eq('clave', 'logo').maybeSingle();
      final valor = (r?['valor'] ?? '').toString().trim();
      if (valor.isEmpty) {
        _log('Sin logo en config: uso texto WIKEND');
        return;
      }
      final b64 = valor.contains(',') ? valor.split(',').last : valor;
      _logoBytes = base64Decode(b64);
      // Achicar y CENTRAR el logo: lo pego centrado sobre un lienzo blanco
      // del ancho del papel (384px = 57mm), asi sale siempre en el medio.
      try {
        final decoded = img.decodeImage(_logoBytes!);
        if (decoded != null) {
          final logo = img.copyResize(decoded, width: 220);
          final canvas = img.Image(width: 384, height: logo.height);
          img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
          final dx = ((384 - logo.width) / 2).round();
          img.compositeImage(canvas, logo, dstX: dx, dstY: 0);
          _logoBytes = Uint8List.fromList(img.encodePng(canvas));
        }
      } catch (_) {}
      _log('Logo cargado (${_logoBytes!.length} bytes)');
    } catch (e) {
      _log('No se pudo cargar el logo: $e');
    }
  }

  // Imprime el logo arriba del ticket; si falla, cae al texto WIKEND
  Future<void> _printHeaderLogo() async {
    if (_logoBytes != null) {
      try {
        await SunmiPrinter.printImage(_logoBytes!);
        return;
      } catch (_) {}
    }
    await SunmiPrinter.printText(boliche, style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 40));
  }

  Future<void> _revisarCola() async {
    if (_ocupado) return;
    _ocupado = true;
    try {
      final rows = await supabase
          .from('impresiones')
          .select()
          .eq('estado', 'pendiente')
          .eq('estacion', widget.estacion)
          .order('created_at', ascending: true);

      for (final job in (rows as List)) {
        final claim = await supabase
            .from('impresiones')
            .update({'estado': 'impreso', 'impresa_at': DateTime.now().toIso8601String()})
            .eq('id', job['id'])
            .eq('estado', 'pendiente')
            .select('id');
        if ((claim as List).isEmpty) continue;

        dynamic payload = job['payload'];
        if (payload is String) {
          try {
            payload = jsonDecode(payload);
          } catch (_) {
            payload = {};
          }
        }
        final kind = (payload['kind'] ?? '').toString();
        if (kind == 'reporte') {
          await _printReporte(payload as Map);
        } else if (kind == 'entrada_qr' || kind == 'consumicion_qr') {
          await _printEntrada(payload as Map, kind);
        } else {
          await _printVenta(payload as Map);
        }
        _log('✓ Impreso (job ${job['id']})');
      }
    } catch (e) {
      _log('Error: $e');
    } finally {
      _ocupado = false;
    }
  }

  Future<void> _printVenta(Map payload) async {
    final tks = (payload['tks'] as List?) ?? [];
    final barra = (payload['barra'] ?? '').toString();
    final evento = (payload['evento'] ?? '').toString();
    final cajero = (payload['cajero'] ?? '').toString();
    final total = tks.length;
    num acum = 0;
    for (int i = 0; i < tks.length; i++) {
      final v = tks[i] as Map;
      acum += (v['precio'] is num) ? v['precio'] : (num.tryParse(v['precio'].toString()) ?? 0);
      await _printHeaderLogo();
      if (evento.isNotEmpty) {
        await SunmiPrinter.printText(evento, style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 26));
      }
      if (barra.isNotEmpty) {
        await SunmiPrinter.printText(barra, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24));
      }
      if (cajero.isNotEmpty) {
        await SunmiPrinter.printText('CAJA: ${cajero.toUpperCase()}', style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 28));
      }
      await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      await SunmiPrinter.printText('N ${v['numero'] ?? ''}   ${i + 1}/$total', style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 28));
      await SunmiPrinter.printText((v['nombre'] ?? '').toString(), style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 38));
      await SunmiPrinter.printText(money(v['precio']), style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 40));
      await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      await SunmiPrinter.printText(lr('Acumulado', money(acum)), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
      await SunmiPrinter.printText(fechaAhora(), style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      await SunmiPrinter.lineWrap(9);
      // Linea de corte a mano bien marcada (la Sunmi de 57mm no corta sola)
      await SunmiPrinter.printText('- - - - -  CORTAR  - - - - -',
          style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 22));
      await SunmiPrinter.lineWrap(8);
      await SunmiPrinter.cutPaper(); // corte real si el aparato lo soporta
    }
  }

  Future<void> _printEntrada(Map payload, String kind) async {
    final evento = (payload['evento'] ?? '').toString();
    final tks = (payload['tks'] as List?) ?? [];
    final titulo = kind == 'consumicion_qr' ? 'CONSUMICION' : 'INGRESO';
    for (final x in tks) {
      final v = x as Map;
      await _printHeaderLogo();
      await SunmiPrinter.printText(titulo, style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 40));
      if (evento.isNotEmpty) {
        await SunmiPrinter.printText(evento, style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 26));
      }
      await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      await SunmiPrinter.printText((v['nombre'] ?? '').toString(), style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 34));
      await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      await SunmiPrinter.printText(fechaAhora(), style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      await SunmiPrinter.lineWrap(9);
      await SunmiPrinter.printText('- - - - -  CORTAR  - - - - -',
          style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 22));
      await SunmiPrinter.lineWrap(8);
      await SunmiPrinter.cutPaper();
    }
  }

  Future<void> _printReporte(Map payload) async {
    await _printHeaderLogo();
    await SunmiPrinter.printText('REPORTE', style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 30));
    final titulo = (payload['titulo'] ?? '').toString();
    final sub = (payload['sub'] ?? '').toString();
    if (titulo.isNotEmpty) await SunmiPrinter.printText(titulo, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 22));
    if (sub.isNotEmpty) await SunmiPrinter.printText(sub, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
    await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
    final lineas = (payload['lineas'] as List?) ?? [];
    for (final x in lineas) {
      final m = x as Map;
      if (m['sep'] == true) {
        await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      } else if (m['h'] != null) {
        await SunmiPrinter.printText(m['h'].toString(), style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 24));
      } else {
        await SunmiPrinter.printText(lr(_clean(m['l']), _clean(m['v'])), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
      }
    }
    await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
    await SunmiPrinter.printText('Impreso ${fechaAhora()}', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
    await SunmiPrinter.lineWrap(3);
    await SunmiPrinter.cutPaper();
  }

  String _clean(dynamic s) => (s ?? '').toString().replaceAll(RegExp(r'<[^>]+>'), '');

  Future<void> _pruebaImpresion() async {
    try {
      await SunmiPrinter.printText(boliche, style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 40));
      await SunmiPrinter.printText('PRUEBA · ${widget.estacion}', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24));
      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.cutPaper();
      _log('Prueba impresa');
    } catch (e) {
      _log('Error prueba: $e');
    }
  }

  Future<void> _cambiarEstacion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('estacion');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
  }

  void _abrirMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1922),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estación: ${widget.estacion}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('El agente está activo e imprimiendo.', style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
            const Divider(color: Colors.white24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () { Navigator.pop(context); _pruebaImpresion(); },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Prueba'),
                ),
                ElevatedButton.icon(
                  onPressed: () { Navigator.pop(context); _web.reload(); },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recargar'),
                ),
                ElevatedButton.icon(
                  onPressed: () { Navigator.pop(context); _cambiarEstacion(); },
                  icon: const Icon(Icons.settings),
                  label: const Text('Cambiar estación'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Últimas impresiones:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            SizedBox(
              height: 160,
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text(_logs[i], style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: WebViewWidget(controller: _web)),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: const Color(0xFFFF2E88),
        onPressed: _abrirMenu,
        child: const Icon(Icons.print),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
