import 'package:flutter/material.dart';

class UsuarioModel {
  final int id;
  final String nombre;
  final String apellido;
  final String correo;
  final String telefono;
  final String rol;
  final String? password;
  final String? fotoUrl;
  final String? avatarUrl;
  final DateTime? createdAt;

  UsuarioModel({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.telefono,
    required this.rol,
    this.password,
    this.fotoUrl,
    this.avatarUrl,
    this.createdAt,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id'] ?? json['id_usuario'] ?? 0,
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? json['apellido_paterno'] ?? json['apellido_materno'] ?? '',
      correo: json['correo'] ?? json['email'] ?? '',
      telefono: json['telefono'] ?? json['celular'] ?? '',
      rol: json['rol'] ?? json['role'] ?? 'paciente',
      password: json['password']?.toString(),
      fotoUrl: json['foto_url']?.toString() ?? json['foto']?.toString() ?? json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString() ?? json['foto_url']?.toString() ?? json['foto']?.toString(),
      createdAt: _parseDateTime(json['created_at'] ?? json['fecha_creacion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_usuario': id,
      'nombre': nombre,
      'apellido': apellido,
      'correo': correo,
      'telefono': telefono,
      'rol': rol,
      'password': password,
      'foto_url': fotoUrl,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UsuarioModel copyWith({
    int? id,
    String? nombre,
    String? apellido,
    String? correo,
    String? telefono,
    String? rol,
    String? password,
    String? fotoUrl,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UsuarioModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      password: password ?? this.password,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get iniciales {
    final nombreLimpio = nombre.trim();
    final apellidoLimpio = apellido.trim();
    final primeraInicial = nombreLimpio.isNotEmpty ? nombreLimpio.split(' ').first.characters.first : '';
    final segundaInicial = apellidoLimpio.isNotEmpty ? apellidoLimpio.split(' ').first.characters.first : '';
    final resultado = '${primeraInicial.toUpperCase()}${segundaInicial.toUpperCase()}'.trim();
    return resultado.isNotEmpty ? resultado : '?';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _resolveImageUrl(String baseUrl, String url) {
    final trimmedBase = baseUrl.trim();
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return trimmedUrl;
    if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
      return trimmedUrl;
    }
    if (trimmedBase.endsWith('/') && trimmedUrl.startsWith('/')) {
      return '$trimmedBase${trimmedUrl.substring(1)}';
    }
    if (!trimmedBase.endsWith('/') && !trimmedUrl.startsWith('/')) {
      return '$trimmedBase/$trimmedUrl';
    }
    return '$trimmedBase$trimmedUrl';
  }
}

extension UsuarioAvatarExtension on UsuarioModel {
  // ignore: non_constant_identifier_names
  Widget WidgetAvatarUsuario(String baseUrl) {
    final String? imageUrl =
        fotoUrl != null && fotoUrl!.trim().isNotEmpty
            ? _resolveImageUrl(baseUrl, fotoUrl!.trim())
            : avatarUrl != null && avatarUrl!.trim().isNotEmpty
                ? _resolveImageUrl(baseUrl, avatarUrl!.trim())
                : null;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 32,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (error, stackTrace) {},
        child: const SizedBox.shrink(),
      );
    }

    return CircleAvatar(
      radius: 32,
      backgroundColor: Colors.grey.shade400,
      child: Text(
        iniciales,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
