// lib/models/clinic_models.dart

import 'package:flutter/material.dart';

// ─── MODELO DE CITAS ───
class Cita {
  final int idCita;
  final int idPaciente;
  final int idMedico;
  final DateTime fechaHora;
  final String motivo;
  final String estado;
  final DateTime? horaInicio;
  final DateTime? horaFin;
  final String? mensajeAuditoria;
  final String? medicoNombre;
  final String? pacienteNombre;

  Cita({
    required this.idCita,
    required this.idPaciente,
    required this.idMedico,
    required this.fechaHora,
    required this.motivo,
    required this.estado,
    this.horaInicio,
    this.horaFin,
    this.mensajeAuditoria,
    this.medicoNombre,
    this.pacienteNombre,
  });

  factory Cita.fromJson(Map<String, dynamic> json) => Cita(
        idCita: json['id_cita'] ?? json['id'] ?? 0,
        idPaciente: json['id_paciente'] ?? json['paciente_id'] ?? 0,
        idMedico: json['id_medico'] ?? json['doctor_id'] ?? 0,
        fechaHora: json['fecha_hora'] != null 
            ? DateTime.parse(json['fecha_hora']) 
            : (json['fecha'] != null ? DateTime.parse(json['fecha']) : DateTime.now()),
        motivo: json['motivo'] ?? json['sintomas'] ?? '',
        estado: json['estado'] ?? 'Pendiente',
        horaInicio: json['hora_inicio'] != null
            ? DateTime.parse(json['hora_inicio'])
            : (json['horaInicio'] != null ? DateTime.parse(json['horaInicio']) : null),
        horaFin: json['hora_fin'] != null
            ? DateTime.parse(json['hora_fin'])
            : (json['horaFin'] != null ? DateTime.parse(json['horaFin']) : null),
        mensajeAuditoria: json['mensaje_auditoria'] ?? json['mensajeAuditoria'] ?? json['mensaje'] ?? null,
        medicoNombre: json['medicoNombre'] ?? json['doctor_nombre'] ?? json['nombre_medico'] ?? json['medico_nombre'] ?? json['doctorName'],
        pacienteNombre: json['pacienteNombre'] ?? json['paciente_nombre'] ?? json['nombre_paciente'] ?? null,
      );

  Map<String, dynamic> toJson() => {
        'id_cita': idCita,
        'id_paciente': idPaciente,
        'id_medico': idMedico,
        'fecha_hora': fechaHora.toIso8601String(),
        'motivo': motivo,
        'estado': estado,
        'hora_inicio': horaInicio?.toIso8601String(),
        'hora_fin': horaFin?.toIso8601String(),
        'mensaje_auditoria': mensajeAuditoria,
        'paciente_nombre': pacienteNombre,
      };

  Color get colorEstado {
    final estadoLower = estado.toLowerCase();
    if (estadoLower.contains('pendiente')) return const Color(0xFFFFB800);
    if (estadoLower.contains('en progreso') || estadoLower.contains('progreso')) return const Color(0xFF4CAF50);
    if (estadoLower.contains('completada') || estadoLower.contains('completado')) return const Color(0xFF4CAF50);
    if (estadoLower.contains('cancelada') || estadoLower.contains('cancelado')) return const Color(0xFFE53935);
    return const Color(0xFF05006B);
  }

  bool get puedeModificarse => estado.toLowerCase() == 'pendiente';

  bool get puedeIniciarse {
    final estadoLower = estado.toLowerCase();
    return estadoLower == 'pendiente' || estadoLower == 'reagendada' || estadoLower == 'en progreso';
  }

  bool get puedeFinalizarse {
    return estado.toLowerCase() == 'en progreso' || estado.toLowerCase() == 'completada';
  }

  String get estadoLegible {
    final estadoLower = estado.toLowerCase();
    if (estadoLower.contains('pendiente')) return 'Pendiente';
    if (estadoLower.contains('en progreso') || estadoLower.contains('progreso')) return 'En progreso';
    if (estadoLower.contains('completada') || estadoLower.contains('completado')) return 'Completada';
    if (estadoLower.contains('cancelada') || estadoLower.contains('cancelado')) return 'Cancelada';
    return estado;
  }
}

