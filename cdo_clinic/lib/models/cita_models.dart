class Cita {
  final int idCita;
  final int idPaciente;
  final int idMedico;
  final DateTime fecha;
  final String hora;
  final String motivo;
  final String estado; // 'Pendiente', 'Confirmada', 'Reagendada', 'En Progreso', 'Completada', 'Cancelada'
  final String? modificadoPor; // 'Paciente', 'Medico', 'Recepcion' o null
  final DateTime? horaInicio;
  final DateTime? horaFin;
  final String? medicoNombre;
  final String? pacienteNombre;
  final String? examenUrl;
  final DateTime? createdAt;

  Cita({
    required this.idCita,
    required this.idPaciente,
    required this.idMedico,
    required this.fecha,
    required this.hora,
    required this.motivo,
    this.estado = 'Pendiente',
    this.modificadoPor,
    this.horaInicio,
    this.horaFin,
    this.medicoNombre,
    this.pacienteNombre,
    this.examenUrl,
    this.createdAt,
  });

  /// ¿La cita puede ser modificada? (no cancelada ni completada)
  bool get puedeModificarse {
    final e = estado.toLowerCase();
    return e != 'cancelada' && e != 'completada';
  }

  /// ¿La cita puede iniciarse? (solo pendiente o reagendada)
  bool get puedeIniciarse {
    final e = estado.toLowerCase();
    return e == 'pendiente' || e == 'reagendada';
  }

  /// ¿La cita puede finalizarse? (solo en progreso)
  bool get puedeFinalizarse {
    return estado.toLowerCase() == 'en progreso';
  }

  /// Mensaje de auditoría legible
  String? get mensajeAuditoria {
    if (modificadoPor == null) return null;
    
    final quien = switch (modificadoPor) {
      'Paciente' => 'el paciente',
      'Medico' => 'el médico',
      'Recepcion' => 'recepción',
      _ => 'sistema',
    };
    
    return switch (estado) {
      'Cancelada' => 'Cancelada por $quien',
      'Reagendada' => 'Reagendada por $quien',
      _ => null,
    };
  }

  /// Color según estado (SEMÁFORO VISUAL)
  Color get colorEstado {
    return switch (estado.toLowerCase()) {
      'pendiente' => const Color(0xFFFFB800), // Amarillo
      'confirmada' => const Color(0xFF4CAF50), // Verde
      'reagendada' => const Color(0xFF2196F3), // Azul
      'en progreso' => const Color(0xFF00BCD4), // Cyan/Verde claro
      'completada' => const Color(0xFF2E7D32), // Verde oscuro
      'cancelada' => const Color(0xFFE53935), // Rojo
      'no asistio' => const Color(0xFF9E9E9E), // Gris
      _ => Colors.grey,
    };
  }

  /// Nombre legible del estado
  String get estadoLegible {
    return switch (estado.toLowerCase()) {
      'pendiente' => 'Pendiente',
      'confirmada' => 'Confirmada',
      'reagendada' => 'Reagendada',
      'en progreso' => 'En Progreso',
      'completada' => 'Completada',
      'cancelada' => 'Cancelada',
      _ => estado,
    };
  }

  DateTime get fechaHora {
    try {
      final partesHora = hora.split(':');
      if (partesHora.length >= 2) {
        final horas = int.parse(partesHora[0]);
        final minutos = int.parse(partesHora[1]);
        return DateTime(fecha.year, fecha.month, fecha.day, horas, minutos);
      }
    } catch (_) {}
    return fecha;
  }

  factory Cita.fromJson(Map<String, dynamic> json) {
    DateTime? parseFecha(dynamic val) {
      if (val == null) return null;
      try { return DateTime.parse(val.toString()); } catch (_) { return null; }
    }

    final fechaHoraRaw = json['fecha_hora'];
    DateTime fechaBase;
    String horaStr;
    
    if (fechaHoraRaw != null) {
      final dt = DateTime.parse(fechaHoraRaw.toString());
      fechaBase = DateTime(dt.year, dt.month, dt.day);
      horaStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      fechaBase = json['fecha'] != null ? DateTime.parse(json['fecha']) : DateTime.now();
      horaStr = json['hora'] ?? '';
    }

    return Cita(
      idCita: json['id_cita'] ?? json['id'] ?? 0,
      idPaciente: json['id_paciente'] ?? json['paciente_id'] ?? 0,
      idMedico: json['id_medico'] ?? json['doctor_id'] ?? 0,
      fecha: fechaBase,
      hora: horaStr,
      motivo: json['motivo'] ?? json['sintomas'] ?? '',
      estado: json['estado'] ?? 'Pendiente',
      modificadoPor: json['modificado_por'],
      horaInicio: parseFecha(json['hora_inicio']),
      horaFin: parseFecha(json['hora_fin']),
      medicoNombre: json['medico_nombre'] ?? json['doctor_nombre'] ?? json['nombre_medico'] ?? null,
      pacienteNombre: json['paciente_nombre'] ?? json['pacienteName'] ?? null,
      examenUrl: json['examen_url'],
      createdAt: parseFecha(json['fecha_creacion'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_cita': idCita,
      'id_paciente': idPaciente,
      'id_medico': idMedico,
      'fecha_hora': '${fecha.toIso8601String().split('T')[0]} $hora:00',
      'motivo': motivo,
      'estado': estado,
      'modificado_por': modificadoPor,
      'hora_inicio': horaInicio?.toIso8601String(),
      'hora_fin': horaFin?.toIso8601String(),
      'examen_url': examenUrl,
      'fecha_creacion': createdAt?.toIso8601String(),
    };
  }

  Cita copyWith({
    int? idCita,
    int? idPaciente,
    int? idMedico,
    DateTime? fecha,
    String? hora,
    String? motivo,
    String? estado,
    String? modificadoPor,
    DateTime? horaInicio,
    DateTime? horaFin,
    String? medicoNombre,
    String? pacienteNombre,
    String? examenUrl,
    DateTime? createdAt,
  }) {
    return Cita(
      idCita: idCita ?? this.idCita,
      idPaciente: idPaciente ?? this.idPaciente,
      idMedico: idMedico ?? this.idMedico,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      motivo: motivo ?? this.motivo,
      estado: estado ?? this.estado,
      modificadoPor: modificadoPor ?? this.modificadoPor,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      medicoNombre: medicoNombre ?? this.medicoNombre,
      pacienteNombre: pacienteNombre ?? this.pacienteNombre,
      examenUrl: examenUrl ?? this.examenUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}