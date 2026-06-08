import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cdo_clinic/features/paciente/agendar_cita_screen.dart';
import 'package:cdo_clinic/services/clinic_api_service.dart';
import 'package:cdo_clinic/models/clinic_models.dart';

// ═══════════════════════════════════════════════════════════════
// DASHBOARD PACIENTE CDO - CORREGIDO Y ACTUALIZADO
// ═══════════════════════════════════════════════════════════════

class PacienteDashboard extends StatefulWidget {
  final String nombrePaciente;
  final String? correoPaciente;
  final String? telefonoPaciente;

  const PacienteDashboard({
    super.key,
    required this.nombrePaciente,
    this.correoPaciente,
    this.telefonoPaciente,
  });

  @override
  State<PacienteDashboard> createState() => _PacienteDashboardState();
}

class _PacienteDashboardState extends State<PacienteDashboard> {
  int _selectedIndex = 0;
  bool _isDarkMode = false;
  bool _cargando = false;
  Color _avatarColor = const Color(0xFF90CAF9);
  String? _avatarUrl;
  int _calificacionEstrellas = 5;
  final Map<int, bool> _historialExpandido = {};

  List<Cita> _listaCitas = [];
  List<Mensaje> _listaMensajes = [];
  List<HistoriaClinica> _listaHistorias = [];
  List<Medico> _medicosInfo = [];
  int? _idMedicoChatActual;

  String get _avatarInicial {
    final parts = widget.nombrePaciente.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  String get _fechaActual =>
      DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now());

  final _especialidades = [
    ('Odontologia', Icons.medical_services_rounded, Colors.blue),
    ('Oftalmologia', Icons.visibility_rounded, Colors.purple),
    ('Otorrinolaringologia', Icons.hearing_rounded, Colors.orange),
    ('Medicina General', Icons.health_and_safety_rounded, Colors.green),
    ('Pediatria', Icons.child_care_rounded, Colors.brown),
    ('Atencion a la Mujer', Icons.female_rounded, Colors.pink),
    ('Atencion de Ninos/as', Icons.family_restroom_rounded, Colors.indigo),
    ('Medicina del Adolescente', Icons.face_rounded, Colors.lightGreen),
    ('Laboratorio Clinico', Icons.science_rounded, Colors.amber),
    ('Cardiologia', Icons.favorite_rounded, Colors.deepOrange),
    ('Ginecobstetricia', Icons.pregnant_woman_rounded, Colors.purpleAccent),
    ('Traumatologia', Icons.accessible_rounded, Colors.blueGrey),
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final api = ClinicApiService();
    final idPaciente = api.idUsuarioActual ?? 1;

    try {
      final resCitas = await api.getCitas(idPaciente);
      if (resCitas.success && mounted) setState(() => _listaCitas = resCitas.data ?? []);

      final resMsgs = await api.getMensajes(idPaciente);
      if (resMsgs.success && mounted) setState(() => _listaMensajes = resMsgs.data ?? []);

      final resHist = await api.getHistorias(idPaciente);
      if (resHist.success && mounted) setState(() => _listaHistorias = resHist.data ?? []);

      final resMedicos = await api.getMedicos();
      if (resMedicos.success && mounted) setState(() => _medicosInfo = resMedicos.data ?? []);
    } catch (e) {
      if (mounted) _showSnack('Error cargando datos: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _nav(int i) => setState(() => _selectedIndex = i);

  // ═══════════════════════════════════════════════════════════════
  // HELPERS DE MÉDICO
  // ═══════════════════════════════════════════════════════════════
  Medico? _getMedicoInfo(int idMedico) {
    try {
      return _medicosInfo.firstWhere((m) => m.idMedico == idMedico);
    } catch (_) {
      return null;
    }
  }

  String _getInicialesMedico(int idMedico) {
    final medico = _getMedicoInfo(idMedico);
    if (medico == null) return 'DR';
    final n = (medico.nombre ?? 'D').trim();
    final a = (medico.apellido ?? 'R').trim();
    if (n.isNotEmpty && a.isNotEmpty) return '${n[0]}${a[0]}'.toUpperCase();
    return n.isNotEmpty ? n[0].toUpperCase() : 'DR';
  }

  // ═══════════════════════════════════════════════════════════════
  // COLORES ADAPTATIVOS
  // ═══════════════════════════════════════════════════════════════
  Color get _fondo => _isDarkMode ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FA);
  Color get _cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _texto => _isDarkMode ? Colors.white : const Color(0xFF1A1A2E);
  Color get _sub => _isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey[500]!;
  Color get _bienvenidoColor => _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B);
  Border? get _cardBorder => _isDarkMode
      ? Border.all(color: Colors.white.withOpacity(0.15), width: 1.5)
      : Border.all(color: Colors.grey.withOpacity(0.1));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _fondo,
        body: Row(children: [
          _sidebar(),
          Expanded(child: [_home(), _buildCitas(), _chat(), _historial(), _perfil()][_selectedIndex]),
        ]),
      );

