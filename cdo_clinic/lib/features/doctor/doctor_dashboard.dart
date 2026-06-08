import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cdo_clinic/services/clinic_api_service.dart';
import 'package:cdo_clinic/models/clinic_models.dart';

// ═══════════════════════════════════════════════════════════════
// ENUMS Y CONSTANTES
// ═══════════════════════════════════════════════════════════════
enum TipoVistaCalendario { dia, semana, mes }
enum EstadoCitaDoctor { pendiente, enProgreso, completada, cancelada, noAsistio }
enum DuracionConsulta { min30, min45, min60, min90 }

extension DuracionConsultaExt on DuracionConsulta {
  int get minutos {
    switch (this) {
      case DuracionConsulta.min30: return 30;
      case DuracionConsulta.min45: return 45;
      case DuracionConsulta.min60: return 60;
      case DuracionConsulta.min90: return 90;
    }
  }
  String get label {
    switch (this) {
      case DuracionConsulta.min30: return '30 min';
      case DuracionConsulta.min45: return '45 min';
      case DuracionConsulta.min60: return '1 hora';
      case DuracionConsulta.min90: return '1.5 horas';
    }
  }
}

final List<Map<String, String>> plantillasDiagnosticos = [
  {
    'nombre': 'Hipertension Arterial',
    'sintomas': 'Cefalea, mareos, vision borrosa, dolor toracico ocasional.',
    'diagnostico': 'Hipertension arterial esencial grado II. PA: 160/100 mmHg.',
    'tratamiento': 'Enalapril 10mg cada 12h. Control de sodio. Ejercicio moderado.',
  },
  {
    'nombre': 'Diabetes Tipo 2',
    'sintomas': 'Polidipsia, poliuria, fatiga, vision borrosa, heridas lentas.',
    'diagnostico': 'Diabetes Mellitus Tipo 2. HbA1c: 8.5%. Glucosa: 180 mg/dL.',
    'tratamiento': 'Metformina 850mg cada 12h con alimentos. Dieta baja en carbohidratos.',
  },
  {
    'nombre': 'Infeccion Respiratoria',
    'sintomas': 'Tos productiva, fiebre 38.5C, congestion nasal, mialgias.',
    'diagnostico': 'Bronquitis aguda. Auscultacion: crepitantes bilaterales.',
    'tratamiento': 'Azitromicina 500mg dia 1, luego 250mg dia 2-5. Hidratacion abundante.',
  },
  {
    'nombre': 'Gastritis',
    'sintomas': 'Dolor epigastrico, nauseas, ardor, distension postprandial.',
    'diagnostico': 'Gastritis erosiva. Refiere consumo de AINEs reciente.',
    'tratamiento': 'Omeprazol 20mg cada 12h antes de comidas. Evitar irritantes.',
  },
  {
    'nombre': 'Ansiedad Generalizada',
    'sintomas': 'Nerviosismo constante, insomnio, palpitaciones, tension muscular.',
    'diagnostico': 'Trastorno de ansiedad generalizada (TAG). Escala GAD-7: 14 puntos.',
    'tratamiento': 'Sertralina 50mg/dia. Tecnicas de relajacion. Psicoterapia recomendada.',
  },
];

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isDarkMode = false;

  final ClinicApiService _api = ClinicApiService();
  int? _idMedico;

  // --- Datos del doctor ---
  String _nombreDoctor = 'Cargando...';
  String _especialidadDoctor = 'Cargando...';
  String _inicialesDoctor = '??';
  String? _licenciaMedica;
  String? _consultorio;
  String? _correoDoctor;
  String? _telefonoDoctor;
  bool _cargandoDoctor = true;

  // --- PERFIL: Avatar y configuracion ---
  String? _avatarUrl;
  Color _avatarColor = const Color(0xFF0066CC);
  final TextEditingController _comentarioCtrl = TextEditingController();
  int _calificacionEstrellas = 5;

  // --- Configuracion de agenda ---
  DuracionConsulta _duracionConsulta = DuracionConsulta.min30;
  TimeOfDay _horaInicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 16, minute: 0);
  List<int> _diasDescanso = [];
  List<DateTime> _vacaciones = [];
  bool _cargandoConfig = false;

  // --- Estado de citas ---
  List<Cita> _citasHoy = [];
  List<Cita> _todasLasCitas = [];
  List<Cita> _citasFiltradas = [];
  bool _cargandoCitas = false;
  String? _errorCitas;
  TipoVistaCalendario _vistaCalendario = TipoVistaCalendario.dia;

  // FECHAS NAVEGABLES PARA CALENDARIO
  DateTime _fechaCalendarioDia = DateTime.now();
  DateTime _fechaCalendarioSemana = DateTime.now();
  DateTime _fechaCalendarioMes = DateTime.now();

  String _filtroPaciente = '';
  String _filtroEstado = 'Todos';

  // --- Paciente seleccionado para expediente ---
  int? _idPacienteExpediente;
  List<HistoriaClinica> _historialPaciente = [];
  List<Cita> _citasPacienteExpediente = [];

  // --- Formulario historia clinica ---
  final _formHistoriaKey = GlobalKey<FormState>();
  final _sintomasCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _tratamientoCtrl = TextEditingController();
  final _notasPrivadasCtrl = TextEditingController();
  String? _rutaRecetaAdjunta;
  String? _nombreRecetaVisual;
  bool _guardandoHistoria = false;
  String? _plantillaSeleccionada;

  // --- Chat ---
  List<Mensaje> _mensajesChat = [];
  final _chatCtrl = TextEditingController();
  int? _idPacienteChat;
  bool _enviandoChat = false;
  bool _cargandoMensajes = false;

  // --- Estadisticas ---
  Map<String, dynamic> _estadisticas = {};
  bool _cargandoStats = false;

  // --- Recordatorios dinamicos ---
  List<Map<String, dynamic>> _recordatorios = [];
  bool _cargandoRecordatorios = false;

  // ================================================================
  // COLORES ADAPTATIVOS
  // ================================================================
  Color get _fondo => _isDarkMode ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FA);
  Color get _cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textoPrincipal => _isDarkMode ? Colors.white : const Color(0xFF1A1A2E);
  Color get _textoSecundario => _isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey[500]!;
  Color get _inputFill => _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FC);
  Color get _borderColor => _isDarkMode ? Colors.white.withOpacity(0.15) : Colors.grey.withOpacity(0.2);
  Color get _accentColor => const Color(0xFF05006B);
  Color get _accentLight => const Color(0xFFFFE600);
  Border? get _cardBorder => _isDarkMode
      ? Border.all(color: Colors.white.withOpacity(0.15), width: 1.5)
      : Border.all(color: Colors.grey.withOpacity(0.1));

  @override
  void initState() {
    super.initState();
    _idMedico = _api.idUsuarioActual;
    _fetchDatosDoctor();
    _fetchDatosIniciales();
  }

  // ================================================================
  // CARGA DE DATOS DEL DOCTOR AUTENTICADO - CORREGIDO
  // ================================================================
  Future<void> _fetchDatosDoctor() async {
    setState(() => _cargandoDoctor = true);
    try {
      final resultado = await _api.getUsuarioActual();
      if (resultado.success && resultado.data != null) {
        final usuario = resultado.data!;
        _actualizarDatosDoctor(usuario);
      } else if (_idMedico != null) {
        final res2 = await _api.getUsuarioPorId(_idMedico!);
        if (res2.success && res2.data != null) {
          final usuario = res2.data!;
          _actualizarDatosDoctor(usuario);
        } else {
          _setFallbackDoctor();
        }
      } else {
        _setFallbackDoctor();
      }
    } catch (e) {
      debugPrint('Error cargando datos doctor: $e');
      _setFallbackDoctor();
    }
  }

  void _actualizarDatosDoctor(dynamic usuario) {
    final serverAvatarUrl = _normalizeAvatarUrl(usuario.fotoUrl ?? usuario.avatarUrl);
    setState(() {
      _nombreDoctor = "Dr. ${usuario.nombre ?? 'Usuario'} ${usuario.apellido ?? ''}";
      _especialidadDoctor = usuario.especialidad ?? 'Medico General';
      _inicialesDoctor = _generarIniciales(usuario.nombre ?? 'D', usuario.apellido ?? 'U');
      _licenciaMedica = usuario.licenciaMedica;
      _consultorio = usuario.consultorio;
      _correoDoctor = usuario.correo;
      _telefonoDoctor = usuario.telefono;
      if (serverAvatarUrl != null) {
        _avatarUrl = serverAvatarUrl;
      }
      _cargandoDoctor = false;
    });
  }

  String? _normalizeAvatarUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _setFallbackDoctor() {
    setState(() {
      _nombreDoctor = 'Dr. Usuario';
      _especialidadDoctor = 'Medico General';
      _inicialesDoctor = 'DU';
      _cargandoDoctor = false;
    });
  }

  String _generarIniciales(String nombre, String apellido) {
    final n = nombre.trim();
    final a = apellido.trim();
    if (n.isNotEmpty && a.isNotEmpty) return '${n[0]}${a[0]}'.toUpperCase();
    if (n.isNotEmpty) return n[0].toUpperCase();
    return '??';
  }

  Future<void> _fetchDatosIniciales() async {
    await _fetchConfigAgenda();
    await _fetchCitas();
    await _fetchEstadisticas();
    await _fetchRecordatorios();
  }

  // ================================================================
  // CONFIGURACION DE AGENDA DESDE BACKEND
  // ================================================================
  Future<void> _fetchConfigAgenda() async {
    if (_idMedico == null) return;
    setState(() => _cargandoConfig = true);
    try {
      final res = await _api.getConfigAgenda(_idMedico!);
      if (res.success && res.data != null) {
        final config = res.data!;
        setState(() {
          _duracionConsulta = _parseDuracion(config['duracion_consulta'] ?? 30);
          final hi = config['hora_inicio']?.toString().split(':') ?? ['8', '0'];
          final hf = config['hora_fin']?.toString().split(':') ?? ['16', '0'];
          _horaInicio = TimeOfDay(hour: int.parse(hi[0]), minute: int.parse(hi[1]));
          _horaFin = TimeOfDay(hour: int.parse(hf[0]), minute: int.parse(hf[1]));
          _diasDescanso = List<int>.from(config['dias_descanso'] ?? []);
          _vacaciones = (config['vacaciones'] as List<dynamic>? ?? [])
              .map((v) => DateTime.parse(v.toString()))
              .toList();
          _cargandoConfig = false;
        });
      } else {
        setState(() => _cargandoConfig = false);
      }
    } catch (e) {
      setState(() => _cargandoConfig = false);
    }
  }

  Future<void> _guardarConfigAgenda() async {
    if (_idMedico == null) return;
    try {
      await _api.guardarConfigAgenda(
        idMedico: _idMedico!,
        duracionConsulta: _duracionConsulta.minutos,
        horaInicio: '${_horaInicio.hour.toString().padLeft(2,'0')}:${_horaInicio.minute.toString().padLeft(2,'0')}:00',
        horaFin: '${_horaFin.hour.toString().padLeft(2,'0')}:${_horaFin.minute.toString().padLeft(2,'0')}:00',
        diasDescanso: _diasDescanso,
        vacaciones: _vacaciones.map((v) => v.toIso8601String()).toList(),
      );
      _showSnack('Configuracion guardada', const Color(0xFF4CAF50));
      await _fetchEstadisticas();
    } catch (e) {
      _mostrarError('Error guardando configuracion: $e');
    }
  }

  DuracionConsulta _parseDuracion(int minutos) {
    switch (minutos) {
      case 45: return DuracionConsulta.min45;
      case 60: return DuracionConsulta.min60;
      case 90: return DuracionConsulta.min90;
      default: return DuracionConsulta.min30;
    }
  }

  // ================================================================
  // CITAS - CORREGIDO ERROR 404 CON MANEJO DE CONEXION
  // ================================================================
  Future<void> _fetchCitas() async {
    if (_idMedico == null) {
      setState(() {
        _errorCitas = 'No hay sesion de medico activa. Por favor inicie sesion nuevamente.';
        _cargandoCitas = false;
      });
      return;
    }
    setState(() { _cargandoCitas = true; _errorCitas = null; });
    try {
      final resultado = await _api.getCitasPorMedico(_idMedico!);
      if (resultado.success && resultado.data != null) {
        final todas = resultado.data!;
        final hoy = DateTime.now();
        final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
        final finHoy = inicioHoy.add(const Duration(days: 1));
        setState(() {
          _todasLasCitas = todas;
          _citasHoy = todas.where((c) {
            final fecha = c.fechaHora;
            return fecha.isAfter(inicioHoy.subtract(const Duration(seconds: 1))) && 
                   fecha.isBefore(finHoy);
          }).toList();
          _aplicarFiltros();
          _cargandoCitas = false;
        });
      } else if (resultado.error != null && (resultado.error!.contains('404') || resultado.error!.contains('Not Found'))) {
        setState(() {
          _errorCitas = 'Servidor no disponible (404). Verifique que el backend este ejecutandose.';
          _todasLasCitas = [];
          _citasHoy = [];
          _citasFiltradas = [];
          _cargandoCitas = false;
        });
      } else {
        setState(() { 
          _errorCitas = resultado.error ?? 'Error al cargar citas.'; 
          _cargandoCitas = false; 
        });
      }
    } on SocketException catch (e) {
      setState(() { 
        _errorCitas = 'No se puede conectar al servidor. Verifique su conexion a internet. Error: ${e.toString()}';
        _cargandoCitas = false; 
      });
    } on HttpException catch (e) {
      setState(() { 
        _errorCitas = 'Error HTTP: ${e.toString()}. El endpoint puede no existir en el servidor.'; 
        _cargandoCitas = false; 
      });
    } catch (e) {
      setState(() { 
        _errorCitas = 'Error de conexion: ${e.toString()}'; 
        _cargandoCitas = false; 
      });
    }
  }

  Future<void> _fetchEstadisticas() async {
    if (_idMedico == null) return;
    setState(() => _cargandoStats = true);
    try {
      final citasCompletadas = _todasLasCitas.where((c) => c.estado.toLowerCase() == 'completada').length;
      final citasCanceladas = _todasLasCitas.where((c) => c.estado.toLowerCase() == 'cancelada').length;
      final citasPendientes = _todasLasCitas.where((c) => c.estado.toLowerCase() == 'pendiente').length;
      final pacientesUnicos = _todasLasCitas.map((c) => c.idPaciente).toSet().length;

      int promedioReal = _duracionConsulta.minutos;

      setState(() {
        _estadisticas = {
          'totalCitas': _todasLasCitas.length,
          'completadas': citasCompletadas,
          'canceladas': citasCanceladas,
          'pendientes': citasPendientes,
          'pacientesUnicos': pacientesUnicos,
          'promedioDuracion': promedioReal,
          'tasaAsistencia': _todasLasCitas.isEmpty ? 0 : 
            (citasCompletadas / (_todasLasCitas.length - citasPendientes) * 100).round(),
        };
        _cargandoStats = false;
      });
    } catch (e) {
      setState(() => _cargandoStats = false);
    }
  }

  // ================================================================
  // RECORDATORIOS DINAMICOS - NO HARDCODEADOS
  // ================================================================
  Future<void> _fetchRecordatorios() async {
    if (_idMedico == null) return;
    setState(() => _cargandoRecordatorios = true);
    try {
      final res = await _api.getRecordatorios(_idMedico!);
      if (res.success && res.data != null) {
        setState(() {
          _recordatorios = List<Map<String, dynamic>>.from(res.data!);
          _cargandoRecordatorios = false;
        });
      } else {
        _generarRecordatoriosDesdeCitas();
      }
    } catch (e) {
      _generarRecordatoriosDesdeCitas();
    }
  }

  void _generarRecordatoriosDesdeCitas() {
    final List<Map<String, dynamic>> dinamicos = [];
    final hoy = DateTime.now();
    final pacientesConCitas = <int, DateTime>{};
    for (final c in _todasLasCitas.where((c) => c.estado.toLowerCase() == 'completada')) {
      if (!pacientesConCitas.containsKey(c.idPaciente) || 
          c.fechaHora.isAfter(pacientesConCitas[c.idPaciente]!)) {
        pacientesConCitas[c.idPaciente] = c.fechaHora;
      }
    }

    final seguimientoPendiente = pacientesConCitas.entries.where((e) {
      return hoy.difference(e.value).inDays > 7;
    }).length;

    if (seguimientoPendiente > 0) {
      dinamicos.add({
        'tipo': 'seguimiento',
        'titulo': 'Pacientes con seguimiento pendiente',
        'descripcion': '$seguimientoPendiente pacientes requieren control en los proximos 7 dias',
        'color': const Color(0xFFFF9800),
        'icon': Icons.follow_the_signs,
      });
    }

    final citasPendientesHoy = _citasHoy.where((c) => c.estado.toLowerCase() == 'pendiente').length;
    if (citasPendientesHoy > 0) {
      dinamicos.add({
        'tipo': 'hoy',
        'titulo': 'Citas pendientes para hoy',
        'descripcion': 'Tienes $citasPendientesHoy citas pendientes por atender',
        'color': const Color(0xFF2196F3),
        'icon': Icons.today,
      });
    }

    setState(() {
      _recordatorios = dinamicos;
      _cargandoRecordatorios = false;
    });
  }

  void _aplicarFiltros() {
    _citasFiltradas = _todasLasCitas.where((cita) {
      final coincideNombre = _filtroPaciente.isEmpty || 
        (cita.pacienteNombre?.toLowerCase().contains(_filtroPaciente.toLowerCase()) ?? false);
      final coincideEstado = _filtroEstado == 'Todos' || cita.estado == _filtroEstado;
      return coincideNombre && coincideEstado;
    }).toList();
  }

  String get _totalCitasHoy => _citasHoy.length.toString();
  String get _pacientesAtendidos => _todasLasCitas.where((c) => c.estado.toLowerCase() == 'completada').length.toString();
  String get _atendidosHoy => _citasHoy.where((c) => c.estado.toLowerCase() == 'completada').length.toString();
  String get _pendientesHoy => _citasHoy.where((c) => c.estado.toLowerCase() == 'pendiente').length.toString();

  // ================================================================
  // ACCIONES: CANCELAR, REAGENDAR, INICIAR, FINALIZAR
  // ================================================================
  // REGLA DE EXCLUSIVIDAD: Si estado es Cancelada o Completada,
  // se ocultan/deshabilitan botones de Cancelar y Reagendar
  bool _puedeCancelar(Cita cita) => cita.puedeModificarse;
  bool _puedeReagendar(Cita cita) => cita.puedeModificarse;
  bool _puedeIniciar(Cita cita) => cita.puedeIniciarse;
  bool _puedeFinalizar(Cita cita) => cita.puedeFinalizarse;

  Future<void> _cancelarCita(Cita cita) async {
    // REGLA DE EXCLUSIVIDAD
    if (!_puedeCancelar(cita)) {
      _mostrarError('No se puede cancelar una cita ${cita.estado.toLowerCase()}');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancelar Cita', style: TextStyle(color: _textoPrincipal, fontWeight: FontWeight.bold)),
        content: Text('Estas seguro de que deseas cancelar esta cita?', style: TextStyle(color: _textoSecundario)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No', style: TextStyle(color: _accentColor))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Si, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      // Enviar rol del medico en el body para auditoria
      final resultado = await _api.cancelarCita(cita.idCita, 'Medico');
      if (resultado.success) {
        await _fetchCitas();
        if (mounted) _showSnack('Cita cancelada', const Color(0xFF4CAF50));
      } else {
        _mostrarError(resultado.error ?? 'Error al cancelar');
      }
    } catch (e) { _mostrarError('Error: $e'); }
  }

  Future<void> _reagendarCita(Cita cita) async {
    // REGLA DE EXCLUSIVIDAD
    if (!_puedeReagendar(cita)) {
      _mostrarError('No se puede reagendar una cita ${cita.estado.toLowerCase()}');
      return;
    }

    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('es', 'ES'),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: _isDarkMode
            ? const ColorScheme.dark(primary: Color(0xFF05006B), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white)
            : const ColorScheme.light(primary: Color(0xFF05006B), onPrimary: Colors.white, surface: Colors.white, onSurface: Color(0xFF1A1A2E)),
        ),
        child: child!,
      ),
    );
    if (fecha == null) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: _isDarkMode
            ? const ColorScheme.dark(primary: Color(0xFF05006B), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white)
            : const ColorScheme.light(primary: Color(0xFF05006B), onPrimary: Colors.white, surface: Colors.white, onSurface: Color(0xFF1A1A2E)),
        ),
        child: child!,
      ),
    );
    if (hora == null) return;
    final nuevaFechaHora = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    try {
      // Enviar rol del medico en el body para auditoria
      final resultado = await _api.reagendarCita(cita.idCita, nuevaFechaHora, 'Medico');
      if (resultado.success) {
        await _fetchCitas();
        if (mounted) _showSnack('Cita reagendada', const Color(0xFF4CAF50));
      } else {
        _mostrarError(resultado.error ?? 'Error al reagendar');
      }
    } catch (e) { _mostrarError('Error: $e'); }
  }

  Future<void> _iniciarCita(Cita cita) async {
    if (!_puedeIniciar(cita)) {
      _mostrarError('Solo se puede iniciar una cita Pendiente o Reagendada');
      return;
    }
    try {
      final resultado = await _api.iniciarCita(cita.idCita);
      if (resultado.success) {
        await _fetchCitas();
        if (mounted) _showSnack('Cita iniciada', const Color(0xFF4CAF50));
      } else {
        _mostrarError(resultado.error ?? 'Error al iniciar');
      }
    } catch (e) { _mostrarError('Error: $e'); }
  }

  Future<void> _finalizarCita(Cita cita) async {
    if (!_puedeFinalizar(cita)) {
      _mostrarError('Solo se puede finalizar una cita En Progreso');
      return;
    }
    try {
      final resultado = await _api.finalizarCita(cita.idCita);
      if (resultado.success) {
        await _fetchCitas();
        if (mounted) _showSnack('Cita finalizada', const Color(0xFF4CAF50));
      } else {
        _mostrarError(resultado.error ?? 'Error al finalizar');
      }
    } catch (e) { _mostrarError('Error: $e'); }
  }

  // ================================================================
  // HISTORIA CLINICA Y RECETAS
  // ================================================================
  Future<void> _fetchHistorialPaciente(int idPaciente) async {
    setState(() { _idPacienteExpediente = idPaciente; });
    try {
      final resultado = await _api.getHistoriasPorPaciente(idPaciente);
      if (resultado.success && resultado.data != null) {
        setState(() { _historialPaciente = resultado.data!; });
      }
      setState(() {
        _citasPacienteExpediente = _todasLasCitas.where((c) => c.idPaciente == idPaciente).toList();
      });
    } catch (e) { _mostrarError('Error cargando historial: $e'); }
  }

  Future<void> _crearHistoriaClinica() async {
    if (!_formHistoriaKey.currentState!.validate()) return;
    if (_idPacienteExpediente == null) { _mostrarError('Selecciona un paciente'); return; }
    setState(() => _guardandoHistoria = true);
    try {
      final resultado = await _api.crearHistoriaClinica(
        idPaciente: _idPacienteExpediente!,
        idMedico: _idMedico!,
        sintomas: _sintomasCtrl.text.trim(),
        diagnostico: _diagnosticoCtrl.text.trim(),
        tratamiento: _tratamientoCtrl.text.trim(),
        notasPrivadas: _notasPrivadasCtrl.text.trim().isNotEmpty ? _notasPrivadasCtrl.text.trim() : null,
      );
      if (resultado.success) {
        _sintomasCtrl.clear(); _diagnosticoCtrl.clear(); _tratamientoCtrl.clear(); _notasPrivadasCtrl.clear();
        setState(() { _rutaRecetaAdjunta = null; _nombreRecetaVisual = null; _plantillaSeleccionada = null; });
        await _fetchHistorialPaciente(_idPacienteExpediente!);
        if (mounted) _showSnack('Historia clinica registrada', const Color(0xFF4CAF50));
      } else { _mostrarError(resultado.error ?? 'Error al guardar'); }
    } catch (e) { _mostrarError('Error: $e'); }
    finally { if (mounted) setState(() => _guardandoHistoria = false); }
  }

  void _aplicarPlantilla(String nombrePlantilla) {
    final plantilla = plantillasDiagnosticos.firstWhere((p) => p['nombre'] == nombrePlantilla);
    setState(() {
      _plantillaSeleccionada = nombrePlantilla;
      _sintomasCtrl.text = plantilla['sintomas']!;
      _diagnosticoCtrl.text = plantilla['diagnostico']!;
      _tratamientoCtrl.text = plantilla['tratamiento']!;
    });
  }

  Future<void> _pickReceta() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.single.path != null) {
        setState(() { _rutaRecetaAdjunta = result.files.single.path; _nombreRecetaVisual = result.files.single.name; });
      }
    } catch (e) { _mostrarError('Error: $e'); }
  }

  // ================================================================
  // CHAT - SIN RESPUESTAS PREDETERMINADAS (solo registros reales)
  // ================================================================
  Future<void> _fetchChat(int idPaciente) async {
    setState(() {
      _idPacienteChat = idPaciente;
      _cargandoMensajes = true;
      _mensajesChat = [];
    });
    try {
      final resultado = await _api.getMensajesPorMedico(_idMedico!);
      final mensajes = resultado.data ?? <Mensaje>[];
      if (resultado.success) {
        setState(() {
          _mensajesChat = mensajes.where((m) => m.idPaciente == idPaciente).toList();
          _cargandoMensajes = false;
        });
      } else {
        setState(() {
          _mensajesChat = [];
          _cargandoMensajes = false;
        });
      }
    } catch (e) {
      setState(() {
        _mensajesChat = [];
        _cargandoMensajes = false;
      });
    }
  }

  Future<void> _enviarMensajeChat() async {
    if (_chatCtrl.text.trim().isEmpty || _idPacienteChat == null) return;
    setState(() => _enviandoChat = true);
    try {
      final resultado = await _api.enviarMensaje(
        idPaciente: _idPacienteChat!,
        idMedico: _idMedico!,
        remitente: 'medico',
        contenido: _chatCtrl.text.trim(),
      );
      if (resultado.success) {
        _chatCtrl.clear();
        await _fetchChat(_idPacienteChat!);
      }
    } catch (e) { _mostrarError('Error: $e'); }
    finally { if (mounted) setState(() => _enviandoChat = false); }
  }

  // ================================================================
  // CONFIGURACION DE AGENDA CON GUARDADO EN BACKEND
  // ================================================================
  Future<void> _configurarDuracionConsulta() async {
    final seleccionado = await showDialog<DuracionConsulta>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Duracion de Consulta', style: TextStyle(color: _textoPrincipal, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DuracionConsulta.values.map((d) => RadioListTile<DuracionConsulta>(
            title: Text(d.label, style: TextStyle(color: _textoPrincipal)),
            value: d,
            groupValue: _duracionConsulta,
            onChanged: (v) => Navigator.pop(ctx, v),
            activeColor: _accentColor,
          )).toList(),
        ),
      ),
    );
    if (seleccionado != null) {
      setState(() => _duracionConsulta = seleccionado);
      await _guardarConfigAgenda();
    }
  }

  Future<void> _seleccionarDiasDescanso() async {
    final diasNombres = ['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo'];
    final seleccionados = List<int>.from(_diasDescanso);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Dias de Descanso', style: TextStyle(color: _textoPrincipal, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (i) => CheckboxListTile(
              title: Text(diasNombres[i], style: TextStyle(color: _textoPrincipal)),
              value: seleccionados.contains(i + 1),
              onChanged: (v) {
                setDialogState(() {
                  if (v == true) seleccionados.add(i + 1);
                  else seleccionados.remove(i + 1);
                });
              },
              activeColor: _accentColor,
              checkColor: Colors.white,
            )),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Guardar', style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
    setState(() => _diasDescanso = seleccionados);
    await _guardarConfigAgenda();
  }

  Future<void> _agregarVacaciones() async {
    final fechaInicio = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
    );
    if (fechaInicio == null) return;
    final fechaFin = await showDatePicker(
      context: context,
      initialDate: fechaInicio.add(const Duration(days: 7)),
      firstDate: fechaInicio,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
    );
    if (fechaFin == null) return;
    for (var d = fechaInicio; d.isBefore(fechaFin.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
      if (!_vacaciones.any((v) => _mismoDia(v, d))) {
        setState(() => _vacaciones.add(d));
      }
    }
    await _guardarConfigAgenda();
  }

  bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _esDiaDescanso(DateTime fecha) => _diasDescanso.contains(fecha.weekday);
  bool _esVacaciones(DateTime fecha) => _vacaciones.any((v) => _mismoDia(v, fecha));

  // ================================================================
  // DESCARGAR REPORTE MENSUAL PDF DESDE BACKEND
  // ================================================================
  Future<void> _descargarReporteMensual() async {
    if (_idMedico == null) {
      _mostrarError('No hay medico autenticado');
      return;
    }
    setState(() => _cargandoStats = true);
    try {
      await _api.descargarReporteMensual(_idMedico!);
      if (mounted) _showSnack('Reporte descargado', const Color(0xFF4CAF50));
    } catch (e) {
      _mostrarError('Error descargando reporte: $e');
    } finally {
      setState(() => _cargandoStats = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: const Color(0xFFE53935)),
    );
  }

  void _showSnack(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  // ================================================================
  // NUEVO: PERFIL DEL DOCTOR
  // ================================================================

  // --- Selector de Avatar ---
  void _pickerAvatar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Elige tu Avatar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona una imagen que te represente',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                // Opcion: Subir foto real desde galeria
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _subirFotoReal();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Subir foto real'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF05006B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'O elige un avatar predeterminado',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: List.generate(15, (i) {
                    final seed = 'Doctor${i + 1}';
                    final url = 'https://api.dicebear.com/7.x/avataaars/png?seed=$seed';
                    final isSelected = _avatarUrl == url;
                    return GestureDetector(
                      onTap: () {
                        setState(() { _avatarUrl = url; });
                        Navigator.pop(context);
                        _showSnack('Avatar actualizado!', Colors.green);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF00D4FF) : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [const BoxShadow(color: Color(0xFF00D4FF), blurRadius: 10, spreadRadius: 2)]
                              : null,
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[100],
                          backgroundImage: NetworkImage(url),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004694),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _subirFotoReal() async {
    if (_idMedico == null) return;
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final res = await _api.subirFotoMedico(_idMedico!, file);
        if (res.success) {
          setState(() {
            _avatarUrl = (res.data != null && res.data!.isNotEmpty)
              ? res.data
              : result.files.single.path!;
          });
          _showSnack('Foto actualizada exitosamente', const Color(0xFF4CAF50));
          await _fetchDatosDoctor();
        } else {
          _mostrarError(res.error ?? 'Error al subir foto');
        }
      }
    } catch (e) {
      _mostrarError('Error: $e');
    }
  }

  // --- Configuracion / Modo Oscuro ---
  void _config() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Configuracion', style: TextStyle(color: _textoPrincipal)),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text('Modo Oscuro', style: TextStyle(color: _textoPrincipal)),
                subtitle: Text('Cambiar tema de la aplicacion', style: TextStyle(color: _textoSecundario, fontSize: 12)),
                value: _isDarkMode,
                activeColor: const Color(0xFFFFE600),
                onChanged: (v) { 
                  setDialogState(() => _isDarkMode = v); 
                  setState(() => _isDarkMode = v); 
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.timer, color: _accentColor),
                title: Text('Duracion de consulta', style: TextStyle(color: _textoPrincipal)),
                subtitle: Text(_duracionConsulta.label, style: TextStyle(color: _textoSecundario, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () { Navigator.pop(context); _configurarDuracionConsulta(); },
              ),
              ListTile(
                leading: Icon(Icons.weekend, color: _accentColor),
                title: Text('Dias de descanso', style: TextStyle(color: _textoPrincipal)),
                subtitle: Text(_diasDescanso.isEmpty ? 'Ninguno' : '${_diasDescanso.length} dias', style: TextStyle(color: _textoSecundario, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () { Navigator.pop(context); _seleccionarDiasDescanso(); },
              ),
              ListTile(
                leading: Icon(Icons.beach_access, color: _accentColor),
                title: Text('Vacaciones', style: TextStyle(color: _textoPrincipal)),
                subtitle: Text(_vacaciones.isEmpty ? 'Ninguna' : '${_vacaciones.length} dias', style: TextStyle(color: _textoSecundario, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () { Navigator.pop(context); _agregarVacaciones(); },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Aceptar', style: TextStyle(color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)))
          ),
        ],
      ),
    );
  }

  // --- Ayuda y Soporte ---
  void _ayuda() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF05006B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.support_agent_rounded, color: Color(0xFF05006B), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text('Centro de Ayuda CDO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textoPrincipal))),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Necesitas asistencia? Nuestro equipo de soporte esta disponible para ayudarte.', style: TextStyle(fontSize: 14, color: _textoSecundario, height: 1.6)),
            const SizedBox(height: 20),
            _ayudaItem(Icons.calendar_month_rounded, 'Agenda y Citas', 'Gestiona tu calendario, duracion de consultas y dias de descanso.'),
            const SizedBox(height: 12),
            _ayudaItem(Icons.people_alt_rounded, 'Pacientes', 'Accede a historiales clinicos, recetas y expedientes de tus pacientes.'),
            const SizedBox(height: 12),
            _ayudaItem(Icons.chat_bubble_rounded, 'Chat', 'Comunicate con tus pacientes en tiempo real.'),
            const SizedBox(height: 12),
            _ayudaItem(Icons.analytics_rounded, 'Estadisticas', 'Revisa tu productividad y genera reportes mensuales.'),
            const SizedBox(height: 12),
            _ayudaItem(Icons.dark_mode_rounded, 'Modo Oscuro', 'Activa el modo oscuro desde Configuracion.'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFF05006B).withOpacity(0.15))),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Para soporte inmediato, contacta al administrador del sistema o usa el chat con soporte tecnico.',
                  style: TextStyle(fontSize: 13, color: _isDarkMode ? Colors.white.withOpacity(0.8) : const Color(0xFF4A5568), height: 1.5))),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido', style: TextStyle(color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _ayudaItem(IconData icon, String title, String desc) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF05006B).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B))),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textoPrincipal)),
      const SizedBox(height: 4),
      Text(desc, style: TextStyle(fontSize: 13, color: _textoSecundario, height: 1.5)),
    ])),
  ]);

  // --- Cerrar Sesion ---
  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cerrar Sesion', style: TextStyle(color: _textoPrincipal, fontWeight: FontWeight.bold)),
        content: Text('Estas seguro de que deseas cerrar sesion?', style: TextStyle(color: _textoSecundario)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: _accentColor))),
          ElevatedButton(
            onPressed: () {
              _api.clearToken();
              Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Si, cerrar sesion'),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // VISTA PERFIL - COMPLETA
  // ================================================================
  Widget _buildPerfilView() => SingleChildScrollView(
    padding: const EdgeInsets.all(40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mi Perfil', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _textoPrincipal)),
      const SizedBox(height: 32),
      Center(child: GestureDetector(
        onTap: _pickerAvatar,
        child: Stack(children: [
          _avatarWidget(url: _avatarUrl, iniciales: _inicialesDoctor, color: _avatarColor, r: 60),
          Positioned(bottom: 0, right: 0, child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFFFE600), shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]),
            child: const Icon(Icons.edit, size: 18, color: Color(0xFF05006B)),
          )),
        ]),
      )),
      const SizedBox(height: 20),
      Center(child: Text(_nombreDoctor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textoPrincipal))),
      Center(child: Text(_especialidadDoctor, style: TextStyle(fontSize: 15, color: _textoSecundario))),
      if (_correoDoctor != null) ...[
        const SizedBox(height: 8),
        Center(child: Text(_correoDoctor!, style: TextStyle(fontSize: 14, color: _textoPrincipal))),
      ],
      if (_telefonoDoctor != null) ...[
        const SizedBox(height: 8),
        Center(child: Text(_telefonoDoctor!, style: TextStyle(fontSize: 14, color: _textoPrincipal))),
      ],
      if (_licenciaMedica != null) ...[
        const SizedBox(height: 8),
        Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.white12 : const Color(0xFFF3F7FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Lic. Medica: $_licenciaMedica', style: TextStyle(
            fontSize: 13,
            color: _isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
            fontWeight: FontWeight.w600,
          )),
        )),
      ],
      const SizedBox(height: 40),
      _menuTile(Icons.settings_rounded, 'Configuracion', _config),
      _menuTile(Icons.support_agent_rounded, 'Ayuda y Soporte', _ayuda),
      _menuTile(Icons.logout_rounded, 'Cerrar Sesion', _cerrarSesion, color: const Color(0xFFE53935)),
    ]),
  );

  Widget _menuTile(IconData i, String t, VoidCallback onTap, {Color? color}) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor, borderRadius: BorderRadius.circular(16),
        border: _isDarkMode ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (color ?? (_isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF4A5568))).withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(i, color: color ?? (_isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF4A5568)), size: 22)),
        const SizedBox(width: 16),
        Expanded(child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textoPrincipal))),
        Icon(Icons.chevron_right_rounded, color: _textoSecundario),
      ]),
    ),
  );

  // ================================================================
  // BUILD PRINCIPAL - SIDEBAR CON PERFIL AGREGADO
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: Row(children: [
        _sidebar(),
        Expanded(child: [
          _buildInicioView(),
          _buildAgendaView(),
          _buildPacientesView(),
          _buildChatView(),
          _buildEstadisticasView(),
          _buildPerfilView(),
        ][_selectedIndex]),
      ]),
    );
  }

  // ================================================================
  // SIDEBAR - CON PERFIL AGREGADO
  // ================================================================
  Widget _sidebar() {
    final items = [
      (Icons.dashboard_rounded, 'Inicio', 0),
      (Icons.calendar_month_rounded, 'Agenda', 1),
      (Icons.people_alt_rounded, 'Pacientes', 2),
      (Icons.chat_bubble_rounded, 'Chat', 3),
      (Icons.analytics_rounded, 'Stats', 4),
      (Icons.person_rounded, 'Perfil', 5),
    ];

    return Container(
      width: 260,
      color: const Color(0xFF05006B),
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(children: [
                const SizedBox(height: 40),
                _logoSidebar(),
                const SizedBox(height: 50),
                ...items.map((i) => _navItem(i)),
                const Spacer(),
                _userCardSidebar(),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _logoSidebar() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 32),
    ),
    const SizedBox(width: 12),
    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CDO', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
      Text('Centro Diagnostico', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1)),
    ]),
  ]);

  Widget _navItem((IconData, String, int) item) {
    final sel = _selectedIndex == item.$3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = item.$3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: sel ? Colors.white.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: sel ? Border.all(color: Colors.white.withOpacity(0.2)) : null,
          ),
          child: Row(children: [
            Icon(item.$1, color: sel ? const Color(0xFFFFE600) : Colors.white.withOpacity(0.6), size: 22),
            const SizedBox(width: 16),
            Text(item.$2, style: TextStyle(
              color: sel ? Colors.white : Colors.white.withOpacity(0.6),
              fontSize: 15,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            )),
            if (sel) ...[const Spacer(), _activeDot()],
          ]),
        ),
      ),
    );
  }

  Widget _activeDot() => Container(
    width: 6, height: 6,
    decoration: const BoxDecoration(color: Color(0xFFFFE600), shape: BoxShape.circle),
  );

  Widget _userCardSidebar() => Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Row(children: [
      _avatarWidget(url: _avatarUrl, iniciales: _inicialesDoctor, color: const Color(0xFF0066CC), r: 24),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_nombreDoctor, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(_especialidadDoctor, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
      ])),
    ]),
  );

  Widget _avatarWidget({String? url, required String iniciales, required Color color, required double r}) {
    final hasUrl = url != null && url.isNotEmpty;
    final ImageProvider? imageProvider = hasUrl
        ? (url!.startsWith('http') ? NetworkImage(url) : FileImage(File(url)))
        : null;

    return CircleAvatar(
      radius: r,
      backgroundColor: color,
      backgroundImage: imageProvider,
      onBackgroundImageError: imageProvider != null ? (_, __) {} : null,
      child: imageProvider == null ? Text(iniciales, style: TextStyle(color: Colors.white, fontSize: r * 0.45, fontWeight: FontWeight.bold)) : null,
    );
  }

  // ================================================================
  // VISTA 0: INICIO (Dashboard principal con resumen)
  // ================================================================
  Widget _buildInicioView() {
    return RefreshIndicator(
      onRefresh: _fetchDatosIniciales,
      color: _accentColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerHome(),
            const SizedBox(height: 40),
            _tituloSeccion('Resumen de Hoy'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildSummaryCard(icon: Icons.calendar_today_rounded, value: _cargandoCitas ? '...' : _totalCitasHoy, label: 'Citas hoy', color: const Color(0xFF05006B))),
                const SizedBox(width: 20),
                Expanded(child: _buildSummaryCard(icon: Icons.people_alt_rounded, value: _cargandoCitas ? '...' : _pacientesAtendidos, label: 'Atendidos total', color: const Color(0xFF00B4DB))),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildSummaryCard(icon: Icons.check_circle_rounded, value: _cargandoCitas ? '...' : _atendidosHoy, label: 'Atendidos hoy', color: const Color(0xFF4CAF50))),
                const SizedBox(width: 20),
                Expanded(child: _buildSummaryCard(icon: Icons.pending_actions_rounded, value: _cargandoCitas ? '...' : _pendientesHoy, label: 'Pendientes', color: const Color(0xFFFF9800))),
              ],
            ),
            const SizedBox(height: 40),
            _tituloSeccion('Proximas Citas'),
            const SizedBox(height: 24),
            _buildCitasList(),
          ],
        ),
      ),
    );
  }

  Widget _headerHome() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bienvenido a CDO!', style: TextStyle(color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B), fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Text(_nombreDoctor, style: TextStyle(color: _textoPrincipal, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
    ]),
    _chip(icon: Icons.calendar_today_rounded, label: DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now())),
  ]);

  Widget _tituloSeccion(String t) => Row(children: [
    Container(width: 4, height: 24, decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B), borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 12),
    Text(t, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textoPrincipal)),
  ]);

  Widget _chip({required IconData icon, required String label}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      color: _isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFF05006B).withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _isDarkMode ? Colors.white.withOpacity(0.2) : const Color(0xFF05006B).withOpacity(0.1))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: _isDarkMode ? Colors.white70 : const Color(0xFF05006B), fontSize: 14, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _buildSummaryCard({required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: _cardBorder,
        boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _textoPrincipal)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: _textoSecundario, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCitasList() {
    if (_cargandoCitas) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF05006B))));
    } else if (_errorCitas != null) {
      return _buildErrorCard(_errorCitas!);
    } else if (_citasHoy.isEmpty) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(child: Column(children: [
            Icon(Icons.event_busy, size: 48, color: _textoSecundario),
            const SizedBox(height: 12),
            Text('No hay citas para hoy', style: TextStyle(color: _textoSecundario, fontSize: 16)),
          ])),
        ),
      );
    }
    return Column(
      children: _citasHoy.map((cita) => _buildCitaCard(cita)).toList(),
    );
  }

  // ================================================================
  // CITA CARD CON SEMAFORO VISUAL Y REGLA DE EXCLUSIVIDAD
  // ================================================================
  Widget _buildCitaCard(Cita cita) {
    final horaFormateada = _formatearHora(cita.fechaHora);
    // SEMAFORO VISUAL: Color segun estado del modelo Cita
    final estadoColor = cita.colorEstado;
    final estadoLegible = cita.estadoLegible;

    // REGLA DE EXCLUSIVIDAD: Determinar si se muestran los botones
    final puedeCancelar = _puedeCancelar(cita);
    final puedeReagendar = _puedeReagendar(cita);
    final puedeIniciar = _puedeIniciar(cita);
    final puedeFinalizar = _puedeFinalizar(cita);

    // Mensaje de auditoria si existe
    final auditoria = cita.mensajeAuditoria;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: _cardBorder,
        boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [estadoColor.withOpacity(0.8), estadoColor]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(horaFormateada, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cita.pacienteNombre ?? 'Paciente #${cita.idPaciente}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(cita.motivo, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text(estadoLegible, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // Mensaje de auditoria si existe
          if (auditoria != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: estadoColor.withOpacity(0.1))),
              ),
              child: Text(
                auditoria,
                style: TextStyle(fontSize: 12, color: estadoColor, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          // Botones de accion con REGLA DE EXCLUSIVIDAD
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (puedeIniciar)
                  _btnAccion(Icons.play_arrow, 'Iniciar', () => _iniciarCita(cita), color: const Color(0xFF4CAF50)),
                if (puedeFinalizar)
                  _btnAccion(Icons.check, 'Completar', () => _finalizarCita(cita), color: const Color(0xFF2E7D32)),
                if (puedeReagendar)
                  _btnAccion(Icons.calendar_today, 'Reagendar', () => _reagendarCita(cita)),
                if (puedeCancelar)
                  _btnAccion(Icons.cancel, 'Cancelar', () => _cancelarCita(cita), color: const Color(0xFFE53935)),
                // Si no hay acciones disponibles, mostrar indicador
                if (!puedeIniciar && !puedeFinalizar && !puedeReagendar && !puedeCancelar)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Cita ${cita.estadoLegible.toLowerCase()}',
                      style: TextStyle(fontSize: 13, color: _textoSecundario, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btnAccion(IconData i, String l, VoidCallback onTap, {Color? color}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color != null ? color.withOpacity(0.1) : _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color ?? (_isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2)))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 16, color: color ?? (_isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B))),
        const SizedBox(width: 6),
        Text(l, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? (_isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)))),
      ]),
    ),
  );

  // ================================================================
  // VISTA 1: AGENDA INTELIGENTE - CON NAVEGACION FUNCIONAL
  // ================================================================
  Widget _buildAgendaView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Agenda Inteligente', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _textoPrincipal)),
          const SizedBox(height: 8),
          Text('Gestiona tu tiempo y disponibilidad', style: TextStyle(fontSize: 15, color: _textoSecundario)),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildVistaButton('Dia', TipoVistaCalendario.dia),
              const SizedBox(width: 12),
              _buildVistaButton('Semana', TipoVistaCalendario.semana),
              const SizedBox(width: 12),
              _buildVistaButton('Mes', TipoVistaCalendario.mes),
            ],
          ),
          const SizedBox(height: 32),
          _tituloSeccion('Configuracion'),
          const SizedBox(height: 24),
          _buildConfigCard(
            icon: Icons.timer,
            title: 'Duracion de consulta',
            subtitle: _duracionConsulta.label,
            onTap: _configurarDuracionConsulta,
          ),
          const SizedBox(height: 12),
          _buildConfigCard(
            icon: Icons.weekend,
            title: 'Dias de descanso',
            subtitle: _diasDescanso.isEmpty ? 'Ninguno' : '${_diasDescanso.length} dias',
            onTap: _seleccionarDiasDescanso,
          ),
          const SizedBox(height: 12),
          _buildConfigCard(
            icon: Icons.beach_access,
            title: 'Vacaciones',
            subtitle: _vacaciones.isEmpty ? 'Ninguna' : '${_vacaciones.length} dias',
            onTap: _agregarVacaciones,
          ),
          const SizedBox(height: 32),
          _buildCalendarioVisual(),
          const SizedBox(height: 32),
          _tituloSeccion('Citas del periodo'),
          const SizedBox(height: 24),
          _buildCitasFiltradasList(),
        ],
      ),
    );
  }

  Widget _buildVistaButton(String label, TipoVistaCalendario tipo) {
    final seleccionado = _vistaCalendario == tipo;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vistaCalendario = tipo),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: seleccionado ? const Color(0xFF05006B) : _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: seleccionado ? const Color(0xFF05006B) : _borderColor),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: seleccionado ? Colors.white : _textoPrincipal,
              fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: _cardBorder,
        boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF05006B).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF05006B), size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: _textoPrincipal)),
        subtitle: Text(subtitle, style: TextStyle(color: _textoSecundario, fontSize: 13)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: _isDarkMode ? Colors.white.withOpacity(0.5) : const Color(0xFF05006B)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildCalendarioVisual() {
    switch (_vistaCalendario) {
      case TipoVistaCalendario.dia:
        return _buildVistaDia();
      case TipoVistaCalendario.semana:
        return _buildVistaSemana();
      case TipoVistaCalendario.mes:
        return _buildVistaMes();
    }
  }

  Widget _buildVistaDia() {
    final fecha = _fechaCalendarioDia;
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: _textoPrincipal),
                  onPressed: () => setState(() => _fechaCalendarioDia = fecha.subtract(const Duration(days: 1))),
                ),
                Text(DateFormat('EEEE, d MMMM', 'es').format(fecha), style: TextStyle(fontWeight: FontWeight.bold, color: _textoPrincipal, fontSize: 16)),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: _textoPrincipal),
                  onPressed: () => setState(() => _fechaCalendarioDia = fecha.add(const Duration(days: 1))),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...List.generate(12, (i) {
              final hora = 8 + i;
              final horaStr = '${hora.toString().padLeft(2, '0')}:00';
              final citasHora = _todasLasCitas.where((c) {
                final fc = c.fechaHora;
                return fc.year == fecha.year && fc.month == fecha.month && fc.day == fecha.day && fc.hour == hora;
              }).toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 50, child: Text(horaStr, style: TextStyle(color: _textoSecundario, fontSize: 12, fontWeight: FontWeight.w500))),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: citasHora.isNotEmpty ? const Color(0xFF05006B).withOpacity(0.1) : _inputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: citasHora.isNotEmpty ? const Color(0xFF05006B).withOpacity(0.3) : _borderColor),
                        ),
                        child: citasHora.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: citasHora.map((c) => Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(color: c.colorEstado, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${c.pacienteNombre ?? "Paciente"} - ${c.motivo}',
                                      style: TextStyle(fontSize: 12, color: _textoPrincipal, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              )).toList(),
                            )
                          : Text('Disponible', style: TextStyle(color: _textoSecundario, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaSemana() {
    final hoy = DateTime.now();
    final inicioSemana = _fechaCalendarioSemana.subtract(Duration(days: _fechaCalendarioSemana.weekday - 1));
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: _textoPrincipal),
                  onPressed: () => setState(() => _fechaCalendarioSemana = _fechaCalendarioSemana.subtract(const Duration(days: 7))),
                ),
                Text('Semana del ${DateFormat('d MMM', 'es').format(inicioSemana)}', style: TextStyle(fontWeight: FontWeight.bold, color: _textoPrincipal, fontSize: 16)),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: _textoPrincipal),
                  onPressed: () => setState(() => _fechaCalendarioSemana = _fechaCalendarioSemana.add(const Duration(days: 7))),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: List.generate(7, (i) {
                final dia = inicioSemana.add(Duration(days: i));
                final esHoy = dia.day == hoy.day && dia.month == hoy.month && dia.year == hoy.year;
                final esDescanso = _esDiaDescanso(dia);
                final esVacacion = _esVacaciones(dia);
                final citasDia = _todasLasCitas.where((c) {
                    final fc = c.fechaHora;
                    return fc.year == dia.year && fc.month == dia.month && fc.day == dia.day;
                  }).length;

                return Expanded(
                  child: GestureDetector(
                    onTap: esDescanso || esVacacion ? null : () {},
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: esVacacion ? Colors.orange.withOpacity(0.15) : esDescanso ? Colors.grey.withOpacity(0.15) : esHoy ? const Color(0xFF05006B).withOpacity(0.1) : _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: esHoy ? const Color(0xFF05006B) : _borderColor, width: esHoy ? 2 : 1),
                      ),
                      child: Column(
                        children: [
                          Text(['L', 'M', 'M', 'J', 'V', 'S', 'D'][i], style: TextStyle(fontSize: 11, color: _textoSecundario)),
                          const SizedBox(height: 4),
                          Text('${dia.day}', style: TextStyle(fontWeight: FontWeight.bold, color: esDescanso || esVacacion ? _textoSecundario : _textoPrincipal)),
                          const SizedBox(height: 4),
                          if (citasDia > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF05006B), borderRadius: BorderRadius.circular(8)),
                              child: Text('$citasDia', style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          if (esVacacion)
                            const Icon(Icons.beach_access, size: 12, color: Colors.orange),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaMes() {
    final hoy = DateTime.now();
    final primerDia = DateTime(_fechaCalendarioMes.year, _fechaCalendarioMes.month, 1);
    final ultimoDia = DateTime(_fechaCalendarioMes.year, _fechaCalendarioMes.month + 1, 0);
    final diasMes = ultimoDia.day;
    final primerWeekday = primerDia.weekday;

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: _textoPrincipal),
                  onPressed: () => setState(() => _fechaCalendarioMes = DateTime(_fechaCalendarioMes.year, _fechaCalendarioMes.month - 1, 1)),
                ),
                Text(DateFormat('MMMM yyyy', 'es').format(_fechaCalendarioMes), style: TextStyle(fontWeight: FontWeight.bold, color: _textoPrincipal, fontSize: 16)),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: _textoPrincipal),
                  onPressed: () => setState(() => _fechaCalendarioMes = DateTime(_fechaCalendarioMes.year, _fechaCalendarioMes.month + 1, 1)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'].map((d) => Expanded(
                child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textoSecundario))),
              )).toList(),
            ),
            const SizedBox(height: 12),
            ...List.generate((diasMes + primerWeekday - 1 + 6) ~/ 7, (semanaIdx) {
              return Row(
                children: List.generate(7, (diaIdx) {
                  final diaNum = semanaIdx * 7 + diaIdx - primerWeekday + 2;
                  if (diaNum < 1 || diaNum > diasMes) return const Expanded(child: SizedBox(height: 50));

                  final dia = DateTime(_fechaCalendarioMes.year, _fechaCalendarioMes.month, diaNum);
                  final esHoy = diaNum == hoy.day && _fechaCalendarioMes.month == hoy.month && _fechaCalendarioMes.year == hoy.year;
                  final esDescanso = _esDiaDescanso(dia);
                  final esVacacion = _esVacaciones(dia);
                  final citasDia = _todasLasCitas.where((c) {
                    final fc = c.fechaHora;
                    return fc.year == dia.year && fc.month == dia.month && fc.day == dia.day;
                  }).length;

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      height: 50,
                      decoration: BoxDecoration(
                        color: esVacacion ? Colors.orange.withOpacity(0.1) : esDescanso ? Colors.grey.withOpacity(0.1) : esHoy ? const Color(0xFF05006B).withOpacity(0.1) : _cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: esHoy ? const Color(0xFF05006B) : _borderColor, width: esHoy ? 2 : 0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$diaNum', style: TextStyle(fontWeight: esHoy ? FontWeight.bold : FontWeight.normal, color: esDescanso || esVacacion ? _textoSecundario : _textoPrincipal)),
                          if (citasDia > 0) Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(color: Color(0xFF05006B), shape: BoxShape.circle),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCitasFiltradasList() {
    if (_citasFiltradas.isEmpty) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(child: Text('No hay citas en este periodo', style: TextStyle(color: _textoSecundario))),
        ),
      );
    }
    return Column(
      children: _citasFiltradas.map((cita) => _buildCitaCard(cita)).toList(),
    );
  }

  // ================================================================
  // VISTA 2: GESTION DE PACIENTES
  // ================================================================
  Widget _buildPacientesView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gestion de Pacientes', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _textoPrincipal)),
          const SizedBox(height: 8),
          Text('Historial clinico, recetas y expedientes', style: TextStyle(fontSize: 15, color: _textoSecundario)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: _cardBorder,
              boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: TextField(
              onChanged: (v) { setState(() { _filtroPaciente = v; _aplicarFiltros(); }); },
              style: TextStyle(color: _textoPrincipal),
              decoration: InputDecoration(
                hintText: 'Buscar paciente...',
                hintStyle: TextStyle(color: _textoSecundario),
                prefixIcon: Icon(Icons.search, color: _textoSecundario),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Todos', 'Pendiente', 'Completada', 'Cancelada'].map((estado) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(estado),
                  selected: _filtroEstado == estado,
                  onSelected: (sel) { if (sel) setState(() { _filtroEstado = estado; _aplicarFiltros(); }); },
                  selectedColor: const Color(0xFF05006B),
                  backgroundColor: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[200],
                  labelStyle: TextStyle(color: _filtroEstado == estado ? Colors.white : _textoPrincipal, fontWeight: FontWeight.w600),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 32),
          Text('Pacientes (${_citasFiltradas.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textoPrincipal)),
          const SizedBox(height: 16),
          _buildPacientesList(),
          if (_idPacienteExpediente != null) ...[
            const SizedBox(height: 40),
            _tituloSeccion('Expediente del Paciente'),
            const SizedBox(height: 24),
            if (_historialPaciente.isNotEmpty) ...[
              Text('Historial Clinico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textoPrincipal)),
              const SizedBox(height: 12),
              ..._historialPaciente.map((h) => _buildHistoriaCard(h)).toList(),
            ] else ...[
              _card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('Sin historial clinico previo', style: TextStyle(color: _textoSecundario))),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Citas Previas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textoPrincipal)),
            const SizedBox(height: 12),
            ..._citasPacienteExpediente.map((c) => ListTile(
              leading: Icon(Icons.event, color: const Color(0xFF05006B)),
              title: Text(_formatearFecha(c.fechaHora), style: TextStyle(color: _textoPrincipal)),
              subtitle: Text(c.motivo, style: TextStyle(color: _textoSecundario)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.colorEstado.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(c.estadoLegible, style: TextStyle(color: c.colorEstado, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            )).toList(),
            const SizedBox(height: 32),
            _tituloSeccion('Nueva Consulta'),
            const SizedBox(height: 24),
            _buildNuevaConsultaForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildPacientesList() {
    if (_citasFiltradas.isEmpty) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(child: Text('No se encontraron pacientes', style: TextStyle(color: _textoSecundario))),
        ),
      );
    }
    final pacientesUnicos = <int, Cita>{};
    for (final c in _citasFiltradas) { pacientesUnicos.putIfAbsent(c.idPaciente, () => c); }
    final lista = pacientesUnicos.values.toList();

    return Column(
      children: lista.map((cita) {
        final totalCitas = _todasLasCitas.where((c) => c.idPaciente == cita.idPaciente).length;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: _cardBorder,
            boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: ListTile(
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF05006B), Color(0xFF0A0E8A)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(
                (cita.pacienteNombre ?? 'P').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              )),
            ),
            title: Text(cita.pacienteNombre ?? 'Paciente #${cita.idPaciente}', style: TextStyle(fontWeight: FontWeight.w600, color: _textoPrincipal)),
            subtitle: Text('$totalCitas citas registradas', style: TextStyle(color: _textoSecundario, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline, color: const Color(0xFF05006B), size: 20),
                  onPressed: () { _fetchChat(cita.idPaciente); setState(() => _selectedIndex = 3); },
                ),
                IconButton(
                  icon: Icon(Icons.folder_open, color: const Color(0xFF05006B), size: 20),
                  onPressed: () => _fetchHistorialPaciente(cita.idPaciente),
                ),
              ],
            ),
            onTap: () => _fetchHistorialPaciente(cita.idPaciente),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHistoriaCard(HistoriaClinica h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: _cardBorder,
        boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ExpansionTile(
        collapsedBackgroundColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        iconColor: const Color(0xFF05006B),
        collapsedIconColor: _textoSecundario,
        title: Text('Consulta del ${_formatearFecha(h.fechaRegistro ?? DateTime.now())}', style: TextStyle(fontWeight: FontWeight.bold, color: _textoPrincipal, fontSize: 15)),
        subtitle: Text(h.diagnostico, style: TextStyle(color: _textoSecundario, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHistoriaDetailRow('Sintomas:', h.sintomas),
                const SizedBox(height: 8),
                _buildHistoriaDetailRow('Diagnostico:', h.diagnostico),
                const SizedBox(height: 8),
                _buildHistoriaDetailRow('Tratamiento:', h.tratamiento),
                if (h.notasPrivadas != null && h.notasPrivadas!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildHistoriaDetailRow('Notas privadas:', h.notasPrivadas!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNuevaConsultaForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: _cardBorder,
        boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Form(
        key: _formHistoriaKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plantilla de diagnostico', style: TextStyle(fontWeight: FontWeight.w600, color: _textoPrincipal)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _plantillaSeleccionada,
                  hint: Text('Seleccionar plantilla...', style: TextStyle(color: _textoSecundario)),
                  isExpanded: true,
                  dropdownColor: _cardColor,
                  style: TextStyle(color: _textoPrincipal),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin plantilla')),
                    ...plantillasDiagnosticos.map((p) => DropdownMenuItem(
                      value: p['nombre'],
                      child: Text(p['nombre']!, style: TextStyle(color: _textoPrincipal)),
                    )).toList(),
                  ],
                  onChanged: (v) { if (v != null) _aplicarPlantilla(v); else setState(() => _plantillaSeleccionada = null); },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildInputField(controller: _sintomasCtrl, label: 'Sintomas', hint: 'Describe los sintomas...', maxLines: 3),
            const SizedBox(height: 16),
            _buildInputField(controller: _diagnosticoCtrl, label: 'Diagnostico', hint: 'Indica el diagnostico...'),
            const SizedBox(height: 16),
            _buildInputField(controller: _tratamientoCtrl, label: 'Tratamiento', hint: 'Describe el tratamiento...', maxLines: 2),
            const SizedBox(height: 16),
            _buildInputField(controller: _notasPrivadasCtrl, label: 'Notas privadas (solo tu)', hint: 'Notas internas no visibles para el paciente...', maxLines: 2),
            const SizedBox(height: 20),
            Text('Receta Digital', style: TextStyle(fontWeight: FontWeight.w600, color: _textoPrincipal)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickReceta,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderColor)),
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: const Color(0xFF05006B)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(_nombreRecetaVisual ?? 'Adjuntar receta en PDF (opcional)', style: TextStyle(color: _nombreRecetaVisual != null ? _textoPrincipal : _textoSecundario))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _guardandoHistoria ? null : _crearHistoriaClinica,
                    icon: _guardandoHistoria ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))) : const Icon(Icons.save),
                    label: const Text('Guardar Historia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF05006B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // VISTA 3: CHAT - SOLO REGISTROS REALES (sin respuestas predeterminadas)
  // ================================================================
  Widget _buildChatView() {
    final pacientesUnicos = <int, Cita>{};
    for (final c in _todasLasCitas) { pacientesUnicos.putIfAbsent(c.idPaciente, () => c); }
    final listaPacientes = pacientesUnicos.values.toList();

    return Row(children: [
      _chatSidebar(listaPacientes),
      Expanded(
        child: Container(
          color: _isDarkMode ? const Color(0xFF0A0A0F) : const Color(0xFFF8F9FC),
          child: _idPacienteChat == null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 64, color: _textoSecundario),
                const SizedBox(height: 16),
                Text('Selecciona un paciente para iniciar chat', style: TextStyle(color: _textoSecundario, fontSize: 16)),
              ]))
            : Column(
                children: [
                  _chatHeader(),
                  const Divider(height: 1),
                  Expanded(
                    child: _cargandoMensajes
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF05006B)))
                      : _mensajesChat.isEmpty
                        ? Center(child: Text('No hay mensajes aun', style: TextStyle(color: _textoSecundario)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            reverse: true,
                            itemCount: _mensajesChat.length,
                            itemBuilder: (context, index) {
                              final msg = _mensajesChat[_mensajesChat.length - 1 - index];
                              final esMedico = msg.remitente.toLowerCase() == 'medico';
                              return Align(
                                alignment: esMedico ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                                  decoration: BoxDecoration(
                                    color: esMedico ? const Color(0xFF05006B) : _cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: !esMedico ? Border.all(color: _borderColor) : null,
                                    boxShadow: !esMedico ? [const BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2))] : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.contenidoTexto ?? msg.contenido ?? 'Sin contenido',
                                        style: TextStyle(color: esMedico ? Colors.white : _textoPrincipal, fontSize: 14, height: 1.5),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatearFechaHora(msg.fechaEnvio ?? DateTime.now()),
                                        style: TextStyle(color: esMedico ? Colors.white.withOpacity(0.7) : _textoSecundario, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // LIMPIEZA DEL CHAT: Sin respuestas predeterminadas, solo input
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: _cardColor,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatCtrl,
                            style: TextStyle(color: _textoPrincipal),
                            decoration: InputDecoration(
                              hintText: 'Escribe un mensaje...',
                              hintStyle: TextStyle(color: _textoSecundario),
                              filled: true,
                              fillColor: _inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _enviandoChat ? null : _enviarMensajeChat,
                          icon: _enviandoChat
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF05006B)))
                            : const Icon(Icons.send, color: Color(0xFF05006B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ),
    ]);
  }

  Widget _chatSidebar(List<Cita> listaPacientes) => Container(
    width: 320,
    decoration: BoxDecoration(
      color: _cardColor,
      border: _isDarkMode ? Border(right: BorderSide(color: Colors.white.withOpacity(0.1))) : null,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Conversaciones', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textoPrincipal)),
      ),
      Expanded(
        child: listaPacientes.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: _textoSecundario),
                const SizedBox(height: 12),
                Text('No hay conversaciones', style: TextStyle(color: _textoSecundario)),
              ]))
            : ListView.builder(
                itemCount: listaPacientes.length,
                itemBuilder: (_, i) => ListTile(
                  leading: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF05006B), Color(0xFF0A0E8A)]), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(
                      (listaPacientes[i].pacienteNombre ?? 'P').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    )),
                  ),
                  title: Text(listaPacientes[i].pacienteNombre ?? 'Paciente #${listaPacientes[i].idPaciente}', style: TextStyle(fontWeight: FontWeight.w600, color: _textoPrincipal)),
                  subtitle: Text('Toca para iniciar chat', style: TextStyle(color: _textoSecundario, fontSize: 12)),
                  trailing: Icon(Icons.chat_bubble, color: const Color(0xFF05006B)),
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                    _fetchChat(listaPacientes[i].idPaciente);
                  },
                ),
              ),
      ),
    ]),
  );

  Widget _chatHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), color: _cardColor,
    child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _idPacienteChat = null)),
      CircleAvatar(
        backgroundColor: const Color(0xFF05006B),
        child: Text(
          _todasLasCitas.firstWhere((c) => c.idPaciente == _idPacienteChat).pacienteNombre?.substring(0, 1) ?? 'P',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          _todasLasCitas.firstWhere((c) => c.idPaciente == _idPacienteChat).pacienteNombre ?? 'Paciente',
          style: TextStyle(fontWeight: FontWeight.bold, color: _textoPrincipal),
        ),
      ),
    ]),
  );

  // ================================================================
  // VISTA 4: ESTADISTICAS - CON RECORDATORIOS DINAMICOS
  // ================================================================
  Widget _buildEstadisticasView() {
    return RefreshIndicator(
      onRefresh: _fetchDatosIniciales,
      color: const Color(0xFF05006B),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Productividad', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _textoPrincipal)),
            const SizedBox(height: 8),
            Text('Estadisticas y reportes de tu actividad', style: TextStyle(fontSize: 15, color: _textoSecundario)),
            const SizedBox(height: 32),
            _cargandoStats
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF05006B)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tituloSeccion('Estadisticas Generales'),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Total Citas', '${_estadisticas['totalCitas'] ?? 0}', Icons.calendar_today, const Color(0xFF05006B))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard('Completadas', '${_estadisticas['completadas'] ?? 0}', Icons.check_circle, const Color(0xFF4CAF50))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Canceladas', '${_estadisticas['canceladas'] ?? 0}', Icons.cancel, const Color(0xFFE53935))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard('Pacientes', '${_estadisticas['pacientesUnicos'] ?? 0}', Icons.people, const Color(0xFFFF9800))),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tasa de Asistencia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textoPrincipal)),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: ((_estadisticas['tasaAsistencia'] ?? 0) / 100).clamp(0.0, 1.0),
                              backgroundColor: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            const SizedBox(height: 12),
                            Text('${_estadisticas['tasaAsistencia'] ?? 0}% de asistencia', style: TextStyle(color: _textoSecundario, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFF9C27B0).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.timer, color: Color(0xFF9C27B0)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Duracion promedio de consulta', style: TextStyle(color: _textoSecundario, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('${_estadisticas['promedioDuracion'] ?? 30} minutos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textoPrincipal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_recordatorios.isNotEmpty) ...[
                      _tituloSeccion('Recordatorios'),
                      const SizedBox(height: 16),
                      ..._recordatorios.map((r) => _buildRecordatorioCardDinamico(r)).toList(),
                      const SizedBox(height: 32),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _descargarReporteMensual,
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar Reporte Mensual (PDF)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF05006B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordatorioCardDinamico(Map<String, dynamic> r) {
    final color = r['color'] as Color? ?? const Color(0xFFFF9800);
    final icon = r['icon'] as IconData? ?? Icons.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['titulo'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: _textoPrincipal, fontSize: 14)),
                const SizedBox(height: 4),
                Text(r['descripcion'] ?? '', style: TextStyle(color: _textoSecundario, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: color),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: _cardBorder,
        boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _textoPrincipal)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: _textoSecundario, fontSize: 13)),
        ],
      ),
    );
  }

  // ================================================================
  // WIDGETS AUXILIARES COMPARTIDOS
  // ================================================================
  Widget _card({required Widget child, EdgeInsets? margin}) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: _cardColor, borderRadius: BorderRadius.circular(20), border: _cardBorder,
      boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
  );

  Widget _buildInputField({required TextEditingController controller, required String label, required String hint, int maxLines = 1, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: _textoPrincipal, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(color: _textoPrincipal, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _textoSecundario, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: _inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF05006B), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoriaDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF05006B), fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(child: Text(value, style: TextStyle(color: _textoPrincipal, fontSize: 13))),
      ],
    );
  }

  Widget _buildErrorCard(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE53935))),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE53935)),
          const SizedBox(width: 12),
          Expanded(child: Text(mensaje, style: const TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
  }

  // ================================================================
  // UTILIDADES DE FORMATO
  // ================================================================
  String _formatearHora(DateTime fechaHora) {
    try {
      return DateFormat('hh:mm a', 'es').format(fechaHora);
    } catch (_) { return fechaHora.toString(); }
  }

  String _formatearFecha(DateTime fecha) {
    try {
      return DateFormat('dd/MM/yyyy', 'es').format(fecha);
    } catch (_) { return fecha.toString(); }
  }

  String _formatearFechaHora(DateTime fecha) {
    try {
      return DateFormat('dd/MM/yyyy hh:mm a', 'es').format(fecha);
    } catch (_) { return fecha.toString(); }
  }

  @override
  void dispose() {
    _sintomasCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _tratamientoCtrl.dispose();
    _notasPrivadasCtrl.dispose();
    _chatCtrl.dispose();
    _comentarioCtrl.dispose();
    super.dispose();
  }
}
