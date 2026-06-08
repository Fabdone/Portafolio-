import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cdo_clinic/services/clinic_api_service.dart';
import 'package:cdo_clinic/models/clinic_models.dart';

class FormValidators {
  static String? motivo(String? v) {
    if (v == null || v.trim().isEmpty) return 'El motivo es obligatorio';
    if (v.trim().length < 10) return 'Minimo 10 caracteres. Describe mejor tu situacion.';
    return null;
  }
  static String? direccion(String? v) {
    if (v == null || v.trim().isEmpty) return 'La direccion es obligatoria';
    if (v.trim().length < 5) return 'Direccion demasiado corta';
    return null;
  }
  static String? cedula(String? v, bool requerida) {
    if (!requerida) return null;
    if (v == null || v.trim().isEmpty) return 'La cedula es obligatoria';
    if (!RegExp(r'^[VE]?\d{6,9}$').hasMatch(v.trim())) return 'Formato invalido (Ej: V12345678)';
    return null;
  }
  static String? genero(String? v) => v == null ? 'Selecciona tu genero' : null;
  static String? fechaNacimiento(DateTime? v) => v == null ? 'Selecciona fecha de nacimiento' : null;
  static String? medico(int? id) => id == null ? 'Selecciona el medico especialista' : null;
}

class AgendarCitaScreen extends StatefulWidget {
  final String especialidad;
  final bool isDarkMode;
  const AgendarCitaScreen({super.key, required this.especialidad, this.isDarkMode = false});

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  final _motivoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _fechaSeleccionada;
  String? _bloqueHorarioElegido;
  DateTime? _nacimiento;
  String? _genero;

  int? _idMedicoSeleccionado;
  Medico? _medicoObjetoSeleccionado;
  List<Medico> _medicosDisponibles = [];
  String? _rutaArchivoReal;
  String? _nombreArchivoVisual;

  bool _cargando = false;
  bool _cargandoMedicos = false;
  bool _cargandoDisponibilidad = false;

  // ═══════════════════════════════════════════════════════════════
  // DATOS REALES DE DISPONIBILIDAD DEL MEDICO
  // ═══════════════════════════════════════════════════════════════
  List<int> _diasDescansoMedico = [];
  List<DateTime> _vacacionesMedico = [];
  int _duracionConsultaMedico = 30;
  TimeOfDay _horaInicioMedico = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _horaFinMedico = const TimeOfDay(hour: 16, minute: 0);
  String? _mensajeVacaciones;
  bool _medicoDeVacaciones = false;

  final _generos = ['Masculino', 'Femenino', 'Otro'];