  // ═══════════════════════════════════════════════════════════════
  // SIDEBAR
  // ═══════════════════════════════════════════════════════════════
  Widget _sidebar() {
    final items = [
      (Icons.home_rounded, 'Inicio', 0),
      (Icons.calendar_month_rounded, 'Citas', 1),
      (Icons.chat_bubble_rounded, 'Mensajes', 2),
      (Icons.medical_information_rounded, 'Historial', 3),
      (Icons.person_rounded, 'Perfil', 4),
    ];

    return Container(
      width: 260,
      color: const Color(0xFF05006B),
      child: Column(children: [
        const SizedBox(height: 40),
        _logoSidebar(),
        const SizedBox(height: 50),
        ...items.map((i) => _navItem(i)),
        const Spacer(),
        _userCardSidebar(),
        const SizedBox(height: 20),
      ]),
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
        onTap: () => _nav(item.$3),
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
      _avatarWidget(url: _avatarUrl, iniciales: _avatarInicial, color: _avatarColor, r: 24),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.nombrePaciente, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('Paciente Activo', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
      ])),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════
  // HOME / INICIO
  // ═══════════════════════════════════════════════════════════════
  Widget _home() => SingleChildScrollView(
    padding: const EdgeInsets.all(40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _headerHome(),
      const SizedBox(height: 40),
      _tituloSeccion('Especialidades Medicas'),
      const SizedBox(height: 24),
      _gridEspecialidades(),
      const SizedBox(height: 50),
      _resena(),
      const SizedBox(height: 40),
      _footer(),
    ]),
  );

  Widget _headerHome() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bienvenido a CDO!', style: TextStyle(color: _bienvenidoColor, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Text(widget.nombrePaciente, style: TextStyle(color: _texto, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
    ]),
    _chip(icon: Icons.calendar_today_rounded, label: _fechaActual),
  ]);

  // ═══════════════════════════════════════════════════════════════
  // GRID ESPECIALIDADES
  // ═══════════════════════════════════════════════════════════════
  Widget _gridEspecialidades() => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 2.8),
    itemCount: _especialidades.length,
    itemBuilder: (_, i) {
      final e = _especialidades[i];
      return _card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _verificarYEspecialidad(e),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: e.$3.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
                  border: _isDarkMode ? Border.all(color: e.$3.withOpacity(0.4), width: 1) : null),
                child: Icon(e.$2, color: e.$3, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(e.$1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _texto))),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey[400]),
            ]),
          ),
        ),
      );
    },
  );

  Future<void> _verificarYEspecialidad((String, IconData, Color) e) async {
    setState(() => _cargando = true);
    try {
      final api = ClinicApiService();
      final medicosRes = await api.getMedicosPorEspecialidad(e.$1);

      if (medicosRes.success && medicosRes.data != null && medicosRes.data!.isNotEmpty) {
        bool hayDisponible = false;
        String? mensajeVacaciones;
        DateTime? fechaReingreso;

        for (final medico in medicosRes.data!) {
          final dispRes = await api.verificarDisponibilidadMedico(medico.idMedico);
          if (dispRes.success && dispRes.data != null) {
            final vacaciones = dispRes.data!['vacaciones'] as List<dynamic>? ?? [];
            if (vacaciones.isEmpty) {
              hayDisponible = true;
              break;
            } else {
              final fechasVac = vacaciones.map((v) => DateTime.parse(v.toString())).toList()..sort();
              if (fechasVac.isNotEmpty) {
                fechaReingreso = fechasVac.last.add(const Duration(days: 1));
              }
            }
          }
        }

        if (!hayDisponible && mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFF9800).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.beach_access, color: Color(0xFFFF9800)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Médicos de Vacaciones', style: TextStyle(color: _texto, fontWeight: FontWeight.bold, fontSize: 18))),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Todos los médicos de ${e.$1} se encuentran de vacaciones actualmente.',
                    style: TextStyle(color: _sub, height: 1.6, fontSize: 14),
                  ),
                  if (fechaReingreso != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF05006B).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF05006B).withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today, color: const Color(0xFF05006B), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fecha de reingreso: ${DateFormat('dd/MM/yyyy').format(fechaReingreso)}',
                            style: TextStyle(color: const Color(0xFF05006B), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Por favor, intenta agendar en otra especialidad o contacta a recepción para más información.',
                    style: TextStyle(color: _sub, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Entendido', style: TextStyle(color: const Color(0xFF05006B), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
          return;
        }
      }

      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => AgendarCitaScreen(especialidad: e.$1, isDarkMode: _isDarkMode)
      ));
      _cargarDatos();
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CITAS - CON SEMÁFORO, BLOQUEO DE BOTONES Y AUDITORÍA
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCitas() {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: Color(0xFF05006B)));

    final citasVigentes = _listaCitas;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mis Citas Programadas', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _texto)),
        const SizedBox(height: 8),
        Text('Gestiona tus citas medicas', style: TextStyle(fontSize: 15, color: _sub)),
        const SizedBox(height: 32),
        if (citasVigentes.isEmpty)
          _card(child: _emptyState('No tienes citas programadas', 'Agenda tu primera cita desde el inicio', Icons.calendar_today_rounded))
        else
          ...citasVigentes.map((c) => _cardCita(c)),
      ]),
    );
  }

  Widget _cardCita(Cita c) {
    final estadoColor = c.colorEstado;
    final puedeModificar = c.puedeModificarse;
    final estaCompletada = c.estado.toLowerCase() == 'completada';
    final estaCancelada = c.estado.toLowerCase() == 'cancelada';

    return _card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: estadoColor, width: 4),
            ),
            gradient: const LinearGradient(colors: [Color(0xFF05006B), Color(0xFF0A0E8A)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: estadoColor.withOpacity(0.5)),
                ),
                child: Row(children: [
                  Icon(
                    c.estado.toLowerCase() == 'pendiente' ? Icons.pending_rounded
                    : c.estado.toLowerCase() == 'en progreso' ? Icons.play_circle_rounded
                    : c.estado.toLowerCase() == 'completada' ? Icons.check_circle_rounded
                    : c.estado.toLowerCase() == 'cancelada' ? Icons.cancel_rounded
                    : Icons.update_rounded,
                    size: 14, color: estadoColor,
                  ),
                  const SizedBox(width: 6),
                  Text(c.estadoLegible, style: TextStyle(color: estadoColor, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 12),
              Text('#CDO-${c.idCita}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontFamily: 'monospace')),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(28),
          child: Row(children: [
            Expanded(child: _datoCita(Icons.calendar_today_rounded, 'Fecha', '${c.fechaHora.day} ${_mes(c.fechaHora.month)} ${c.fechaHora.year}')),
            _div(),
            Expanded(child: _datoCita(Icons.access_time_rounded, 'Hora', '${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}')),
            _div(),
            Expanded(child: _datoCita(Icons.local_hospital_rounded, 'Especialidad', c.motivo)),
          ]),
        ),
        if (c.horaInicio != null || c.horaFin != null || c.mensajeAuditoria != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.horaInicio != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.play_circle_outline, size: 14, color: const Color(0xFF4CAF50)),
                      const SizedBox(width: 6),
                      Text('Iniciada: ${_formatearFechaHora(c.horaInicio!)}', style: TextStyle(fontSize: 12, color: const Color(0xFF4CAF50))),
                    ]),
                  ),
                if (c.horaFin != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline, size: 14, color: const Color(0xFF2E7D32)),
                      const SizedBox(width: 6),
                      Text('Finalizada: ${_formatearFechaHora(c.horaFin!)}', style: TextStyle(fontSize: 12, color: const Color(0xFF2E7D32))),
                    ]),
                  ),
                if (c.mensajeAuditoria != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Icon(Icons.history, size: 14, color: _sub),
                      const SizedBox(width: 6),
                      Text(c.mensajeAuditoria!, style: TextStyle(fontSize: 12, color: _sub, fontStyle: FontStyle.italic)),
                    ]),
                  ),
              ],
            ),
          ),
        if (puedeModificar)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(children: [
              Expanded(child: _btnAccion(Icons.edit_calendar_rounded, 'Reagendar', () => _accionCita('reagendar', c))),
              const SizedBox(width: 12),
              Expanded(child: _btnAccion(Icons.cancel_rounded, 'Cancelar', () => _accionCita('cancelar', c), color: const Color(0xFFE53935))),
            ]),
          ),
        if (!puedeModificar)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: estaCancelada ? Colors.red.withOpacity(0.05) : Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: estaCancelada ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  estaCancelada ? Icons.cancel_outlined : Icons.check_circle_outline,
                  size: 16,
                  color: estaCancelada ? Colors.red : const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                Text(
                  estaCancelada ? 'Cita cancelada - No se puede modificar' : 'Cita completada - No se puede modificar',
                  style: TextStyle(fontSize: 13, color: _sub, fontStyle: FontStyle.italic),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Future<void> _accionCita(String accion, Cita c) async {
    final api = ClinicApiService();
    try {
      if (accion == 'cancelar') {
        if (!c.puedeModificarse) {
          _showSnack('Esta cita ya no puede cancelarse', Colors.orange);
          return;
        }

        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Cancelar Cita', style: TextStyle(color: _texto, fontWeight: FontWeight.bold)),
            content: Text('¿Estás seguro de cancelar la cita #CDO-${c.idCita}?', style: TextStyle(color: _sub)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No', style: TextStyle(color: const Color(0xFF05006B)))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Sí, cancelar'),
              ),
            ],
          ),
        );
        if (confirmar != true) return;

        setState(() => _cargando = true);
        final res = await api.cancelarCita(c.idCita, 'Paciente');
        if (res.success) {
          _showSnack('Cita cancelada exitosamente', Colors.green);
          await _cargarDatos();
        } else {
          _showSnack(res.error ?? 'Error al cancelar', Colors.red);
        }
      } else if (accion == 'reagendar') {
        if (!c.puedeModificarse) {
          _showSnack('Esta cita ya no puede reagendarse', Colors.orange);
          return;
        }

        final DateTime? fechaElegida = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 60)),
          locale: const Locale('es', 'ES'),
        );
        if (fechaElegida != null) {
          final nuevaFecha = DateTime(fechaElegida.year, fechaElegida.month, fechaElegida.day, c.fechaHora.hour, c.fechaHora.minute);
          setState(() => _cargando = true);
          final res = await api.reagendarCita(c.idCita, nuevaFecha, 'Paciente');
          if (res.success) {
            _showSnack('Cita reagendada exitosamente', Colors.green);
            await _cargarDatos();
          } else {
            _showSnack(res.error ?? 'Error al reagendar', Colors.red);
          }
        }
      }
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CHAT / MENSAJES - CON FOTO REAL DEL MÉDICO
  // ═══════════════════════════════════════════════════════════════
  Widget _chat() {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: Color(0xFF05006B)));

    final medicosUnicos = <int>{};
    for (final m in _listaMensajes) { medicosUnicos.add(m.idMedico); }
    for (final c in _listaCitas) { medicosUnicos.add(c.idMedico); }
    final listaMedicosIds = medicosUnicos.toList();

    final ctrl = TextEditingController();
    final focus = FocusNode();
    String? rutaArchivo;
    String? nombreArchivoMostrado;

    return StatefulBuilder(
      builder: (context, setSt) => Row(children: [
        _chatSidebar(listaMedicosIds),
        Expanded(
          child: Container(
            color: _isDarkMode ? const Color(0xFF0A0A0F) : const Color(0xFFF8F9FC),
            child: _idMedicoChatActual == null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 64, color: _sub),
                    const SizedBox(height: 16),
                    Text(
                      listaMedicosIds.isEmpty
                          ? 'No tienes conversaciones'
                          : 'Selecciona un médico para ver el chat',
                      style: TextStyle(color: _sub, fontSize: 16),
                    ),
                  ]))
                : Column(children: [
                    _chatHeader(),
                    const Divider(height: 1),
                    Expanded(
                      child: _listaMensajes.isEmpty
                          ? Center(child: Text('No hay mensajes aún', style: TextStyle(color: _sub)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: _listaMensajes.where((m) => m.idMedico == _idMedicoChatActual).length,
                              itemBuilder: (_, i) {
                                final msgsFiltrados = _listaMensajes.where((m) => m.idMedico == _idMedicoChatActual).toList();
                                return _burbuja(msgsFiltrados[i]);
                              },
                            ),
                    ),
                    if (nombreArchivoMostrado != null) ...[
                      _adjuntoPreview(nombreArchivoMostrado!, () => setSt(() { rutaArchivo = null; nombreArchivoMostrado = null; })),
                    ],
                    _chatInput(ctrl, focus, rutaArchivo, nombreArchivoMostrado, setSt),
                  ]),
          ),
        ),
      ]),
    );
  }

  Widget _chatSidebar(List<int> listaMedicosIds) => Container(
    width: 320,
    decoration: BoxDecoration(
      color: _cardColor,
      border: _isDarkMode ? Border(right: BorderSide(color: Colors.white.withOpacity(0.1))) : null,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Conversaciones', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _texto)),
      ),
      Expanded(
        child: listaMedicosIds.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: _sub),
                const SizedBox(height: 12),
                Text('No hay conversaciones', style: TextStyle(color: _sub)),
              ]))
            : ListView.builder(
                itemCount: listaMedicosIds.length,
                itemBuilder: (_, i) {
                  final idMedico = listaMedicosIds[i];
                  final medico = _getMedicoInfo(idMedico);
                  final estaSeleccionado = _idMedicoChatActual == idMedico;

                  return ListTile(
                    leading: _avatarWidget(
                      url: medico?.fotoUrl,
                      iniciales: _getInicialesMedico(idMedico),
                      color: const Color(0xFF05006B),
                      r: 24,
                    ),
                    title: Text(
                      medico != null
                          ? 'Dr. ${medico.nombre ?? ''} ${medico.apellido ?? ''}'
                          : 'Dr. #$idMedico',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _texto),
                    ),
                    subtitle: Text(
                      medico?.especialidad ?? 'Médico',
                      style: TextStyle(color: _sub, fontSize: 12),
                    ),
                    trailing: estaSeleccionado
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Color(0xFF05006B), shape: BoxShape.circle),
                          )
                        : null,
                    selected: estaSeleccionado,
                    selectedTileColor: _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFF05006B).withOpacity(0.05),
                    onTap: () => setState(() => _idMedicoChatActual = idMedico),
                  );
                },
              ),
      ),
    ]),
  );

  Widget _chatHeader() {
    final medico = _idMedicoChatActual != null ? _getMedicoInfo(_idMedicoChatActual!) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      color: _cardColor,
      child: Row(children: [
        _avatarWidget(
          url: medico?.fotoUrl,
          iniciales: _idMedicoChatActual != null ? _getInicialesMedico(_idMedicoChatActual!) : 'CDO',
          color: const Color(0xFF05006B),
          r: 22,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            medico != null
                ? 'Dr. ${medico.nombre ?? ''} ${medico.apellido ?? ''}'
                : 'Centro Diagnostico Occidente',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: _texto),
          ),
          Text(
            medico?.especialidad ?? 'Soporte Médico Operativo',
            style: TextStyle(fontSize: 13, color: _sub),
          ),
        ])),
        if (medico != null)
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
          ),
      ]),
    );
  }

  Widget _adjuntoPreview(String nombre, VoidCallback onRemove) => Container(
    color: Colors.green.withOpacity(0.1),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    child: Row(children: [
      const Icon(Icons.insert_drive_file, color: Colors.green, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text('Adjunto: $nombre', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500))),
      IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 18), onPressed: onRemove),
    ]),
  );

  Widget _chatInput(TextEditingController ctrl, FocusNode focus, String? rutaArchivo, String? nombreArchivoMostrado, StateSetter setSt) => Container(
    padding: const EdgeInsets.all(20), color: _cardColor,
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.attach_file_rounded, color: rutaArchivo != null ? const Color(0xFF4CAF50) : (_isDarkMode ? Colors.white70 : null)),
        onPressed: () async {
          try {
            FilePickerResult? result = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
            );
            if (result != null && result.files.single.path != null) {
              setSt(() {
                rutaArchivo = result.files.single.path;
                nombreArchivoMostrado = result.files.single.name;
              });
              _showSnack('Archivo adjuntado', Colors.green);
            }
          } catch (_) {
            _showSnack('Error al abrir archivos', Colors.orange);
          }
        },
      ),
      Expanded(
        child: TextField(
          controller: ctrl, focusNode: focus,
          decoration: InputDecoration(
            hintText: 'Escribir mensaje...',
            hintStyle: TextStyle(color: _isDarkMode ? Colors.white.withOpacity(0.4) : Colors.grey[400]),
            filled: true, fillColor: _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          style: TextStyle(color: _texto),
          onChanged: (_) => setSt(() {}),
        ),
      ),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: (ctrl.text.trim().isNotEmpty || rutaArchivo != null) && _idMedicoChatActual != null
            ? () async {
                final api = ClinicApiService();
                try {
                  final res = await api.enviarMensaje(
                    idPaciente: api.idUsuarioActual ?? 1,
                    idMedico: _idMedicoChatActual!,
                    remitente: 'paciente',
                    contenido: ctrl.text.trim(),
                    rutaArchivo: rutaArchivo,
                  );
                  if (res.success) {
                    ctrl.clear(); focus.unfocus();
                    setSt(() { rutaArchivo = null; nombreArchivoMostrado = null; });
                    await _cargarDatos();
                  } else {
                    _showSnack(res.error ?? 'Error al enviar', Colors.red);
                  }
                } catch (e) {
                  _showSnack('Fallo de red: $e', Colors.red);
                }
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (ctrl.text.trim().isNotEmpty || rutaArchivo != null) && _idMedicoChatActual != null
                ? const Color(0xFF05006B)
                : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );

  Widget _burbuja(Mensaje msg) {
    final remitente = msg.remitente.toLowerCase();
    final esPaciente = remitente == 'paciente';
    final medico = _getMedicoInfo(msg.idMedico);

    return Align(
      alignment: esPaciente ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: esPaciente ? const Color(0xFF05006B) : _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: !esPaciente && _isDarkMode ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
          boxShadow: !esPaciente ? [const BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2))] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!esPaciente && medico != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Dr. ${medico.nombre ?? ''} ${medico.apellido ?? ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF05006B),
                ),
              ),
            ),
          Text(msg.contenidoTexto, style: TextStyle(color: esPaciente ? Colors.white : _texto, fontSize: 15, height: 1.5)),
          if (msg.resultadoAdjuntoUrl != null && msg.resultadoAdjuntoUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showSnack('Descargando receta...', Colors.blue),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: esPaciente ? Colors.white.withOpacity(0.15) : const Color(0xFF05006B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: esPaciente ? Colors.white.withOpacity(0.3) : const Color(0xFF05006B).withOpacity(0.2),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.picture_as_pdf, size: 20, color: esPaciente ? Colors.white : const Color(0xFF05006B)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receta Médica',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: esPaciente ? Colors.white : const Color(0xFF05006B),
                        ),
                      ),
                      Text(
                        'Toca para descargar',
                        style: TextStyle(
                          fontSize: 11,
                          color: esPaciente ? Colors.white.withOpacity(0.7) : _sub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.download_rounded, size: 18, color: esPaciente ? Colors.white70 : const Color(0xFF05006B).withOpacity(0.6)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _formatearFechaHora(msg.fechaEnvio),
            style: TextStyle(fontSize: 12, color: esPaciente ? Colors.white.withOpacity(0.6) : Colors.grey[500]),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HISTORIAL CLINICO
  // ═══════════════════════════════════════════════════════════════
  Widget _historial() {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: Color(0xFF05006B)));

    final citasHistorial = _listaCitas.where((c) {
      return c.estado.toLowerCase() == 'completada' || c.estado.toLowerCase() == 'cancelada';
    }).toList();

    final tieneDatos = _listaHistorias.isNotEmpty || citasHistorial.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Historial Clinico', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _texto)),
        const SizedBox(height: 8),
        Text('Registro de consultas y tratamientos', style: TextStyle(fontSize: 15, color: _sub)),
        const SizedBox(height: 32),
        if (!tieneDatos)
          _card(child: _emptyState('No hay registros', 'Tus consultas apareceran aqui', Icons.folder_open_rounded))
        else ...[
          ...citasHistorial.map((c) => _itemHistorialCita(c)),
          ..._listaHistorias.asMap().entries.map((e) => _itemHistoriaClinica(e.value, e.key)),
        ],
      ]),
    );
  }

  Widget _itemHistorialCita(Cita c) {
    final bool cancelada = c.estado.toLowerCase() == 'cancelada';
    return _card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cancelada ? Colors.red.withOpacity(0.1) : const Color(0xFF05006B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(cancelada ? Icons.cancel_rounded : Icons.check_circle_rounded,
            color: cancelada ? Colors.red : const Color(0xFF05006B), size: 22),
        ),
        title: Text('${c.motivo} - ${c.estadoLegible}', style: TextStyle(fontWeight: FontWeight.w600, color: _texto)),
        subtitle: Text('${c.fechaHora.day} ${_mes(c.fechaHora.month)} ${c.fechaHora.year} | Dr. ${c.medicoNombre ?? 'General'}',
          style: TextStyle(color: _sub, fontSize: 13)),
        trailing: IconButton(
          icon: Icon(Icons.download_rounded, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)),
          onPressed: () => _descargarHistorialCita(c),
        ),
      ),
    );
  }

  Widget _itemHistoriaClinica(HistoriaClinica h, int index) {
    final expandido = _historialExpandido[index] ?? false;
    final medicoReviso = h.diagnostico.isNotEmpty && h.diagnostico != 'Pendiente por registrar...';

    return _card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _historialExpandido[index] = !expandido),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF05006B).withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Text('${h.fechaConsulta.day} ${_mes(h.fechaConsulta.month)} ${h.fechaConsulta.year}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B))),
              ),
              Row(children: [
                if (!medicoReviso)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.hourglass_top_rounded, size: 12, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text('Pendiente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange[700])),
                    ]),
                  ),
                Icon(expandido ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 22, color: _isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey[400]),
              ]),
            ]),
            const SizedBox(height: 12),
            Text(medicoReviso ? 'Consulta atendida - toca para detalles' : 'Esperando revision medica',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _texto)),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 16),
                Divider(color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
                const SizedBox(height: 12),
                if (!medicoReviso)
                  _alertaPendiente()
                else ...[
                  _campoHistoria('Sintomas Evaluados', h.sintomas, Icons.healing_rounded),
                  const SizedBox(height: 10),
                  _campoHistoria('Diagnostico Medico', h.diagnostico, Icons.fact_check_rounded),
                  const SizedBox(height: 10),
                  _campoHistoria('Plan de Tratamiento', h.tratamiento, Icons.medication_rounded),
                ],
                if (h.recetaDigital != null && medicoReviso) ...[
                  const SizedBox(height: 12),
                  _btnDescargarReceta(h.recetaDigital!),
                ],
              ]),
              crossFadeState: expandido ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _alertaPendiente() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange.withOpacity(0.2))),
    child: Row(children: [
      Icon(Icons.info_outline_rounded, color: Colors.orange[700], size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'El medico aun no ha revisado esta consulta. Los detalles se actualizaran cuando el especialista complete su evaluacion.',
        style: TextStyle(fontSize: 13, color: Colors.orange[800], height: 1.5))),
    ]),
  );

  Widget _btnDescargarReceta(String receta) => GestureDetector(
    onTap: () => _showSnack('Descargando receta: $receta', Colors.green),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF05006B), borderRadius: BorderRadius.circular(10)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.download_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Descargar Receta Digital', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Future<void> _descargarHistorialCita(Cita c) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'historial_cdo_${c.idCita}_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');
      final contenido = '''CENTRO DIAGNOSTICO OCCIDENTE (CDO)
=====================================
ID Cita: #CDO-${c.idCita}
Paciente: ${widget.nombrePaciente}
Fecha: ${c.fechaHora.day}/${c.fechaHora.month}/${c.fechaHora.year}
Hora: ${c.fechaHora.hour.toString().padLeft(2, '0')}:${c.fechaHora.minute.toString().padLeft(2, '0')}
Especialidad: ${c.motivo}
Estado: ${c.estadoLegible}
Medico: ${c.medicoNombre ?? 'No asignado'}
=====================================
Generado el ${DateTime.now()}
''';
      await file.writeAsString(contenido);
      _showSnack('Historial descargado: $fileName', Colors.green);
    } catch (e) {
      _showSnack('Error al descargar: $e', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PERFIL
  // ═══════════════════════════════════════════════════════════════
  Widget _perfil() => SingleChildScrollView(
    padding: const EdgeInsets.all(40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mi Perfil', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _texto)),
      const SizedBox(height: 32),
      Center(child: GestureDetector(
        onTap: _pickerAvatar,
        child: Stack(children: [
          _avatarWidget(url: _avatarUrl, iniciales: _avatarInicial, color: _avatarColor, r: 60),
          Positioned(bottom: 0, right: 0, child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFFFE600), shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]),
            child: const Icon(Icons.edit, size: 18, color: Color(0xFF05006B)),
          )),
        ]),
      )),
      const SizedBox(height: 20),
      Center(child: Text(widget.nombrePaciente, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _texto))),
      Center(child: Text(widget.correoPaciente ?? 'Sin correo', style: TextStyle(fontSize: 15, color: _sub))),
      if (widget.telefonoPaciente != null) ...[
        const SizedBox(height: 8),
        Center(child: Text(widget.telefonoPaciente!, style: TextStyle(fontSize: 14, color: _sub))),
      ],
      const SizedBox(height: 40),
      _menuTile(Icons.settings_rounded, 'Configuracion', _config),
      _menuTile(Icons.support_agent_rounded, 'Ayuda y Soporte', _ayuda),
      _menuTile(Icons.logout_rounded, 'Cerrar Sesion', () {
        ClinicApiService().clearToken();
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      }, color: const Color(0xFFE53935)),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════
  // RESEÑA / CALIFICACION
  // ═══════════════════════════════════════════════════════════════
  Widget _resena() => _card(
    child: Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: _isDarkMode ? Colors.white.withOpacity(0.02) : const Color(0x0A05006B)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.rate_review_rounded, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B), size: 30),
          const SizedBox(width: 14),
          Text('Tu Opinion nos Ayuda a Crecer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _texto, letterSpacing: -0.3)),
        ]),
        const SizedBox(height: 20),
        _resenaHistorica(),
        const SizedBox(height: 24),
        Text('Como fue tu experiencia? Dejanos tu calificacion:', style: TextStyle(fontSize: 16, color: _texto, height: 1.6, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        _estrellasInteractivas(),
        const SizedBox(height: 16),
        _comentarioField(),
        const SizedBox(height: 16),
        _btnEnviarResena(),
      ]),
    ),
  );

  Widget _resenaHistorica() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _isDarkMode ? Colors.white.withOpacity(0.04) : const Color(0xFFF0F4FF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFF05006B).withOpacity(0.1))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.history_edu_rounded, size: 18, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)),
        const SizedBox(width: 8),
        Text('Resena Historica de CDO', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
          color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B))),
      ]),
      const SizedBox(height: 12),
      Text(
        'El Centro Diagnostico Occidente (CDO) fue fundado con el proposito de brindar atencion medica integral de excelencia a la comunidad de Barinas y sus alrededores. A lo largo de los anos, CDO se ha consolidado como un referente en diagnostico especializado, combinando tecnologia de vanguardia con un equipo humano altamente calificado.',
        style: TextStyle(fontSize: 14, color: _isDarkMode ? Colors.white.withOpacity(0.85) : const Color(0xFF4A5568), height: 1.7),
        textAlign: TextAlign.justify,
      ),
    ]),
  );

  Widget _estrellasInteractivas() => StatefulBuilder(
    builder: (context, setStateEstrellas) => Row(
      children: List.generate(5, (index) {
        final estrellaActual = index + 1;
        return IconButton(
          icon: Icon(estrellaActual <= _calificacionEstrellas ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFFFE600), size: 36),
          onPressed: () {
            setStateEstrellas(() => _calificacionEstrellas = estrellaActual);
            _showSnack('Calificacion: $_calificacionEstrellas estrellas', const Color(0xFF05006B));
          },
        );
      }),
    ),
  );

  final TextEditingController _comentarioCtrl = TextEditingController();

  Widget _comentarioField() => TextField(
    controller: _comentarioCtrl,
    maxLines: 3,
    decoration: InputDecoration(
      hintText: 'Escribe tu comentario (opcional)...',
      hintStyle: TextStyle(color: _isDarkMode ? Colors.white.withOpacity(0.4) : Colors.grey[400]),
      filled: true, fillColor: _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
    style: TextStyle(color: _texto),
  );

  Widget _btnEnviarResena() => ElevatedButton.icon(
    onPressed: () async {
      final api = ClinicApiService();
      final res = await api.enviarResena(
        idPaciente: api.idUsuarioActual ?? 1,
        calificacion: _calificacionEstrellas,
        comentario: _comentarioCtrl.text.trim(),
      );
      if (res.success) {
        _comentarioCtrl.clear();
        _showSnack('Resena enviada con exito!', Colors.green);
      } else {
        _showSnack(res.error ?? 'Error al enviar resena', Colors.red);
      }
    },
    icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
    label: const Text('Enviar Calificacion', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF05006B), foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2,
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // AYUDA Y SOPORTE
  // ═══════════════════════════════════════════════════════════════
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
          Expanded(child: Text('Centro de Ayuda CDO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _texto))),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Necesitas asistencia? Nuestro equipo de soporte esta disponible para ayudarte.', style: TextStyle(fontSize: 14, color: _sub, height: 1.6)),
            const SizedBox(height: 20),
            _ayudaItem(Icons.calendar_month_rounded, 'Agendar Citas', 'Programa, reagenda o cancela tus consultas medicas.'),
            const SizedBox(height: 12),
            _ayudaItem(Icons.chat_bubble_rounded, 'Mensajes', 'Comunicate con soporte tecnico de CDO a traves del chat.'),
            const SizedBox(height: 12),
            _ayudaItem(Icons.medical_information_rounded, 'Historial', 'Consulta tus registros medicos y recetas digitales.'),
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
                Expanded(child: Text('Para soporte inmediato, utiliza el chat de mensajes con el equipo de CDO.',
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

  // ═══════════════════════════════════════════════════════════════
  // WIDGETS REUTILIZABLES / HELPERS
  // ═══════════════════════════════════════════════════════════════
  Widget _avatarWidget({String? url, required String iniciales, required Color color, required double r}) {
    final hasUrl = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: r,
      backgroundColor: color,
      backgroundImage: hasUrl ? NetworkImage(url) : null,
      onBackgroundImageError: hasUrl ? (_, __) {} : null,
      child: !hasUrl ? Text(iniciales, style: TextStyle(color: Colors.white, fontSize: r * 0.45, fontWeight: FontWeight.bold)) : null,
    );
  }

  Widget _card({required Widget child, EdgeInsets? margin}) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: _cardColor, borderRadius: BorderRadius.circular(20), border: _cardBorder,
      boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
  );

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

  Widget _tituloSeccion(String t) => Row(children: [
    Container(width: 4, height: 24, decoration: BoxDecoration(color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B), borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 12),
    Text(t, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _texto)),
  ]);

  Widget _emptyState(String titulo, String subtitulo, IconData icon) => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(child: Column(children: [
      Icon(icon, size: 48, color: _sub),
      const SizedBox(height: 16),
      Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _texto)),
      const SizedBox(height: 8),
      Text(subtitulo, style: TextStyle(fontSize: 14, color: _sub)),
    ])),
  );

  Widget _datoCita(IconData i, String l, String v) => Column(children: [
    Icon(i, size: 20, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)),
    const SizedBox(height: 8),
    Text(l, style: TextStyle(fontSize: 12, color: _sub)),
    const SizedBox(height: 4),
    Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _texto), textAlign: TextAlign.center),
  ]);

  Widget _div() => Container(width: 1, height: 50, color: _isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey[200]);

  Widget _btnAccion(IconData i, String l, VoidCallback onTap, {Color? color}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color ?? (_isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(i, size: 18, color: color ?? (_isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B))),
        const SizedBox(width: 8),
        Text(l, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? (_isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)))),
      ]),
    ),
  );

  Widget _campoHistoria(String l, String v, IconData i) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(i, size: 16, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)), const SizedBox(width: 8),
      Text(l, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)))]),
    const SizedBox(height: 6),
    Text(v.isNotEmpty ? v : 'Pendiente...', style: TextStyle(fontSize: 14, color: _isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF4A5568), height: 1.6)),
  ]);

  Widget _menuTile(IconData i, String t, VoidCallback onTap, {Color? color}) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor, borderRadius: BorderRadius.circular(16),
        border: _isDarkMode ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (color ?? const Color(0xFF05006B)).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(i, color: color ?? (_isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B)), size: 22)),
        const SizedBox(width: 16),
        Expanded(child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _texto))),
        Icon(Icons.chevron_right_rounded, color: _sub),
      ]),
    ),
  );

  Widget _ayudaItem(IconData icon, String title, String desc) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF05006B).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B))),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _texto)),
      const SizedBox(height: 4),
      Text(desc, style: TextStyle(fontSize: 13, color: _sub, height: 1.5)),
    ])),
  ]);

  Widget _footer() => Center(child: Text('2026 CDO Clinic. Todos los derechos reservados.', style: TextStyle(color: _sub, fontSize: 13)));

  String _mes(int m) => ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'][m-1];

  String _formatearHora(DateTime dt) => '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  String _formatearFechaHora(DateTime dt) {
    try {
      return DateFormat('dd/MM/yyyy hh:mm a', 'es').format(dt);
    } catch (_) {
      return dt.toString();
    }
  }

  void _showSnack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  void _pickerAvatar() {
    final List<String> avatares = [
      'https://api.dicebear.com/7.x/avataaars/png?seed=Felix',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Aneka',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Zack',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Molly',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Bandit',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Bella',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Coco',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Leo',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Luna',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Max',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Mia',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Nala',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Oreo',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Pepper',
      'https://api.dicebear.com/7.x/avataaars/png?seed=Rocky',
    ];

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
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: avatares.map((url) {
                    final isSelected = _avatarUrl == url;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _avatarUrl = url;
                        });
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
                  }).toList(),
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

  void _config() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Configuracion', style: TextStyle(color: _texto)),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SwitchListTile(
            title: Text('Modo Oscuro', style: TextStyle(color: _texto)),
            value: _isDarkMode,
            activeColor: const Color(0xFFFFE600),
            onChanged: (v) { setDialogState(() => _isDarkMode = v); setState(() => _isDarkMode = v); },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Aceptar', style: TextStyle(color: _isDarkMode ? const Color(0xFFFFE600) : const Color(0xFF05006B))))],
      ),
    );
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }
}