// ─── MODELO MÉDICO (DOCTOR) EXTANDIDO ───
class Medico {
  final int idMedico;
  final String nombre;
  final String? apellido;
  final String especialidad;
  final int experiencia;
  final String descripcion;
  final String? foto;
  final double calificacion;
  final String? correo;
  final String? telefono;
  final String? consultorio;

  Medico({
    required this.idMedico,
    required this.nombre,
    this.apellido,
    required this.especialidad,
    required this.experiencia,
    required this.descripcion,
    this.foto,
    this.calificacion = 0.0,
    this.correo,
    this.telefono,
    this.consultorio,
  });

  factory Medico.fromJson(Map<String, dynamic> json) => Medico(
        idMedico: json['id_medico'] ?? json['id'] ?? 0,
        nombre: json['nombre'] ?? '',
        apellido: json['apellido'] ?? json['apellido_paterno'] ?? json['apellido_materno'] ?? null,
        especialidad: json['especialidad'] ?? '',
        experiencia: json['experiencia'] ?? 0,
        descripcion: json['descripcion'] ?? '',
        foto: json['foto'] ?? json['fotoUrl'] ?? json['foto_url'],
        calificacion: (json['calificacion'] ?? 0.0).toDouble(),
        correo: json['correo'],
        telefono: json['telefono'],
        consultorio: json['consultorio'] ?? json['consultorio_nombre'] ?? json['sucursal'] ?? null,
      );

  Map<String, dynamic> toJson() => {
        'id_medico': idMedico,
        'nombre': nombre,
        'apellido': apellido,
        'especialidad': especialidad,
        'experiencia': experiencia,
        'descripcion': descripcion,
        'foto': foto,
        'calificacion': calificacion,
        'correo': correo,
        'telefono': telefono,
        'consultorio': consultorio,
      };

  String? get fotoUrl => foto;
  int? get anosExperiencia => experiencia;
  String? get resenaProfesional => descripcion;
}

// ─── MODELO DE USUARIOS ───
class Usuario {
  final int idUsuario;
  final String nombre;
  final String correo;
  final String telefono;
  final String rol;
  final String? apellido;
  final String? avatarUrl;
  final String? password;
  final DateTime? createdAt;

  Usuario({
    required this.idUsuario,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.rol,
    this.apellido,
    this.avatarUrl,
    this.password,
    this.createdAt,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        idUsuario: json['id_usuario'] ?? json['id'] ?? 0,
        nombre: json['nombre'] ?? '',
        correo: json['correo'] ?? '',
        telefono: json['telefono'] ?? '',
      rol: json['rol'] ?? 'paciente',
        apellido: json['apellido'] ?? json['apellido_paterno'] ?? json['apellido_materno'] ?? null,
        avatarUrl: json['avatarUrl'] ?? json['avatar_url'] ?? json['foto'] ?? null,
        password: json['password'],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id_usuario': idUsuario,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'rol': rol,
        'apellido': apellido,
        'avatar_url': avatarUrl,
        'password': password,
        'created_at': createdAt?.toIso8601String(),
      };
}

// Añadimos un getter `fotoUrl` para que el código UI pueda usar una URL completa
extension UsuarioFotoUrl on Usuario {
  String? get fotoUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    const String serverUrl = 'http://localhost:3000';
    final url = avatarUrl!;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final path = url.startsWith('/') ? url : '/$url';
    return '$serverUrl$path';
  }
}

class DoctorUsuario {
  final int id;
  final String nombre;
  final String apellido;
  final String? rol;
  final String? especialidad;
  final String? licenciaMedica;
  final String? consultorio;
  final String? correo;
  final String? telefono;
  final String? avatarUrl;

