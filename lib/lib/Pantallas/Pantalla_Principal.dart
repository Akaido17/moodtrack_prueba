import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'PantallaEstadoAnimo.dart';
import 'Pantalla_Objetivos.dart';
import 'Pantalla_Recordatorios.dart';
import 'Pantalla_Agregar_Psicologo.dart';
import 'Pantalla_Reportes.dart';
import '../Objetivo.dart' as objetivo_model;
import '../Recordatorio.dart' as recordatorio_model;
import '../servicios/db_helper.dart';
import '../servicios/NotificacionesService.dart';
import '../servicios/Usuario.dart';
import '../servicios/AnalisisEstadosAnimo.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PantallaPrincipal extends StatefulWidget {
  final int usuarioId;
  final String? usuarioEmail; // Email del usuario para usar en las APIs

  const PantallaPrincipal({Key? key, required this.usuarioId, this.usuarioEmail}) : super(key: key);

  @override
  _EstadoPantallaPrincipal createState() => _EstadoPantallaPrincipal();
}

class _EstadoPantallaPrincipal extends State<PantallaPrincipal> {
  int _indiceSeleccionado = 0;
  List<objetivo_model.Objetivo> objetivos = [];
  List<recordatorio_model.Recordatorio> recordatorios = [];
  final DBHelper _dbHelper = DBHelper();
  final AnalisisEstadosAnimo _analisisService = AnalisisEstadosAnimo();
  bool _cargandoObjetivos = false;
  bool _cargandoRecordatorios = false;
  int? _tipoUsuario;
  bool _alertaMostrada = false; // Para evitar mostrar la alerta múltiples veces

  @override
  void initState() {
    super.initState();
    _cargarTipoUsuario();
    _cargarObjetivos();
    _cargarRecordatorios();
  }

  Future<void> _cargarTipoUsuario() async {
    final tipo = await UsuarioService.obtenerTipoUsuario();
    setState(() {
      _tipoUsuario = tipo;
    });
    print('📋 Tipo de usuario cargado: $tipo');
    // Verificar alerta después de cargar el tipo de usuario y un pequeño delay
    // para asegurar que los datos estén disponibles
    Future.delayed(Duration(seconds: 3), () {
      print('⏰ Ejecutando verificación de alerta después del delay...');
      if (mounted) {
        _verificarAlertaEstadosAnimo();
      }
    });
  }

