import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../servicios/Usuario.dart';
import '../Objetivo.dart' as objetivo_model;
import '../Recordatorio.dart' as recordatorio_model;
import '../servicios/db_helper.dart';
import 'Pantalla_Objetivos.dart';
import 'Pantalla_Recordatorios.dart';
import 'Pantalla_Reportes.dart';
import 'Pantalla_Generar_QR.dart';

class PantallaTablaUsuarios extends StatefulWidget {
  @override
  _PantallaTablaUsuariosState createState() => _PantallaTablaUsuariosState();
}

class Registro {
  final int psicologoId;
  final int pacienteId;
  final String pacienteUsuario;

  Registro({
    required this.psicologoId,
    required this.pacienteId,
    required this.pacienteUsuario,
  });

  factory Registro.fromJson(Map<String, dynamic> json) {
    return Registro(
      psicologoId: json['psicologo'] ?? json['psicologo_id'] ?? 0,
      pacienteId: json['paciente'] ?? json['paciente_id'] ?? json['id_paciente'] ?? 0,
      pacienteUsuario: json['paciente_usuario'] ??
          json['usuario'] ??
          json['nombre_usuario'] ??
          '',
    );
  }
}


class RegistroService {
  static const String baseUrl = 'https://moodtrackapi-production.up.railway.app/api';
  static const String relacionesPath = '$baseUrl/Registrarpaciente';

  static Future<List<Registro>> obtenerRegistros() async {
    try {
      print('🔄 Obteniendo relaciones psicólogo-paciente');

      final response = await http.get(
        Uri.parse(relacionesPath),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> jsonList;
        if (decoded is List) {
          jsonList = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          jsonList = decoded['data'];
        } else {
          throw Exception('Formato inesperado en la respuesta del servidor');
        }

        final registros = jsonList.map((json) => Registro.fromJson(json)).toList();
        print('✅ ${registros.length} relaciones obtenidas exitosamente');
        return registros;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener registros: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Registro> crearRegistro({
    required int psicologoId,
    required int pacienteId,
  }) async {
    try {
      print('🔄 Creando relación psicólogo $psicologoId - paciente $pacienteId');
      
      final response = await http.post(
        Uri.parse(relacionesPath),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id_psicologo': psicologoId,
          'id_paciente': pacienteId,
        }),
      ).timeout(Duration(seconds: 10));

      print('📥 Respuesta del servidor: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final registroCreado = Registro.fromJson(
          data is Map<String, dynamic> ? data : data['data'],
        );
        print('✅ Relación creada exitosamente');
        return registroCreado;
      } else {
        // Intentar obtener mensaje de error del servidor
        String mensajeError = 'Error al crear registro';
        try {
          final errorData = json.decode(response.body);
          mensajeError = errorData['error'] ?? errorData['message'] ?? mensajeError;
        } catch (e) {
          mensajeError = 'Error del servidor: ${response.statusCode}';
        }
        print('❌ Error: $mensajeError');
        throw Exception(mensajeError);
      }
    } catch (e) {
      print('❌ Error al crear registro: $e');
      // Si es un timeout o error de conexión, lanzar un mensaje más claro
      if (e.toString().contains('TimeoutException') || e.toString().contains('SocketException')) {
        throw Exception('Error de conexión. Verifica tu conexión a internet.');
      }
      throw e;
    }
  }

  static Future<void> eliminarRegistro({
    required int psicologoId,
    required int pacienteId,
  }) async {
    try {
      print('🗑 Eliminando relación psicólogo $psicologoId - paciente $pacienteId');

      final response = await http.delete(
        Uri.parse('$relacionesPath/$psicologoId/$pacienteId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar registro');
      }

      print('Registro eliminado exitosamente');
    } catch (e) {
      print('Error al eliminar registro: $e');
      throw Exception('Error al eliminar registro: $e');
    }
  }
}