  /// Devuelve URL HTTP completa, construyendo la URL si es relativa
  String? get fotoUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    const String serverUrl = 'http://localhost:3000';
    final url = avatarUrl!;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // Rutas relativas: /uploads/... o uploads/...
    final path = url.startsWith('/') ? url : '/$url';
    return '$serverUrl$path';
  }

  DoctorUsuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    this.rol,
    this.especialidad,
    this.licenciaMedica,
    this.consultorio,
    this.correo,
    this.telefono,
    this.avatarUrl,
  });

  factory DoctorUsuario.fromJson(Map<String, dynamic> json) {
    final fullName = json['nombre_completo'] ?? json['nombre'] ?? '';
    final apellido = json['apellido'] ?? json['apellido_paterno'] ?? json['apellido_materno'] ?? _extraerApellido(fullName);
    final nombre = json['nombre'] ?? _extraerNombre(fullName);

    return DoctorUsuario(
      id: json['id'] ?? json['id_usuario'] ?? json['medico_id'] ?? 0,
      nombre: nombre,
      apellido: apellido,
      rol: json['rol'] ?? json['role'] ?? json['tipo'] ?? json['tipo_usuario'] ?? null,
      especialidad: json['especialidad'] ?? json['especialidad_doctor'] ?? null,
      licenciaMedica: json['licencia_medica'] ?? json['licencia'] ?? null,
      consultorio: json['consultorio'] ?? json['consultorio_nombre'] ?? json['sucursal'] ?? null,
      correo: json['correo'] ?? json['email'] ?? json['correo_electronico'] ?? null,
      telefono: json['telefono'] ?? json['celular'] ?? json['telefono_movil'] ?? null,
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'] ?? json['foto'] ?? json['foto_url'] ?? json['url'] ?? null,
    );
  }

  static String _extraerNombre(String fullName) {
    final partes = fullName.split(' ').where((part) => part.isNotEmpty).toList();
    return partes.isNotEmpty ? partes.first : '';
  }

  static String _extraerApellido(String fullName) {
    final partes = fullName.split(' ').where((part) => part.isNotEmpty).toList();
    if (partes.length <= 1) return '';
    return partes.sublist(1).join(' ');
  }
}

// ─── MODELO DE MENSAJES PARA EL CHAT (CORREGIDO Y SINCRONIZADO) ───
class Mensaje {
  final int idMensaje;
  final int idPaciente;
  final int idMedico;
  final String remitente; // Puede ser 'paciente' o 'medico'
  final String contenidoTexto;
  final String? recipeDigital;
  final String? resultadoAdjuntoUrl;
  final DateTime fechaEnvio;

  Mensaje({
    required this.idMensaje,
    required this.idPaciente,
    required this.idMedico,
    required this.remitente,
    required this.contenidoTexto,
    this.recipeDigital,
    this.resultadoAdjuntoUrl,
    required this.fechaEnvio,
  });

