import 'package:flutter/material.dart';
import '../servicios/Generar_Pdf.dart';
import '../servicios/Guardar_Estado_Animo.dart';
import '../servicios/Usuario.dart';
import '../EstadoAnimo.dart' as estado_model;

class PantallaReportesEstadoAnimo extends StatefulWidget {
  final int? usuarioId;
  final bool esPsicologo;

  const PantallaReportesEstadoAnimo({
    Key? key,
    this.usuarioId,
    this.esPsicologo = false,
  }) : super(key: key);

  @override
  State<PantallaReportesEstadoAnimo> createState() =>
      _PantallaReportesEstadoAnimoState();
}

class _PantallaReportesEstadoAnimoState
    extends State<PantallaReportesEstadoAnimo> {
  final Guardar_Estado _estadoService = Guardar_Estado();

  List<estado_model.EstadoAnimo> estadosAnimo = [];
  List<Map<String, dynamic>> pacientes = [];

  bool _isLoading = false;
  String _periodoSeleccionado = '7dias';
  int? _pacienteSeleccionado;

  final TextEditingController _codigoPacienteController = TextEditingController();
  bool _mostrarCampoCodigo = false;

  // Controladores para el diálogo de generar reporte
  final TextEditingController _idUsuarioController = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  @override
  void dispose() {
    _codigoPacienteController.dispose();
    _idUsuarioController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pacienteSeleccionado = widget.usuarioId;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      if (widget.esPsicologo) {
        await _cargarPacientes();
      }
      await _cargarEstadosAnimo();
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPacientes() async {
    try {
      final resultado = await _estadoService.obtenerPacientes(widget.usuarioId ?? 0);

      if (resultado['success']) {
        List<Map<String, dynamic>> listaPacientes = [
          {'id': null, 'nombre': 'Todos los pacientes'}
        ];

        final data = resultado['data'] as List;
        for (var paciente in data) {
          listaPacientes.add({
            'id': paciente['id'],
            'nombre': paciente['nombre'] ?? 'Sin nombre',
          });
        }

        setState(() {
          pacientes = listaPacientes;
        });
      }
    } catch (e) {
      print('Error al cargar pacientes: $e');
      setState(() {
        pacientes = [
          {'id': null, 'nombre': 'Todos los pacientes'},
        ];
      });
    }
  }

  Future<void> _cargarEstadosAnimo() async {
    try {
      DateTime fechaInicio = _calcularFechaInicio();

      final resultado = _pacienteSeleccionado == null
          ? await _estadoService.obtenerTodosEstadosAnimo(
        fechaInicio,
        psicologoId: widget.esPsicologo ? widget.usuarioId : null,
      )
          : await _estadoService.obtenerEstadosAnimoPorPeriodo(
        _pacienteSeleccionado!,
        fechaInicio,
      );

      if (resultado['success']) {
        final datosEstados = resultado['data'] as List;

        List<estado_model.EstadoAnimo> estadosCargados = [];

        for (var item in datosEstados) {
          try {
            estadosCargados.add(
              estado_model.EstadoAnimo(
                id: item['id'],
                estado: item['estado'] is int
                    ? item['estado']
                    : int.parse(item['estado'].toString()),
                comentario: item['comentario']?.toString() ?? '',
                fechaCreacion: DateTime.parse(item['fecha_creacion'].toString()),
              ),
            );
          } catch (e) {
            continue;
          }
        }

        setState(() {
          estadosAnimo = estadosCargados;
        });
        
        // Mostrar mensaje si no hay datos después de cargar
        if (estadosCargados.isEmpty && mounted) {
          print('No se encontraron registros en el período seleccionado');
        }
      } else {
        // Si no fue exitoso, mostrar el error
        final errorMsg = resultado['error'] ?? 'Error desconocido al cargar datos';
        if (mounted) {
          print('Error al cargar estados: $errorMsg');
        }
        setState(() {
          estadosAnimo = [];
        });
      }
    } catch (e) {
      _mostrarError('Error al cargar estados: $e');
    }
  }

  DateTime _calcularFechaInicio() {
    DateTime ahora = DateTime.now();
    switch (_periodoSeleccionado) {
      case '7dias':
        return ahora.subtract(Duration(days: 7));
      case '30dias':
        return ahora.subtract(Duration(days: 30));
      case '3meses':
        return ahora.subtract(Duration(days: 90));
      case '6meses':
        return ahora.subtract(Duration(days: 180));
      default:
        return ahora.subtract(Duration(days: 7));
    }
  }

  Map<String, int> _calcularDistribucion() {
    Map<String, int> distribucion = {
      'Muy Triste': 0,
      'Triste': 0,
      'Neutral': 0,
      'Feliz': 0,
      'Muy Feliz': 0,
    };

    for (var estado in estadosAnimo) {
      switch (estado.estado) {
        case 1:
          distribucion['Muy Triste'] = distribucion['Muy Triste']! + 1;
          break;
        case 2:
          distribucion['Triste'] = distribucion['Triste']! + 1;
          break;
        case 3:
          distribucion['Neutral'] = distribucion['Neutral']! + 1;
          break;
        case 4:
          distribucion['Feliz'] = distribucion['Feliz']! + 1;
          break;
        case 5:
          distribucion['Muy Feliz'] = distribucion['Muy Feliz']! + 1;
          break;
      }
    }

    return distribucion;
  }

  double _calcularPromedio() {
    if (estadosAnimo.isEmpty) return 0.0;
    int suma = estadosAnimo.fold(0, (sum, estado) => sum + estado.estado);
    return suma / estadosAnimo.length;
  }

  Map<String, List<int>> _agruparPorDia() {
    Map<String, List<int>> estadosPorDia = {};

    for (var estado in estadosAnimo) {
      String fecha = _formatearFechaCorta(estado.fechaCreacion);
      if (!estadosPorDia.containsKey(fecha)) {
        estadosPorDia[fecha] = [];
      }
      estadosPorDia[fecha]!.add(estado.estado);
    }

    return estadosPorDia;
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _formatearFechaCorta(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarExito(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _buscarPorCodigo() async {
    String codigo = _codigoPacienteController.text.trim();

    if (codigo.isEmpty) {
      _mostrarError('Por favor ingrese un código de paciente');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Buscar el paciente por código
      // Asumimos que el código es el ID del usuario
      int? idPaciente = int.tryParse(codigo);

      if (idPaciente == null) {
        _mostrarError('El código debe ser un número válido');
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _pacienteSeleccionado = idPaciente;
      });

      await _cargarEstadosAnimo();

      if (estadosAnimo.isEmpty) {
        _mostrarError('No se encontraron registros para el código: $codigo');
      } else {
        _mostrarExito('Paciente encontrado: ${estadosAnimo.length} registros');
      }

    } catch (e) {
      _mostrarError('Error al buscar paciente: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generarReporte() async {
    // Obtener el tipo de usuario y el ID del usuario logueado
    final tipoUsuario = await UsuarioService.obtenerTipoUsuario() ?? 0;
    final usuarioIdLogueado = await UsuarioService.obtenerUsuarioId();
    
    // Inicializar valores por defecto
    _idUsuarioController.text = _pacienteSeleccionado?.toString() ?? widget.usuarioId?.toString() ?? '';
    _fechaInicio = _calcularFechaInicio();
    _fechaFin = DateTime.now();

    // Variables para el diálogo
    int? pacienteSeleccionadoId = _pacienteSeleccionado;
    List<Map<String, dynamic>> pacientesDialogo = [];
    bool cargandoPacientes = tipoUsuario == 2 && usuarioIdLogueado != null;
    
    // Para pacientes (tipo 1), usar directamente el ID del usuario logueado
    int? idUsuarioParaReporte;
    if (tipoUsuario == 1) {
      idUsuarioParaReporte = usuarioIdLogueado;
    }

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Cargar pacientes si es psicólogo y aún no se han cargado
          if (tipoUsuario == 2 && usuarioIdLogueado != null && cargandoPacientes && pacientesDialogo.isEmpty) {
            Future.microtask(() async {
              try {
                final resultado = await _estadoService.obtenerPacientes(usuarioIdLogueado);
                if (resultado['success']) {
                  setDialogState(() {
                    pacientesDialogo = List<Map<String, dynamic>>.from(resultado['data'] ?? []);
                    cargandoPacientes = false;
                  });
                } else {
                  setDialogState(() {
                    cargandoPacientes = false;
                  });
                }
              } catch (e) {
                print('Error al cargar pacientes: $e');
                setDialogState(() {
                  cargandoPacientes = false;
                });
              }
            });
          }

          return AlertDialog(
          title: Text(
            'Configurar Reporte',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Solo mostrar selección de paciente para psicólogos (tipo 2)
                if (tipoUsuario == 2) ...[
                  SizedBox(height: 16),
                  if (cargandoPacientes)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else if (pacientesDialogo.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay pacientes asignados',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else ...[
                    Text(
                      'Seleccionar Paciente:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: pacienteSeleccionadoId,
                          isExpanded: true,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          hint: Text('Seleccione un paciente'),
                          items: pacientesDialogo.map((paciente) {
                            return DropdownMenuItem<int?>(
                              value: paciente['id'],
                              child: Text(paciente['nombre'] ?? 'Sin nombre'),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            setDialogState(() {
                              pacienteSeleccionadoId = valor;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ],
                // Para pacientes (tipo 1), no se muestra ningún campo de usuario
                // Se usa automáticamente el ID del usuario logueado
                SizedBox(height: 16),
                Text(
                  'Fecha de Inicio:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: _fechaInicio ?? DateTime.now().subtract(Duration(days: 7)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (fecha != null) {
                      setDialogState(() {
                        _fechaInicio = fecha;
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          _fechaInicio != null
                              ? '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}'
                              : 'Seleccionar fecha',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Fecha de Fin:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: _fechaFin ?? DateTime.now(),
                      firstDate: _fechaInicio ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (fecha != null) {
                      setDialogState(() {
                        _fechaFin = fecha;
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          _fechaFin != null
                              ? '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}'
                              : 'Seleccionar fecha',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validar campos según el tipo de usuario
                int? idUsuario;
                
                if (tipoUsuario == 2) {
                  // Si es psicólogo, validar que se haya seleccionado un paciente
                  if (pacienteSeleccionadoId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Por favor seleccione un paciente'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  idUsuario = pacienteSeleccionadoId;
                } else if (tipoUsuario == 1) {
                  // Si es paciente, usar directamente el ID del usuario logueado
                  if (idUsuarioParaReporte == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: No se pudo obtener el ID del usuario'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  idUsuario = idUsuarioParaReporte;
                } else {
                  // Para otros tipos de usuario (si los hay), validar el campo de texto
                  if (_idUsuarioController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Por favor ingrese un ID de usuario'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  idUsuario = int.tryParse(_idUsuarioController.text.trim());
                  if (idUsuario == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('El ID de usuario debe ser un número válido'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                if (_fechaInicio == null || _fechaFin == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Por favor seleccione ambas fechas'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (_fechaInicio!.isAfter(_fechaFin!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('La fecha de inicio debe ser anterior a la fecha de fin'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context, {
                  'idUsuario': idUsuario,
                  'fechaInicio': _fechaInicio,
                  'fechaFin': _fechaFin,
                });
              },
              child: Text('Generar Reporte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),
          ],
        );
        },
      ),
    );

    if (resultado != null) {
      final idUsuario = resultado['idUsuario'] as int;
      final fechaInicio = resultado['fechaInicio'] as DateTime;
      final fechaFin = resultado['fechaFin'] as DateTime;

      // Cargar estados de ánimo con el rango de fechas especificado
      await _cargarEstadosAnimoPersonalizado(idUsuario, fechaInicio, fechaFin);
    }
  }

  Future<void> _cargarEstadosAnimoPersonalizado(int idUsuario, DateTime fechaInicio, DateTime fechaFin) async {
    setState(() => _isLoading = true);

    try {
      // Normalizar fechas para comparación (solo fecha, sin hora)
      final fechaInicioNormalizada = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
      final fechaFinNormalizada = DateTime(fechaFin.year, fechaFin.month, fechaFin.day, 23, 59, 59);
      
      // Cargar estados de ánimo por período y luego filtrar por rango de fechas
      final resultado = await _estadoService.obtenerEstadosAnimoPorPeriodo(
        idUsuario,
        fechaInicioNormalizada,
      );

      if (resultado['success']) {
        final datosEstados = resultado['data'] as List;

        List<estado_model.EstadoAnimo> estadosCargados = [];

        for (var item in datosEstados) {
          try {
            final fechaCreacionStr = item['fecha_creacion']?.toString();
            if (fechaCreacionStr == null) continue;
            
            // Parsear fecha de creación
            DateTime fechaCreacion;
            try {
              fechaCreacion = DateTime.parse(fechaCreacionStr);
            } catch (e) {
              // Intentar parsear como fecha sin hora
              final partes = fechaCreacionStr.split('T')[0].split('-');
              if (partes.length == 3) {
                fechaCreacion = DateTime(
                  int.parse(partes[0]),
                  int.parse(partes[1]),
                  int.parse(partes[2]),
                );
              } else {
                continue;
              }
            }
            
            // Normalizar fecha de creación para comparación
            final fechaCreacionNormalizada = DateTime(
              fechaCreacion.year,
              fechaCreacion.month,
              fechaCreacion.day,
            );
            
            // Filtrar por rango de fechas (inclusive)
            if (fechaCreacionNormalizada.isAfter(fechaInicioNormalizada.subtract(Duration(days: 1))) &&
                fechaCreacionNormalizada.isBefore(fechaFinNormalizada.add(Duration(days: 1)))) {
              estadosCargados.add(
                estado_model.EstadoAnimo(
                  id: item['id'],
                  estado: item['estado'] is int
                      ? item['estado']
                      : int.parse(item['estado'].toString()),
                  comentario: item['comentario']?.toString() ?? '',
                  fechaCreacion: fechaCreacion,
                ),
              );
            }
          } catch (e) {
            print('Error al procesar estado: $e');
            continue;
          }
        }

        // Ordenar por fecha de creación (más reciente primero)
        estadosCargados.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

        setState(() {
          estadosAnimo = estadosCargados;
          _pacienteSeleccionado = idUsuario;
        });

        if (estadosCargados.isEmpty) {
          _mostrarError('No se encontraron registros para el usuario $idUsuario en el rango de fechas seleccionado');
        } else {
          _mostrarExito('Se encontraron ${estadosCargados.length} registros en el rango seleccionado');
          // Mostrar diálogo de opciones de exportación
          _mostrarOpcionesExportacion();
        }
      } else {
        final errorMsg = resultado['error'] ?? 'Error desconocido al cargar datos';
        _mostrarError('Error al cargar estados: $errorMsg');
        setState(() {
          estadosAnimo = [];
        });
      }
    } catch (e) {
      _mostrarError('Error al cargar estados: $e');
      setState(() {
        estadosAnimo = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarOpcionesExportacion() {
    if (estadosAnimo.isEmpty) {
      _mostrarError('No hay datos para generar el reporte');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen del Reporte:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            _buildResumenItem('Total de registros:', '${estadosAnimo.length}'),
            _buildResumenItem('Promedio:', _calcularPromedio().toStringAsFixed(2)),
            if (_pacienteSeleccionado != null)
              _buildResumenItem('ID Usuario:', '${_pacienteSeleccionado}'),
            _buildResumenItem(
              'Período:',
              _getRangoFechasTexto(),
            ),
            SizedBox(height: 16),
            Text(
              '¿Cómo desea exportar el reporte?',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _exportarComoTexto();
            },
            icon: Icon(Icons.text_snippet),
            label: Text('Texto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _exportarComoJSON();
            },
            icon: Icon(Icons.code),
            label: Text('JSON'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                setState(() => _isLoading = true);
                final reporte = await Generar_Pdf.generar_pdf_tabla(estadosAnimo);
                setState(() => _isLoading = false);
                _mostrarExito('Reporte PDF generado exitosamente con ${estadosAnimo.length} registros');
              } catch (e) {
                setState(() => _isLoading = false);
                _mostrarError('Error al generar el reporte PDF: $e');
              }
            },
            icon: Icon(Icons.picture_as_pdf),
            label: Text('PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _getNombrePeriodo() {
    switch (_periodoSeleccionado) {
      case '7dias':
        return 'Últimos 7 días';
      case '30dias':
        return 'Últimos 30 días';
      case '3meses':
        return 'Últimos 3 meses';
      case '6meses':
        return 'Últimos 6 meses';
      default:
        return 'Personalizado';
    }
  }

  String _getRangoFechasTexto() {
    if (_fechaInicio != null && _fechaFin != null) {
      return '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year} - ${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}';
    }
    return _getNombrePeriodo();
  }

  void _exportarComoTexto() {
    String reporte = '═══════════════════════════════════\n';
    reporte += 'REPORTE DE ESTADOS DE ÁNIMO\n';
    reporte += '═══════════════════════════════════\n\n';

    reporte += 'Período: ${_getRangoFechasTexto()}\n';
    if (_pacienteSeleccionado != null) {
      reporte += 'ID Usuario: ${_pacienteSeleccionado}\n';
    }
    reporte += 'Fecha de generación: ${_formatearFecha(DateTime.now())}\n';
    reporte += 'Total de registros: ${estadosAnimo.length}\n';
    reporte += 'Promedio general: ${_calcularPromedio().toStringAsFixed(2)}/5\n\n';

    reporte += '--- DISTRIBUCIÓN ---\n';
    Map<String, int> dist = _calcularDistribucion();
    dist.forEach((key, value) {
      double porcentaje = (value / estadosAnimo.length) * 100;
      reporte += '$key: $value (${porcentaje.toStringAsFixed(1)}%)\n';
    });

    reporte += '\n--- REGISTROS ---\n';
    for (var estado in estadosAnimo.take(20)) {
      reporte += '\n${_formatearFecha(estado.fechaCreacion)}\n';
      reporte += 'Estado: ${estado.estado}/5 ${estado.getEmoji()}\n';
      if (estado.comentario.isNotEmpty) {
        reporte += 'Comentario: ${estado.comentario}\n';
      }
      reporte += '---\n';
    }

    print(reporte);
    _mostrarExito('Reporte generado en la consola');
  }

  void _exportarComoJSON() {
    Map<String, dynamic> reporte = {
      'periodo': _getRangoFechasTexto(),
      'fecha_inicio': _fechaInicio?.toIso8601String(),
      'fecha_fin': _fechaFin?.toIso8601String(),
      'id_usuario': _pacienteSeleccionado,
      'fecha_generacion': DateTime.now().toIso8601String(),
      'total_registros': estadosAnimo.length,
      'promedio': _calcularPromedio(),
      'distribucion': _calcularDistribucion(),
      'registros': estadosAnimo.map((e) => {
        'id': e.id,
        'estado': e.estado,
        'comentario': e.comentario,
        'fecha': e.fechaCreacion.toIso8601String(),
      }).toList(),
    };

    print('JSON Reporte:');
    print(reporte);
    _mostrarExito('Reporte JSON generado en la consola');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reportes de Estados de Ánimo',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltros(),
            SizedBox(height: 20),
            _buildTarjetasResumen(),
            SizedBox(height: 20),
            _buildGraficoTendencia(),
            SizedBox(height: 20),
            _buildGraficoDistribucion(),
            SizedBox(height: 20),
            _buildListaEstados(),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _generarReporte,
                child: const Text('Generar Reporte PDF'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (widget.esPsicologo && pacientes.isNotEmpty) ...[
              Text('Paciente:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _pacienteSeleccionado,
                    isExpanded: true,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    items: pacientes.map((paciente) {
                      return DropdownMenuItem<int?>(
                        value: paciente['id'],
                        child: Text(paciente['nombre']),
                      );
                    }).toList(),
                    onChanged: (valor) {
                      setState(() {
                        _pacienteSeleccionado = valor;
                        _codigoPacienteController.clear();
                      });
                      _cargarEstadosAnimo();
                    },
                  ),
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Text('O buscar por código:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _mostrarCampoCodigo = !_mostrarCampoCodigo;
                      });
                    },
                    icon: Icon(
                      _mostrarCampoCodigo ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(_mostrarCampoCodigo ? 'Ocultar' : 'Mostrar'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              if (_mostrarCampoCodigo) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codigoPacienteController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Código del paciente',
                          hintText: 'Ej: 123',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _buscarPorCodigo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Icon(Icons.search, color: Colors.white),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 16),
            ],
            Text('Período:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _periodoSeleccionado,
                  isExpanded: true,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  items: [
                    DropdownMenuItem(value: '7dias', child: Text('Últimos 7 días')),
                    DropdownMenuItem(value: '30dias', child: Text('Últimos 30 días')),
                    DropdownMenuItem(value: '3meses', child: Text('Últimos 3 meses')),
                    DropdownMenuItem(value: '6meses', child: Text('Últimos 6 meses')),
                  ],
                  onChanged: (valor) {
                    setState(() {
                      _periodoSeleccionado = valor!;
                    });
                    _cargarEstadosAnimo();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetasResumen() {
    double promedio = _calcularPromedio();

    return Row(
      children: [
        Expanded(
          child: _buildTarjetaMetrica(
            'Total Registros',
            estadosAnimo.length.toString(),
            Icons.assessment,
            Colors.blue,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildTarjetaMetrica(
            'Promedio',
            promedio.toStringAsFixed(1),
            Icons.trending_up,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildTarjetaMetrica(
      String titulo,
      String valor,
      IconData icono,
      Color color,
      ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: color, size: 28),
            ),
            SizedBox(height: 12),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoTendencia() {
    Map<String, List<int>> estadosPorDia = _agruparPorDia();

    if (estadosPorDia.isEmpty) {
      return _buildCardVacio('No hay datos para mostrar la tendencia');
    }

    Map<String, double> promediosPorDia = {};
    estadosPorDia.forEach((fecha, estados) {
      double promedio = estados.reduce((a, b) => a + b) / estados.length;
      promediosPorDia[fecha] = promedio;
    });

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Tendencia de Estados de Ánimo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: promediosPorDia.entries.map((entry) {
                  double altura = (entry.value / 5) * 160;
                  Color color = _getColorPorEstado(entry.value.round());

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            entry.value.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            height: altura,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.7),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            entry.key,
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoDistribucion() {
    Map<String, int> distribucion = _calcularDistribucion();
    int total = estadosAnimo.length;

    if (total == 0) {
      return _buildCardVacio('No hay datos para mostrar la distribución');
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'Distribución de Estados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ...distribucion.entries.map((entry) {
              double porcentaje = total == 0 ? 0 : (entry.value / total) * 100;
              Color color = _getColorPorNombre(entry.key);

              return Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${entry.value} (${porcentaje.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: porcentaje / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildListaEstados() {
    if (estadosAnimo.isEmpty) {
      return _buildCardVacio('No hay registros en este período');
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Últimos Registros (${estadosAnimo.length > 10 ? '10' : estadosAnimo.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...estadosAnimo.take(10).map((estado) {
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: EdgeInsets.all(8),
                  tileColor: estado.getColor().withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: estado.getColor().withOpacity(0.3)),
                  ),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: estado.getColor().withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        estado.getEmoji(),
                        style: TextStyle(fontSize: 24),
                      ),
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
                        Text(
                          estado.comentario,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 4),
                      Text(
                        _formatearFecha(estado.fechaCreacion),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardVacio(String mensaje) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.mood, size: 60, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                mensaje,
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorPorEstado(int estado) {
    switch (estado) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getColorPorNombre(String nombre) {
    switch (nombre) {
      case 'Muy Triste':
        return Colors.red;
      case 'Triste':
        return Colors.orange;
      case 'Neutral':
        return Colors.yellow[700]!;
      case 'Feliz':
        return Colors.lightGreen;
      case 'Muy Feliz':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}