import 'package:flutter/material.dart';
import 'package:cdo_clinic/models/cita_model.dart';

class MisCitasPacienteScreen extends StatefulWidget {
  const MisCitasPacienteScreen({super.key});

  @override
  State<MisCitasPacienteScreen> createState() => _MisCitasPacienteScreenState();
}

class _MisCitasPacienteScreenState extends State<MisCitasPacienteScreen> {
  final List<Map<String, dynamic>> citas = [
    {
      'id': 1,
      'dia': '25',
      'mes': 'May',
      'hora': '09:30 AM',
      'doctor': 'Dr. Carlos Mendoza',
      'especialidad': 'Cardiología',
      'estado': 'Pendiente',
      'colorEstado': const Color(0xFFFFB800),
      'bgEstado': const Color(0xFFFFF8E1),
    },
    {
      'id': 2,
      'dia': '20',
      'mes': 'May',
      'hora': '11:00 AM',
      'doctor': 'Dra. María Fernández',
      'especialidad': 'Cardiología',
      'estado': 'Completada',
      'colorEstado': const Color(0xFF4CAF50),
      'bgEstado': const Color(0xFFE8F5E9),
    },
    {
      'id': 3,
      'dia': '15',
      'mes': 'May',
      'hora': '02:00 PM',
      'doctor': 'Dr. Andrés López',
      'especialidad': 'Cardiología',
      'estado': 'Cancelada',
      'colorEstado': const Color(0xFFE53935),
      'bgEstado': const Color(0xFFFFEBEE),
    },
    {
      'id': 4,
      'dia': '10',
      'mes': 'May',
      'hora': '10:00 AM',
      'doctor': 'Dra. Laura Gómez',
      'especialidad': 'Cardiología',
      'estado': 'Completada',
      'colorEstado': const Color(0xFF4CAF50),
      'bgEstado': const Color(0xFFE8F5E9),
    },
    {
      'id': 5,
      'dia': '28',
      'mes': 'May',
      'hora': '04:30 PM',
      'doctor': 'Dr. Carlos Mendoza',
      'especialidad': 'Cardiología',
      'estado': 'Pendiente',
      'colorEstado': const Color(0xFFFFB800),
      'bgEstado': const Color(0xFFFFF8E1),
    },
  ];

  void _reprogramarCita(int id) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reprogramando cita #$id...'),
        backgroundColor: const Color(0xFF004694),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004694),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mis Citas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: citas.length,
        itemBuilder: (context, index) {
          final cita = citas[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Fecha circular
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF004694), Color(0xFF0066CC)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cita['dia'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          cita['mes'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cita['doctor'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cita['especialidad'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cita['hora'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: cita['bgEstado'],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                cita['estado'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: cita['colorEstado'],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Botón reprogramar
                  if (cita['estado'] == 'Pendiente')
                    GestureDetector(
                      onTap: () => _reprogramarCita(cita['id']),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004694).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_calendar_rounded,
                          color: Color(0xFF004694),
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}