  /// Verifica si hay más estados negativos que positivos en los últimos 3 días
  /// y muestra una alerta si es necesario
  Future<void> _verificarAlertaEstadosAnimo({bool forzar = false}) async {
    // Solo verificar si no se ha mostrado la alerta ya (a menos que se fuerce)
    if (_alertaMostrada && !forzar) {
      print('⚠️ Alerta ya mostrada, omitiendo verificación (usa forzar=true para forzar)');
      return;
    }
    
    // Solo verificar para pacientes (tipo 1)
    if (_tipoUsuario != 1) {
      print('⚠️ Usuario no es paciente (tipo: $_tipoUsuario), omitiendo alerta');
      return;
    }

    // Validar que el usuarioId sea válido
    if (widget.usuarioId == null || widget.usuarioId <= 0) {
      print('⚠️ UsuarioId inválido: ${widget.usuarioId}, omitiendo alerta');
      return;
    }

    print('🔍 Verificando alerta de estados de ánimo para usuario: ${widget.usuarioId}');

    try {
      // Llamar directamente a analizarUltimosDias para obtener más información
      final resultado = await _analisisService.analizarUltimosDias(
        widget.usuarioId,
        3,
      );

      print('🔍 Resultado completo: $resultado');
      print('🔍 debeMostrar: ${resultado['hayAlerta']}');
      print('🔍 promedio: ${resultado['promedio']}');
      print('🔍 total: ${resultado['total']}');

      final debeMostrar = resultado['hayAlerta'] == true;
      final promedio = resultado['promedio'] ?? 0.0;
      final total = resultado['total'] ?? 0;

      print('🔍 Análisis completado:');
      print('   - debeMostrar: $debeMostrar');
      print('   - promedio: $promedio');
      print('   - total: $total');
      print('   - mounted: $mounted');

      if (debeMostrar && mounted) {
        print('✅ CONDICIÓN CUMPLIDA - Mostrando alerta de estados de ánimo');
        final resumen = await _analisisService.obtenerResumenAlerta(
          widget.usuarioId,
          dias: 3,
        );

        print('📊 Resumen final: promedio=${resumen['promedio']}, total=${resumen['total']}');

        // Asegurar que el diálogo se muestre en el siguiente frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mostrarDialogoAlerta(resumen);
            if (!forzar) {
              setState(() {
                _alertaMostrada = true;
              });
            }
          }
        });
      } else {
        print('ℹ️ No se debe mostrar alerta:');
        print('   - debeMostrar: $debeMostrar');
        print('   - mounted: $mounted');
        if (total == 0) {
          print('   - Razón: No hay estados en los últimos 3 días');
        } else {
          print('   - Razón: El promedio ($promedio) no es <= 2.0');
        }
      }
    } catch (e) {
      print('❌ Error al verificar alerta de estados de ánimo: $e');
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
    print('🚨 INTENTANDO MOSTRAR ALERTA POP-UP');
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

  Future<void> _cargarObjetivos() async {
    setState(() {
      _cargandoObjetivos = true;
    });

    try {
      final objetivosCargados = await _dbHelper.getAllObjetivos(widget.usuarioId);
      for (var obj in objetivosCargados) {
        print('  - ${obj.titulo} (ID: ${obj.id})');
      }
      setState(() {
        objetivos = objetivosCargados;
        _cargandoObjetivos = false;
      });
    } catch (e) {
      setState(() {
        _cargandoObjetivos = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar objetivos: $e')),
      );
    }
  }

  Future<void> _agregarObjetivo(objetivo_model.Objetivo objetivo, {int? pacienteId}) async {
    try {
      // Si hay un pacienteId (psicólogo seleccionó un paciente), usar ese ID
      // Si no, usar el ID del usuario actual
      final idUsuarioFinal = pacienteId ?? widget.usuarioId;
      
      // Usar email si está disponible, sino usar ID
      final objetivoGuardado = await _dbHelper.insertObjetivo(
        objetivo, 
        idUsuarioFinal,
        usuarioEmail: widget.usuarioEmail,
      );
      print('📥 Respuesta del servidor: $objetivoGuardado');
      
      if (objetivoGuardado != null) {
        setState(() {
          objetivos.add(objetivoGuardado);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Objetivo guardado correctamente')),
        );
        print('✅ Objetivo guardado exitosamente');
      } else {
        throw Exception('El servidor no pudo guardar el objetivo');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _actualizarObjetivo(int indice, objetivo_model.Objetivo objetivo) async {
    try {
      if (objetivo.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se puede actualizar un objetivo sin ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final exito = await _dbHelper.updateObjetivo(objetivo);
      if (exito) {
        setState(() {
          objetivos[indice] = objetivo;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Objetivo actualizado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        throw Exception('No se pudo actualizar el objetivo');
      }
    } catch (e) {
      print('Error al actualizar objetivo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar objetivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarObjetivo(int indice) async {
    final objetivo = objetivos[indice];
    if (objetivo.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede eliminar un objetivo sin ID')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Objetivo'),
        content: Text('¿Estás seguro de que deseas eliminar "${objetivo.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final exito = await _dbHelper.deleteObjetivo(objetivo.id!);
        if (exito) {
          setState(() {
            objetivos.removeAt(indice);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Objetivo eliminado correctamente')),
          );
        } else {
          throw Exception('No se pudo eliminar el objetivo');
        }
      } catch (e) {
        print('Error al eliminar objetivo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar objetivo: $e')),
        );
      }
    }
  }

  Future<void> _cargarRecordatorios() async {
    setState(() {
      _cargandoRecordatorios = true;
    });

    try {
      final recordatoriosCargados = await _dbHelper.getAllRecordatorios(widget.usuarioId);
      setState(() {
        recordatorios = recordatoriosCargados;
        _cargandoRecordatorios = false;
      });

      // Programar notificaciones para recordatorios activos cargados
      for (var recordatorio in recordatoriosCargados) {
        if (recordatorio.estaActivo && recordatorio.id != null) {
          try {
            if (recordatorio.fechaRecordatorio != null) {
              // Notificación "Una vez"
              DateTime fechaHora;
              if (recordatorio.fechaRecordatorio!.hour == 0 && 
                  recordatorio.fechaRecordatorio!.minute == 0) {
                fechaHora = DateTime(
                  recordatorio.fechaRecordatorio!.year,
                  recordatorio.fechaRecordatorio!.month,
                  recordatorio.fechaRecordatorio!.day,
                  recordatorio.hora.hour,
                  recordatorio.hora.minute,
                );
              } else {
                fechaHora = recordatorio.fechaRecordatorio!;
              }
              
              // Solo programar si la fecha no ha pasado
              if (fechaHora.isAfter(DateTime.now())) {
                await NotificacionesService.programarNotificacionUnaVez(
                  id: recordatorio.id!,
                  titulo: recordatorio.titulo,
                  cuerpo: recordatorio.descripcion.isNotEmpty 
                      ? recordatorio.descripcion 
                      : 'Recordatorio: ${recordatorio.titulo}',
                  fechaHora: fechaHora,
                );
              }
            } else if (recordatorio.diasSemana != null && recordatorio.diasSemana!.isNotEmpty) {
              // Notificaciones repetidas
              await NotificacionesService.programarNotificacionRepetida(
                idBase: recordatorio.id! * 100,
                titulo: recordatorio.titulo,
                cuerpo: recordatorio.descripcion.isNotEmpty 
                    ? recordatorio.descripcion 
                    : 'Recordatorio: ${recordatorio.titulo}',
                hora: recordatorio.hora,
                diasSemana: recordatorio.diasSemana!,
              );
            }
          } catch (e) {
            print('Error al programar notificación para recordatorio ${recordatorio.id}: $e');
            // Continuar con los demás recordatorios
          }
        }
      }
    } catch (e) {
      print('Error al cargar recordatorios: $e');
      setState(() {
        _cargandoRecordatorios = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar recordatorios: $e')),
      );
    }
  }

  Future<void> _agregarRecordatorio(recordatorio_model.Recordatorio recordatorio, {int? pacienteId}) async {
    try {
      // Si hay un pacienteId (psicólogo seleccionó un paciente), usar ese ID
      // Si no, usar el ID del usuario actual
      final idUsuarioFinal = pacienteId ?? widget.usuarioId;
      
      final recordatorioGuardado = await _dbHelper.insertRecordatorio(
        recordatorio, 
        idUsuarioFinal,
        usuarioEmail: widget.usuarioEmail,
      );
      
      if (recordatorioGuardado != null) {
        setState(() {
          recordatorios.add(recordatorioGuardado);
        });

        // Programar notificaciones si el recordatorio está activo
        if (recordatorioGuardado.estaActivo && recordatorioGuardado.id != null) {
          try {
            if (recordatorioGuardado.fechaRecordatorio != null) {
              // Notificación "Una vez"
              // fechaRecordatorio ya tiene la hora combinada, pero si no, la combinamos
              DateTime fechaHora;
              if (recordatorioGuardado.fechaRecordatorio!.hour == 0 && 
                  recordatorioGuardado.fechaRecordatorio!.minute == 0) {
                // Si la hora es 00:00, probablemente no se combinó, así que la combinamos ahora
                fechaHora = DateTime(
                  recordatorioGuardado.fechaRecordatorio!.year,
                  recordatorioGuardado.fechaRecordatorio!.month,
                  recordatorioGuardado.fechaRecordatorio!.day,
                  recordatorioGuardado.hora.hour,
                  recordatorioGuardado.hora.minute,
                );
              } else {
                // Ya tiene la hora, usamos directamente
                fechaHora = recordatorioGuardado.fechaRecordatorio!;
              }
              
              await NotificacionesService.programarNotificacionUnaVez(
                id: recordatorioGuardado.id!,
                titulo: recordatorioGuardado.titulo,
                cuerpo: recordatorioGuardado.descripcion.isNotEmpty 
                    ? recordatorioGuardado.descripcion 
                    : 'Recordatorio: ${recordatorioGuardado.titulo}',
                fechaHora: fechaHora,
              );
            } else if (recordatorioGuardado.diasSemana != null && recordatorioGuardado.diasSemana!.isNotEmpty) {
              // Notificaciones repetidas
              await NotificacionesService.programarNotificacionRepetida(
                idBase: recordatorioGuardado.id! * 100, // Multiplicar para evitar conflictos
                titulo: recordatorioGuardado.titulo,
                cuerpo: recordatorioGuardado.descripcion.isNotEmpty 
                    ? recordatorioGuardado.descripcion 
                    : 'Recordatorio: ${recordatorioGuardado.titulo}',
                hora: recordatorioGuardado.hora,
                diasSemana: recordatorioGuardado.diasSemana!,
              );
            }
          } catch (e) {
            print('Error al programar notificación: $e');
            // No fallar la creación del recordatorio si falla la notificación
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recordatorio guardado correctamente')),
        );
        print('Recordatorio guardado exitosamente');
      } else {
        print('El servidor devolvió null');
        throw Exception('El servidor no pudo guardar el recordatorio');
      }
    } catch (e) {
      print('Error completo al guardar recordatorio: $e');
      print('Tipo de error: ${e.runtimeType}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _actualizarRecordatorio(int indice, recordatorio_model.Recordatorio recordatorio) async {
    try {
      if (recordatorio.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se puede actualizar un recordatorio sin ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final exito = await _dbHelper.updateRecordatorio(recordatorio);
      if (exito) {
        setState(() {
          recordatorios[indice] = recordatorio;
        });

        // Actualizar notificaciones según el estado
        try {
          if (recordatorio.estaActivo) {
            // Cancelar notificaciones anteriores
            if (recordatorio.fechaRecordatorio != null) {
              await NotificacionesService.cancelarNotificacion(recordatorio.id!);
              // Programar nueva notificación "Una vez"
              // fechaRecordatorio ya tiene la hora combinada, pero si no, la combinamos
              DateTime fechaHora;
              if (recordatorio.fechaRecordatorio!.hour == 0 && 
                  recordatorio.fechaRecordatorio!.minute == 0) {
                // Si la hora es 00:00, probablemente no se combinó, así que la combinamos ahora
                fechaHora = DateTime(
                  recordatorio.fechaRecordatorio!.year,
                  recordatorio.fechaRecordatorio!.month,
                  recordatorio.fechaRecordatorio!.day,
                  recordatorio.hora.hour,
                  recordatorio.hora.minute,
                );
              } else {
                // Ya tiene la hora, usamos directamente
                fechaHora = recordatorio.fechaRecordatorio!;
              }
              await NotificacionesService.programarNotificacionUnaVez(
                id: recordatorio.id!,
                titulo: recordatorio.titulo,
                cuerpo: recordatorio.descripcion.isNotEmpty 
                    ? recordatorio.descripcion 
                    : 'Recordatorio: ${recordatorio.titulo}',
                fechaHora: fechaHora,
              );
            } else if (recordatorio.diasSemana != null && recordatorio.diasSemana!.isNotEmpty) {
              // Cancelar notificaciones anteriores (cancelar todas las posibles)
              for (int dia = 1; dia <= 7; dia++) {
                await NotificacionesService.cancelarNotificacion(recordatorio.id! * 100 + dia);
              }
              // Programar nuevas notificaciones repetidas
              await NotificacionesService.programarNotificacionRepetida(
                idBase: recordatorio.id! * 100,
                titulo: recordatorio.titulo,
                cuerpo: recordatorio.descripcion.isNotEmpty 
                    ? recordatorio.descripcion 
                    : 'Recordatorio: ${recordatorio.titulo}',
                hora: recordatorio.hora,
                diasSemana: recordatorio.diasSemana!,
              );
            }
          } else {
              // Cancelar todas las notificaciones si se desactiva
            if (recordatorio.fechaRecordatorio != null) {
              await NotificacionesService.cancelarNotificacion(recordatorio.id!);
            } else if (recordatorio.diasSemana != null && recordatorio.diasSemana!.isNotEmpty) {
              // Cancelar cada notificación individualmente (cancelar todas las posibles)
              for (int dia = 1; dia <= 7; dia++) {
                await NotificacionesService.cancelarNotificacion(recordatorio.id! * 100 + dia);
              }
            }
          }
        } catch (e) {
          print('Error al actualizar notificaciones: $e');
          // No fallar la actualización si falla la notificación
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Recordatorio ${recordatorio.estaActivo ? "activado" : "desactivado"} correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        throw Exception('No se pudo actualizar el recordatorio');
      }
    } catch (e) {
      print('Error al actualizar recordatorio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar recordatorio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarRecordatorio(int indice) async {
    final recordatorio = recordatorios[indice];
    if (recordatorio.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede eliminar un recordatorio sin ID')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Recordatorio'),
        content: Text('¿Estás seguro de que deseas eliminar "${recordatorio.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final exito = await _dbHelper.deleteRecordatorio(recordatorio.id!);
        if (exito) {
          // Cancelar notificaciones asociadas
          try {
            if (recordatorio.fechaRecordatorio != null) {
              await NotificacionesService.cancelarNotificacion(recordatorio.id!);
            } else if (recordatorio.diasSemana != null && recordatorio.diasSemana!.isNotEmpty) {
              // Cancelar todas las notificaciones repetidas
              for (int dia = 1; dia <= 7; dia++) {
                await NotificacionesService.cancelarNotificacion(recordatorio.id! * 100 + dia);
              }
            }
          } catch (e) {
            print('Error al cancelar notificaciones: $e');
            // No fallar la eliminación si falla la cancelación de notificaciones
          }

          setState(() {
            recordatorios.removeAt(indice);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recordatorio eliminado correctamente')),
          );
        } else {
          throw Exception('No se pudo eliminar el recordatorio');
        }
      } catch (e) {
        print('Error al eliminar recordatorio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar recordatorio: $e')),
        );
      }
    }
  }

  Widget _getCurrentPage() {
    // Si es paciente, ajustar los índices para incluir "Agregar Psicólogo"
    final esPaciente = _tipoUsuario == 1;
    
    if (esPaciente) {
      switch (_indiceSeleccionado) {
        case 0:
          return PantallaEstadoAnimo(usuarioId: widget.usuarioId);
        case 1:
          return PantallaObjetivos(
            objetivos: objetivos,
            alAgregarObjetivo: _agregarObjetivo,
            alActualizarObjetivo: _actualizarObjetivo,
            alEliminarObjetivo: _eliminarObjetivo,
            cargando: _cargandoObjetivos,
            onRefresh: _cargarObjetivos,
          );
        case 2:
          return PantallaRecordatorios(
            recordatorios: recordatorios,
            alAgregarRecordatorio: _agregarRecordatorio,
            alAlternarRecordatorio: (indice) {
              final recordatorio = recordatorios[indice];
              if (recordatorio.id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No se puede actualizar un recordatorio sin ID'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final recordatorioActualizado = recordatorio_model.Recordatorio(
                id: recordatorio.id,
                idUsuario: recordatorio.idUsuario,
                titulo: recordatorio.titulo,
                descripcion: recordatorio.descripcion,
                hora: recordatorio.hora,
                diasSemana: recordatorio.diasSemana,
                fechaRecordatorio: recordatorio.fechaRecordatorio,
                estaActivo: !recordatorio.estaActivo,
                fechaCreacion: recordatorio.fechaCreacion,
              );
              _actualizarRecordatorio(indice, recordatorioActualizado);
            },
            alEliminarRecordatorio: _eliminarRecordatorio,
            cargando: _cargandoRecordatorios,
            onRefresh: _cargarRecordatorios,
          );
        case 3:
          return PantallaReportesEstadoAnimo(
            usuarioId: widget.usuarioId,
            esPsicologo: false,
          );
        case 4:
          return PantallaTabla();
        case 5:
          return PantallaAgregarPsicologo();
        default:
          return PantallaEstadoAnimo(usuarioId: widget.usuarioId);
      }
    } else {
      // Para no pacientes (psicólogos u otros)
      switch (_indiceSeleccionado) {
        case 0:
          return PantallaEstadoAnimo(usuarioId: widget.usuarioId);
        case 1:
          return PantallaObjetivos(
            objetivos: objetivos,
            alAgregarObjetivo: _agregarObjetivo,
            alActualizarObjetivo: _actualizarObjetivo,
            alEliminarObjetivo: _eliminarObjetivo,
            cargando: _cargandoObjetivos,
            onRefresh: _cargarObjetivos,
          );
        case 2:
          return PantallaRecordatorios(
            recordatorios: recordatorios,
            alAgregarRecordatorio: _agregarRecordatorio,
            alAlternarRecordatorio: (indice) {
              final recordatorio = recordatorios[indice];
              if (recordatorio.id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No se puede actualizar un recordatorio sin ID'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final recordatorioActualizado = recordatorio_model.Recordatorio(
                id: recordatorio.id,
                idUsuario: recordatorio.idUsuario,
                titulo: recordatorio.titulo,
                descripcion: recordatorio.descripcion,
                hora: recordatorio.hora,
                diasSemana: recordatorio.diasSemana,
                fechaRecordatorio: recordatorio.fechaRecordatorio,
                estaActivo: !recordatorio.estaActivo,
                fechaCreacion: recordatorio.fechaCreacion,
              );
              _actualizarRecordatorio(indice, recordatorioActualizado);
            },
            alEliminarRecordatorio: _eliminarRecordatorio,
            cargando: _cargandoRecordatorios,
            onRefresh: _cargarRecordatorios,
          );
        case 3:
          return PantallaTabla();
        default:
          return PantallaEstadoAnimo(usuarioId: widget.usuarioId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentPage(),
      bottomNavigationBar: _tipoUsuario == null
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _indiceSeleccionado,
              onTap: (indice) async {
                setState(() {
                  _indiceSeleccionado = indice;
                });
                // Ajustar índices según tipo de usuario
                final esPaciente = _tipoUsuario == 1;
                if (esPaciente) {
                  if (indice == 1) {
                    await _cargarObjetivos();
                  } else if (indice == 2) {
                    await _cargarRecordatorios();
                  }
                } else {
                  if (indice == 1) {
                    await _cargarObjetivos();
                  } else if (indice == 2) {
                    await _cargarRecordatorios();
                  }
                }
              },
              items: _tipoUsuario == 1
                  ? [
                      // Items para pacientes (incluye "Agregar Psicólogo")
                      BottomNavigationBarItem(
                        icon: Icon(Icons.mood),
                        label: 'Estado de Ánimo',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.flag),
                        label: 'Objetivos',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.notifications),
                        label: 'Recordatorios',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.assessment),
                        label: 'Reportes',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.table_chart),
                        label: 'Psicologos',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.qr_code_scanner),
                        label: 'Agregar Psicólogo',
                      ),
                    ]
                  : [
                      // Items para no pacientes (psicólogos u otros)
                      BottomNavigationBarItem(
                        icon: Icon(Icons.mood),
                        label: 'Estado de Ánimo',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.flag),
                        label: 'Objetivos',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.notifications),
                        label: 'Recordatorios',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.table_chart),
                        label: 'Psicologos',
                      ),
                    ],
            ),
    );
  }
}

class PantallaTabla extends StatefulWidget {
  @override
  _PantallaTablaState createState() => _PantallaTablaState();
}

class Registro {
  final int codigo;
  final String nombre;
  final String especialidad;
  final String nro_registro;

  Registro({
    required this.codigo,
    required this.nombre,
    required this.especialidad,
    required this.nro_registro,
  });

  factory Registro.fromJson(Map<String, dynamic> json) {
    return Registro(
      codigo: json['codigo'] ?? 1,
      nombre: json['nombre'] ?? '',
      especialidad: json['especialidad'] ?? '',
      nro_registro: json['nro_registro'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'especialidad': especialidad,
      'nro_registro': nro_registro,
    };
  }
}

class RegistroService {
  static const String baseUrl = 'https://moodtrackapi-production.up.railway.app/api';

  static Future<List<Registro>> obtenerRegistros() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/psicologos'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('📡 Respuesta del servidor: ${response.statusCode}');
      print('📄 Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonMap = json.decode(response.body);

        List<dynamic> jsonList = jsonMap['data'] ?? jsonMap['psicologos'] ?? [];

        List<Registro> registros = jsonList
            .map((json) => Registro.fromJson(json))
            .toList();

        return registros;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error completo: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}

class _PantallaTablaState extends State<PantallaTabla> {
  List<Registro> registros = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final datos = await RegistroService.obtenerRegistros();

      setState(() {
        registros = datos;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void mostrarDialogoAgregar() {
    final nroSocioController = TextEditingController();
    final nombreController = TextEditingController();
    final especialidadController = TextEditingController();
    final nroRegistroController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Agregar Registro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nroSocioController,
                  decoration: InputDecoration(
                    labelText: 'Número de Socio',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: especialidadController,
                  decoration: InputDecoration(
                    labelText: 'Área',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: nroRegistroController,
                  decoration: InputDecoration(
                    labelText: 'Número de Registro',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.assignment),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void confirmarEliminar(Registro registro) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que deseas eliminar "${registro.nombre}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Registro',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.table_chart, size: 32, color: Colors.orange),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registro de Psicologos con Consultas Presenciales',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isLoading
                          ? 'Cargando...'
                          : 'Total: ${registros.length} registros',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: mostrarDialogoAgregar,
        backgroundColor: Colors.orange,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Conectando con PostgreSQL...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error de conexión',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: cargarDatos,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text('Reintentar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (registros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay registros disponibles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Presiona + para agregar el primero',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
            columns: [
              DataColumn(
                label: Text(
                  'Nro Socio',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Nombre',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Área',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Nro Registro',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Acciones',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: registros.map((registro) {
              return DataRow(
                cells: [
                  DataCell(Text(registro.codigo.toString())),
                  DataCell(Text(registro.nombre)),
                  DataCell(Text(registro.especialidad)),
                  DataCell(Text(registro.nro_registro)),
                  DataCell(
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => confirmarEliminar(registro),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}


