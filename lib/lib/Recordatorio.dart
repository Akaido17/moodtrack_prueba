import 'package:flutter/material.dart';

class Recordatorio {
  int? id;
  int? idUsuario;
  final String titulo;
  final String descripcion;
  final TimeOfDay hora;
  final List<int>? diasSemana; // 1-7 (lunes a domingo) - null si es "Una vez"
  DateTime? fechaRecordatorio; // null si es "Repetir"
  bool estaActivo;
  final DateTime fechaCreacion;

  Recordatorio({
    this.id,
    this.idUsuario,
    required this.titulo,
    required this.descripcion,
    required this.hora,
    this.diasSemana,
    this.fechaRecordatorio,
    this.estaActivo = true,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (idUsuario != null) 'id_usuario': idUsuario,
      'titulo': titulo,
      'descripcion': descripcion,
      'hora': '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
      if (diasSemana != null && diasSemana!.isNotEmpty) 'dias_semana': diasSemana!.join(','), // Convertir lista a string separado por comas
      if (fechaRecordatorio != null) 'fecha_recordatorio': fechaRecordatorio!.toIso8601String(),
      'esta_activo': estaActivo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  factory Recordatorio.fromJson(Map<String, dynamic> json) {
    // Parsear la hora desde string "HH:mm"
    final horaString = json['hora'] as String? ?? '00:00';
    final partesHora = horaString.split(':');
    final hora = TimeOfDay(
      hour: int.parse(partesHora[0]),
      minute: int.parse(partesHora[1]),
    );

    // Parsear días de la semana (puede ser null)
    List<int>? diasSemana;
    if (json['dias_semana'] != null) {
      final diasString = json['dias_semana'] as String;
      if (diasString.isNotEmpty) {
        diasSemana = diasString.split(',').map((dia) => int.parse(dia.trim())).toList();
      }
    }

    // Parsear fecha_recordatorio (puede ser null)
    DateTime? fechaRecordatorio;
    if (json['fecha_recordatorio'] != null) {
      fechaRecordatorio = DateTime.parse(json['fecha_recordatorio']);
    }

    return Recordatorio(
      id: json['id'],
      idUsuario: json['id_usuario'],
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      hora: hora,
      diasSemana: diasSemana,
      fechaRecordatorio: fechaRecordatorio,
      estaActivo: json['esta_activo'] ?? true,
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
    );
  }
}
