import 'dart:convert';

import 'package:flutter/material.dart';
import 'PantallaEstadoAnimo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path_package;
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'Pantalla_login.dart';
import 'Pantalla_registro.dart';
import 'package:http/http.dart' as http;
import '../Objetivo.dart';
import '../servicios/db_helper.dart';
import '../servicios/Usuario.dart'; // Agregar este import
import '../servicios/Guardar_Estado_Animo.dart';

class PantallaObjetivos extends StatelessWidget {
  final List<Objetivo> objetivos;
  final Function(Objetivo, {int? pacienteId}) alAgregarObjetivo;
  final Function(int, Objetivo) alActualizarObjetivo;
  final Function(int) alEliminarObjetivo;
  final bool cargando;
  final Future<void> Function()? onRefresh;

  PantallaObjetivos({
    required this.objetivos,
    required this.alAgregarObjetivo,
    required this.alActualizarObjetivo,
    required this.alEliminarObjetivo,
    this.cargando = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Objetivos',
            style: TextStyle(fontSize: 24, color: Colors.white , fontWeight: FontWeight.bold)  ),
        backgroundColor: Colors.black,
      ),
      body: cargando
          ? Center(child: CircularProgressIndicator())
          : objetivos.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag, size: 80, color: Colors.grey),
            Text(
              'No tienes objetivos aún',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: ListView.builder(
          itemCount: objetivos.length,
          itemBuilder: (context, indice) {
            final objetivo = objetivos[indice];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: objetivo.id != null ? () {
                  alActualizarObjetivo(
                    indice,
                    Objetivo(
                      id: objetivo.id,
                      idUsuario: objetivo.idUsuario,
                      titulo: objetivo.titulo,
                      descripcion: objetivo.descripcion,
                      fechaObjetivo: objetivo.fechaObjetivo,
                      horaObjetivo: objetivo.horaObjetivo,
                      estaCompletado: !objetivo.estaCompletado,
                      fechaCreacion: objetivo.fechaCreacion,
                    ),
                  );
                } : null,
                child: ListTile(
                  leading: GestureDetector(
                    onTap: objetivo.id != null ? () {
                      alActualizarObjetivo(
                        indice,
                        Objetivo(
                          id: objetivo.id,
                          idUsuario: objetivo.idUsuario,
                          titulo: objetivo.titulo,
                          descripcion: objetivo.descripcion,
                          fechaObjetivo: objetivo.fechaObjetivo,
                          horaObjetivo: objetivo.horaObjetivo,
                          estaCompletado: !objetivo.estaCompletado,
                          fechaCreacion: objetivo.fechaCreacion,
                        ),
                      );
                    } : null,
                    child: Checkbox(
                      value: objetivo.estaCompletado,
                      onChanged: objetivo.id != null ? (valor) {
                        alActualizarObjetivo(
                          indice,
                          Objetivo(
                            id: objetivo.id,
                            idUsuario: objetivo.idUsuario,
                            titulo: objetivo.titulo,
                            descripcion: objetivo.descripcion,
                            fechaObjetivo: objetivo.fechaObjetivo,
                            horaObjetivo: objetivo.horaObjetivo,
                            estaCompletado: valor ?? false,
                            fechaCreacion: objetivo.fechaCreacion,
                          ),
                        );
                      } : null,
                    ),
                  ),
                title: Text(
                  objetivo.titulo,
                  style: TextStyle(
                    decoration: objetivo.estaCompletado
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (objetivo.descripcion.isNotEmpty) Text(objetivo.descripcion),
                    Text(
                      'Fecha: ${_formatearFecha(objetivo.fechaObjetivo)} a las ${objetivo.horaObjetivo.format(context)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      objetivo.estaCompletado ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: objetivo.estaCompletado ? Colors.green : Colors.grey,
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => alEliminarObjetivo(indice),
                      tooltip: 'Eliminar objetivo',
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoAgregarObjetivo(context),
        child: Icon(Icons.add),
        backgroundColor: Colors.black,
      ),
    );
  }

  void _mostrarDialogoAgregarObjetivo(BuildContext context) async {
    // Obtener el tipo de usuario guardado
    final tipoUsuario = await UsuarioService.obtenerTipoUsuario() ?? 0;
    final psicologoId = await UsuarioService.obtenerUsuarioId();
    
    String titulo = '';
    String descripcion = '';
    int? pacienteSeleccionadoId;
    List<Map<String, dynamic>> pacientes = [];
    bool cargandoPacientes = tipoUsuario == 2 && psicologoId != null;
    DateTime fechaSeleccionada = DateTime.now();
    TimeOfDay horaSeleccionada = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Cargar pacientes si es psicólogo y aún no se han cargado
          if (tipoUsuario == 2 && psicologoId != null && cargandoPacientes && pacientes.isEmpty) {
            Future.microtask(() async {
              try {
                final estadoService = Guardar_Estado();
                final resultado = await estadoService.obtenerPacientes(psicologoId);
                if (resultado['success']) {
                  setDialogState(() {
                    pacientes = List<Map<String, dynamic>>.from(resultado['data'] ?? []);
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
          title: Text('Nuevo Objetivo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Título del objetivo',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (valor) {
                    titulo = valor;
                    setDialogState(() {});
                  },
                ),
                if (tipoUsuario == 2) ...[
                  SizedBox(height: 16),
                  if (cargandoPacientes)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else if (pacientes.isEmpty)
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
                          items: pacientes.map((paciente) {
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
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (valor) => descripcion = valor,
                ),
                SizedBox(height: 16),
                ListTile(
                  title: Text('Fecha objetivo'),
                  subtitle: Text(_formatearFecha(fechaSeleccionada)),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: fechaSeleccionada,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (fecha != null) {
                      setDialogState(() {
                        fechaSeleccionada = fecha;
                      });
                    }
                  },
                ),
                ListTile(
                  title: Text('Hora objetivo'),
                  subtitle: Text(horaSeleccionada.format(context)),
                  trailing: Icon(Icons.access_time),
                  onTap: () async {
                    final hora = await showTimePicker(
                      context: context,
                      initialTime: horaSeleccionada,
                    );
                    if (hora != null) {
                      setDialogState(() {
                        horaSeleccionada = hora;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: (titulo.isNotEmpty && (tipoUsuario != 2 || pacienteSeleccionadoId != null))
                  ? () {
                alAgregarObjetivo(
                  Objetivo(
                    titulo: titulo,
                    descripcion: descripcion,
                    fechaObjetivo: fechaSeleccionada,
                    horaObjetivo: horaSeleccionada,
                    fechaCreacion: DateTime.now(),
                  ),
                  pacienteId: tipoUsuario == 2 ? pacienteSeleccionadoId : null,
                );
                Navigator.pop(context);
              }
                  : null,
              child: Text('Crear'),
            ),
          ],
        );
        },
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}