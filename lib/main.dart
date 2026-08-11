// ============================================================================
// BOLICHES SUNMI · Caja + Impresora todo en uno
// PASO 3: WebView (abre el sistema) + agente de impresion por atras.
// La impresion del navegador queda anulada; todo imprime por el agente.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
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
  String _hasarIp = '';   // IP de la Hasar de red (queda guardada aunque uses la interna)
  int _hasarPort = 9100;
  bool _modoRed = false;   // true = imprime por red; false = impresora interna del Sunmi
  bool get _redMode => _modoRed && _hasarIp.trim().isNotEmpty;

  Future<void> _cargarConfigRed() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasarIp = prefs.getString('hasar_ip') ?? '';
      _hasarPort = prefs.getInt('hasar_port') ?? 9100;
      _modoRed = prefs.getBool('modo_red') ?? false;
    });
    if (_redMode) _log('Impresión por RED activada: $_hasarIp:$_hasarPort');
  }

  @override
  void initState() {
    super.initState();
    _cargarConfigRed();
    _cargarLogo();
    Permission.camera.request(); // permiso de camara para escanear QR
    _web = WebViewController(
      onPermissionRequest: (request) {
        request.grant(); // autoriza camara/microfono al WebView
      },
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (u) {
          // Anula la impresion del navegador: todo imprime por el agente
          _web.runJavaScript('window.print = function(){};');
          // Le avisa al sistema web cual es la estacion de este Sunmi
          _web.runJavaScript("try{window.SUNMI_ESTACION='${widget.estacion}';localStorage.setItem('sunmi_estacion','${widget.estacion}');if(window.aplicarEstacionSunmi)window.aplicarEstacionSunmi('${widget.estacion}');}catch(e){}");
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
        } else if (kind == 'cierre_caja') {
          await _printCierre(payload as Map);
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

  // ====== IMPRESIÓN POR RED (Hasar/Epson por IP, corta sola) ======
  Future<void> _enviarRed(List<int> bytes) async {
    Socket? s;
    try {
      s = await Socket.connect(_hasarIp, _hasarPort, timeout: const Duration(seconds: 5));
      s.add(bytes);
      await s.flush();
      await Future.delayed(const Duration(milliseconds: 400));
      _log('🖨 Enviado a Hasar $_hasarIp');
    } catch (e) {
      _log('❌ Error impresión red: $e');
    } finally {
      try { await s?.close(); } catch (_) {}
    }
  }

  // Helpers ESC/POS
  List<int> _eText(String s) {
    final limpio = s
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n')
        .replaceAll('Á', 'A').replaceAll('É', 'E').replaceAll('Í', 'I')
        .replaceAll('Ó', 'O').replaceAll('Ú', 'U').replaceAll('Ñ', 'N');
    return [...latin1.encode(limpio), 0x0A];
  }
  List<int> _eLine(String s, {int size = 0, bool bold = false, int align = 1}) {
    final b = <int>[];
    b.addAll([0x1B, 0x61, align]); // align: 0 izq, 1 centro, 2 der
    if (bold) b.addAll([0x1B, 0x45, 1]);
    if (size != 0) b.addAll([0x1D, 0x21, size == 2 ? 0x11 : 0x01]);
    b.addAll(_eText(s));
    if (size != 0) b.addAll([0x1D, 0x21, 0x00]);
    if (bold) b.addAll([0x1B, 0x45, 0]);
    return b;
  }
  List<int> _eFeed(int n) => [0x1B, 0x64, n];
  List<int> _eCut() => [0x1D, 0x56, 66, 0]; // corte parcial con avance

  // Convierte el logo (imagen) al formato raster ESC/POS (para imprimir por red)
  List<int>? _logoEscpos() {
    if (_logoBytes == null) return null;
    try {
      final im = img.decodeImage(_logoBytes!);
      if (im == null) return null;
      int w = im.width;
      if (w > 384) w = 384;
      final widthBytes = (w + 7) ~/ 8;
      final h = im.height;
      final out = <int>[];
      out.addAll([0x1D, 0x76, 0x30, 0x00,
        widthBytes & 0xFF, (widthBytes >> 8) & 0xFF,
        h & 0xFF, (h >> 8) & 0xFF]);
      for (int y = 0; y < h; y++) {
        for (int bx = 0; bx < widthBytes; bx++) {
          int b = 0;
          for (int bit = 0; bit < 8; bit++) {
            final x = bx * 8 + bit;
            if (x < w && x < im.width) {
              final px = im.getPixel(x, y);
              final lum = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
              if (lum < 128) b |= (0x80 >> bit);
            }
          }
          out.add(b);
        }
      }
      return out;
    } catch (e) {
      return null;
    }
  }

  // Encabezado para red: logo (imagen) si está, si no el texto WIKEND
  List<int> _headerRed() {
    final logo = _logoEscpos();
    if (logo != null) {
      final b = <int>[];
      b.addAll([0x1B, 0x61, 1]); // centrar
      b.addAll(logo);
      b.addAll([0x0A]);
      return b;
    }
    return _eLine('WIKEND', size: 2, bold: true);
  }

  List<int> _escposVenta(Map payload) {
    final tks = (payload['tks'] as List?) ?? [];
    final barra = (payload['barra'] ?? '').toString();
    final evento = (payload['evento'] ?? '').toString();
    final cajero = (payload['cajero'] ?? '').toString();
    final total = tks.length;
    num acum = 0;
    final b = <int>[];
    for (int i = 0; i < tks.length; i++) {
      final v = tks[i] as Map;
      acum += (v['precio'] is num) ? v['precio'] : (num.tryParse(v['precio'].toString()) ?? 0);
      b.addAll([0x1B, 0x40]);
      b.addAll(_headerRed());
      if (evento.isNotEmpty) b.addAll(_eLine(evento, size: 1, bold: true));
      if (barra.isNotEmpty) b.addAll(_eLine(barra, size: 1));
      if (cajero.isNotEmpty) b.addAll(_eLine('CAJA: ${cajero.toUpperCase()}', size: 1, bold: true));
      b.addAll(_eLine(divisor));
      b.addAll(_eLine('N ${v['numero'] ?? ''}   ${i + 1}/$total', size: 1, bold: true));
      b.addAll(_eLine((v['nombre'] ?? '').toString(), size: 2, bold: true));
      b.addAll(_eLine(money(v['precio']), size: 2, bold: true));
      b.addAll(_eLine(divisor));
      b.addAll(_eLine(lr('Acumulado', money(acum)), align: 0));
      b.addAll(_eLine(fechaAhora()));
      b.addAll(_eFeed(2));
      b.addAll(_eCut());
    }
    return b;
  }

  List<int> _escposEntrada(Map payload, String kind) {
    final evento = (payload['evento'] ?? '').toString();
    final tks = (payload['tks'] as List?) ?? [];
    final titulo = kind == 'consumicion_qr' ? 'CONSUMICION' : 'INGRESO';
    final b = <int>[];
    for (final x in tks) {
      final v = x as Map;
      b.addAll([0x1B, 0x40]);
      b.addAll(_headerRed());
      b.addAll(_eLine(titulo, size: 2, bold: true));
      if (evento.isNotEmpty) b.addAll(_eLine(evento, size: 1, bold: true));
      b.addAll(_eLine(divisor));
      final numTxt = (v['numero'] ?? '').toString();
      if (numTxt.isNotEmpty) b.addAll(_eLine(numTxt, size: 2, bold: true));
      b.addAll(_eLine((v['nombre'] ?? '').toString(), size: 1, bold: true));
      b.addAll(_eLine(divisor));
      b.addAll(_eLine(fechaAhora()));
      b.addAll(_eFeed(2));
      b.addAll(_eCut());
    }
    return b;
  }

  List<int> _escposReporte(Map payload) {
    final b = <int>[];
    b.addAll([0x1B, 0x40]);
    b.addAll(_eLine('WIKEND', size: 2, bold: true));
    b.addAll(_eLine('REPORTE', size: 1, bold: true));
    final titulo = (payload['titulo'] ?? '').toString();
    final sub = (payload['sub'] ?? '').toString();
    if (titulo.isNotEmpty) b.addAll(_eLine(titulo));
    if (sub.isNotEmpty) b.addAll(_eLine(sub));
    b.addAll(_eLine(divisor));
    final lineas = (payload['lineas'] as List?) ?? [];
    for (final x in lineas) {
      final m = x as Map;
      if (m['sep'] == true) {
        b.addAll(_eLine(divisor));
      } else if (m['h'] != null) {
        b.addAll(_eLine(m['h'].toString(), bold: true));
      } else {
        b.addAll(_eLine(lr(_clean(m['l']), _clean(m['v'])), align: 0));
      }
    }
    b.addAll(_eLine(fechaAhora()));
    b.addAll(_eFeed(2));
    b.addAll(_eCut());
    return b;
  }

  List<int> _escposCierre(Map payload) {
    final b = <int>[];
    num toNum(v) => (v is num) ? v : (num.tryParse('$v') ?? 0);
    b.addAll([0x1B, 0x40]);
    b.addAll(_eLine('WIKEND', size: 2, bold: true));
    b.addAll(_eLine('CIERRE DE CAJA', size: 1, bold: true));
    final barra = (payload['barra'] ?? '').toString();
    if (barra.isNotEmpty) b.addAll(_eLine(barra, size: 1));
    b.addAll(_eLine(divisor));
    b.addAll(_eLine(lr('Fondo inicial', money(payload['inicial'])), align: 0));
    b.addAll(_eLine(lr('Total ventas', money(payload['totalVentas'])), align: 0));
    final porPago = (payload['porPago'] as List?) ?? [];
    if (porPago.isNotEmpty) {
      b.addAll(_eLine(divisor));
      b.addAll(_eLine('POR MEDIO DE PAGO', bold: true));
      for (final x in porPago) {
        final m = x as Map;
        b.addAll(_eLine(lr((m['forma'] ?? '').toString().toUpperCase(), money(m['monto'])), align: 0));
      }
    }
    if (toNum(payload['ingresos']) != 0) b.addAll(_eLine(lr('Ingresos', money(payload['ingresos'])), align: 0));
    if (toNum(payload['egresos']) != 0) b.addAll(_eLine(lr('Egresos', money(payload['egresos'])), align: 0));
    b.addAll(_eLine(divisor));
    b.addAll(_eLine(lr('Efectivo esperado', money(payload['efectivoEsperado'])), align: 0));
    b.addAll(_eLine(lr('Efectivo contado', money(payload['contado'])), align: 0));
    final dif = toNum(payload['diferencia']);
    b.addAll(_eLine(lr(dif >= 0 ? 'Sobrante' : 'Faltante', money(dif.abs())), align: 0));
    b.addAll(_eLine(divisor));
    b.addAll(_eLine((payload['fecha'] ?? fechaAhora()).toString()));
    b.addAll(_eFeed(2));
    b.addAll(_eCut());
    return b;
  }

  Future<void> _printCierre(Map payload) async {
    if (_redMode) { await _enviarRed(_escposCierre(payload)); return; }
    num toNum(v) => (v is num) ? v : (num.tryParse('$v') ?? 0);
    await _printHeaderLogo();
    await SunmiPrinter.printText('CIERRE DE CAJA', style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 30));
    final barra = (payload['barra'] ?? '').toString();
    if (barra.isNotEmpty) await SunmiPrinter.printText(barra, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24));
    await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
    await SunmiPrinter.printText(lr('Fondo inicial', money(payload['inicial'])), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
    await SunmiPrinter.printText(lr('Total ventas', money(payload['totalVentas'])), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
    final porPago = (payload['porPago'] as List?) ?? [];
    if (porPago.isNotEmpty) {
      await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      await SunmiPrinter.printText('POR MEDIO DE PAGO', style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 22));
      for (final x in porPago) {
        final m = x as Map;
        await SunmiPrinter.printText(lr((m['forma'] ?? '').toString().toUpperCase(), money(m['monto'])), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
      }
    }
    if (toNum(payload['ingresos']) != 0) await SunmiPrinter.printText(lr('Ingresos', money(payload['ingresos'])), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
    if (toNum(payload['egresos']) != 0) await SunmiPrinter.printText(lr('Egresos', money(payload['egresos'])), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
    await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
    await SunmiPrinter.printText(lr('Efectivo esperado', money(payload['efectivoEsperado'])), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
    await SunmiPrinter.printText(lr('Efectivo contado', money(payload['contado'])), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
    final dif = toNum(payload['diferencia']);
    await SunmiPrinter.printText(lr(dif >= 0 ? 'Sobrante' : 'Faltante', money(dif.abs())), style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 22));
    await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
    await SunmiPrinter.printText((payload['fecha'] ?? fechaAhora()).toString(), style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
    await SunmiPrinter.lineWrap(9);
    await SunmiPrinter.printText('- - - - -  CORTAR  - - - - -', style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 22));
    await SunmiPrinter.lineWrap(8);
    await SunmiPrinter.cutPaper();
  }

  Future<void> _printVenta(Map payload) async {
    if (_redMode) { await _enviarRed(_escposVenta(payload)); return; }
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
    if (_redMode) { await _enviarRed(_escposEntrada(payload, kind)); return; }
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
      final numTxt = (v['numero'] ?? '').toString();
      if (numTxt.isNotEmpty) {
        await SunmiPrinter.printText(numTxt, style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 40));
      }
      await SunmiPrinter.printText((v['nombre'] ?? '').toString(), style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 34));
      await SunmiPrinter.printText(divisor, style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      await SunmiPrinter.printText(fechaAhora(), style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20));
      await SunmiPrinter.lineWrap(18);
      await SunmiPrinter.printText('- - - - -  CORTAR  - - - - -',
          style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 22));
      await SunmiPrinter.lineWrap(8);
      await SunmiPrinter.cutPaper();
    }
  }

  Future<void> _printReporte(Map payload) async {
    if (_redMode) { await _enviarRed(_escposReporte(payload)); return; }
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
    if (_redMode) {
      final b = <int>[];
      b.addAll([0x1B, 0x40]);
      b.addAll(_eLine('WIKEND', size: 2, bold: true));
      b.addAll(_eLine('PRUEBA RED', size: 1, bold: true));
      b.addAll(_eLine(widget.estacion));
      b.addAll(_eLine(fechaAhora()));
      b.addAll(_eFeed(2));
      b.addAll(_eCut());
      await _enviarRed(b);
      return;
    }
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

  Future<void> _configRedDialog() async {
    bool usarRed = _modoRed;
    final ipCtrl = TextEditingController(text: _hasarIp.isNotEmpty ? _hasarIp : '192.168.0.100');
    final portCtrl = TextEditingController(text: _hasarPort.toString());
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Impresora del ticket'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            RadioListTile<bool>(
              value: false,
              groupValue: usarRed,
              onChanged: (v) => setLocal(() => usarRed = false),
              title: const Text('Interna del Sunmi'),
              subtitle: const Text('La del propio equipo'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<bool>(
              value: true,
              groupValue: usarRed,
              onChanged: (v) => setLocal(() => usarRed = true),
              title: const Text('Hasar por red (IP)'),
              subtitle: const Text('Corta sola, más rápida'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (usarRed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(flex: 3, child: TextField(controller: ipCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'IP de la Hasar', isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: TextField(controller: portCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Puerto', isDense: true))),
                ]),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final ip = ipCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim()) ?? 9100;
                if (usarRed && ip.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Escribí la IP de la Hasar')));
                  return;
                }
                // La IP siempre queda guardada (aunque uses la interna)
                await prefs.setString('hasar_ip', ip);
                await prefs.setInt('hasar_port', port);
                await prefs.setBool('modo_red', usarRed);
                setState(() { _hasarIp = ip; _hasarPort = port; _modoRed = usarRed; });
                if (mounted) Navigator.pop(ctx);
                final msg = _redMode ? '✅ Ahora imprime por RED (Hasar $_hasarIp)' : '✅ Ahora imprime en la interna del Sunmi';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
                _log(msg);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
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
                  onPressed: () { Navigator.pop(context); _configRedDialog(); },
                  icon: const Icon(Icons.print),
                  label: Text(_redMode ? 'Impresora: RED' : 'Impresora: interna'),
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

// ============================================================================
//  Escaner NATIVO de tarjetas (no usa el WebView, no crashea en el Sunmi)
//  Lee el QR, valida con marcar_ingreso_tarjeta, muestra verde/rojo,
//  beep/vibra e imprime el ticket de ingreso (via la cola de su estacion).
// ============================================================================
class ScannerTarjetaScreen extends StatefulWidget {
  final String estacion;
  const ScannerTarjetaScreen({super.key, required this.estacion});
  @override
  State<ScannerTarjetaScreen> createState() => _ScannerTarjetaScreenState();
}

class _ScannerTarjetaScreenState extends State<ScannerTarjetaScreen> {
  String? _nocheId;
  bool _busy = false;
  String _lastCode = '';
  int _lastT = 0;
  String _resTipo = ''; // ok | err | ''
  String _resMsg = 'Acercá una tarjeta';
  String _resSub = '';
  int _contador = 0;

  @override
  void initState() {
    super.initState();
    _cargarNoche();
  }

  Future<void> _cargarNoche() async {
    try {
      final r = await supabase.from('noches').select('id').eq('estado', 'abierta').order('id', ascending: false).limit(1).maybeSingle();
      if (r != null) _nocheId = r['id'].toString();
    } catch (_) {}
    if (_nocheId == null && mounted) {
      setState(() { _resTipo = 'err'; _resMsg = 'No hay noche abierta'; });
    }
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_busy) return;
    final raw = cap.barcodes.isNotEmpty ? (cap.barcodes.first.rawValue ?? '') : '';
    if (raw.isEmpty) return;
    final code = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (code.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (code == _lastCode && now - _lastT < 3500) return;
    _lastCode = code; _lastT = now;
    if (_nocheId == null) { await _cargarNoche(); if (_nocheId == null) return; }
    _busy = true;
    try {
      final res = await supabase.rpc('marcar_ingreso_tarjeta', params: {'p_qr': code, 'p_noche_id': _nocheId});
      final m = (res is Map) ? res : <String, dynamic>{};
      if (m['ok'] == true) {
        _contador++;
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
        setState(() { _resTipo = 'ok'; _resMsg = 'INGRESO OK'; _resSub = (m['titular'] ?? '').toString(); });
        await _enqueuePrint((m['titular'] ?? '').toString());
      } else if (m['ya'] == true) {
        HapticFeedback.heavyImpact();
        String hora = '';
        final used = m['used_at']?.toString();
        if (used != null && used.isNotEmpty) {
          try {
            final d = DateTime.parse(used).toLocal();
            String dd(int n) => n.toString().padLeft(2, '0');
            hora = '${dd(d.hour)}:${dd(d.minute)}';
          } catch (_) {}
        }
        setState(() {
          _resTipo = 'err';
          _resMsg = 'YA INGRESÓ';
          _resSub = (m['titular'] ?? '').toString() + (hora.isNotEmpty ? '  ·  entró $hora' : '');
        });
      } else {
        HapticFeedback.heavyImpact();
        setState(() { _resTipo = 'err'; _resMsg = (m['msg'] ?? 'No válido').toString(); _resSub = ''; });
      }
    } catch (e) {
      setState(() { _resTipo = 'err'; _resMsg = 'Error de conexión'; _resSub = ''; });
    } finally {
      await Future.delayed(const Duration(milliseconds: 1000));
      _busy = false;
    }
  }

  Future<void> _enqueuePrint(String titular) async {
    try {
      await supabase.from('impresiones').insert({
        'tipo': 'ticket',
        'estado': 'pendiente',
        'estacion': widget.estacion,
        'payload': {
          'kind': 'entrada_qr',
          'evento': '',
          'tks': [
            {'numero': 'FREE', 'nombre': 'INGRESO · $titular', 'precio': 0}
          ]
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final Color col = _resTipo == 'ok'
        ? const Color(0xFF1B7F4B)
        : _resTipo == 'err'
            ? const Color(0xFFB3261E)
            : const Color(0xCC000000);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          // Marco guía
          Center(
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Resultado abajo
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              color: col,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _resTipo == 'ok' ? '✅ $_resMsg' : _resTipo == 'err' ? '⛔ $_resMsg' : _resMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  if (_resSub.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(_resSub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                  const SizedBox(height: 10),
                  Text('Ingresos en esta sesión: $_contador', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
          // Cerrar
          Positioned(
            top: 40, left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 46, right: 16,
            child: Text('Estación ${widget.estacion}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
