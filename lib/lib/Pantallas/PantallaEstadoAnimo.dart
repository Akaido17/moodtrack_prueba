import 'package:flutter/material.dart';
import '../servicios/Guardar_Estado_Animo.dart';
import '../servicios/AnalisisEstadosAnimo.dart';
import '../EstadoAnimo.dart' as estado_model;

class PantallaEstadoAnimo extends StatefulWidget {
  final int usuarioId;
  final Future<void> Function()? onRefresh;

  const PantallaEstadoAnimo({
    Key? key,
    required this.usuarioId,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<PantallaEstadoAnimo> createState() => _PantallaEstadoAnimoState();
}

class _PantallaEstadoAnimoState extends State<PantallaEstadoAnimo> {
  final Guardar_Estado _estadoService = Guardar_Estado();
  final AnalisisEstadosAnimo _analisisService = AnalisisEstadosAnimo();
  List<estado_model.EstadoAnimo> estadosAnimo = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarEstadosAnimo();
  }

  Future<void> _cargarEstadosAnimo() async {
    setState(() => _isLoading = true);

    try {
      final resultado = await _estadoService.obtenerEstadosAnimo(widget.usuarioId);

      if (resultado['success']) {
        final datosEstados = resultado['data'];

        if (datosEstados == null || datosEstados is! List) {
          setState(() {
            estadosAnimo = [];
            _isLoading = false;
          });
          return;
        }

        List<estado_model.EstadoAnimo> estadosCargados = [];

        for (var item in datosEstados) {
          try {
            if (item is! Map) continue;

            int estadoValor;
            if (item['estado'] is int) {
              estadoValor = item['estado'];
            } else if (item['estado'] is String) {
              estadoValor = int.parse(item['estado']);
            } else {
              estadoValor = 3;
            }

            DateTime fecha;
            if (item['fecha_creacion'] == null) {
              fecha = DateTime.now();
            } else {
              try {
                fecha = DateTime.parse(item['fecha_creacion'].toString());
              } catch (e) {
                fecha = DateTime.now();
              }
            }

            final nuevoEstado = estado_model.EstadoAnimo(
              id: item['id'],
              estado: estadoValor,
              comentario: item['comentario']?.toString() ?? '',
              fechaCreacion: fecha,
            );

            estadosCargados.add(nuevoEstado);
          } catch (e) {
            continue;
          }
        }

        setState(() {
          estadosAnimo = estadosCargados;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          estadosAnimo = [];
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        estadosAnimo = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refrescar() async {
    await _cargarEstadosAnimo();
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
  }

  String _formatearFechaHora(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  /// Verifica si hay alerta después de guardar un estado de ánimo
  Future<void> _verificarAlertaDespuesGuardar() async {
    print('🔍 Verificando alerta después de guardar estado para usuario: ${widget.usuarioId}');
    try {
      final debeMostrar = await _analisisService.debeMostrarAlerta(
        widget.usuarioId,
        dias: 3,
      );

      print('🔍 Resultado de verificación después de guardar: debeMostrar = $debeMostrar');

      if (debeMostrar && mounted) {
        print('✅ Mostrando alerta después de guardar');
        final resumen = await _analisisService.obtenerResumenAlerta(
          widget.usuarioId,
          dias: 3,
        );

        print('📊 Resumen después de guardar: promedio=${resumen['promedio']}, total=${resumen['total']}');

        _mostrarDialogoAlerta(resumen);
      } else {
        print('ℹ️ No se debe mostrar alerta después de guardar (debeMostrar=$debeMostrar, mounted=$mounted)');
      }
    } catch (e) {
      print('❌ Error al verificar alerta después de guardar: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Muestra un diálogo de alerta cuando se detecta un patrón preocupante
  void _mostrarDialogoAlerta(Map<String, dynamic> resumen) {
    final promedio = resumen['promedio'] ?? 0.0;
    final total = resumen['total'] ?? 0;
    final dias = resumen['dias'] ?? 3;
    final tipoPatron = resumen['tipoPatron'] ?? 'promedio_bajo';
    final mensaje = resumen['mensaje'] ?? 'Hemos detectado un patrón preocupante en tus estados de ánimo.';
    final sugerencias = (resumen['sugerencias'] as List?)?.cast<String>() ?? [];
    final severidad = resumen['severidad'] ?? 'media';

    print('🚨 ============================================');
    print('🚨 INTENTANDO MOSTRAR ALERTA POP-UP (desde PantallaEstadoAnimo)');
    print('🚨 Tipo patrón: $tipoPatron');
    print('🚨 Promedio: $promedio');
    print('🚨 Total estados: $total');
    print('🚨 Días analizados: $dias');
    print('🚨 Severidad: $severidad');
    print('🚨 Mensaje: $mensaje');
    print('🚨 Sugerencias: $sugerencias');
    print('🚨 ============================================');

    if (!mounted) {
      print('⚠️ Widget no está montado, no se puede mostrar diálogo');
      return;
    }

    // Determinar colores según severidad
    Color colorPrincipal;
    Color colorFondo;
    IconData icono;
    
    switch (severidad) {
      case 'alta':
        colorPrincipal = Colors.red[800]!;
        colorFondo = Colors.red[50]!;
        icono = Icons.warning_amber_rounded;
        break;
      case 'media':
        colorPrincipal = Colors.orange[800]!;
        colorFondo = Colors.orange[50]!;
        icono = Icons.info_outline;
        break;
      default:
        colorPrincipal = Colors.blue[800]!;
        colorFondo = Colors.blue[50]!;
        icono = Icons.lightbulb_outline;
    }

    // Mostrar el diálogo inmediatamente sin delays
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      print('✅ Mostrando diálogo de alerta ahora...');
      
      showDialog(
        context: context,
        barrierDismissible: false, // No se puede cerrar tocando fuera
        barrierColor: Colors.black87, // Fondo oscuro para destacar
        builder: (BuildContext context) {
          print('✅ Construyendo diálogo de alerta');
          return PopScope(
            canPop: false, // Prevenir que se cierre con el botón de retroceso
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorFondo, colorFondo.withOpacity(0.7)],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icono grande y visible
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorPrincipal.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icono,
                          color: colorPrincipal,
                          size: 64,
                        ),
                      ),
                      SizedBox(height: 20),
                      // Título
                      Text(
                        severidad == 'alta' ? '⚠️ AVISO IMPORTANTE' : '💡 INFORMACIÓN',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorPrincipal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      // Mensaje principal
                      Text(
                        mensaje,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      // Contenedor con información adicional
                      if (promedio > 0) ...[
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colorPrincipal.withOpacity(0.3), width: 2),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.trending_down,
                                color: colorPrincipal,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Promedio de Estados',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${promedio.toStringAsFixed(2)} / 5.0',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: colorPrincipal,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'En los últimos $dias días has registrado $total estados de ánimo.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                      // Sugerencias
                      if (sugerencias.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb, color: Colors.blue[700], size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sugerencias:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              ...sugerencias.map((sugerencia) => Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_circle_outline, 
                                         color: Colors.blue[700], size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        sugerencia,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                      // Botón grande y visible
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            print('✅ Usuario cerró la alerta');
                            Navigator.of(context, rootNavigator: true).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPrincipal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: Text(
                            'ENTENDIDO',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  void _mostrarDialogoEstadoAnimo(BuildContext context, int nivel, Color color) {
    String nota = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Registrar Estado de Ánimo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nivel: $nivel/5'),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (valor) => nota = valor,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              setState(() => _isLoading = true);

              try {
                // Validar que usuarioId sea válido antes de enviar
                if (widget.usuarioId <= 0) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ID de usuario inválido'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  setState(() => _isLoading = false);
                  return;
                }
                
                // Validar y convertir usuarioId a entero si es necesario
                int usuarioIdFinal = widget.usuarioId;
                
                // Si usuarioId no es un entero válido, intentar convertirlo
                if (usuarioIdFinal is! int || usuarioIdFinal <= 0) {
                  print('⚠️ Advertencia: usuarioId no es un entero válido: ${widget.usuarioId} (tipo: ${widget.usuarioId.runtimeType})');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ID de usuario inválido'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  setState(() => _isLoading = false);
                  return;
                }
                
                print('📤 Guardando estado de ánimo para usuario ID: $usuarioIdFinal (tipo: ${usuarioIdFinal.runtimeType})');
                final resultado = await _estadoService.guardarEstadoAnimo(
                  usuarioId: usuarioIdFinal,
                  estado: nivel,
                  nota: nota,
                );

                setState(() => _isLoading = false);

                if (resultado['success']) {
                  await _cargarEstadosAnimo();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Estado guardado! Total: ${estadosAnimo.length}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Esperar un momento para asegurar que el estado se haya guardado
                    // y luego verificar si hay alerta después de guardar
                    await Future.delayed(Duration(milliseconds: 500));
                    _verificarAlertaDespuesGuardar();
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(resultado['error'] ?? 'Error al guardar'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                setState(() => _isLoading = false);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Estado de Ánimo',
          style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            child: Text(
              '¿Cómo te sientes hoy?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _construirBotonEstadoAnimo(context, 1, '😢', Colors.red),
              _construirBotonEstadoAnimo(context, 2, '😔', Colors.orange),
              _construirBotonEstadoAnimo(context, 3, '😐', Colors.yellow),
              _construirBotonEstadoAnimo(context, 4, '😊', Colors.lightGreen),
              _construirBotonEstadoAnimo(context, 5, '😄', Colors.green),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: estadosAnimo.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mood, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tienes estados de ánimo registrados',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Selecciona un emoji arriba para comenzar',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _refrescar,
              child: ListView.builder(
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: estadosAnimo.length,
                itemBuilder: (context, index) {
                  final estado = estadosAnimo[index];

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: estado.getColor().withOpacity(0.2),
                        child: Text(
                          estado.getEmoji(),
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                      title: Text(
                        'Estado: ${estado.estado}/5',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (estado.comentario.isNotEmpty) ...[
                            SizedBox(height: 4),
                            Text(estado.comentario),
                          ],
                          SizedBox(height: 4),
                          Text(
                            _formatearFechaHora(estado.fechaCreacion),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotonEstadoAnimo(BuildContext context, int nivel, String emoji, Color color) {
    return GestureDetector(
      onTap: () => _mostrarDialogoEstadoAnimo(context, nivel, color),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}