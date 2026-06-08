import 'package:flutter/material.dart';
import 'perfil_doctor_detail_screen.dart';

class DoctoresPorEspecialidadScreen extends StatelessWidget {
  final String especialidad;

  const DoctoresPorEspecialidadScreen({
    super.key,
    required this.especialidad,
  });

  final List<Map<String, dynamic>> doctores = const [
    {
      'nombre': 'Dr. Carlos Mendoza',
      'especialidad': 'Cardiología',
      'experiencia': 15,
      'calificacion': 4.9,
      'descripcion':
          'Especialista en cardiología intervencionista con más de 15 años de experiencia en el tratamiento de enfermedades cardiovasculares. Graduado de la Universidad Nacional.',
      'color': Color(0xFFFF6B6B),
    },
    {
      'nombre': 'Dra. María Fernández',
      'especialidad': 'Cardiología',
      'experiencia': 12,
      'calificacion': 4.8,
      'descripcion':
          'Cardióloga especializada en ecocardiografía y manejo de insuficiencia cardíaca. Miembro activo de la Sociedad Colombiana de Cardiología.',
      'color': Color(0xFFFF8C42),
    },
    {
      'nombre': 'Dr. Andrés López',
      'especialidad': 'Cardiología',
      'experiencia': 20,
      'calificacion': 5.0,
      'descripcion':
          'Médico cirujano cardiovascular con amplia trayectoria en cirugía de revascularización miocárdica y reemplazo valvular.',
      'color': Color(0xFF667EEA),
    },
    {
      'nombre': 'Dra. Laura Gómez',
      'especialidad': 'Cardiología',
      'experiencia': 8,
      'calificacion': 4.7,
      'descripcion':
          'Especialista en cardiología pediátrica. Enfoque en prevención y tratamiento de cardiopatías congénitas.',
      'color': Color(0xFF4ECDC4),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1565C0),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                especialidad,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF0D47A1),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final doctor = doctores[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PerfilDoctorDetailScreen(
                            doctor: doctor,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    doctor['color'],
                                    doctor['color'].withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: Text(
                                  doctor['nombre']
                                      .toString()
                                      .split(' ')[1][0],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doctor['nombre'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    doctor['especialidad'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1565C0)
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 14,
                                              color: Color(0xFFFFB800),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${doctor['calificacion']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1565C0),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${doctor['experiencia']} años exp.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: doctores.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}