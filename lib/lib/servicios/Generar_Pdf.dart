import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:pdf/widgets.dart';

import 'Generar_Reporte.dart';
import '../EstadoAnimo.dart';

// Import condicional para File solo en plataformas no-web
import 'dart:io' if (dart.library.html) 'dart:html' as html;

class Registro_Estado {
  final String estado;
  final DateTime fecha;
  final String comentario;

  const Registro_Estado({required this.estado , required this.fecha, required this.comentario });
}

class Generar_Pdf {
  static String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  static String _obtenerNombreEstado(int estado) {
    switch (estado) {
      case 1:
        return 'Muy Triste (1/5)';
      case 2:
        return 'Triste (2/5)';
      case 3:
        return 'Neutral (3/5)';
      case 4:
        return 'Feliz (4/5)';
      case 5:
        return 'Muy Feliz (5/5)';
      default:
        return 'Desconocido';
    }
  }

  static String _generarNombreArchivo() {
    final ahora = DateTime.now();
    final fecha = '${ahora.year}${ahora.month.toString().padLeft(2, '0')}${ahora.day.toString().padLeft(2, '0')}';
    final hora = '${ahora.hour.toString().padLeft(2, '0')}${ahora.minute.toString().padLeft(2, '0')}${ahora.second.toString().padLeft(2, '0')}';
    return 'Reporte_Estado_${fecha}_$hora';
  }

  static Future<dynamic> generar_pdf_tabla(List<EstadoAnimo> estadosAnimo, {String? nombreArchivo}) async {
    final pdf = Document();
    final headers = ['Estado', 'Fecha', 'Comentario'];
    
    // Convertir los estados de ánimo a datos para la tabla
    final data = estadosAnimo.map((estado) => [
      _obtenerNombreEstado(estado.estado),
      _formatearFecha(estado.fechaCreacion),
      estado.comentario.isEmpty ? 'Sin comentario' : estado.comentario,
    ]).toList();

    // Si no hay datos, mostrar un mensaje
    if (data.isEmpty) {
      pdf.addPage(
        Page(
          build: (context) => Center(
            child: Text('No hay registros de estado de ánimo para mostrar'),
          ),
        ),
      );
    } else {
      pdf.addPage(
        Page(
          build: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reporte de Estados de Ánimo',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                'Total de registros: ${estadosAnimo.length}',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 20),
              TableHelper.fromTextArray(
                data: data,
                headers: headers,
              ),
            ],
          ),
        ),
      );
    }
    
    // Si no se proporciona un nombre, usar el formato: Reporte_Estado_FechaGeneracion_HoraGeneracion
    final nombreFinal = nombreArchivo ?? _generarNombreArchivo();
    return await Guardar_Reporte.savePdf(name: nombreFinal, pdf: pdf);
  }

}