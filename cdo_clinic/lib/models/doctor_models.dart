class DoctorModel {
  final int id;
  final String nombre;
  final String especialidad;
  final int experiencia;
  final String descripcion;
  final String? foto;
  final double calificacion;
  final String? correo;
  final String? telefono;

  DoctorModel({
    required this.id,
    required this.nombre,
    required this.especialidad,
    required this.experiencia,
    required this.descripcion,
    this.foto,
    this.calificacion = 0.0,
    this.correo,
    this.telefono,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'] ?? 0 Perfecto, continúo con el resto del código. Aquí están los modelos restantes y la corrección del login con la identidad visual premium que solicitaste:

---

## 📂 `lib/models/doctor_model.dart` (continuación)

```dart
      nombre: json['nombre'] ?? '',
      especialidad: json['especialidad'] ?? '',
      experiencia: json['experiencia'] ?? 0,
      descripcion: json['descripcion'] ?? '',
      foto: json['foto'],
      calificacion: (json['calificacion'] ?? 0.0).toDouble(),
      correo: json['correo'],
      telefono: json['telefono'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'especialidad': especialidad,
      'experiencia': experiencia,
      'descripcion': descripcion,
      'foto': foto,
      'calificacion': calificacion,
      'correo': correo,
      'telefono': telefono,
    };
  }

  DoctorModel copyWith({
    int? id,
    String? nombre,
    String? especialidad,
    int? experiencia,
    String? descripcion,
    String? foto,
    double? calificacion,
    String? correo,
    String? telefono,
  }) {
    return DoctorModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      especialidad: especialidad ?? this.especialidad,
      experiencia: experiencia ?? this.experiencia,
      descripcion: descripcion ?? this.descripcion,
      foto: foto ?? this.foto,
      calificacion: calificacion ?? this.calificacion,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
    );
  }
}