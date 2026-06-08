import 'package:flutter/material.dart';

class EstadisticasScreen extends StatelessWidget {
  const EstadisticasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004694),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Dashboard Ejecutivo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Métricas principales
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.event_available,
                    value: '1,248',
                    label: 'Citas Atendidas',
                    gradient: const [
                      Color(0xFF004694),
                      Color(0xFF0066CC),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.cancel_presentation_rounded,
                    value: '12%',
                    label: 'Ausentismo',
                    gradient: const [
                      Color(0xFFE53935),
                      Color(0xFFEF5350),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.trending_up_rounded,
                    value: '342',
                    label: 'Pacientes Nuevos',
                    gradient: const [
                      Color(0xFF4CAF50),
                      Color(0xFF66BB6A),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.star_rounded,
                    value: '4.8',
                    label: 'Satisfacción',
                    gradient: const [
                      Color(0xFFFFB800),
                      Color(0xFFFFCA28),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Gráfica de barras simulada
            const Text(
              'Citas por Mes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBar('Ene', 0.6, const Color(0xFF004694)),
                      _buildBar('Feb', 0.8, const Color(0xFF0066CC)),
                      _buildBar('Mar', 0.5, const Color(0xFF00B4DB)),
                      _buildBar('Abr', 0.9, const Color(0xFF004694)),
                      _buildBar('May', 0.7, const Color(0xFF0066CC)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLegend('Cardiología', const Color(0xFF004694)),
                      _buildLegend('Pediatría', const Color(0xFF0066CC)),
                      _buildLegend('General', const Color(0xFF00B4DB)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Gráfica pastel simulada
            const Text(
              'Especialidades más buscadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPieSlice(
                        color: const Color(0xFF004694),
                        percentage: 0.40,
                        label: '40%',
                      ),
                      const SizedBox(width: 8),
                      _buildPieSlice(
                        color: const Color(0xFF00B4DB),
                        percentage: 0.25,
                        label: '25%',
                      ),
                      const SizedBox(width: 8),
                      _buildPieSlice(
                        color: const Color(0xFF4CAF50),
                        percentage: 0.20,
                        label: '20%',
                      ),
                      const SizedBox(width: 8),
                      _buildPieSlice(
                        color: const Color(0xFFFFB800),
                        percentage: 0.15,
                        label: '15%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      _buildPieLegend(
                        'Cardiología',
                        '40%',
                        const Color(0xFF004694),
                      ),
                      const SizedBox(height: 10),
                      _buildPieLegend(
                        'Pediatría',
                        '25%',
                        const Color(0xFF00B4DB),
                      ),
                      const SizedBox(height: 10),
                      _buildPieLegend(
                        'Ginecología',
                        '20%',
                        const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 10),
                      _buildPieLegend(
                        'Otras',
                        '15%',
                        const Color(0xFFFFB800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String mes, double height, Color color) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 120 * height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                color,
                color.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          mes,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPieSlice({
    required Color color,
    required double percentage,
    required String label,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.7),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPieLegend(String label, String percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2D3748),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}