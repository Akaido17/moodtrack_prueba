import 'package:flutter/material.dart';

class EstadoAnimo {
  int? id;
  int? idUsuario;
  final int estado;
  final String comentario;
  final DateTime fechaCreacion;

  EstadoAnimo({
    this.id,
    this.idUsuario,
    required this.estado,
    required this.comentario,
    required this.fechaCreacion,
  });


  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (idUsuario != null) 'id_usuario': idUsuario,
      'estado': estado,
      'comentario': comentario,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }


  factory EstadoAnimo.fromJson(Map<String, dynamic> json) {
    // Manejar diferentes formatos de fecha
    DateTime fechaCreacion;
    try {
      if (json['fecha_creacion'] is String) {
        fechaCreacion = DateTime.parse(json['fecha_creacion']);
      } else {
        fechaCreacion = DateTime.now();
      }
    } catch (e) {
      print('⚠️ Error al parsear fecha_creacion: ${json['fecha_creacion']}, usando fecha actual');
      fechaCreacion = DateTime.now();
    }
    
    return EstadoAnimo(
      id: json['id'] is int ? json['id'] : (json['id'] is String ? int.tryParse(json['id']) : null),
      idUsuario: json['id_usuario'] is int ? json['id_usuario'] : (json['id_usuario'] is String ? int.tryParse(json['id_usuario']) : null),
      estado: json['estado'] is int ? json['estado'] : (json['estado'] is String ? int.tryParse(json['estado']) ?? 0 : 0),
      comentario: json['comentario']?.toString() ?? '',
      fechaCreacion: fechaCreacion,
    );
  }


  Color getColor() {
    switch (estado) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }


  String getEmoji() {
    switch (estado) {
      case 1:
        return '😢';
      case 2:
        return '😔';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '😄';
      default:
        return '😶';
    }
  }
}


