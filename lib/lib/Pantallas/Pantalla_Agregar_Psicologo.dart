import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import '../servicios/Usuario.dart';
import 'Pantalla_Tabla_Usuarios.dart';

class PantallaAgregarPsicologo extends StatefulWidget {
  @override
  _PantallaAgregarPsicologoState createState() => _PantallaAgregarPsicologoState();
}

class _PantallaAgregarPsicologoState extends State<PantallaAgregarPsicologo> {
  final MobileScannerController controller = MobileScannerController();
  bool _mostrandoScanner = false;
  bool _procesando = false;
  String? _ultimoCodigoProcesado;
  bool _cargandoDatos = false;

  @override
  void dispose() {
    controller.stop();
    controller.dispose();
    super.dispose();
  }


  void _procesarQRCode(String? rawValue) async {
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    // Evitar procesar múltiples veces el mismo código
    if (_procesando || _ultimoCodigoProcesado == rawValue) {
      return;
    }

    setState(() {
      _procesando = true;
      _ultimoCodigoProcesado = rawValue;
    });

    // Detener el scanner inmediatamente
    await controller.stop();

    // Obtener el ID del paciente actual
    final pacienteId = await UsuarioService.obtenerUsuarioId();
    if (pacienteId == null) {
      if (mounted) {
        setState(() {
          _procesando = false;
          _mostrandoScanner = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo obtener el ID del paciente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Intentar parsear el ID del psicólogo del QR
    int? psicologoId;
    try {
      final json = rawValue;
      // Si es un JSON, intentar parsearlo
      if (json.startsWith('{')) {
        final data = jsonDecode(json);
        psicologoId = data['psicologo_id'] ?? data['id'] ?? data['psicologoId'] ?? data['id_psicologo'];
      } else {
        // Si no es JSON, intentar parsearlo directamente como número
        psicologoId = int.tryParse(rawValue.trim());
      }
    } catch (e) {
      // Si falla el parseo JSON, intentar como número directo
      psicologoId = int.tryParse(rawValue.trim());
    }

    if (psicologoId != null) {
      // Crear el registro directamente - el servidor validará si el psicólogo existe
      setState(() {
        _cargandoDatos = true;
      });

      try {
        await RegistroService.crearRegistro(
          psicologoId: psicologoId,
          pacienteId: pacienteId,
        );

        if (mounted) {
          // Detener el scanner
          await controller.stop();
          
            // Resetear el estado para volver a la pantalla inicial
            setState(() {
              _mostrandoScanner = false;
              _procesando = false;
              _cargandoDatos = false;
              _ultimoCodigoProcesado = null;
            });
          
          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Psicólogo vinculado correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _procesando = false;
            _cargandoDatos = false;
            _mostrandoScanner = false;
            _ultimoCodigoProcesado = null;
          });
          
          // Extraer mensaje de error más descriptivo
          String mensajeError = 'Error al vincular psicólogo';
          if (e.toString().contains('Error al crear registro')) {
            mensajeError = 'No se pudo vincular el psicólogo. Verifica que el ID sea correcto.';
          } else {
            mensajeError = 'Error: ${e.toString()}';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensajeError),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _procesando = false;
          _mostrandoScanner = false;
          _ultimoCodigoProcesado = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código QR no válido. Debe contener un ID de psicólogo.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _activarScanner() {
    setState(() {
      _mostrandoScanner = true;
      _ultimoCodigoProcesado = null;
    });
    controller.start();
  }

  void _volverAInicio() {
    setState(() {
      _mostrandoScanner = false;
      _ultimoCodigoProcesado = null;
      _procesando = false;
      _cargandoDatos = false;
    });
    controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrandoScanner) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Escanear Código QR'),
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              await controller.stop();
              _volverAInicio();
            },
          ),
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (_procesando) return; // No procesar si ya se está procesando

                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                    _procesarQRCode(barcode.rawValue);
                    break; // Solo procesar el primer código encontrado
                  }
                }
              },
            ),
            // Overlay con guía de escaneo
            Positioned.fill(
              child: CustomPaint(
                painter: QRScannerOverlay(),
              ),
            ),
            // Instrucciones
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Escanea el código QR del psicólogo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Coloca el código QR dentro del marco',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (_cargandoDatos)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(height: 16),
                      Text(
                        'Procesando...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Eliminada la pantalla intermedia que causaba la pantalla negra
    // Ahora navegamos directamente de vuelta después del insert exitoso

    // Pantalla inicial con botón para activar scanner
    return Scaffold(
      appBar: AppBar(
        title: Text('Agregar Psicólogo'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 120,
                color: Colors.orange,
              ),
              SizedBox(height: 32),
              Text(
                'Escanea el código QR',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Presiona el botón para activar el escáner y vincular un psicólogo',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _activarScanner,
                icon: Icon(Icons.qr_code_scanner, size: 28),
                label: Text(
                  'Activar Escáner QR',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// Clase para dibujar el overlay del escáner
class QRScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Área de escaneo (centro de la pantalla)
    final scanAreaSize = size.width * 0.7;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2;
    final scanArea = Rect.fromLTWH(
      scanAreaLeft,
      scanAreaTop,
      scanAreaSize,
      scanAreaSize,
    );

    // Crear un agujero en el centro
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanArea, Radius.circular(20)),
      );
    path.addPath(holePath, Offset.zero);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Dibujar las esquinas del marco
    final cornerPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final cornerLength = 30.0;
    final cornerRadius = 20.0;

    // Esquina superior izquierda
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + cornerRadius),
      Offset(scanAreaLeft, scanAreaTop + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + cornerRadius, scanAreaTop),
      Offset(scanAreaLeft + cornerLength, scanAreaTop),
      cornerPaint,
    );

    // Esquina superior derecha
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize - cornerRadius, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerRadius),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerLength),
      cornerPaint,
    );

    // Esquina inferior izquierda
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + cornerRadius, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize),
      cornerPaint,
    );

    // Esquina inferior derecha
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize - cornerRadius, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerRadius),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
