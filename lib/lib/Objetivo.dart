import 'package:flutter/material.dart';
import 'Pantallas/Pantalla_login.dart';
import 'servicios/Usuario.dart';

class Objetivo {
  int? id;
  int? idUsuario;
  String titulo;
  String descripcion;
  DateTime fechaObjetivo;
  TimeOfDay horaObjetivo;
  bool estaCompletado;
  DateTime fechaCreacion;

  Objetivo({
    this.id,
    this.idUsuario,
    required this.titulo,
    required this.descripcion,
    required this.fechaObjetivo,
    required this.horaObjetivo,
    this.estaCompletado = false,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toJson({int? usuarioId}) {
    // Usar el usuarioId pasado como parámetro, o el idUsuario del objeto, o null
    final idUsuarioFinal = usuarioId ?? idUsuario;
    final json = {
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha_objetivo': fechaObjetivo.toIso8601String(),
      'hora_objetivo': '${horaObjetivo.hour.toString().padLeft(2, '0')}:${horaObjetivo.minute.toString().padLeft(2, '0')}',
      'esta_completado': estaCompletado,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'id_usuario': idUsuarioFinal,
    };
    print('🔍 Objetivo.toJson(): $json');
    return json;
  }

  factory Objetivo.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 Parseando objetivo: $json');
      
      // Parsear la hora desde string "HH:mm"
      final horaString = json['hora_objetivo'] as String? ?? '00:00';
      final partesHora = horaString.split(':');
      final hora = TimeOfDay(
        hour: int.parse(partesHora[0]),
        minute: int.parse(partesHora[1]),
      );

      final objetivo = Objetivo(
        id: json['id'],
        idUsuario: json['id_usuario'],
        titulo: json['titulo'] ?? '',
        descripcion: json['descripcion'] ?? '',
        fechaObjetivo: DateTime.parse(json['fecha_objetivo']),
        horaObjetivo: hora,
        estaCompletado: json['esta_completado'] ?? false,
        fechaCreacion: DateTime.parse(json['fecha_creacion']),
      );
      
      print('✅ Objetivo parseado: ${objetivo.titulo}');
      return objetivo;
    } catch (e) {
      print('❌ Error parseando objetivo: $e');
      print('❌ JSON: $json');
      rethrow;
    }
  }
}
