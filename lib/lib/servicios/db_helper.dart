import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../Objetivo.dart'; // Asegúrate de importar tu clase Objetivo
import '../Recordatorio.dart'; // Importar clase Recordatorio
import '../EstadoAnimo.dart'; // Importar clase EstadoAnimo

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static const String baseUrl = 'http://192.168.56.1:3000/api';

  Future<List<Objetivo>> getAllObjetivos(int usuarioId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/metas/usuario/$usuarioId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('🎯 Datos recibidos de la API: ${data.length} elementos');
        if (data.isNotEmpty) {
          print('🎯 Primer elemento: ${data[0]}');
        }
        final objetivos = data.map((json) => Objetivo.fromJson(json)).toList();
        print('🎯 Objetivos parseados: ${objetivos.length}');
        return objetivos;
      } else {
        throw Exception('Error al cargar objetivos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getAllObjetivos: $e');
      return []; // Retorna lista vacía en caso de error
    }
  }

  Future<Objetivo?> insertObjetivo(Objetivo objetivo, int usuarioId, {String? usuarioEmail}) async {
    print('═══════════════════════════════════');
    print('📤 ENVIANDO POST a: $baseUrl/metas');
    print('🆔 Usuario ID recibido: $usuarioId');
    print('📧 Usuario Email recibido: $usuarioEmail');
    
    final bodyJson = objetivo.toJson();
    
    // Crear body limpio sin id_usuario del toJson
    final body = <String, dynamic>{
      'titulo': bodyJson['titulo'],
      'descripcion': bodyJson['descripcion'],
      'fecha_objetivo': bodyJson['fecha_objetivo'],
      'hora_objetivo': bodyJson['hora_objetivo'],
      'esta_completado': bodyJson['esta_completado'],
      'fecha_creacion': bodyJson['fecha_creacion'],
    };
    
    // Agregar usuario_email (preferido) o id_usuario como fallback
    if (usuarioEmail != null && usuarioEmail.isNotEmpty) {
      body['usuario_email'] = usuarioEmail;
      print('✅ Usando usuario_email: $usuarioEmail');
    } else if (usuarioId != null && usuarioId != 0) {
      body['id_usuario'] = usuarioId;
      print('✅ Usando id_usuario: $usuarioId');
    } else {
      print('❌ ERROR: No hay usuarioEmail ni usuarioId válido!');
      throw Exception('No se puede crear la meta: falta información del usuario');
    }
    
    print('📦 Datos finales a enviar: $body');
    print('═══════════════════════════════════');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/metas'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');
      print('📥 Response Headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Datos parseados: $data');
        return Objetivo.fromJson(data);
      } else {
        print('❌ Error HTTP: ${response.statusCode} - ${response.body}');
        throw Exception('Error al crear objetivo: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error completo en insertObjetivo: $e');
      print('❌ Tipo de error: ${e.runtimeType}');
      rethrow; // Re-lanzar el error para que se maneje en main.dart
    }
  }

  Future<bool> updateObjetivo(Objetivo objetivo) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/metas/${objetivo.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(objetivo.toJson(usuarioId: objetivo.idUsuario)),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Error al actualizar objetivo: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en updateObjetivo: $e');
      return false;
    }
  }

  Future<bool> deleteObjetivo(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/metas/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Error al eliminar objetivo: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en deleteObjetivo: $e');
      return false;
    }
  }

  // ==================== MÉTODOS PARA RECORDATORIOS ====================

  Future<List<Recordatorio>> getAllRecordatorios(int usuarioId) async {
    print('🔔 Obteniendo todos los recordatorios...');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recordatorios/usuario/$usuarioId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Recordatorio.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar recordatorios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getAllRecordatorios: $e');
      return []; // Retorna lista vacía en caso de error
    }
  }

  Future<Recordatorio?> insertRecordatorio(Recordatorio recordatorio, int usuarioId, {String? usuarioEmail}) async {
    print('═══════════════════════════════════');
    print('📤 Enviando POST a: $baseUrl/recordatorios');
    print('🆔 Usuario ID recibido: $usuarioId');
    print('📧 Usuario Email recibido: $usuarioEmail');
    
    final bodyJson = recordatorio.toJson();
    
    // Crear body limpio sin id_usuario del toJson
    final body = <String, dynamic>{
      'titulo': bodyJson['titulo'],
      'descripcion': bodyJson['descripcion'],
      'hora': bodyJson['hora'],
      if (bodyJson['dias_semana'] != null) 'dias_semana': bodyJson['dias_semana'],
      if (bodyJson['fecha_recordatorio'] != null) 'fecha_recordatorio': bodyJson['fecha_recordatorio'],
      'esta_activo': bodyJson['esta_activo'],
      'fecha_creacion': bodyJson['fecha_creacion'],
    };
    
    // Agregar usuario_email (preferido) o id_usuario como fallback
    if (usuarioEmail != null && usuarioEmail.isNotEmpty) {
      body['usuario_email'] = usuarioEmail;
      print('✅ Usando usuario_email: $usuarioEmail');
    } else if (usuarioId != null && usuarioId != 0) {
      body['id_usuario'] = usuarioId;
      print('✅ Usando id_usuario: $usuarioId');
    } else {
      print('❌ ERROR: No hay usuarioEmail ni usuarioId válido!');
      throw Exception('No se puede crear el recordatorio: falta información del usuario');
    }
    
    print('📦 Datos a enviar: $body');
    print('═══════════════════════════════════');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recordatorios'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');
      print('📥 Response Headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Datos parseados: $data');
        return Recordatorio.fromJson(data);
      } else {
        print('❌ Error HTTP: ${response.statusCode} - ${response.body}');
        throw Exception('Error al crear recordatorio: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error completo en insertRecordatorio: $e');
      print('❌ Tipo de error: ${e.runtimeType}');
      rethrow; // Re-lanzar el error para que se maneje en main.dart
    }
  }

  Future<bool> updateRecordatorio(Recordatorio recordatorio) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/recordatorios/${recordatorio.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(recordatorio.toJson()),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Error al actualizar recordatorio: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en updateRecordatorio: $e');
      return false;
    }
  }

  Future<bool> deleteRecordatorio(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/recordatorios/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Error al eliminar recordatorio: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en deleteRecordatorio: $e');
      return false;
    }
  }

  // ==================== MÉTODOS PARA ESTADOS DE ÁNIMO ====================

  Future<List<EstadoAnimo>> getAllEstadosAnimo(int usuarioId) async {
    print('💭 Obteniendo todos los estados de ánimo para usuario: $usuarioId');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/estados-animo/$usuarioId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // El backend devuelve {success: true, data: [...]}
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> data = responseData['data'] as List<dynamic>;
          print('💭 Estados de ánimo encontrados: ${data.length}');
          
          final estados = data.map((json) {
            try {
              return EstadoAnimo.fromJson(json);
            } catch (e) {
              print('⚠️ Error al parsear estado individual: $e');
              print('⚠️ JSON problemático: $json');
              return null;
            }
          }).whereType<EstadoAnimo>().toList();
          
          print('💭 Estados parseados exitosamente: ${estados.length}');
          return estados;
        } else {
          print('⚠️ Respuesta del backend no tiene el formato esperado');
          return [];
        }
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        throw Exception('Error al cargar estados de ánimo: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getAllEstadosAnimo: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return []; // Retorna lista vacía en caso de error
    }
  }

  Future<EstadoAnimo?> insertEstadoAnimo(EstadoAnimo estadoAnimo, int usuarioId) async {
    print('📤 Enviando POST a: $baseUrl/estados-animo');
    final body = {
      ...estadoAnimo.toJson(),
      'id_usuario': usuarioId,
    };
    print('📦 Datos a enviar: $body');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/estados-animo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');
      print('📥 Response Headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Datos parseados: $data');
        return EstadoAnimo.fromJson(data);
      } else {
        print('❌ Error HTTP: ${response.statusCode} - ${response.body}');
        throw Exception('Error al crear estado de ánimo: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error completo en insertEstadoAnimo: $e');
      print('❌ Tipo de error: ${e.runtimeType}');
      rethrow; // Re-lanzar el error para que se maneje en main.dart
    }
  }

  Future<bool> deleteEstadoAnimo(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/estados-animo/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Error al eliminar estado de ánimo: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en deleteEstadoAnimo: $e');
      return false;
    }
  }
}