class _PantallaTablaUsuariosState extends State<PantallaTablaUsuarios> {
  List<Registro> registros = [];
  bool isLoading = true;
  String? error;
  int? _psicologoId;
  int _indiceSeleccionado = 0;
  List<objetivo_model.Objetivo> objetivos = [];
  List<recordatorio_model.Recordatorio> recordatorios = [];
  bool _cargandoObjetivos = false;
  bool _cargandoRecordatorios = false;
  final DBHelper _dbHelper = DBHelper();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // Método para refrescar cuando la pantalla vuelve a estar visible
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refrescar datos cuando la pantalla vuelve a estar visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _indiceSeleccionado == 0) {
        cargarDatos();
      }
    });
  }

  Future<void> _initialize() async {
    final id = await UsuarioService.obtenerUsuarioId();
    if (!mounted) return;
    setState(() {
      _psicologoId = id;
    });
    await Future.wait([
      cargarDatos(),
      _cargarObjetivos(),
      _cargarRecordatorios(),
    ]);
  }

  Future<void> cargarDatos() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final datos = await RegistroService.obtenerRegistros();
      setState(() {
        if (_psicologoId != null) {
          registros = datos.where((registro) => registro.psicologoId == _psicologoId).toList();
        } else {
          registros = datos;
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _cargarObjetivos() async {
    if (_psicologoId == null) return;
    setState(() {
      _cargandoObjetivos = true;
    });

    try {
      final objetivosCargados = await _dbHelper.getAllObjetivos(_psicologoId!);
      if (!mounted) return;
      setState(() {
        objetivos = objetivosCargados;
        _cargandoObjetivos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoObjetivos = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar objetivos: $e')),
      );
    }
  }

  Future<void> _agregarObjetivo(objetivo_model.Objetivo objetivo, {int? pacienteId}) async {
    if (_psicologoId == null) return;
    try {
      // Si hay un pacienteId (psicólogo seleccionó un paciente), usar ese ID
      // Si no, usar el ID del psicólogo actual
      final idUsuarioFinal = pacienteId ?? _psicologoId!;
      
      final objetivoGuardado = await _dbHelper.insertObjetivo(
        objetivo,
        idUsuarioFinal,
      );
      if (objetivoGuardado != null && mounted) {
        setState(() {
          objetivos.add(objetivoGuardado);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Objetivo guardado correctamente')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar objetivo: $e')),
      );
    }
  }

  Future<void> _actualizarObjetivo(int indice, objetivo_model.Objetivo objetivo) async {
    try {
      final exito = await _dbHelper.updateObjetivo(objetivo);
      if (exito && mounted) {
        setState(() {
          objetivos[indice] = objetivo;
        });
      } else {
        throw Exception('No se pudo actualizar el objetivo');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar objetivo: $e')),
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
        content: Text('¿Eliminar "${objetivo.titulo}"?'),
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
        if (exito && mounted) {
          setState(() {
            objetivos.removeAt(indice);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Objetivo eliminado')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar objetivo: $e')),
        );
      }
    }
  }

  Future<void> _cargarRecordatorios() async {
    if (_psicologoId == null) return;
    setState(() {
      _cargandoRecordatorios = true;
    });

    try {
      final recordatoriosCargados =
          await _dbHelper.getAllRecordatorios(_psicologoId!);
      if (!mounted) return;
      setState(() {
        recordatorios = recordatoriosCargados;
        _cargandoRecordatorios = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoRecordatorios = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar recordatorios: $e')),
      );
    }
  }

  Future<void> _agregarRecordatorio(
      recordatorio_model.Recordatorio recordatorio, {int? pacienteId}) async {
    if (_psicologoId == null) return;
    try {
      // Si hay un pacienteId (psicólogo seleccionó un paciente), usar ese ID
      // Si no, usar el ID del psicólogo actual
      final idUsuarioFinal = pacienteId ?? _psicologoId!;
      
      final recordatorioGuardado = await _dbHelper.insertRecordatorio(
        recordatorio,
        idUsuarioFinal,
      );
      if (recordatorioGuardado != null && mounted) {
        setState(() {
          recordatorios.add(recordatorioGuardado);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Recordatorio guardado correctamente')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar recordatorio: $e')),
      );
    }
  }

  Future<void> _actualizarRecordatorio(
      int indice, recordatorio_model.Recordatorio recordatorio) async {
    try {
      final exito = await _dbHelper.updateRecordatorio(recordatorio);
      if (exito && mounted) {
        setState(() {
          recordatorios[indice] = recordatorio;
        });
      } else {
        throw Exception('No se pudo actualizar el recordatorio');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar recordatorio: $e')),
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
        content: Text('¿Eliminar "${recordatorio.titulo}"?'),
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
        if (exito && mounted) {
          setState(() {
            recordatorios.removeAt(indice);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Recordatorio eliminado')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar recordatorio: $e')),
        );
      }
    }
  }

  void mostrarDialogoAgregar() {
    if (_psicologoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo determinar el psicólogo actual.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Abrir la pantalla para generar el código QR
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaGenerarQR(
          psicologoId: _psicologoId!,
        ),
      ),
    );
  }

  void confirmarEliminar(Registro registro) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirmar eliminación'),
          content: Text('¿Eliminar la relación con el paciente ${registro.pacienteUsuario.isNotEmpty ? registro.pacienteUsuario : registro.pacienteId}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await RegistroService.eliminarRegistro(
                    psicologoId: registro.psicologoId,
                    pacienteId: registro.pacienteId,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Relación eliminada'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  cargarDatos();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentPage(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildPacientesPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pacientes asignados',
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
                      'Registro de pacientes',
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
          if (_psicologoId != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Psicólogo actual: $_psicologoId',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Expanded(
            child: _buildPacientesContent(),
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

  Widget _buildPacientesContent() {
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
                  'ID Paciente',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Usuario',
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
                  DataCell(Text(registro.pacienteId.toString())),
                  DataCell(Text(
                    registro.pacienteUsuario.isNotEmpty
                        ? registro.pacienteUsuario
                        : '—',
                  )),
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

  Widget _getCurrentPage() {
    switch (_indiceSeleccionado) {
      case 0:
        return _buildPacientesPage();
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
        return PantallaReportesEstadoAnimo();
      default:
        return _buildPacientesPage();
    }
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _indiceSeleccionado,
      onTap: (indice) {
        setState(() {
          _indiceSeleccionado = indice;
        });
        if (indice == 0) {
          // Refrescar tabla de pacientes cuando se vuelve a esta pestaña
          cargarDatos();
        } else if (indice == 1) {
          _cargarObjetivos();
        } else if (indice == 2) {
          _cargarRecordatorios();
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Pacientes',
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
          icon: Icon(Icons.notifications),
          label: 'Reportes',
        ),
      ],
    );
  }
}