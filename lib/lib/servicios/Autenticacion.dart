import 'dart:convert';
import 'package:http/http.dart' as http;

class Autenticacion {  // El nombre de la clase puede quedar igual
  static const String baseUrl = 'https://moodtrackapi-production.up.railway.app/api';

  // Método para registrar un nuevo usuario
  Future<Map<String, dynamic>> register(String email, String password) async {
    final url = '$baseUrl/register';

    print('═══════════════════════════════════');
    print('🔄 INICIANDO REGISTRO');
    print('📍 URL: $url');
    print('📧 Usuario: $email');
    print('═══════════════════════════════════');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'usuario': email,
          'password': password,
        }),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Body: ${response.body}');
      print('═══════════════════════════════════');

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'error': error['error'] ?? 'Error desconocido',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Respuesta inválida del servidor',
          };
        }
      }
    } catch (e) {
      print('❌ ERROR COMPLETO: $e');
      print('═══════════════════════════════════');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = '$baseUrl/login';

    print('═══════════════════════════════════');
    print('🔄 INICIANDO LOGIN');
    print('📍 URL: $url');
    print('📧 Usuario: $email');
    print('═══════════════════════════════════');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'usuario': email,
          'password': password,
        }),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Body: ${response.body}');
      print('═══════════════════════════════════');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'error': error['error'] ?? 'Error desconocido',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Respuesta inválida del servidor',
          };
        }
      }
    } catch (e) {
      print('❌ ERROR COMPLETO: $e');
      print('═══════════════════════════════════');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }
}