  // ═══════════════════════════════════════════════════════════════
  // COLORES ADAPTATIVOS (MISMO ESTILO QUE PACIENTE DASHBOARD)
  // ═══════════════════════════════════════════════════════════════
  bool get _isDarkMode => widget.isDarkMode;
  Color get _fondo => _isDarkMode ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FA);
  Color get _cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _texto => _isDarkMode ? Colors.white : const Color(0xFF1A1A2E);
  Color get _sub => _isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey[500]!;
  Color get _inputFill => _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FC);
  Color get _borderColor => _isDarkMode ? Colors.white.withOpacity(0.15) : Colors.grey.withOpacity(0.1);
  Color get _hintColor => _isDarkMode ? Colors.white.withOpacity(0.4) : Colors.grey[400]!;
  Color get _accentColor => _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B);
  Color get _accentBg => _isDarkMode ? const Color(0xFFFFE600).withOpacity(0.1) : const Color(0xFF05006B).withOpacity(0.05);
  Color get _alertaVacacionesBg => _isDarkMode ? const Color(0xFFFF6B6B).withOpacity(0.15) : const Color(0xFFFFEBEE);
  Color get _alertaVacacionesBorder => const Color(0xFFE53935);
  Color get _alertaVacacionesText => const Color(0xFFE53935);

  bool get _esPediatria {
    final e = widget.especialidad.toLowerCase();
    return e.contains('pediatr') || e.contains('nin') || e.contains('adolescente');
  }

  int? get _edad {
    if (_nacimiento == null) return null;
    final hoy = DateTime.now();
    int e = hoy.year - _nacimiento!.year;
    if (hoy.month < _nacimiento!.month || (hoy.month == _nacimiento!.month && hoy.day < _nacimiento!.day)) e--;
    return e;
  }

  bool get _reqCedula => !_esPediatria || (_edad != null && _edad! >= 11);
  bool get _puedeAgendar => !_esPediatria || (_edad == null || _edad! <= 18);

  String get _nacVisual => _nacimiento == null ? 'Selecciona fecha de nacimiento' : DateFormat('dd/MM/yyyy').format(_nacimiento!);

  @override
  void initState() {
    super.initState();
    _obtenerMedicosPorEspecialidad();
  }

  Future<void> _obtenerMedicosPorEspecialidad() async {
    setState(() => _cargandoMedicos = true);
    try {
      final api = ClinicApiService();
      final resultado = await api.getMedicosPorEspecialidad(widget.especialidad);
      if (resultado.success && resultado.data != null) {
        setState(() { _medicosDisponibles = resultado.data!; });
      } else {
        _error(resultado.error ?? 'No se encontraron medicos disponibles.');
      }
    } catch (e) {
      _error('Error al cargar medicos: $e');
    } finally {
      setState(() => _cargandoMedicos = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // VERIFICAR DISPONIBILIDAD REAL DEL MEDICO DESDE BACKEND
  // ═══════════════════════════════════════════════════════════════
  Future<void> _verificarDisponibilidadMedico(int idMedico) async {
    setState(() {
      _cargandoDisponibilidad = true;
      _mensajeVacaciones = null;
      _medicoDeVacaciones = false;
      _diasDescansoMedico = [];
      _vacacionesMedico = [];
    });

    try {
      final api = ClinicApiService();
      final res = await api.verificarDisponibilidadMedico(idMedico);

      if (res.success && res.data != null) {
        final data = res.data!;

        setState(() {
          _diasDescansoMedico = List<int>.from(data['dias_descanso'] ?? []);
          _vacacionesMedico = (data['vacaciones'] as List<dynamic>? ?? [])
              .map((v) => DateTime.parse(v.toString()))
              .toList();
        });

        // Verificar si el medico esta actualmente de vacaciones
        final hoy = DateTime.now();
        final enVacaciones = _vacacionesMedico.any((v) => 
          v.year == hoy.year && v.month == hoy.month && v.day == hoy.day
        );

        if (enVacaciones) {
          final fechasOrdenadas = List<DateTime>.from(_vacacionesMedico)..sort();
          DateTime? fechaReingreso;
          for (int i = 0; i < fechasOrdenadas.length - 1; i++) {
            final diff = fechasOrdenadas[i + 1].difference(fechasOrdenadas[i]).inDays;
            if (diff > 1) {
              fechaReingreso = fechasOrdenadas[i].add(const Duration(days: 1));
              break;
            }
          }
          if (fechaReingreso == null && fechasOrdenadas.isNotEmpty) {
            fechaReingreso = fechasOrdenadas.last.add(const Duration(days: 1));
          }

          setState(() {
            _medicoDeVacaciones = true;
            _mensajeVacaciones = fechaReingreso != null
                ? 'El medico se encuentra de vacaciones. Reingresa el ${DateFormat('dd/MM/yyyy').format(fechaReingreso)}.'
                : 'El medico se encuentra de vacaciones.';
          });
        }

        // Cargar configuracion completa (duracion, horarios)
        final resConfig = await api.getConfigAgenda(idMedico);
        if (resConfig.success && resConfig.data != null) {
          final config = resConfig.data!;
          setState(() {
            _duracionConsultaMedico = config['duracion_consulta'] ?? 30;
            final hi = config['hora_inicio']?.toString().split(':') ?? ['8', '0'];
            final hf = config['hora_fin']?.toString().split(':') ?? ['16', '0'];
            _horaInicioMedico = TimeOfDay(hour: int.parse(hi[0]), minute: int.parse(hi[1]));
            _horaFinMedico = TimeOfDay(hour: int.parse(hf[0]), minute: int.parse(hf[1]));
          });
        }
      }
    } catch (e) {
      // Si falla, usar valores por defecto
    } finally {
      setState(() => _cargandoDisponibilidad = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GENERAR OPCIONES DE DIAS REALES BASADOS EN DISPONIBILIDAD
  // ═══════════════════════════════════════════════════════════════
  List<String> _generarOpcionesDiasReales() {
    final List<String> opciones = [];
    final hoy = DateTime.now();

    for (int i = 1; i <= 30; i++) {
      final fecha = hoy.add(Duration(days: i));
      final diaSemana = fecha.weekday;

      if (_diasDescansoMedico.contains(diaSemana)) continue;

      final enVacaciones = _vacacionesMedico.any((v) => 
        v.year == fecha.year && v.month == fecha.month && v.day == fecha.day
      );
      if (enVacaciones) continue;

      final inicioMinutos = _horaInicioMedico.hour * 60 + _horaInicioMedico.minute;
      final finMinutos = _horaFinMedico.hour * 60 + _horaFinMedico.minute;

      for (int m = inicioMinutos; m < finMinutos; m += _duracionConsultaMedico) {
        final hora = m ~/ 60;
        final minuto = m % 60;
        final horaStr = '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
        final diaNombre = _nombreDiaSemana(diaSemana);
        final fechaStr = DateFormat('dd/MM').format(fecha);

        opciones.add('$diaNombre $fechaStr ($horaStr)');
      }
    }

    return opciones.take(10).toList();
  }

  String _nombreDiaSemana(int dia) {
    const nombres = ['', 'Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo'];
    return nombres[dia];
  }

  DateTime _parseFechaDesdeBloque(String bloque) {
    final regex = RegExp(r'\d{2}/\d{2}');
    final match = regex.firstMatch(bloque);
    if (match == null) return DateTime.now();

    final fechaStr = match.group(0)!;
    final partes = fechaStr.split('/');
    final dia = int.parse(partes[0]);
    final mes = int.parse(partes[1]);
    final anio = DateTime.now().year;

    final horaRegex = RegExp(r'\((\d{2}):(\d{2})\)');
    final horaMatch = horaRegex.firstMatch(bloque);
    int hora = 8;
    int minuto = 0;
    if (horaMatch != null) {
      hora = int.parse(horaMatch.group(1)!);
      minuto = int.parse(horaMatch.group(2)!);
    }

    return DateTime(anio, mes, dia, hora, minuto);
  }

  Future<void> _pickNacimiento() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context, initialDate: hoy.subtract(const Duration(days: 7300)),
      firstDate: DateTime(1900), lastDate: hoy,
      locale: const Locale('es', 'ES'),
      builder: (_, c) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: _isDarkMode 
            ? const ColorScheme.dark(primary: Color(0xFF05006B), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white)
            : const ColorScheme.light(primary: Color(0xFF05006B), onPrimary: Colors.white, surface: Colors.white, onSurface: Color(0xFF1A1A2E)),
        ), 
        child: c!,
      ),
    );
    if (f != null) setState(() => _nacimiento = f);
  }

  Future<void> _pickArchivo() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _rutaArchivoReal = result.files.single.path;
          _nombreArchivoVisual = result.files.single.name;
        });
      }
    } catch (e) {
      _error('Error al abrir explorador de archivos: $e');
    }
  }

  Future<void> _agendar() async {
    if (!_formKey.currentState!.validate()) return;

    final medErr = FormValidators.medico(_idMedicoSeleccionado);
    final genErr = FormValidators.genero(_genero);
    final nacErr = FormValidators.fechaNacimiento(_nacimiento);

    if (medErr != null || genErr != null || nacErr != null) {
      _error(medErr ?? genErr ?? nacErr!);
      return;
    }

    if (_bloqueHorarioElegido == null) {
      _error('Debes seleccionar un dia de consulta disponible para el medico');
      return;
    }

    final fechaCita = _parseFechaDesdeBloque(_bloqueHorarioElegido!);
    final diaSemana = fechaCita.weekday;

    if (_diasDescansoMedico.contains(diaSemana)) {
      _error('El medico no atiende este dia (dia de descanso). Selecciona otro.');
      return;
    }

    final enVacaciones = _vacacionesMedico.any((v) => 
      v.year == fechaCita.year && v.month == fechaCita.month && v.day == fechaCita.day
    );
    if (enVacaciones) {
      _error('El medico se encuentra de vacaciones en esta fecha. Selecciona otra.');
      return;
    }

    setState(() => _cargando = true);
    try {
      final api = ClinicApiService();
      final fechaFormateada = DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCita);

      final resultado = await api.crearCita(
        idPaciente: api.idUsuarioActual ?? 1,
        idMedico: _idMedicoSeleccionado!,
        fechaHora: fechaFormateada,
        motivo: _motivoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        cedula: _reqCedula ? _cedulaCtrl.text.trim() : 'Menor de Edad',
        genero: _genero!,
        fechaNacimiento: DateFormat('yyyy-MM-dd').format(_nacimiento!),
        rutaAdjunto: _rutaArchivoReal,
        especialidad: widget.especialidad,
      );

      if (resultado.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita agendada exitosamente!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        _error(resultado.error ?? 'Error al procesar la cita.');
      }
    } catch (e) {
      _error('Error al conectar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _error(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: const Color(0xFFE53935)));
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD PRINCIPAL - ESTILO DASHBOARD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar izquierdo estilo dashboard
              _sidebar(),
              // Contenido principal
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        const SizedBox(height: 40),
                        _cardMedico(),
                        const SizedBox(height: 24),
                        _cardDatosPersonales(),
                        const SizedBox(height: 24),
                        _cardMotivo(),
                        const SizedBox(height: 24),
                        _cardAdjunto(),
                        const SizedBox(height: 32),
                        _botonAgendar(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_cargando) 
            Container(
              color: _isDarkMode ? Colors.black54 : Colors.black12, 
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF05006B))),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SIDEBAR - ESTILO DASHBOARD
  // ═══════════════════════════════════════════════════════════════
  Widget _sidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF05006B),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _logoSidebar(),
          const SizedBox(height: 50),
          _navItem(Icons.arrow_back_rounded, 'Volver al Dashboard', () => Navigator.pop(context)),
          const Spacer(),
          _infoSidebar(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _logoSidebar() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 32),
      ),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CDO', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          Text('Centro Diagnostico', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1)),
        ],
      ),
    ],
  );

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFFFE600), size: 22),
              const SizedBox(width: 16),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(color: Color(0xFFFFE600), shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSidebar() => Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: Colors.white.withOpacity(0.7), size: 18),
            const SizedBox(width: 8),
            Text('Agendando Cita', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.especialidad,
          style: const TextStyle(color: Color(0xFFFFE600), fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _header() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nueva Cita Medica',
            style: TextStyle(
              color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.especialidad,
            style: TextStyle(color: _texto, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ],
      ),
      _chip(
        icon: Icons.medical_services_rounded,
        label: 'Especialidad Activa',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════
  // CARD: SELECCION DE MEDICO Y DISPONIBILIDAD
  // ═══════════════════════════════════════════════════════════════
  Widget _cardMedico() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Medico Especialista'),
        const SizedBox(height: 20),
        _cargandoMedicos 
          ? const LinearProgressIndicator(color: Color(0xFF05006B))
          : Container(
              decoration: BoxDecoration(
                color: _inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderColor),
              ),
              child: DropdownButtonFormField<int>(
                value: _idMedicoSeleccionado,
                dropdownColor: _cardColor,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.person_rounded, color: _accentColor),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                hint: Text('Selecciona el Doctor de tu preferencia', style: TextStyle(color: _hintColor)),
                style: TextStyle(color: _texto, fontSize: 15, fontWeight: FontWeight.w600),
                items: _medicosDisponibles.map((m) => DropdownMenuItem(
                  value: m.idMedico, 
                  child: Text('Dr(a). ${m.nombre} (${m.consultorio})', style: TextStyle(color: _texto, fontWeight: FontWeight.w600))
                )).toList(),
                onChanged: (v) async {
                  setState(() {
                    _idMedicoSeleccionado = v;
                    _medicoObjetoSeleccionado = _medicosDisponibles.firstWhere((element) => element.idMedico == v);
                    _bloqueHorarioElegido = null;
                  });
                  if (v != null) {
                    await _verificarDisponibilidadMedico(v);
                  }
                },
              ),
            ),

        // ALERTA DE VACACIONES
        if (_mensajeVacaciones != null) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _alertaVacacionesBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _alertaVacacionesBorder, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.beach_access, color: _alertaVacacionesText),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medico de Vacaciones', style: TextStyle(fontWeight: FontWeight.bold, color: _alertaVacacionesText)),
                      const SizedBox(height: 4),
                      Text(_mensajeVacaciones!, style: TextStyle(color: _alertaVacacionesText, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Info disponibilidad real
        if (_medicoObjetoSeleccionado != null && !_medicoDeVacaciones) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: _accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horario de la Dra/Dr. ${_medicoObjetoSeleccionado!.nombre}:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_horaInicioMedico.format(context)} - ${_horaFinMedico.format(context)} | Duracion: ${_duracionConsultaMedico} min',
                        style: TextStyle(color: _accentColor, fontSize: 13),
                      ),
                      if (_diasDescansoMedico.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Dias de descanso: ${_diasDescansoMedico.map((d) => _nombreDiaSemana(d)).join(', ')}',
                          style: TextStyle(color: _accentColor, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dias disponibles reales
          _cargandoDisponibilidad
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF05006B)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dias Disponibles para Consulta', style: TextStyle(fontWeight: FontWeight.w600, color: _texto, fontSize: 16)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: _generarOpcionesDiasReales().map((dia) {
                      final sel = _bloqueHorarioElegido == dia;
                      return ChoiceChip(
                        label: Text(
                          dia,
                          style: TextStyle(
                            color: sel ? Colors.white : _texto,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        selected: sel,
                        selectedColor: const Color(0xFF05006B),
                        backgroundColor: _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.white,
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: sel ? const Color(0xFF05006B) : _borderColor,
                        ),
                        onSelected: (selected) {
                          setState(() { _bloqueHorarioElegido = selected ? dia : null; });
                        },
                      );
                    }).toList(),
                  ),
                  if (_generarOpcionesDiasReales().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'No hay dias disponibles en los proximos 30 dias. El medico puede estar de vacaciones o tener descansos programados.',
                        style: TextStyle(color: _sub, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
        ],
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // CARD: DATOS PERSONALES
  // ═══════════════════════════════════════════════════════════════
  Widget _cardDatosPersonales() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Datos Personales'),
        const SizedBox(height: 24),

        // Fecha de nacimiento y Genero
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fecha de Nacimiento', style: TextStyle(fontWeight: FontWeight.w600, color: _texto)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickNacimiento,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: _inputFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake_rounded, color: _accentColor, size: 20),
                          const SizedBox(width: 12),
                          Text(_nacVisual, style: TextStyle(color: _texto, fontSize: 15, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Icon(Icons.calendar_today_rounded, color: _sub, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Genero', style: TextStyle(fontWeight: FontWeight.w600, color: _texto)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _borderColor),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _genero,
                      dropdownColor: _cardColor,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      style: TextStyle(color: _texto, fontSize: 15, fontWeight: FontWeight.w600),
                      hint: Text('Selecciona', style: TextStyle(color: _hintColor)),
                      items: _generos.map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g, style: TextStyle(color: _texto, fontWeight: FontWeight.w600)),
                      )).toList(),
                      onChanged: (v) => setState(() => _genero = v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Info pediatria
        if (_esPediatria && _edad != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF05006B).withOpacity(0.15) : const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF05006B).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  _edad! < 11 ? Icons.child_care_rounded : Icons.person_rounded,
                  color: const Color(0xFF05006B),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _edad! < 11
                      ? 'Paciente pediatrico: $_edad anos. No se requiere cedula.'
                      : 'Paciente: $_edad anos. Se requiere cedula de identidad.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isDarkMode ? Colors.white.withOpacity(0.85) : const Color(0xFF4A5568),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Cedula condicional
        if (_reqCedula) ...[
          const SizedBox(height: 24),
          _inputField(
            ctrl: _cedulaCtrl,
            label: 'Cedula de Identidad',
            hint: 'Ej: V12345678',
            val: (v) => FormValidators.cedula(v, _reqCedula),
            icon: Icons.badge_rounded,
          ),
        ],
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // CARD: MOTIVO Y DIRECCION
  // ═══════════════════════════════════════════════════════════════
  Widget _cardMotivo() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Detalles de la Consulta'),
        const SizedBox(height: 24),
        _inputField(
          ctrl: _motivoCtrl,
          label: 'Motivo de la Cita / Sintomas',
          hint: 'Describe brevemente tus sintomas o el motivo de tu consulta...',
          maxLines: 3,
          val: FormValidators.motivo,
          icon: Icons.healing_rounded,
        ),
        const SizedBox(height: 20),
        _inputField(
          ctrl: _direccionCtrl,
          label: 'Direccion de Habitacion',
          hint: 'Escribe tu direccion actual completa...',
          val: FormValidators.direccion,
          icon: Icons.home_rounded,
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // CARD: ADJUNTO
  // ═══════════════════════════════════════════════════════════════
  Widget _cardAdjunto() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Estudios Previos (Opcional)'),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickArchivo,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: _inputFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _nombreArchivoVisual != null ? Icons.insert_drive_file_rounded : Icons.cloud_upload_rounded,
                    color: _accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombreArchivoVisual ?? 'Subir archivo adjunto',
                        style: TextStyle(
                          color: _nombreArchivoVisual != null ? _texto : _hintColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _nombreArchivoVisual != null ? 'Toca para cambiar el archivo' : 'PDF, JPG o PNG - Max 10MB',
                        style: TextStyle(color: _sub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: _sub),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // BOTON AGENDAR
  // ═══════════════════════════════════════════════════════════════
  Widget _botonAgendar() => SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: (_cargando || !_puedeAgendar || _medicoDeVacaciones) ? null : _agendar,
      style: ElevatedButton.styleFrom(
        backgroundColor: _medicoDeVacaciones ? Colors.grey : const Color(0xFF05006B),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: const Color(0xFF05006B).withOpacity(0.3),
      ),
      child: _cargando
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _medicoDeVacaciones ? Icons.beach_access : 
                (_puedeAgendar ? Icons.check_circle_outline : Icons.block),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                _medicoDeVacaciones ? 'Medico de Vacaciones' :
                (_puedeAgendar ? 'Confirmar y Agendar Cita' : 'No disponible para tu edad'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
            ],
          ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // WIDGETS REUTILIZABLES - ESTILO DASHBOARD
  // ═══════════════════════════════════════════════════════════════
  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(20),
      border: _isDarkMode
          ? Border.all(color: Colors.white.withOpacity(0.15), width: 1.5)
          : Border.all(color: Colors.grey.withOpacity(0.1)),
      boxShadow: [
        BoxShadow(
          color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: child,
      ),
    ),
  );

  Widget _tituloSeccion(String t) => Row(
    children: [
      Container(
        width: 4,
        height: 24,
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 12),
      Text(t, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _texto)),
    ],
  );

  Widget _chip({required IconData icon, required String label}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      color: _isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFF05006B).withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _isDarkMode ? Colors.white.withOpacity(0.2) : const Color(0xFF05006B).withOpacity(0.1),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : const Color(0xFF05006B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _inputField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? val,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: _texto, fontSize: 15)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          validator: val,
          style: TextStyle(color: _texto, fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, color: _accentColor) : null,
            hintText: hint,
            hintStyle: TextStyle(color: _hintColor, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: _inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _accentColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _direccionCtrl.dispose();
    _cedulaCtrl.dispose();
    super.dispose();
  }
}
