import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cdo_clinic/models/clinic_models.dart';

class ClinicApiService {
  static const String _baseUrl = 'http://localhost:3000/api';
  static const String _serverUrl = 'http://localhost:3000'; // Base URL sin /api
  static int? _idUsuarioActual;
  static String? _token;
  static String? _rolUsuarioActual;
  static Map<String, dynamic>? _usuarioActualData;

  int? get idUsuarioActual => _idUsuarioActual;
  String? get rolUsuarioActual => _rolUsuarioActual;
  Map<String, dynamic>? get usuarioActualData => _usuarioActualData;

  /// Convierte URLs relativas a URLs HTTP completas
  static String _buildFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // Rutas relativas: /uploads/... o uploads/...
    if (!url.startsWith('/')) url = '/$url';
    return '$_serverUrl$url';
  }

  void setUsuario(int id) => _idUsuarioActual = id;

  void setRolUsuario(String? rol) => _rolUsuarioActual = _normalizeRole(rol);

  void setUsuarioActualData(Map<String, dynamic>? usuario) => _usuarioActualData = usuario;

  int? _extractUsuarioId(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['id_usuario'] ?? json['usuario_id'] ?? json['idUsuario'];
    if (idRaw is int) return idRaw;
    if (idRaw is String) return int.tryParse(idRaw);
    return null;
  }

  String? _extractUsuarioRol(Map<String, dynamic> json) {
    return json['rol'] as String?
        ?? json['role'] as String?
        ?? json['tipo'] as String?
        ?? json['tipo_usuario'] as String?;
  }

  String _normalizeRole(String? rawRole) {
    if (rawRole == null || rawRole.trim().isEmpty) return '';
    final normalized = rawRole
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('á', 'a')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();

    if (normalized.contains('recepcion')) return 'recepcion';
    if (normalized.contains('medic') || normalized.contains('doctor')) return 'medico';
    if (normalized.contains('admin')) return 'admin';
    if (normalized.contains('gerente')) return 'gerente';
    if (normalized.contains('paciente')) return 'paciente';
    return normalized;
  }

  Map<String, dynamic>? _extractUserFromLoginBody(Map<String, dynamic> body) {
    if (body['usuario'] is Map<String, dynamic>) {
      return body['usuario'] as Map<String, dynamic>;
    }
    if (body['data'] is Map<String, dynamic>) {
      final data = body['data'] as Map<String, dynamic>;
      if (data['usuario'] is Map<String, dynamic>) {
        return data['usuario'] as Map<String, dynamic>;
      }
      return data;
    }
    return null;
  }

  void clearToken() {
    _idUsuarioActual = null;
    _token = null;
    _rolUsuarioActual = null;
    debugPrint('Cerrando sesion y limpiando datos locales...');
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<Map<String, dynamic>>> login(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return ApiResponse(success: false, error: 'Correo y contraseña son obligatorios.');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': email.trim(), 'password': password.trim()}),
      );

      final body = _parseJsonSafely(response.body);
      if (body != null && response.statusCode == 200 && body['success'] == true) {
        final user = _extractUserFromLoginBody(body);
        if (user == null) {
          return ApiResponse(success: false, error: 'Respuesta del servidor incompleta.');
        }

        _idUsuarioActual = _extractUsuarioId(user);
        final rawRol = _extractUsuarioRol(user);
        _rolUsuarioActual = _normalizeRole(rawRol);
        _usuarioActualData = user;
        return ApiResponse(success: true, data: body);
      }

      return ApiResponse(success: false, error: body?['mensaje'] ?? body?['error'] ?? 'Credenciales invalidas.');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error de conexion: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> registro({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
  }) async {
    try {
      if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
        return ApiResponse(success: false, error: 'Todos los campos obligatorios deben completarse.');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre.trim(),
          'correo': email.trim(),
          'telefono': telefono.trim(),
          'password': password,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse(success: true, data: body);
      }
      return ApiResponse(success: false, error: body['mensaje'] ?? 'Error al registrar el paciente.');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error de conexion: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 1. OBTENER MEDICOS POR ESPECIALIDAD
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<List<Medico>>> getMedicosPorEspecialidad(String especialidad) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/medicos/${Uri.encodeComponent(especialidad)}'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> jsonList = body['data'];
          final medicos = jsonList.map((j) => Medico.fromJson(j)).toList();
          return ApiResponse(success: true, data: medicos);
        }
      }
      return ApiResponse(success: false, error: 'Error del servidor: ${response.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error de conexion: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. CREAR CITA
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<Map<String, dynamic>>> crearCitaReal({
    required int idPaciente,
    required int idMedico,
    required String fechaHora,
    required String motivo,
    required String especialidad,
    required String direccion,
    required String cedula,
    required String fechaNacimiento,
    required String genero,
    String? rutaArchivo,
  }) async {
    try {
      final body = {
        'id_paciente': idPaciente,
        'id_medico': idMedico,
        'specialty': especialidad,
        'fecha_hora': fechaHora,
        'motivo': motivo,
        'direccion': direccion,
        'cedula': cedula,
        'fecha_nacimiento': fechaNacimiento,
        'genero': genero,
        if (rutaArchivo != null) 'ruta_archivo': rutaArchivo,
      };

      debugPrint('📤 Enviando a /citas/crear: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/citas/crear'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      debugPrint('📥 Respuesta ${response.statusCode}: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse(success: true, data: jsonDecode(response.body));
      }

      if (response.statusCode == 404) {
        final body = jsonDecode(response.body);
        return ApiResponse(
          success: false, 
          error: body['mensaje'] ?? 'Médico o especialidad no encontrada.'
        );
      }

      if (response.statusCode == 400) {
        final body = jsonDecode(response.body);
        return ApiResponse(
          success: false, 
          error: body['mensaje'] ?? 'Datos inválidos o médico ocupado.'
        );
      }

      return ApiResponse(
        success: false, 
        error: 'Error del servidor: ${response.statusCode} - ${response.body}'
      );
    } catch (e) {
      return ApiResponse(success: false, error: 'Error de red: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> crearCita({
    required int idPaciente,
    required int idMedico,
    required String fechaHora,
    required String motivo,
    required String especialidad,
    required String direccion,
    required String cedula,
    required String fechaNacimiento,
    required String genero,
    String? rutaAdjunto,
  }) async {
    return await crearCitaReal(
      idPaciente: idPaciente,
      idMedico: idMedico,
      fechaHora: fechaHora,
      motivo: motivo,
      especialidad: especialidad,
      direccion: direccion,
      cedula: cedula,
      fechaNacimiento: fechaNacimiento,
      genero: genero,
      rutaArchivo: rutaAdjunto,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. OBTENER CITAS DEL PACIENTE
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<List<Cita>>> getCitas(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/citas/paciente/$idPaciente'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> jsonList = body['data'];
          final citas = jsonList.map((j) => Cita.fromJson(j)).toList();
          return ApiResponse(success: true, data: citas);
        }
      }
      return ApiResponse(success: false, error: 'Error: ${response.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error de conexion: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. OBTENER CITAS POR MEDICO
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<List<Cita>>> getCitasPorMedico(int idMedico) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/citas/medico/$idMedico'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> jsonList = body['data'];
          final citas = jsonList.map((j) => Cita.fromJson(j)).toList();
          return ApiResponse(success: true, data: citas);
        }
      }
      return ApiResponse(success: false, error: 'Error: ${response.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. INICIAR CITA (NUEVO - Control de tiempos)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> iniciarCita(int idCita) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/citas/iniciar/$idCita'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResponse(success: body['success'] == true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al iniciar: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 6. FINALIZAR CITA (NUEVO - Control de tiempos)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> finalizarCita(int idCita) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/citas/finalizar/$idCita'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResponse(success: body['success'] == true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al finalizar: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 7. CANCELAR CITA (CORREGIDO - Con auditoría modificado_por)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> cancelarCita(int idCita, String rolUsuario) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/citas/cancelar/$idCita'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'modificado_por': rolUsuario}), // 'Paciente', 'Medico' o 'Recepcion'
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResponse(success: body['success'] == true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al cancelar: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 8. REAGENDAR CITA (CORREGIDO - Con auditoría modificado_por)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> reagendarCita(int idCita, DateTime nuevaFecha, String rolUsuario) async {
    try {
      final fechaFormateada = nuevaFecha.toIso8601String().substring(0, 19).replaceFirst('T', ' ');
      final response = await http.put(
        Uri.parse('$_baseUrl/citas/reagendar/$idCita'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fecha_hora': fechaFormateada,
          'modificado_por': rolUsuario, // 'Paciente', 'Medico' o 'Recepcion'
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResponse(success: body['success'] == true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al reagendar: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 9. OBTENER MENSAJES DEL PACIENTE
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<List<Mensaje>>> getMensajes(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/mensajes/$idPaciente'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> jsonList = body['data'];
          final mensajes = jsonList.map((j) => Mensaje.fromJson(j)).toList();
          return ApiResponse(success: true, data: mensajes);
        }
      }
      return ApiResponse(success: false, error: 'Error: ${response.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 10. OBTENER MENSAJES POR MEDICO
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<List<Mensaje>>> getMensajesPorMedico(int idMedico) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/mensajes/medico/$idMedico'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> jsonList = body['data'];
          final mensajes = jsonList.map((j) => Mensaje.fromJson(j)).toList();
          return ApiResponse(success: true, data: mensajes);
        }
      }
      return ApiResponse(success: false, error: 'Error: ${response.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 11. ENVIAR MENSAJE (con archivo adjunto)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> enviarMensaje({
    required int idPaciente,
    required int idMedico,
    required String remitente,
    required String contenido,
    String? rutaArchivo,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/mensajes'));
      request.fields['id_paciente'] = idPaciente.toString();
      request.fields['id_medico'] = idMedico.toString();
      request.fields['remitente'] = remitente;
      request.fields['contenido_texto'] = contenido;

      if (rutaArchivo != null && File(rutaArchivo).existsSync()) {
        final file = File(rutaArchivo);
        final extension = rutaArchivo.split('.').last.toLowerCase();
        final contentType = _getContentType(extension);
        request.files.add(await http.MultipartFile.fromPath(
          'adjunto',
          rutaArchivo,
          contentType: MediaType.parse(contentType),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return ApiResponse(success: true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al enviar: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'pdf': return 'application/pdf';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 12. OBTENER HISTORIALES CLINICOS
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<List<HistoriaClinica>>> getHistorias(int idPaciente) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/historiales/$idPaciente'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> jsonList = body['data'];
          final historias = jsonList.map((j) => HistoriaClinica.fromJson(j)).toList();
          return ApiResponse(success: true, data: historias);
        }
      }
      return ApiResponse(success: false, error: 'Error: ${response.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  Future<ApiResponse<List<HistoriaClinica>>> getHistoriasPorPaciente(int idPaciente) => getHistorias(idPaciente);

  // ═══════════════════════════════════════════════════════════════
  // 13. CREAR HISTORIA CLINICA (CORREGIDO - Nuevo esquema con notas_privadas)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<Map<String, dynamic>>> crearHistoriaClinica({
    required int idPaciente,
    int? idCita,
    int? idMedico,
    required String sintomas,
    required String diagnostico,
    required String tratamiento,
    String? notasPrivadas,
  }) async {
    try {
      final medico = idMedico ?? _idUsuarioActual;
      final response = await http.post(
        Uri.parse('$_baseUrl/historias'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_paciente': idPaciente,
          if (idCita != null) 'id_cita': idCita,
          if (medico != null) 'id_medico': medico,
          'sintomas': sintomas,
          'diagnostico': diagnostico,
          'tratamiento': tratamiento,
          if (notasPrivadas != null && notasPrivadas.isNotEmpty) 'notas_privadas': notasPrivadas,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse(success: true, data: body);
      }
      return ApiResponse(success: false, error: body['mensaje'] ?? 'Error: ${response.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 14. EDITAR HISTORIA CLINICA (NUEVO)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> editarHistoriaClinica(int idHistoria, {
    String? sintomas,
    String? diagnostico,
    String? tratamiento,
    String? notasPrivadas,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (sintomas != null) body['sintomas'] = sintomas;
      if (diagnostico != null) body['diagnostico'] = diagnostico;
      if (tratamiento != null) body['tratamiento'] = tratamiento;
      if (notasPrivadas != null) body['notas_privadas'] = notasPrivadas;

      final response = await http.put(
        Uri.parse('$_baseUrl/historias/$idHistoria'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse(success: data['success'] == true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al editar: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 15. ELIMINAR HISTORIA CLINICA (NUEVO)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> eliminarHistoriaClinica(int idHistoria) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/historias/$idHistoria'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse(success: data['success'] == true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al eliminar: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 16. ENVIAR RESENA
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> enviarResena({
    required int idPaciente,
    required int calificacion,
    required String comentario,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/resenas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_paciente': idPaciente,
          'calificacion': calificacion,
          'comentario': comentario,
        }),
      );
      if (response.statusCode == 201) {
        return ApiResponse(success: true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al enviar resena: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 17. ENVIAR RESENA DE MEDICO (NUEVO)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> enviarResenaMedico({
    required int idPaciente,
    required int idMedico,
    required int estrellas,
    required String comentario,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/resenas/medicos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_paciente': idPaciente,
          'id_medico': idMedico,
          'estrellas': estrellas,
          'comentario': comentario,
        }),
      );
      if (response.statusCode == 201) {
        return ApiResponse(success: true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al enviar resena: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 18. OBTENER USUARIO ACTUAL
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<DoctorUsuario>> getUsuarioActual() async {
    try {
      if (_idUsuarioActual == null) {
        return ApiResponse(success: false, error: 'No hay usuario autenticado');
      }

      final resultado = await getUsuarioPorId(_idUsuarioActual!);
      if (resultado.success && resultado.data != null) {
        final servidor = resultado.data!;
        if (_rolUsuarioActual != null && _rolUsuarioActual!.isNotEmpty) {
          final servidorRol = _normalizeRole(servidor.rol);
          if (servidorRol.isNotEmpty && servidorRol != _rolUsuarioActual) {
            debugPrint('El rol del servidor ($servidorRol) no coincide con el rol local ($_rolUsuarioActual). Usando datos locales.');
            if (_usuarioActualData != null) {
              return ApiResponse(
                success: true,
                data: DoctorUsuario.fromJson({
                  ..._usuarioActualData!,
                  'rol': _rolUsuarioActual,
                }),
              );
            }
          }
        }
        return resultado;
      }

      if (_usuarioActualData != null) {
        return ApiResponse(success: true, data: DoctorUsuario.fromJson(_usuarioActualData!));
      }

      return resultado;
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 19. OBTENER USUARIO POR ID
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<DoctorUsuario>> getUsuarioPorId(int idUsuario) async {
    final endpoints = [
      '$_baseUrl/usuario/$idUsuario',
      '$_baseUrl/usuarios/$idUsuario',
      '$_baseUrl/usuario/perfil/$idUsuario',
      '$_baseUrl/usuario/$idUsuario/perfil',
    ];

    String? lastError;
    for (final endpoint in endpoints) {
      try {
        final response = await http.get(Uri.parse(endpoint));
        if (response.statusCode != 200) {
          lastError = 'Error HTTP ${response.statusCode} en $endpoint';
          continue;
        }

        final body = _parseJsonSafely(response.body);
        if (body != null && body['success'] == true && body['data'] != null) {
          final usuario = DoctorUsuario.fromJson(body['data']);
          return ApiResponse(success: true, data: usuario);
        }

        lastError = body?['mensaje']?.toString() ?? body?['error']?.toString() ?? 'Usuario no encontrado en $endpoint';
      } catch (e) {
        lastError = 'Error de conexion en $endpoint: $e';
      }
    }

    return ApiResponse(success: false, error: lastError ?? 'Usuario no encontrado');
  }

  // Helper: parse JSON safely, return null for non-JSON (HTML) responses
  Map<String, dynamic>? _parseJsonSafely(String body) {
    final trimmed = body.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('<')) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // 20. CONFIGURACION DE AGENDA (Actualizado a nuevo esquema)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<Map<String, dynamic>>> getConfigAgenda(int idMedico) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/agenda/config/$idMedico'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return ApiResponse(success: true, data: body['data']);
        }
      }
      return ApiResponse(success: false, error: 'Error cargando configuración');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  Future<ApiResponse<void>> guardarConfigAgenda({
    required int idMedico,
    required int duracionConsulta,
    required String horaInicio,
    required String horaFin,
    required List<int> diasDescanso,
    List<String>? vacaciones,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/agenda/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_medico': idMedico,
          'duracion_consulta': duracionConsulta,
          'hora_inicio': horaInicio,
          'hora_fin': horaFin,
          'dias_libres': diasDescanso,
          'vacaciones': vacaciones,
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResponse(success: body['success'] == true);
      }
      return ApiResponse(success: false, error: 'Error guardando configuración');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 21. RECORDATORIOS
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<List<Map<String, dynamic>>>> getRecordatorios(int idMedico) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/recordatorios/$idMedico'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> recs = body['data'] ?? [];
          return ApiResponse(success: true, data: recs.cast<Map<String, dynamic>>());
        }
      }
      return ApiResponse(success: false, error: 'Error cargando recordatorios');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 22. VERIFICAR DISPONIBILIDAD DEL MEDICO
  // ═══════════════════════════════════════════════════════════════
  List<String> _buildVacacionesList(Map<String, dynamic> body) {
    final dynamic rawVacaciones = body['vacaciones'];
    if (rawVacaciones is List) {
      return rawVacaciones.map((v) => v.toString()).toList();
    }

    final dynamic inicio = body['vacaciones_inicio'];
    final dynamic fin = body['vacaciones_fin'];
    final List<String> vacaciones = [];

    DateTime? parseFecha(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    if (inicio is String && fin is String) {
      final inicioDate = parseFecha(inicio);
      final finDate = parseFecha(fin);
      if (inicioDate != null && finDate != null) {
        for (var date = inicioDate; !date.isAfter(finDate); date = date.add(const Duration(days: 1))) {
          final y = date.year.toString().padLeft(4, '0');
          final m = date.month.toString().padLeft(2, '0');
          final d = date.day.toString().padLeft(2, '0');
          vacaciones.add('$y-$m-$d');
        }
      }
      return vacaciones;
    }

    if (inicio is List && fin is List && inicio.length == fin.length) {
      for (int i = 0; i < inicio.length; i++) {
        final inicioDate = parseFecha(inicio[i]);
        final finDate = parseFecha(fin[i]);
            if (inicioDate != null && finDate != null) {
              for (var date = inicioDate; !date.isAfter(finDate); date = date.add(const Duration(days: 1))) {
                final y = date.year.toString().padLeft(4, '0');
                final m = date.month.toString().padLeft(2, '0');
                final d = date.day.toString().padLeft(2, '0');
                vacaciones.add('$y-$m-$d');
              }
            }
          }
      return vacaciones;
    }

    if (inicio is List) {
      vacaciones.addAll(inicio.map((v) => v.toString()));
      return vacaciones;
    }

    if (fin is List) {
      vacaciones.addAll(fin.map((v) => v.toString()));
      return vacaciones;
    }

    return vacaciones;
  }

  Future<ApiResponse<Map<String, dynamic>>> verificarDisponibilidadMedico(int idMedico) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/medico/disponibilidad/$idMedico'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return ApiResponse(success: true, data: {
            'disponible': body['disponible'],
            'dias_descanso': body['dias_descanso'] ?? body['dias_libres'] ?? [],
            'vacaciones': _buildVacacionesList(body),
            'vacaciones_inicio': body['vacaciones_inicio'],
            'vacaciones_fin': body['vacaciones_fin'],
          });
        }
      }
      return ApiResponse(success: false, error: 'Error verificando disponibilidad');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 23. OBTENER TODOS LOS MEDICOS
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<List<Medico>>> getMedicos() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/medicos'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> jsonList = body['data'];
          final medicos = jsonList.map((j) => Medico.fromJson(j)).toList();
          return ApiResponse(success: true, data: medicos);
        }
      }
      return ApiResponse(success: false, error: 'Error: ${response.statusCode}');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 24. SUBIR FOTO DEL MEDICO (NUEVO - Multer)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<String>> subirFotoMedico(int idMedico, File imagen) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/medicos/subir-foto/$idMedico'),
      );
      final extension = imagen.path.split('.').last.toLowerCase();
      request.files.add(await http.MultipartFile.fromPath(
        'foto',
        imagen.path,
        contentType: MediaType.parse(_getContentType(extension)),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final String? fotoUrl = data['foto_url']?.toString()
            ?? data['avatar_url']?.toString()
            ?? data['foto']?.toString()
            ?? data['url']?.toString()
            ?? data['data']?['foto_url']?.toString()
            ?? data['data']?['avatar_url']?.toString()
            ?? data['data']?['foto']?.toString();
        // Construir URL HTTP completa si es relativa
        final fullUrl = _buildFullImageUrl(fotoUrl);
        return ApiResponse(success: true, data: fullUrl);
      }
      return ApiResponse(success: false, error: data['mensaje'] ?? data['error'] ?? 'Error al subir foto');
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 25. SUBIR FOTO DEL USUARIO (GENÉRICO)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<String>> subirFotoUsuario(int idUsuario, File imagen) async {
    final endpoints = [
      '$_baseUrl/usuario/subir-foto/$idUsuario',
      '$_baseUrl/usuarios/subir-foto/$idUsuario',
      '$_baseUrl/usuario/$idUsuario/subir-foto',
      '$_baseUrl/usuarios/$idUsuario/subir-foto',
    ];

    final extension = imagen.path.split('.').last.toLowerCase();
    final contentType = MediaType.parse(_getContentType(extension));
    String? lastError;

    for (final endpoint in endpoints) {
      try {
        final request = http.MultipartRequest('POST', Uri.parse(endpoint));
        request.headers['Accept'] = 'application/json';
        request.files.add(await http.MultipartFile.fromPath(
          'foto',
          imagen.path,
          contentType: contentType,
        ));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final body = response.body;

        final data = _parseJsonSafely(body);
        if (data == null) {
          // Intentar extraer ruta de imagen desde HTML/plain-text si el servidor responde con otra cosa
          try {
            debugPrint('subirFotoUsuario: respuesta no-JSON desde $endpoint: ${body.length} bytes');
            final snippet = body.length > 1000 ? body.substring(0, 1000) : body;
            debugPrint('subirFotoUsuario snippet: $snippet');

            // 1) Buscar src="...png|jpg" o src='...'
            final srcRegex = RegExp(r"""src=["']([^"']+?\.(?:png|jpg|jpeg|gif|webp))["']""", caseSensitive: false);
            final uploadsRegex = RegExp(r"""(/uploads/[^"'\s<>]+)""", caseSensitive: false);
            final fullUrlRegex = RegExp(r"""(https?:\/\/[^"'\s<>]+?\.(?:png|jpg|jpeg|gif|webp))""", caseSensitive: false);
            final filenameRegex = RegExp(r"""([\w\-/]+?\.(?:png|jpg|jpeg|gif|webp))""", caseSensitive: false);

            String? found;
            final m1 = srcRegex.firstMatch(body);
            if (m1 != null) found = m1.group(1);
            if (found == null) {
              final m2 = uploadsRegex.firstMatch(body);
              if (m2 != null) found = m2.group(1);
            }
            if (found == null) {
              final m3 = fullUrlRegex.firstMatch(body);
              if (m3 != null) found = m3.group(1);
            }
            if (found == null) {
              final m4 = filenameRegex.firstMatch(body);
              if (m4 != null) found = m4.group(1);
            }

            if (found != null && found.isNotEmpty) {
              final path = found.trim();
              final fullUrl = (path.startsWith('http://') || path.startsWith('https://'))
                  ? path
                  : _buildFullImageUrl(path);
              debugPrint('subirFotoUsuario: extrajo URL -> $fullUrl');
              return ApiResponse(success: true, data: fullUrl);
            }
          } catch (e) {
            debugPrint('Error extrayendo URL desde respuesta no-JSON: $e');
          }
          lastError = 'Respuesta no JSON desde $endpoint';
          continue;
        }

        if (response.statusCode == 200 && data['success'] == true) {
          final String? fotoUrl = data['foto_url']?.toString()
              ?? data['avatar_url']?.toString()
              ?? data['foto']?.toString()
              ?? data['url']?.toString()
              ?? data['data']?['foto_url']?.toString()
              ?? data['data']?['avatar_url']?.toString()
              ?? data['data']?['foto']?.toString();
          final fullUrl = _buildFullImageUrl(fotoUrl);
          return ApiResponse(success: true, data: fullUrl);
        }

        lastError = data['mensaje']?.toString() ?? data['error']?.toString() ?? 'Error al subir foto en $endpoint';
      } catch (e) {
        lastError = 'Error de conexion: $e';
      }
    }

    return ApiResponse(success: false, error: lastError ?? 'No fue posible subir la foto');
  }

  // Intento de persistir avatar o preferencias de perfil del usuario en varios endpoints posibles
  Future<ApiResponse<bool>> _actualizarPerfilUsuario(int idUsuario, {
    String? avatarUrl,
    String? preferenciaTema,
  }) async {
    final body = <String, dynamic>{};
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (preferenciaTema != null) body['preferencia_tema'] = preferenciaTema;

    if (body.isEmpty) {
      return ApiResponse(success: false, error: 'No se proporcionaron campos para actualizar', data: false);
    }

    final endpoints = [
      '$_baseUrl/usuarios/perfil/$idUsuario',
      '$_baseUrl/usuario/perfil/$idUsuario',
      '$_baseUrl/usuario/$idUsuario',
      '$_baseUrl/usuarios/$idUsuario',
      '$_baseUrl/usuario/$idUsuario/perfil',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http.put(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (response.statusCode == 200) {
          final parsed = _parseJsonSafely(response.body);
          if (parsed != null) {
            if (parsed['success'] == true || parsed['ok'] == true) {
              return ApiResponse(success: true, data: true);
            }
          } else if (response.body.contains('success') || response.body.contains('ok')) {
            return ApiResponse(success: true, data: true);
          }
        }
      } catch (e) {
        debugPrint('actualizarPerfilUsuario error en $endpoint: $e');
      }
    }
    return ApiResponse(success: false, error: 'No se pudo actualizar el perfil en el servidor', data: false);
  }

  Future<ApiResponse<bool>> actualizarAvatarUsuario(int idUsuario, String avatarUrl) async {
    return _actualizarPerfilUsuario(idUsuario, avatarUrl: avatarUrl);
  }

  Future<ApiResponse<bool>> actualizarPreferenciaTemaUsuario(int idUsuario, String preferenciaTema) async {
    return _actualizarPerfilUsuario(idUsuario, preferenciaTema: preferenciaTema);
  }

  // ═══════════════════════════════════════════════════════════════
  // 26. ACTUALIZAR PERFIL PACIENTE (NUEVO - Avatar y Tema)
  // ═══════════════════════════════════════════════════════════════
  Future<ApiResponse<bool>> actualizarPerfilPaciente(int idPaciente, {
    String? avatarPredeterminado,
    String? preferenciaTema,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (avatarPredeterminado != null) body['avatar_predeterminado'] = avatarPredeterminado;
      if (preferenciaTema != null) body['preferencia_tema'] = preferenciaTema;

      if (body.isEmpty) {
        return ApiResponse(success: false, error: 'No se proporcionaron campos para actualizar', data: false);
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/paciente/perfil/$idPaciente'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse(success: data['success'] == true, data: true);
      }
      return ApiResponse(success: false, error: 'Error al actualizar perfil: ${response.statusCode}', data: false);
    } catch (e) {
      return ApiResponse(success: false, error: 'Error: $e', data: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 26. DESCARGAR REPORTE MENSUAL PDF (NUEVO)
  // ═══════════════════════════════════════════════════════════════
  Future<void> descargarReporteMensual(int idMedico, {int? mes, int? anio}) async {
    try {
      final queryParams = <String, String>{};
      if (mes != null) queryParams['mes'] = mes.toString();
      if (anio != null) queryParams['anio'] = anio.toString();

      final uri = Uri.parse('$_baseUrl/stats/reporte-mensual/$idMedico')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        // Guardar en carpeta de documentos del dispositivo
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'reporte_cdo_${anio ?? DateTime.now().year}_${mes ?? DateTime.now().month}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        // Compartir el archivo
        await Share.shareXFiles([XFile(file.path)], text: 'Reporte mensual CDO Clinic');
      } else {
        throw Exception('Error descargando reporte: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error descargando reporte: $e');
    }
  }
}