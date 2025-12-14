import 'dart:convert';
import 'package:http/http.dart' as http;

class Guardar_Estado {
  static const String baseUrl = 'http://192.168.100.4:3000/api';

  Future<Map<String, dynamic>> guardarEstadoAnimo({
    required int usuarioId,
    required int estado,
    required String nota,
  }) async {
    print('💾 Guardando estado de ánimo...');
    print('📋 usuarioId recibido: $usuarioId (tipo: ${usuarioId.runtimeType})');
    print('📋 estado recibido: $estado (tipo: ${estado.runtimeType})');
    
    // Validar que usuarioId sea un entero válido
    if (usuarioId <= 0) {
      print('❌ Error: usuarioId inválido: $usuarioId');
      return {
        'success': false,
        'error': 'ID de usuario inválido: $usuarioId',
      };
    }
    
    // Validar que estado esté en el rango correcto
    if (estado < 1 || estado > 5) {
      print('❌ Error: estado inválido: $estado');
      return {
        'success': false,
        'error': 'El estado debe estar entre 1 y 5',
      };
    }

    // Asegurarse de que usuarioId sea un entero
    final int idUsuarioFinal = usuarioId is int ? usuarioId : int.parse(usuarioId.toString());
    
    print('📤 Enviando datos al servidor:');
    print('   - id_usuario: $idUsuarioFinal');
    print('   - estado: $estado');
    print('   - comentario: $nota');

    try {
      // Asegurarse de que todos los valores sean del tipo correcto
      final bodyData = <String, dynamic>{
        'id_usuario': idUsuarioFinal,  // Asegurar que sea int
        'estado': estado,              // Asegurar que sea int
        'comentario': nota.toString(),  // Asegurar que sea String
      };
      
      // Validar que el JSON se pueda serializar correctamente
      final jsonBody = jsonEncode(bodyData);
      print('📦 Body JSON: $jsonBody');
      
      // Verificar que el JSON parseado tenga los valores correctos
      final parsed = jsonDecode(jsonBody) as Map<String, dynamic>;
      if (parsed['id_usuario'] is! int) {
        print('❌ Error: id_usuario no es un entero después de serializar: ${parsed['id_usuario']} (tipo: ${parsed['id_usuario'].runtimeType})');
        return {
          'success': false,
          'error': 'Error interno: id_usuario no es un entero válido',
        };
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/estados-animo'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonBody,
      );

      print('📥 Status: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        // Intentar obtener el mensaje de error del servidor
        String errorMsg = 'Error al guardar';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['error'] ?? errorData['message'] ?? 'Error al guardar';
        } catch (e) {
          errorMsg = response.body.isNotEmpty ? response.body : 'Error al guardar';
        }
        print('❌ Error del servidor: $errorMsg');
        return {
          'success': false,
          'error': errorMsg,
        };
      }
    } catch (e) {
      print('❌ Egfrror: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> obtenerEstadosAnimo(int usuarioId) async {
    print('📋 Obteniendo estados de ánimo...');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/estados-animo/$usuarioId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body)['data'],
        };
      } else {
        return {
          'success': false,
          'error': 'Error al obtener datos',
        };
      }
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> obtenerEstadosAnimoPorPeriodo(
      int usuarioId,
      DateTime fechaInicio,
      ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/estados-animo/$usuarioId/periodo?fecha_inicio=${fechaInicio.toIso8601String()}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Error al obtener estados: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Obtiene estados de ánimo de todos los pacientes (para psicólogos)
  Future<Map<String, dynamic>> obtenerTodosEstadosAnimo(
      DateTime fechaInicio, {
        int? psicologoId,
      }) async {
    try {
      String url = '$baseUrl/estados-animo/todos?fecha_inicio=${fechaInicio.toIso8601String()}';

      if (psicologoId != null) {
        url += '&psicologo_id=$psicologoId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Error al obtener estados: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Obtiene lista de pacientes para el psicólogo
  Future<Map<String, dynamic>> obtenerPacientes(int psicologoId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/psicologo/$psicologoId/pacientes'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['pacientes'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Error al obtener pacientes: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Obtiene estadísticas agregadas de estados de ánimo
  Future<Map<String, dynamic>> obtenerEstadisticas({
    int? usuarioId,
    int? psicologoId,
    required DateTime fechaInicio,
  }) async {
    try {
      String url = '$baseUrl/estados-animo/estadisticas?fecha_inicio=${fechaInicio.toIso8601String()}';

      if (usuarioId != null) {
        url += '&usuario_id=$usuarioId';
      }

      if (psicologoId != null) {
        url += '&psicologo_id=$psicologoId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'estadisticas': data['estadisticas'],
          'tendencia': data['tendencia'],
          'por_dia_semana': data['por_dia_semana'],
        };
      } else {
        return {
          'success': false,
          'error': 'Error al obtener estadísticas: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Obtiene resumen detallado de un paciente
  Future<Map<String, dynamic>> obtenerResumenPaciente(
      int usuarioId,
      DateTime fechaInicio,
      ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/estados-animo/$usuarioId/resumen?fecha_inicio=${fechaInicio.toIso8601String()}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'resumen': data['resumen'],
          'actividad_reciente': data['actividad_reciente'],
          'estado_mas_frecuente': data['estado_mas_frecuente'],
        };
      } else {
        return {
          'success': false,
          'error': 'Error al obtener resumen: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  /// Compara dos pacientes
  Future<Map<String, dynamic>> compararPacientes(
      int usuarioId1,
      int usuarioId2,
      DateTime fechaInicio,
      ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/estados-animo/comparar?usuario_id_1=$usuarioId1&usuario_id_2=$usuarioId2&fecha_inicio=${fechaInicio.toIso8601String()}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'comparacion': data['comparacion'],
        };
      } else {
        return {
          'success': false,
          'error': 'Error al comparar pacientes: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }
}