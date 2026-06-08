import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cdo_clinic/services/clinic_api_service.dart';
import 'package:cdo_clinic/features/paciente/paciente_dashboard.dart';
import 'package:cdo_clinic/features/doctor/doctor_dashboard.dart';
import 'package:cdo_clinic/features/admin/admin_dashboard.dart';
import 'package:cdo_clinic/features/gerente/gerente_dashboard.dart';
import 'package:cdo_clinic/features/recepcion/recepcion_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _regNameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPhoneController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureRegPassword = true;
  bool _showRegister = false;
  bool _isLoading = false;

  late final AnimationController _orbitController;
  late final AnimationController _cardController;
  late final Animation<double> _loginSlide;
  late final Animation<double> _registerSlide;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loginSlide = Tween<double>(begin: 0, end: -1).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeInOutCubic),
    );

    _registerSlide = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeInOutCubic),
    );
  }

  void _toggleAuthMode() {
    setState(() { _showRegister = !_showRegister; });
    if (_showRegister) {
      _cardController.forward();
    } else {
      _cardController.reverse();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    _orbitController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGIN - INTEGRADO CON BACKEND REAL
  // ═══════════════════════════════════════════════════════════════
  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showSnack('Por favor completa todos los campos', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ClinicApiService();
      final res = await api.login(_emailController.text.trim(), _passwordController.text);

      if (res.success && res.data != null) {
        // Extraer datos del usuario de la respuesta del backend
        final data = res.data!;
        final usuario = data['usuario'] is Map<String, dynamic>
            ? data['usuario'] as Map<String, dynamic>
            : data['data'] is Map<String, dynamic>
                ? data['data'] as Map<String, dynamic>
                : null;
        if (usuario == null) {
          _showSnack('Respuesta de usuario inválida.', Colors.red);
          return;
        }

        final nombre = '${usuario['nombre'] ?? ''} ${usuario['apellido'] ?? ''}'.trim();
        final correo = usuario['correo'] as String? ?? usuario['email'] as String? ?? '';
        final telefono = usuario['telefono'] as String? ?? usuario['celular'] as String?;

        final idUsuario = usuario['id'] as int? ?? usuario['id_usuario'] as int? ?? int.tryParse(usuario['id']?.toString() ?? '');
        final rawRol = usuario['rol'] as String? ?? usuario['role'] as String? ?? usuario['tipo'] as String?;
        final rol = _normalizeRole(rawRol);

        if (idUsuario != null) {
          api.setUsuario(idUsuario);
        }
        if (rawRol != null) {
          api.setRolUsuario(rawRol);
        }

        if (!mounted) return;

        debugPrint('ROL DEL USUARIO: $rawRol -> $rol');

        switch (rol) {
          case 'medico':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DoctorDashboard()),
            );
            break;
          case 'administrador':
          case 'admin':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboard()),
            );
            break;
          case 'gerente':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => EstadisticasScreen()),
            );
            break;
          case 'recepcion':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const RecepcionDashboard()),
            );
            break;
          default:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PacienteDashboard(
                  nombrePaciente: nombre,
                  correoPaciente: correo,
                  telefonoPaciente: telefono,
                ),
              ),
            );
        }
      } else {
        _showSnack(res.error ?? 'Credenciales incorrectas', Colors.red);
      }
    } catch (e) {
      _showSnack('Error de conexion: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // REGISTRO - INTEGRADO CON BACKEND REAL
  // Usa api.registro() segun la especificacion del ClinicApiService
  // ═══════════════════════════════════════════════════════════════
  Future<void> _handleRegister() async {
    if (_regNameController.text.trim().isEmpty || 
        _regEmailController.text.trim().isEmpty || 
        _regPasswordController.text.isEmpty) {
      _showSnack('Por favor llena los campos obligatorios', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ClinicApiService();
      final res = await api.registro(
        nombre: _regNameController.text.trim(),
        email: _regEmailController.text.trim(),
        telefono: _regPhoneController.text.trim(),
        password: _regPasswordController.text,
      );

      if (res.success) {
        _showSnack('Registro exitoso! Por favor inicia sesion', Colors.green);
        _emailController.text = _regEmailController.text;
        _toggleAuthMode();
      } else {
        _showSnack(res.error ?? 'Error en el registro', Colors.red);
      }
    } catch (e) {
      _showSnack('Error en el servidor: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF050A1F), Color(0xFF0A1628), Color(0xFF0D1B3E), Color(0xFF0A1628)],
          ),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _orbitController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: NeonOrbitPainter(progress: _orbitController.value),
                );
              },
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004694).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3), width: 2),
                          boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
                        ),
                        child: const Icon(Icons.local_hospital_rounded, size: 60, color: Color(0xFF00D4FF)),
                      ),
                      const SizedBox(height: 32),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF80E5FF), Color(0xFF00D4FF)],
                        ).createShader(bounds),
                        child: const Text(
                          'Centro Diagnostico\nOccidente',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2, letterSpacing: 1.2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Tu salud, nuestra prioridad', style: TextStyle(fontSize: 14, color: const Color(0xFF00D4FF).withOpacity(0.6), fontStyle: FontStyle.italic, letterSpacing: 2)),
                      const SizedBox(height: 40),
                      Stack(
                          children: [
                            AnimatedBuilder(
                              animation: _loginSlide,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(_loginSlide.value * MediaQuery.of(context).size.width, 0),
                                  child: Opacity(opacity: 1 - _cardController.value, child: _buildLoginCard()),
                                );
                              },
                            ),
                            AnimatedBuilder(
                              animation: _registerSlide,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(_registerSlide.value * MediaQuery.of(context).size.width, 0),
                                  child: Opacity(opacity: _cardController.value, child: _buildRegisterCard()),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Iniciar Sesion', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _input(controller: _emailController, icon: Icons.email_outlined, label: 'Correo Electronico', hint: 'ejemplo@cdo.com'),
          const SizedBox(height: 20),
          _input(controller: _passwordController, icon: Icons.lock_outline, label: 'Contrasena', hint: '••••••••', obscure: _obscurePassword, suffix: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.5)),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004694), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Ingresar al Sistema', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : _toggleAuthMode,
              child: const Text('No tienes cuenta? Registrate aqui', style: TextStyle(color: Color(0xFF00D4FF))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Crear Cuenta', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _input(controller: _regNameController, icon: Icons.person_outline, label: 'Nombre Completo', hint: 'Juan Perez'),
          const SizedBox(height: 14),
          _input(controller: _regEmailController, icon: Icons.email_outlined, label: 'Correo Electronico', hint: 'juan@cdo.com'),
          const SizedBox(height: 14),
          _input(controller: _regPhoneController, icon: Icons.phone_outlined, label: 'Telefono', hint: '04141234567'),
          const SizedBox(height: 14),
          _input(controller: _regPasswordController, icon: Icons.lock_outline, label: 'Contrasena', hint: 'Minimo 6 caracteres', obscure: _obscureRegPassword, suffix: IconButton(
            icon: Icon(_obscureRegPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.5)),
            onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Finalizar Registro', style: TextStyle(color: Color(0xFF050A1F), fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : _toggleAuthMode,
              child: const Text('Ya tienes cuenta? Inicia sesion', style: TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input({required TextEditingController controller, required IconData icon, required String label, required String hint, bool obscure = false, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF00D4FF).withOpacity(0.7), size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 1)),
          ),
        ),
      ],
    );
  }
}

class NeonOrbitPainter extends CustomPainter {
  final double progress;
  NeonOrbitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.4);
    _drawOrbit(canvas, center, size.width * 0.5, progress * 360, const Color(0xFF00D4FF), 0.1, 1.0);
    _drawOrbit(canvas, center, size.width * 0.7, progress * 180, const Color(0xFF004694), 0.04, 2.0);
  }

  void _drawOrbit(Canvas canvas, Offset center, double radius, double rotation, Color color, double opacity, double strokeWidth) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final rect = Rect.fromCenter(center: center, width: radius * 2, height: radius * 2 * 0.6);
    final matrix4 = Matrix4.identity()..translate(center.dx, center.dy)..rotateZ(rotation * pi / 180)..translate(-center.dx, -center.dy);

    path.addOval(rect);
    canvas.save();
    canvas.transform(matrix4.storage);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NeonOrbitPainter oldDelegate) => oldDelegate.progress != progress;
}