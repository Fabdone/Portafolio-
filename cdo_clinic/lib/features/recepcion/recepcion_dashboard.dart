import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cdo_clinic/services/clinic_api_service.dart';
import 'package:cdo_clinic/models/clinic_models.dart';

// ================================================================
// MODELO DE CITA PARA RECEPCION (sin datos medicos)
// Solo datos logisticos: paciente, medico, hora, estado, consultorio
// ================================================================
class CitaRecepcion {
  final int idCita;
  final String hora;
  final String nombrePaciente;
  final String nombreMedico;
  final String consultorio;
  final String estado;
  final String motivo;

  CitaRecepcion({
    required this.idCita,
    required this.hora,
    required this.nombrePaciente,
    required this.nombreMedico,
    required this.consultorio,
    required this.estado,
    required this.motivo,
  });

  factory CitaRecepcion.fromJson(Map<String, dynamic> json) {
    return CitaRecepcion(
      idCita: json['id_cita'] ?? 0,
      hora: json['hora']?.toString() ?? '',
      nombrePaciente: json['nombre_paciente'] ?? 'Paciente sin nombre',
      nombreMedico: json['nombre_medico'] ?? 'Medico sin nombre',
      consultorio: json['consultorio'] ?? 'N/A',
      estado: json['estado'] ?? 'Pendiente',
      motivo: json['motivo'] ?? '',
    );
  }

  /// Color del semaforo segun estado
  Color get colorEstado {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return const Color(0xFFFFB800); // Amarillo
      case 'en espera':
        return const Color(0xFF2196F3); // Azul
      case 'en progreso':
        return const Color(0xFF00BCD4); // Cyan
      case 'completada':
        return const Color(0xFF2E7D32); // Verde oscuro
      case 'cancelada':
        return const Color(0xFFE53935); // Rojo
      default:
        return Colors.grey;
    }
  }

  String get estadoLegible {
    switch (estado.toLowerCase()) {
      case 'pendiente': return 'Pendiente';
      case 'en espera': return 'En Espera';
      case 'en progreso': return 'En Progreso';
      case 'completada': return 'Completada';
      case 'cancelada': return 'Cancelada';
      default: return estado;
    }
  }

  bool get puedeCheckIn => estado.toLowerCase() == 'pendiente';
  bool get puedeCancelar => estado.toLowerCase() != 'cancelada' && estado.toLowerCase() != 'completada';
}

// ================================================================
// SERVICIO API PARA RECEPCION
// ================================================================
class RecepcionApiService {
  static const String _baseUrl = 'http://localhost:3000/api';

