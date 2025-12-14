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
import 'Pantalla_Objetivos.dart';
import '../Recordatorio.dart';
import '../servicios/db_helper.dart';
import '../servicios/Usuario.dart';
import '../servicios/Guardar_Estado_Animo.dart';

class PantallaRecordatorios extends StatelessWidget {
  final List<Recordatorio> recordatorios;
  final Function(Recordatorio, {int? pacienteId}) alAgregarRecordatorio;
  final Function(int) alAlternarRecordatorio;
  final Function(int) alEliminarRecordatorio;
  final bool cargando;
  final Future<void> Function()? onRefresh;

  PantallaRecordatorios({
    required this.recordatorios,
    required this.alAgregarRecordatorio,
    required this.alAlternarRecordatorio,
    required this.alEliminarRecordatorio,
    this.cargando = false,
    this.onRefresh,
  });

  final List<String> nombresDiasSemana = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recordatorios',
            style: TextStyle(fontSize: 24, color: Colors.white , fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.black,
      ),
      body: cargando
          ? Center(child: CircularProgressIndicator())
          : recordatorios.isEmpty
              ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 80, color: Colors.grey),
            Text(
              'No tienes recordatorios aún',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
              : RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: ListView.builder(
          itemCount: recordatorios.length,
          itemBuilder: (context, indice) {
            final recordatorio = recordatorios[indice];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(
                  recordatorio.estaActivo ? Icons.notifications_active : Icons.notifications_off,
                  color: recordatorio.estaActivo ? Colors.purple : Colors.grey,
                ),
                title: Text(recordatorio.titulo),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recordatorio.descripcion.isNotEmpty) Text(recordatorio.descripcion),
                    Text('Hora: ${recordatorio.hora.format(context)}'),
                    if (recordatorio.fechaRecordatorio != null)
                      Text(
                        'Fecha: ${_formatearFecha(recordatorio.fechaRecordatorio!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      )
                    else if (recordatorio.diasSemana != null && recordatorio.diasSemana!.isNotEmpty)
                      Text(
                        'Días: ${recordatorio.diasSemana!.map((dia) => nombresDiasSemana[dia - 1]).join(', ')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: recordatorio.estaActivo,
                      onChanged: (valor) => alAlternarRecordatorio(indice),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => alEliminarRecordatorio(indice),
                      tooltip: 'Eliminar recordatorio',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoAgregarRecordatorio(context),
        child: Icon(Icons.add),
        backgroundColor: Colors.black,
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  void _mostrarDialogoAgregarRecordatorio(BuildContext context) async {
    final tipoUsuario = await UsuarioService.obtenerTipoUsuario() ?? 0;
    final psicologoId = await UsuarioService.obtenerUsuarioId();
    
    String titulo = '';
    String descripcion = '';
    int? pacienteSeleccionadoId;
    List<Map<String, dynamic>> pacientes = [];
    bool cargandoPacientes = tipoUsuario == 2 && psicologoId != null;
    String tipoRecordatorio = 'Una vez'; // 'Una vez' o 'Repetir'
    TimeOfDay horaSeleccionada = TimeOfDay.now();
    DateTime fechaSeleccionada = DateTime.now();
    List<int> diasSemanaSeleccionados = [];

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
          title: Text('Nuevo Recordatorio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Título del recordatorio',
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
                Text('Tipo de recordatorio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Una vez'),
                        value: 'Una vez',
                        groupValue: tipoRecordatorio,
                        onChanged: (valor) {
                          setDialogState(() {
                            tipoRecordatorio = valor!;
                            diasSemanaSeleccionados.clear();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Repetir'),
                        value: 'Repetir',
                        groupValue: tipoRecordatorio,
                        onChanged: (valor) {
                          setDialogState(() {
                            tipoRecordatorio = valor!;
                            fechaSeleccionada = DateTime.now();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ListTile(
                  title: Text('Hora del recordatorio'),
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
                if (tipoRecordatorio == 'Una vez') ...[
                  SizedBox(height: 16),
                  ListTile(
                    title: Text('Fecha del recordatorio'),
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
                ] else ...[
                  SizedBox(height: 16),
                  Text('Días de la semana:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Wrap(
                    children: List.generate(7, (indice) {
                      final dia = indice + 1;
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(nombresDiasSemana[indice]),
                          selected: diasSemanaSeleccionados.contains(dia),
                          onSelected: (seleccionado) {
                            setDialogState(() {
                              if (seleccionado) {
                                diasSemanaSeleccionados.add(dia);
                              } else {
                                diasSemanaSeleccionados.remove(dia);
                              }
                            });
                          },
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: (titulo.isNotEmpty && 
                         (tipoRecordatorio == 'Una vez' || 
                          (tipoRecordatorio == 'Repetir' && diasSemanaSeleccionados.isNotEmpty)) &&
                         (tipoUsuario != 2 || pacienteSeleccionadoId != null))
                  ? () {
                // Si es "Una vez", combinar fecha y hora
                DateTime? fechaCompleta;
                if (tipoRecordatorio == 'Una vez') {
                  fechaCompleta = DateTime(
                    fechaSeleccionada.year,
                    fechaSeleccionada.month,
                    fechaSeleccionada.day,
                    horaSeleccionada.hour,
                    horaSeleccionada.minute,
                  );
                }
                
                final recordatorio = Recordatorio(
                  titulo: titulo,
                  descripcion: descripcion,
                  hora: horaSeleccionada,
                  diasSemana: tipoRecordatorio == 'Repetir' ? diasSemanaSeleccionados : null,
                  fechaRecordatorio: fechaCompleta,
                  fechaCreacion: DateTime.now(),
                );
                alAgregarRecordatorio(
                  recordatorio,
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
}