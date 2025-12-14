import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Pantalla_Tabla_Usuarios.dart';
import 'Pantalla_Principal.dart';
import '../servicios/Autenticacion.dart';
import '../servicios/Usuario.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const int tipoPaciente = 1;
  static const int tipoPsicologo = 2;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Autenticacion _authService = Autenticacion();
  bool _isLoading = false;
  bool _obscurePassword = true;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Usuario',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Contraseña',

                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : () async {
                // Validar campos vacíos
                if (_emailController.text.isEmpty ||
                    _passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor completa todos los campos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  _isLoading = true;
                });

                // Intentar login
                final resultado = await _authService.login(
                  _emailController.text.trim(),
                  _passwordController.text,
                );

                setState(() {
                  _isLoading = false;
                });

                if (resultado['success']) {
                  // Login exitoso
                  print('═══════════════════════════════════');
                  print('🔍 Resultado completo: $resultado');
                  print('🔍 Data completa: ${resultado['data']}');
                  
                  final data = resultado['data'];
                  print('🔍 Data.usuario: ${data['usuario']}');
                  print('🔍 Data.usuario.id: ${data['usuario']?['id']}');
                  print('🔍 Data.usuario.usuario: ${data['usuario']?['usuario']}');
                  
                  final usuario = data['usuario'];
                  print('🔍 Objeto usuario: $usuario');
                  print('🔍 usuario.id: ${usuario['id']}');
                  print('🔍 usuario.usuario: ${usuario['usuario']}');
                  
                  if (usuario == null) {
                    print('❌ ERROR: usuario es null!');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: No se pudo obtener datos del usuario'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (mounted) {
                    final nombreUsuario = usuario['usuario'] ?? usuario['nombre'] ?? 'Usuario';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('¡Bienvenido $nombreUsuario!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    final tipoUsuario = usuario['tipo_usuario'];
                    final esPsicologo = tipoUsuario == tipoPsicologo ||
                        (tipoUsuario is String &&
                            tipoUsuario.toLowerCase().contains('psic'));

                    final usuarioId = usuario['id'];
                    final usuarioEmail = usuario['usuario']; // Email del usuario
                    print('🆔 Usuario ID extraído: $usuarioId');
                    print('📧 Usuario Email extraído: $usuarioEmail');
                    
                    if (usuarioId == null && (usuarioEmail == null || usuarioEmail.isEmpty)) {
                      print('❌ ERROR CRÍTICO: No se pudo obtener ID ni email del usuario!');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: No se pudo obtener datos del usuario. Por favor, intenta de nuevo.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    // Intentar guardar el usuario
                    try {
                      if (usuarioId != null) {
                        print('💾 Intentando guardar usuario con ID: $usuarioId');
                        await UsuarioService.guardarUsuario(
                          usuarioId,
                          usuarioEmail ?? '',
                          tipoUsuario: tipoUsuario,
                        );
                        print('✅ Usuario guardado exitosamente');
                      } else if (usuarioEmail != null && usuarioEmail.isNotEmpty) {
                        print('⚠️ ADVERTENCIA: usuarioId es null, pero hay email. Guardando solo email.');
                        // Si no hay ID pero hay email, guardar solo el email
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('usuario_email', usuarioEmail);
                        if (tipoUsuario != null) {
                          await prefs.setInt('tipo_usuario', tipoUsuario);
                        }
                        print('✅ Email guardado (sin ID)');
                      }
                    } catch (e) {
                      print('❌ ERROR al guardar usuario: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Advertencia: No se pudo guardar la sesión localmente: $e'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }

                    if (esPsicologo) {
                      print('✅ Navegando a PantallaTablaUsuarios (psicólogo)');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaTablaUsuarios(),
                        ),
                      );
                    } else {
                      print('✅ Navegando a PantallaPrincipal con usuarioId: $usuarioId, email: $usuarioEmail');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaPrincipal(
                            usuarioId: usuarioId ?? 0, // 0 como fallback si es null
                            usuarioEmail: usuarioEmail,
                          ),
                        ),
                      );
                    }
                  }
                  print('═══════════════════════════════════');
                } else {
                  // Error en login
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(resultado['error']),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text('Iniciar Sesión'),
            ),
            TextButton(
              onPressed: () {
                // Navegar a la pantalla de registro
                Navigator.pushNamed(context, '/register');
              },
              child: Text('¿No tienes una cuenta? Regístrate'),
            ),
            TextButton(
              onPressed: () {
                // Navegar a la pantalla de registro
                Navigator.pushNamed(context, '/registroPsicologo');
              },
              child: Text('Registrate como psícologo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}