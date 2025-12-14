import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart';
import 'package:open_file/open_file.dart';

// Imports condicionales para diferentes plataformas
import 'dart:io' if (dart.library.html) 'io_stub.dart' as io;
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;

class Guardar_Reporte{
  static Future<dynamic> savePdf({
    required String  name,
    required Document pdf,
  }) async {
    final bytes = await pdf.save();
    final fileName = name.endsWith('.pdf') ? name : '$name.pdf';
    
    if (kIsWeb) {
      // Para Web: descargar el archivo usando dart:html
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      return null; // En Web no retornamos un File
    } else {
      // Para Android, iOS y otras plataformas: guardar en el sistema de archivos
      final root = (await getExternalStorageDirectory()) ?? 
                   (await getApplicationDocumentsDirectory())!;
      final file = io.File('${root.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    }
  }
  
  static Future<void> openpdf(dynamic file) async{
    if (kIsWeb) {
      // En Web, el archivo ya se descargó automáticamente
      return;
    } else if (file != null) {
      // En otras plataformas, abrir el archivo
      final path = (file as io.File).path;
      await OpenFile.open(path);
    }
  }
}