  factory Mensaje.fromJson(Map<String, dynamic> json) => Mensaje(
        idMensaje: json['id_mensaje'] ?? 0,
        idPaciente: json['id_paciente'] ?? 0,
        idMedico: json['id_medico'] ?? 0,
        remitente: json['remitente'] ?? 'paciente', // Valor por defecto seguro
        contenidoTexto: json['contenido_texto'] ?? json['contenido'] ?? '',
        recipeDigital: json['recipe_digital'],
        resultadoAdjuntoUrl: json['resultado_adjunto_url'],
        fechaEnvio: json['fecha_envio'] != null
            ? DateTime.parse(json['fecha_envio'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id_mensaje': idMensaje,
        'id_paciente': idPaciente,
        'id_medico': idMedico,
        'remitente': remitente,
        'contenido_texto': contenidoTexto,
        'recipe_digital': recipeDigital,
        'resultado_adjunto_url': resultadoAdjuntoUrl,
        'fecha_envio': fechaEnvio.toIso8601String(),
      };

  // 💡 Funciones extra (Getters) útiles para pintar la UI del Chat
  bool esEmitidoPorMi(int idUsuarioActual, String rolUsuarioActual) {
    final remitenteNormalized = remitente.toLowerCase();
    if (rolUsuarioActual == 'paciente' && remitenteNormalized == 'paciente' && idUsuarioActual == idPaciente) {
      return true;
    }
    if (rolUsuarioActual == 'medico' && remitenteNormalized == 'medico' && idUsuarioActual == idMedico) {
      return true;
    }
    return false;
  }

  // Compatibilidad: algunos lugares esperan `contenido`
  String get contenido => contenidoTexto;
}


// ─── MODELO HISTORIA CLÍNICA ───
class HistoriaClinica {
  final int idHistoria;
  final int idPaciente;
  final DateTime fechaConsulta;
  final DateTime? fechaRegistro;
  final String sintomas;
  final String diagnostico;
  final String tratamiento;
  final String? recetaDigital;
  final String? notasPrivadas;
  final List<Receta>? recipes;

  HistoriaClinica({
    required this.idHistoria,
    required this.idPaciente,
    required this.fechaConsulta,
    required this.sintomas,
    required this.diagnostico,
    required this.tratamiento,
    this.recetaDigital,
    this.notasPrivadas,
    this.fechaRegistro,
    this.recipes,
  });

  factory HistoriaClinica.fromJson(Map<String, dynamic> json) => HistoriaClinica(
        idHistoria: json['id_historia'] ?? 0,
        idPaciente: json['id_paciente'] ?? 0,
        fechaConsulta: DateTime.parse(json['fecha_consulta'] ?? json['fecha'] ?? DateTime.now().toString()),
        fechaRegistro: json['fecha_registro'] != null ? DateTime.parse(json['fecha_registro']) : null,
        sintomas: json['sintomas'] ?? '',
        diagnostico: json['diagnostico'] ?? '',
        tratamiento: json['tratamiento'] ?? '',
        recetaDigital: json['receta_digital'],
        notasPrivadas: json['notas_privadas'] ?? json['notasPrivadas'] ?? null,
        recipes: json['recipes'] != null
            ? (json['recipes'] as List).map((r) => Receta.fromJson(r)).toList()
            : (json['recetas'] != null ? (json['recetas'] as List).map((r) => Receta.fromJson(r)).toList() : null),
      );

  Map<String, dynamic> toJson() => {
        'id_historia': idHistoria,
        'id_paciente': idPaciente,
        'fecha_consulta': fechaConsulta.toIso8601String(),
        'fecha_registro': fechaRegistro?.toIso8601String(),
        'sintomas': sintomas,
        'diagnostico': diagnostico,
        'tratamiento': tratamiento,
        'receta_digital': recetaDigital,
        'notas_privadas': notasPrivadas,
      };
}

      // Modelo de receta simple para historias
      class Receta {
        final String medicamento;
        final String dosis;
        final String frecuencia;
        final String duracion;

        Receta({required this.medicamento, required this.dosis, required this.frecuencia, required this.duracion});

        factory Receta.fromJson(Map<String, dynamic> json) => Receta(
          medicamento: json['medicamento'] ?? json['name'] ?? '',
          dosis: json['dosis'] ?? json['dose'] ?? '',
          frecuencia: json['frecuencia'] ?? json['frequency'] ?? '',
          duracion: json['duracion'] ?? json['duration'] ?? '',
        );

        Map<String, dynamic> toJson() => {
          'medicamento': medicamento,
          'dosis': dosis,
          'frecuencia': frecuencia,
          'duracion': duracion,
        };
      }

// ─── RESPUESTA ESTANDARIZADA DEL BACKEND ───
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse({required this.success, this.data, this.error});
}

// Clase de utilidades para validaciones rápidas requerida en el Chat
class Validators {
  static String? mensajeChat(String text, bool tieneArchivo) {
    if (text.trim().isEmpty && !tieneArchivo) {
      return 'El mensaje no puede estar vacío';
    }
    return null;
  }
}