  // --- 1. Check-In Manual ---
  Future<ApiResponse<bool>> checkIn(int idCita) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/recepcion/check-in/$idCita'),
      );
      final body = jsonDecode(response.body);
      return ApiResponse(
        success: body['success'] == true,
        data: body['success'] == true,
        error: body['mensaje'],
      );
    } catch (e) {
      return ApiResponse(success: false, error: 'Error de conexion: $e');
    }
  }

  // --- 2. Listado de citas del dia ---
  Future<ApiResponse<List<CitaRecepcion>>> getCitasHoy() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/recepcion/citas-hoy'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> jsonList = body['data'];
          final citas = jsonList.map((j) => CitaRecepcion.fromJson(j)).toList();
          return ApiResponse(success: true, data: citas);
        }
      }
      return ApiResponse(success: false, error: 'Error del servidor: ${response.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error de conexion: $e');
    }
  }

  // --- 3. Registrar paciente walk-in ---
  Future<ApiResponse<Map<String, dynamic>>> registrarPaciente({
    required String nombre,
    required String apellido,
    required String cedula,
    String? telefono,
    String? correo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/recepcion/registrar-paciente'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre.trim(),
          'apellido': apellido.trim(),
          'cedula_identidad': cedula.trim(),
          'telefono': telefono?.trim(),
          'correo': correo?.trim(),
        }),
      );
      final body = jsonDecode(response.body);
      return ApiResponse(
        success: body['success'] == true,
        data: body,
        error: body['mensaje'],
      );
    } catch (e) {
      return ApiResponse(success: false, error: 'Error de conexion: $e');
    }
  }

  // --- 4. Cancelar cita desde recepcion ---
  Future<ApiResponse<bool>> cancelarCita(int idCita) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/recepcion/cancelar-cita/$idCita'),
      );
      final body = jsonDecode(response.body);
      return ApiResponse(
        success: body['success'] == true,
        data: body['success'] == true,
        error: body['mensaje'],
      );
    } catch (e) {
      return ApiResponse(success: false, error: 'Error de conexion: $e');
    }
  }

  // --- 5. Descargar reporte diario PDF ---
  Future<void> descargarReporteDiario(int idMedico) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/recepcion/reporte-diario/$idMedico'),
      );
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'reporte_diario_${idMedico}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Reporte diario CDO Clinic');
      } else {
        throw Exception('Error descargando reporte: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}

// ================================================================
// DASHBOARD DE RECEPCION - VISTA PRINCIPAL
// ================================================================
class RecepcionDashboard extends StatefulWidget {
  const RecepcionDashboard({super.key});

  @override
  State<RecepcionDashboard> createState() => _RecepcionDashboardState();
}

class _RecepcionDashboardState extends State<RecepcionDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isDarkMode = false;

  late TabController _tabController;
  final RecepcionApiService _api = RecepcionApiService();
  final ClinicApiService _clinicApi = ClinicApiService();

  // --- Datos del recepcionista ---
  String _nombreRecepcion = 'Cargando...';
  String _rolRecepcion = 'Recepcion';
  String _inicialesRecepcion = '??';
  String? _correoRecepcion;
  String? _telefonoRecepcion;
  bool _cargandoUsuario = true;
  String? _avatarUrl;
  Color _avatarColor = const Color(0xFF0066CC);

  List<CitaRecepcion> _todasLasCitas = [];
  List<CitaRecepcion> _citasFiltradas = [];
  bool _cargando = false;
  String? _error;
  String _busqueda = '';

  // Contadores para badges
  int get _countPendientes => _todasLasCitas.where((c) => c.estado.toLowerCase() == 'pendiente').length;
  int get _countEnEspera => _todasLasCitas.where((c) => c.estado.toLowerCase() == 'en espera').length;
  int get _countEnProgreso => _todasLasCitas.where((c) => c.estado.toLowerCase() == 'en progreso').length;

  // ================================================================
  // COLORES ADAPTATIVOS (IGUAL que Paciente y Doctor)
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
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _fetchDatosUsuario();
    _fetchCitas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ================================================================
  // CARGA DE DATOS DEL USUARIO RECEPCION
  // ================================================================
  Future<void> _fetchDatosUsuario() async {
    setState(() => _cargandoUsuario = true);
    try {
      final resultado = await _clinicApi.getUsuarioActual();
      if (resultado.success && resultado.data != null) {
        final usuario = resultado.data!;
        _actualizarDatosUsuario(usuario);
      } else {
        _setFallbackUsuario();
      }
    } catch (e) {
      debugPrint('Error cargando datos recepcion: $e');
      _setFallbackUsuario();
    }
  }

  void _actualizarDatosUsuario(dynamic usuario) {
    final serverAvatarUrl = _normalizeAvatarUrl(usuario.fotoUrl ?? usuario.avatarUrl);
    setState(() {
      _nombreRecepcion = "${usuario.nombre ?? 'Usuario'} ${usuario.apellido ?? ''}".trim();
      // Preferir el rol almacenado en el servicio (set en login), si existe
      _rolRecepcion = _clinicApi.rolUsuarioActual ?? usuario.rol ?? 'Recepcion';
      _inicialesRecepcion = _generarIniciales(usuario.nombre ?? 'U', usuario.apellido ?? 'S');
      _correoRecepcion = usuario.correo;
      _telefonoRecepcion = usuario.telefono;
      if (serverAvatarUrl != null) {
        _avatarUrl = serverAvatarUrl;
      }
      _cargandoUsuario = false;
    });
  }

  String? _normalizeAvatarUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _setFallbackUsuario() {
    setState(() {
      _nombreRecepcion = 'Usuario Recepcion';
      _rolRecepcion = 'Recepcion';
      _inicialesRecepcion = 'UR';
      _cargandoUsuario = false;
    });
  }

  String _generarIniciales(String nombre, String apellido) {
    final n = nombre.trim();
    final a = apellido.trim();
    if (n.isNotEmpty && a.isNotEmpty) return '${n[0]}${a[0]}'.toUpperCase();
    if (n.isNotEmpty) return n[0].toUpperCase();
    return '??';
  }

  Future<void> _fetchCitas() async {
    setState(() { _cargando = true; _error = null; });
    final resultado = await _api.getCitasHoy();
    if (resultado.success && resultado.data != null) {
      setState(() {
        _todasLasCitas = resultado.data!;
        _cargando = false;
      });
    } else {
      setState(() {
        _error = resultado.error ?? 'Error cargando citas';
        _cargando = false;
      });
    }
  }

  List<CitaRecepcion> _getCitasPorTab(int tabIndex) {
    List<CitaRecepcion> base;
    switch (tabIndex) {
      case 0: base = _todasLasCitas; break;
      case 1: base = _todasLasCitas.where((c) => c.estado.toLowerCase() == 'pendiente').toList(); break;
      case 2: base = _todasLasCitas.where((c) => c.estado.toLowerCase() == 'en espera').toList(); break;
      case 3: base = _todasLasCitas.where((c) => c.estado.toLowerCase() == 'en progreso').toList(); break;
      default: base = _todasLasCitas;
    }
    if (_busqueda.isEmpty) return base;
    return base.where((c) =>
      c.nombrePaciente.toLowerCase().contains(_busqueda.toLowerCase()) ||
      c.nombreMedico.toLowerCase().contains(_busqueda.toLowerCase())
    ).toList();
  }

  Future<void> _checkIn(CitaRecepcion cita) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirmar Check-In', style: TextStyle(fontWeight: FontWeight.bold, color: _textoPrincipal)),
        content: Text('Marcar a ${cita.nombrePaciente} como "En Espera"?', style: TextStyle(color: _textoSecundario)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: TextStyle(color: _accentColor))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cargando = true);
    final resultado = await _api.checkIn(cita.idCita);
    setState(() => _cargando = false);

    if (resultado.success) {
      _showSnack('${cita.nombrePaciente} registrado en sala de espera', const Color(0xFF4CAF50));
      await _fetchCitas();
    } else {
      _mostrarError(resultado.error ?? 'Error en check-in');
    }
  }

  Future<void> _cancelarCita(CitaRecepcion cita) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancelar Cita', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFFE53935))),
        content: Text('Cancelar la cita de ${cita.nombrePaciente}?', style: TextStyle(color: _textoSecundario)),
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

    setState(() => _cargando = true);
    final resultado = await _api.cancelarCita(cita.idCita);
    setState(() => _cargando = false);

    if (resultado.success) {
      _showSnack('Cita cancelada', const Color(0xFF4CAF50));
      await _fetchCitas();
    } else {
      _mostrarError(resultado.error ?? 'Error al cancelar');
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
  // AVATAR - SUBIR FOTO REAL O ELEGIR AVATAR
  // ================================================================
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
                      backgroundColor: _accentColor,
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
                    final seed = 'Recepcion${i + 1}';
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
                      backgroundColor: _accentColor,
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
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final idUsuario = _clinicApi.idUsuarioActual;
        if (idUsuario != null) {
          final res = await _clinicApi.subirFotoUsuario(idUsuario, file);
          if (res.success) {
            setState(() {
              _avatarUrl = (res.data != null && res.data!.isNotEmpty)
                ? res.data
                : result.files.single.path!;
            });
            _showSnack('Foto actualizada exitosamente', const Color(0xFF4CAF50));
            // Intentar persistir la URL del avatar en el servidor
            try {
              final persist = await _clinicApi.actualizarAvatarUsuario(idUsuario, _avatarUrl!);
              if (persist.success) {
                debugPrint('Avatar guardado en servidor');
                await _fetchDatosUsuario();
              } else {
                debugPrint('No se pudo guardar avatar en servidor: ${persist.error}');
              }
            } catch (e) {
              debugPrint('Error actualizando avatar en servidor: $e');
            }
          } else {
            setState(() => _avatarUrl = result.files.single.path!);
            _showSnack('Foto seleccionada localmente; la subida al servidor falló.', const Color(0xFFFFA000));
            debugPrint('Error al subir foto de usuario: ${res.error}');
          }
        } else {
          // Fallback: usar ruta local si no hay API
          setState(() => _avatarUrl = result.files.single.path!);
          _showSnack('Foto seleccionada (modo local)', const Color(0xFF4CAF50));
        }
      }
    } catch (e) {
      _mostrarError('Error: $e');
    }
  }

  // ================================================================
  // REGISTRAR PACIENTE WALK-IN (Modal)
  // ================================================================
  void _mostrarRegistroPaciente() {
    final nombreCtrl = TextEditingController();
    final apellidoCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool guardando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.person_add, color: _accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Registrar Paciente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _textoPrincipal))),
          ]),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputFieldRegistro(controller: nombreCtrl, label: 'Nombre *', icon: Icons.person),
                  const SizedBox(height: 12),
                  _buildInputFieldRegistro(controller: apellidoCtrl, label: 'Apellido *', icon: Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildInputFieldRegistro(controller: cedulaCtrl, label: 'Cedula *', icon: Icons.badge),
                  const SizedBox(height: 12),
                  _buildInputFieldRegistro(controller: telefonoCtrl, label: 'Telefono', icon: Icons.phone, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildInputFieldRegistro(controller: correoCtrl, label: 'Correo', icon: Icons.email, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text('La contrasena provisional sera el numero de cedula.', style: TextStyle(fontSize: 12, color: Colors.amber))),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: _accentColor))),
            ElevatedButton.icon(
              onPressed: guardando ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => guardando = true);
                final res = await _api.registrarPaciente(
                  nombre: nombreCtrl.text,
                  apellido: apellidoCtrl.text,
                  cedula: cedulaCtrl.text,
                  telefono: telefonoCtrl.text.isEmpty ? null : telefonoCtrl.text,
                  correo: correoCtrl.text.isEmpty ? null : correoCtrl.text,
                );
                setDialogState(() => guardando = false);
                if (res.success) {
                  Navigator.pop(ctx);
                  _showSnack('Paciente registrado. ID: ${res.data?['id_paciente']}', const Color(0xFF4CAF50));
                } else {
                  _mostrarError(res.error ?? 'Error al registrar');
                }
              },
              icon: guardando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: const Text('Registrar'),
              style: ElevatedButton.styleFrom(backgroundColor: _accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFieldRegistro({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: _textoPrincipal),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textoSecundario),
        prefixIcon: Icon(icon, color: _accentColor),
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accentColor, width: 1.5)),
      ),
      validator: label.contains('*') ? (v) => v == null || v.isEmpty ? 'Obligatorio' : null : null,
    );
  }

  // ================================================================
  // CONFIGURACION
  // ================================================================
  void _config() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Configuracion', style: TextStyle(color: _textoPrincipal)),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SwitchListTile(
            title: Text('Modo Oscuro', style: TextStyle(color: _textoPrincipal)),
            subtitle: Text('Cambiar tema de la aplicacion', style: TextStyle(color: _textoSecundario, fontSize: 12)),
            value: _isDarkMode,
            activeColor: _accentLight,
            onChanged: (v) async {
              setDialogState(() => _isDarkMode = v);
              setState(() => _isDarkMode = v);
              final idUsuario = _clinicApi.idUsuarioActual;
              if (idUsuario != null) {
                final persist = await _clinicApi.actualizarPreferenciaTemaUsuario(idUsuario, v ? 'dark' : 'light');
                if (!persist.success) {
                  debugPrint('No se pudo guardar preferencia de tema: ${persist.error}');
                }
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Aceptar', style: TextStyle(color: _isDarkMode ? _accentLight : _accentColor)),
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
            decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.support_agent_rounded, color: _accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text('Centro de Ayuda CDO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textoPrincipal))),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Necesitas asistencia? Nuestro equipo de soporte esta disponible para ayudarte.', style: TextStyle(fontSize: 14, color: _textoSecundario, height: 1.6)),
            const SizedBox(height: 20),
            _ayudaItem(Icons.calendar_month_rounded, 'Check-In de Pacientes', 'Registra la llegada de pacientes a la sala de espera.'),
            const SizedBox(height: 12),
            _ayudaItem(Icons.person_add, 'Registro Walk-in', 'Registra nuevos pacientes que llegan sin cita previa.'),
            const SizedBox(height: 12),
            _ayudaItem(Icons.cancel, 'Cancelar Citas', 'Cancela citas desde recepcion cuando sea necesario.'),
            const SizedBox(height: 12),
            _ayudaItem(Icons.download, 'Reportes Diarios', 'Genera y comparte reportes diarios por medico.'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isDarkMode ? Colors.white.withOpacity(0.1) : _accentColor.withOpacity(0.15)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: _isDarkMode ? _accentLight : _accentColor, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Para soporte inmediato, contacta al administrador del sistema.',
                  style: TextStyle(fontSize: 13, color: _isDarkMode ? Colors.white.withOpacity(0.8) : const Color(0xFF4A5568), height: 1.5))),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido', style: TextStyle(color: _isDarkMode ? _accentLight : _accentColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _ayudaItem(IconData icon, String title, String desc) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _accentColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: _isDarkMode ? _accentLight : _accentColor)),
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
              _clinicApi.clearToken();
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
  // BUILD PRINCIPAL - SIDEBAR + CONTENIDO (IGUAL que Paciente/Doctor)
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: Row(children: [
        _sidebar(),
        Expanded(child: [
          _buildInicioView(),
          _buildCitasView(),
          _buildPerfilView(),
        ][_selectedIndex]),
      ]),
    );
  }

  // ================================================================
  // SIDEBAR - IDENTICO al de Paciente y Doctor
  // ================================================================
  Widget _sidebar() {
    final items = [
      (Icons.dashboard_rounded, 'Inicio', 0),
      (Icons.calendar_month_rounded, 'Citas', 1),
      (Icons.person_rounded, 'Perfil', 2),
    ];

    return Container(
      width: 260,
      color: _accentColor,
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
            Icon(item.$1, color: sel ? _accentLight : Colors.white.withOpacity(0.6), size: 22),
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
      _avatarWidget(url: _avatarUrl, iniciales: _inicialesRecepcion, color: const Color(0xFF0066CC), r: 24),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_nombreRecepcion, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(_rolRecepcion, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
      ])),
    ]),
  );

  Widget _avatarWidget({String? url, required String iniciales, required Color color, required double r}) {
    final hasUrl = url != null && url.isNotEmpty;
    final ImageProvider? imageProvider = hasUrl
        ? (url.startsWith('http') ? NetworkImage(url) : FileImage(File(url)))
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
  // VISTA 0: INICIO (Dashboard con resumen y acciones rapidas)
  // ================================================================
  Widget _buildInicioView() {
    return RefreshIndicator(
      onRefresh: _fetchCitas,
      color: _accentColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerHome(),
            const SizedBox(height: 40),
            _tituloSeccion('Resumen del Dia'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildSummaryCard(
                  icon: Icons.calendar_today_rounded,
                  value: _cargando ? '...' : _todasLasCitas.length.toString(),
                  label: 'Total citas',
                  color: _accentColor,
                )),
                const SizedBox(width: 20),
                Expanded(child: _buildSummaryCard(
                  icon: Icons.schedule,
                  value: _cargando ? '...' : _countPendientes.toString(),
                  label: 'Pendientes',
                  color: const Color(0xFFFFB800),
                )),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildSummaryCard(
                  icon: Icons.chair,
                  value: _cargando ? '...' : _countEnEspera.toString(),
                  label: 'En Espera',
                  color: const Color(0xFF2196F3),
                )),
                const SizedBox(width: 20),
                Expanded(child: _buildSummaryCard(
                  icon: Icons.medical_services,
                  value: _cargando ? '...' : _countEnProgreso.toString(),
                  label: 'En Progreso',
                  color: const Color(0xFF00BCD4),
                )),
              ],
            ),
            const SizedBox(height: 40),
            _tituloSeccion('Acciones Rapidas'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildAccionRapida(
                    icon: Icons.person_add,
                    label: 'Registrar Paciente',
                    color: const Color(0xFF4CAF50),
                    onTap: _mostrarRegistroPaciente,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAccionRapida(
                    icon: Icons.refresh,
                    label: 'Actualizar Citas',
                    color: _accentColor,
                    onTap: _fetchCitas,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _tituloSeccion('Citas del Dia'),
            const SizedBox(height: 24),
            _buildCitasList(_getCitasPorTab(0)),
          ],
        ),
      ),
    );
  }

  Widget _headerHome() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bienvenido a CDO!', style: TextStyle(color: _isDarkMode ? _accentLight : _accentColor, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Text(_nombreRecepcion, style: TextStyle(color: _textoPrincipal, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
    ]),
    _chip(icon: Icons.calendar_today_rounded, label: DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now())),
  ]);

  Widget _tituloSeccion(String t) => Row(children: [
    Container(width: 4, height: 24, decoration: BoxDecoration(color: _isDarkMode ? _accentLight : _accentColor, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 12),
    Text(t, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textoPrincipal)),
  ]);

  Widget _chip({required IconData icon, required String label}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      color: _isDarkMode ? Colors.white.withOpacity(0.08) : _accentColor.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _isDarkMode ? Colors.white.withOpacity(0.2) : _accentColor.withOpacity(0.1))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: _isDarkMode ? _accentLight : _accentColor),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: _isDarkMode ? Colors.white70 : _accentColor, fontSize: 14, fontWeight: FontWeight.w500)),
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

  Widget _buildAccionRapida({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: _cardBorder,
          boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textoPrincipal), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // VISTA 1: CITAS (con tabs y buscador)
  // ================================================================
  Widget _buildCitasView() {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.local_hospital, size: 28),
            SizedBox(width: 12),
            Text('CDO Clinic - Recepcion', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Registrar paciente',
            onPressed: _mostrarRegistroPaciente,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _fetchCitas,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: _accentLight,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(icon: Icon(Icons.list), text: 'Todas'),
            Tab(icon: const Icon(Icons.schedule), text: 'Pendientes ($_countPendientes)'),
            Tab(icon: const Icon(Icons.chair), text: 'En Espera ($_countEnEspera)'),
            Tab(icon: const Icon(Icons.medical_services), text: 'En Progreso ($_countEnProgreso)'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                style: TextStyle(color: _textoPrincipal),
                decoration: InputDecoration(
                  hintText: 'Buscar paciente o medico...',
                  hintStyle: TextStyle(color: _textoSecundario.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: _accentColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
          ),
          // Contenido
          Expanded(
            child: _cargando
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF004694)))
              : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFFE53935))),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _fetchCitas, child: const Text('Reintentar')),
                  ]))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCitasList(_getCitasPorTab(0)),
                      _buildCitasList(_getCitasPorTab(1)),
                      _buildCitasList(_getCitasPorTab(2)),
                      _buildCitasList(_getCitasPorTab(3)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // VISTA 2: PERFIL (IGUAL que Paciente y Doctor)
  // ================================================================
  Widget _buildPerfilView() => SingleChildScrollView(
    padding: const EdgeInsets.all(40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mi Perfil', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _textoPrincipal)),
      const SizedBox(height: 32),
      Center(child: GestureDetector(
        onTap: _pickerAvatar,
        child: Stack(children: [
          _avatarWidget(url: _avatarUrl, iniciales: _inicialesRecepcion, color: _avatarColor, r: 60),
          Positioned(bottom: 0, right: 0, child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFFFE600), shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]),
            child: const Icon(Icons.edit, size: 18, color: Color(0xFF05006B)),
          )),
        ]),
      )),
      const SizedBox(height: 20),
      Center(child: Text(_nombreRecepcion, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textoPrincipal))),
      Center(child: Text(_rolRecepcion, style: TextStyle(fontSize: 15, color: _textoSecundario))),
      if (_correoRecepcion != null) ...[
        const SizedBox(height: 8),
        Center(child: Text(_correoRecepcion!, style: TextStyle(fontSize: 14, color: _textoPrincipal))),
      ],
      if (_telefonoRecepcion != null) ...[
        const SizedBox(height: 8),
        Center(child: Text(_telefonoRecepcion!, style: TextStyle(fontSize: 14, color: _textoPrincipal))),
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
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (color ?? (_isDarkMode ? _accentLight : const Color(0xFF4A5568))).withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(i, color: color ?? (_isDarkMode ? _accentLight : const Color(0xFF4A5568)), size: 22)),
        const SizedBox(width: 16),
        Expanded(child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textoPrincipal))),
        Icon(Icons.chevron_right_rounded, color: _textoSecundario),
      ]),
    ),
  );

  // ================================================================
  // LISTA DE CITAS
  // ================================================================
  Widget _buildCitasList(List<CitaRecepcion> citas) {
    if (citas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No hay citas en esta seccion', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCitas,
      color: _accentColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: citas.length,
        itemBuilder: (context, index) {
          final cita = citas[index];
          return _buildCitaCard(cita);
        },
      ),
    );
  }

  Widget _buildCitaCard(CitaRecepcion cita) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: _cardBorder,
        boxShadow: [BoxShadow(color: _isDarkMode ? const Color(0x66000000) : const Color(0x0A000000), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Header con color de estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cita.colorEstado.withOpacity(0.8), cita.colorEstado]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    cita.hora,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cita.nombrePaciente,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    cita.estadoLegible,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Body - Solo datos logisticos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: _accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cita.nombreMedico,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.meeting_room, size: 16, color: _accentColor),
                    const SizedBox(width: 8),
                    Text(
                      'Consultorio: ${cita.consultorio}',
                      style: TextStyle(fontSize: 13, color: _textoSecundario),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notes, size: 16, color: _accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Motivo: ${cita.motivo}',
                        style: TextStyle(fontSize: 13, color: _textoSecundario),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Botones de accion
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cita.puedeCheckIn)
                      ElevatedButton.icon(
                        onPressed: () => _checkIn(cita),
                        icon: const Icon(Icons.login_rounded, size: 16),
                        label: const Text('Check-In'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    if (cita.puedeCheckIn && cita.puedeCancelar) const SizedBox(width: 8),
                    if (cita.puedeCancelar)
                      OutlinedButton.icon(
                        onPressed: () => _cancelarCita(cita),
                        icon: const Icon(Icons.cancel, size: 16, color: Color(0xFFE53935)),
                        label: const Text('Cancelar', style: TextStyle(color: Color(0xFFE53935))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE53935)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
