import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RegistroPsicologo extends StatefulWidget {
  @override
  _RegistroPsicologo createState() => _RegistroPsicologo();
}

class _RegistroPsicologo extends State<RegistroPsicologo> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _IdController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  static const String baseUrl = 'https://moodtrackapi-production.up.railway.app/api';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _IdController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validarPassword(String? value) {
    print('🔍 Validando contraseña: ${value?.length ?? 0} caracteres');
    if (value == null || value.isEmpty) {
      print('Contraseña vacía');
      return 'Por favor ingresa tu contraseña';
    }

    if (value.length < 6) {
      print('Contraseña muy corta');
      return 'La contraseña debe tener al menos 6 caracteres';
    }

    print('✅ Contraseña válida');
    return null;
  }

  String? _validarConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      print('Confirmación vacía');
      return 'Por favor confirma tu contraseña';
    }

    if (value != _passwordController.text) {
      print('Las contraseñas no coinciden');
      return 'Las contraseñas no coinciden';
    }

    print('Contraseñas coinciden');
    return null;
  }

  String? _validarId(String? value) {
    if (value == null || value.isEmpty) {
      print('Confirmación vacía');
      return 'Por favor confirma tu contraseña';
    }

    if (value != _passwordController.text) {
      print('Las contraseñas no coinciden');
      return 'Las contraseñas no coinciden';
    }

    print('Contraseñas coinciden');
    return null;
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('¡Registro exitoso!'),
          ],
        ),
        content: Text('Tu cuenta ha sido creada correctamente. Ahora puedes iniciar sesión.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar el diálogo
              Navigator.pop(context); // Volver a la pantalla de login
            },
            child: Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Error'),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarPsicologo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = '$baseUrl/registrarPsicologo';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'usuario': _emailController.text.trim(),
          'password': _passwordController.text,
          'registro' : _IdController.text  ,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 201) {
        print('Registro exitoso');
        _mostrarExito();
      } else {
        final error = jsonDecode(response.body);
        print('Error en registro: ${error['error']}');
        _mostrarError(error['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      print('Excepción capturada: $e');
      setState(() {
        _isLoading = false;
      });
      _mostrarError('Error al conectar con el servidor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 20),
                Icon(
                  Icons.person_add,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(height: 30),
                Text(
                  'Crea tu cuenta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30),

                // Campo de email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                  ),
                ),
                SizedBox(height: 16),

                // Campo de contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: _validarPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    helperText: 'Mínimo 6 caracteres',
                  ),
                ),
                SizedBox(height: 16),

                // Campo de confirmar contraseña
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  validator: _validarConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  obscureText: true,
                  controller:  _IdController,
                  validator: _validarConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'ID Psicologo',
                    prefixIcon: Icon(Icons.account_circle_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                  ),
                ),
                SizedBox(height: 30),

                // Botón de registro
                ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    _registrarPsicologo();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    'Registrarse',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(height: 16),

                // Botón para volver al login
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('¿Ya tienes una cuenta? Inicia sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
