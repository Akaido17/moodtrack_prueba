import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:io';

class NotificacionesService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('🔔 Inicializando servicio de notificaciones...');

      // Inicializar timezone
      try {
        tz_data.initializeTimeZones();
        print('✅ Timezone inicializado');
      } catch (e) {
        print('⚠️ Error al inicializar timezone: $e');
        // Continuar aunque falle la inicialización de timezone
      }

      // Crear canal de notificaciones para Android (debe hacerse antes de inicializar)
      if (Platform.isAndroid) {
        try {
          final androidInfo = await _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          if (androidInfo != null) {
            // Crear canal de notificaciones con alta importancia
            const androidChannel = AndroidNotificationChannel(
              'recordatorios_canal',
              'Recordatorios',
              description: 'Notificaciones de recordatorios',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            );
            await androidInfo.createNotificationChannel(androidChannel);
            print('✅ Canal de notificaciones creado: recordatorios_canal');
          }
        } catch (e) {
          print('⚠️ Error al crear canal de notificaciones: $e');
          // Continuar aunque falle la creación del canal
        }
      }

      // Configuración para Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configuración para iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      try {
        final initialized = await _notifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (details) {
            // Manejar cuando se toca la notificación
            print('🔔 Notificación tocada: ${details.id}');
          },
        );

        if (initialized != null) {
          print('🔔 Inicialización del plugin: ${initialized ? "EXITOSA" : "FALLIDA"}');
        } else {
          print('🔔 Inicialización del plugin: RESULTADO DESCONOCIDO');
        }
      } catch (e) {
        print('⚠️ Error al inicializar el plugin de notificaciones: $e');
        // Continuar aunque falle la inicialización
      }

      // Solicitar permisos para Android 13+ (API 33+) - hacerlo de forma no bloqueante
      if (Platform.isAndroid) {
        try {
          final androidInfo = await _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          if (androidInfo != null) {
            // Solicitar permiso de notificaciones (Android 13+)
            try {
              final granted = await androidInfo.requestNotificationsPermission();
              if (granted != null) {
                print('🔔 Permiso de notificaciones: ${granted ? "CONCEDIDO" : "DENEGADO"}');
              } else {
                print('🔔 Permiso de notificaciones: NO DISPONIBLE');
              }
            } catch (e) {
              print('⚠️ Error al solicitar permiso de notificaciones: $e');
            }
            
            // También solicitar permiso para alarmas exactas (Android 12+)
            try {
              final exactAlarmGranted = await androidInfo.requestExactAlarmsPermission();
              if (exactAlarmGranted != null) {
                print('🔔 Permiso de alarmas exactas: ${exactAlarmGranted ? "CONCEDIDO" : "DENEGADO"}');
              } else {
                print('🔔 Permiso de alarmas exactas: NO DISPONIBLE');
              }
            } catch (e) {
              print('⚠️ Error al solicitar permiso de alarmas exactas: $e');
              // El método puede no estar disponible en versiones anteriores del plugin
            }
          }
        } catch (e) {
          print('⚠️ Error al solicitar permisos de Android: $e');
          // Continuar aunque falle la solicitud de permisos
        }
      }

      _initialized = true;
      print('✅ Servicio de notificaciones inicializado');
    } catch (e, stackTrace) {
      print('❌ Error crítico al inicializar servicio de notificaciones: $e');
      print('❌ Stack trace: $stackTrace');
      // Marcar como inicializado para evitar reintentos infinitos
      _initialized = true;
      // No relanzar el error para que la app pueda iniciar
    }
  }

  static Future<void> programarNotificacionUnaVez({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime fechaHora,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      'recordatorios_canal',
      'Recordatorios',
      channelDescription: 'Notificaciones de recordatorios',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convertir DateTime a TZDateTime
    final tzDateTime = tz.TZDateTime.from(fechaHora, tz.local);
    
    print('📅 Programando notificación única:');
    print('   ID: $id');
    print('   Título: $titulo');
    print('   Fecha/Hora: $tzDateTime');
    print('   Fecha/Hora local: ${DateTime.now()}');

    try {
      // Verificar que la fecha no esté en el pasado
      final ahora = tz.TZDateTime.now(tz.local);
      if (tzDateTime.isBefore(ahora)) {
        print('⚠️ ADVERTENCIA: La fecha programada está en el pasado: $tzDateTime');
        print('⚠️ Fecha actual: $ahora');
        print('⚠️ La notificación puede no mostrarse');
      }

      await _notifications.zonedSchedule(
        id,
        titulo,
        cuerpo,
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null, // No repetir para notificaciones únicas
      );

      print('✅ Notificación programada exitosamente para: $tzDateTime');
      print('✅ Diferencia con ahora: ${tzDateTime.difference(ahora).inMinutes} minutos');
    } catch (e) {
      print('❌ Error al programar notificación: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Intentar con modo alternativo si falla
      try {
        print('🔄 Intentando con modo alternativo...');
        await _notifications.zonedSchedule(
          id,
          titulo,
          cuerpo,
          tzDateTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exact,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        print('✅ Notificación programada con modo alternativo');
      } catch (e2) {
        print('❌ Error también con modo alternativo: $e2');
        rethrow;
      }
    }
  }

  static Future<void> programarNotificacionRepetida({
    required int idBase,
    required String titulo,
    required String cuerpo,
    required TimeOfDay hora,
    required List<int> diasSemana, // 1-7 (lunes a domingo)
  }) async {
    await initialize();

    print('🔔 Programando notificaciones repetidas:');
    print('   Título: $titulo');
    print('   Hora: ${hora.hour}:${hora.minute}');
    print('   Días: $diasSemana');
    print('   ID Base: $idBase');

    final androidDetails = AndroidNotificationDetails(
      'recordatorios_canal',
      'Recordatorios',
      channelDescription: 'Notificaciones de recordatorios repetidos',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Programar una notificación para cada día de la semana seleccionado
    for (int i = 0; i < diasSemana.length; i++) {
      final dia = diasSemana[i];
      final notificationId = idBase + dia; // Usar el día como parte del ID

      print('📅 Programando notificación para día $dia (ID: $notificationId)');

      // Obtener la fecha actual en la zona horaria local
      final ahora = tz.TZDateTime.now(tz.local);
      
      // Calcular cuántos días hasta el próximo día de la semana
      // weekday: 1 = lunes, 7 = domingo
      int diaActual = ahora.weekday;
      int diasHastaProximoDia = (dia - diaActual) % 7;
      if (diasHastaProximoDia < 0) diasHastaProximoDia += 7;
      
      // Si es hoy, verificar si la hora ya pasó
      if (diasHastaProximoDia == 0) {
        final horaActual = TimeOfDay.fromDateTime(ahora);
        if (hora.hour < horaActual.hour || 
            (hora.hour == horaActual.hour && hora.minute <= horaActual.minute)) {
          diasHastaProximoDia = 7; // Programar para la próxima semana
          print('   ⏰ La hora ya pasó hoy, programando para la próxima semana');
        } else {
          print('   ⏰ La hora aún no ha pasado hoy, programando para hoy');
        }
      }

      // Calcular la fecha de la primera notificación
      final fechaNotificacion = ahora.add(Duration(days: diasHastaProximoDia));
      
      // Crear TZDateTime con la hora específica
      final tzDateTime = tz.TZDateTime(
        tz.local,
        fechaNotificacion.year,
        fechaNotificacion.month,
        fechaNotificacion.day,
        hora.hour,
        hora.minute,
      );

      print('   📅 Primera notificación: $tzDateTime');
      print('   📅 Fecha actual: $ahora');

      // Verificar que la fecha no esté en el pasado
      if (tzDateTime.isBefore(ahora)) {
        print('⚠️ ADVERTENCIA: La fecha programada está en el pasado: $tzDateTime');
        print('⚠️ Fecha actual: $ahora');
      }

      // Programar la notificación con repetición semanal
      // matchDateTimeComponents: dayOfWeekAndTime hace que se repita cada semana
      // en el mismo día y hora
      try {
        await _notifications.zonedSchedule(
          notificationId,
          titulo,
          cuerpo,
          tzDateTime,
          details,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );

        print('✅ Notificación repetida programada para día $dia (${_obtenerNombreDia(dia)}) a las ${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}');
        print('✅ Primera notificación en: ${tzDateTime.difference(ahora).inMinutes} minutos');
      } catch (e) {
        print('❌ Error al programar notificación repetida para día $dia: $e');
        print('❌ Stack trace: ${StackTrace.current}');
        
        // Intentar con modo alternativo si falla
        try {
          print('🔄 Intentando con modo alternativo para día $dia...');
          await _notifications.zonedSchedule(
            notificationId,
            titulo,
            cuerpo,
            tzDateTime,
            details,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            androidScheduleMode: AndroidScheduleMode.exact,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          print('✅ Notificación repetida programada con modo alternativo');
        } catch (e2) {
          print('❌ Error también con modo alternativo: $e2');
          // Continuar con los demás días
        }
      }
    }
    
    print('🔔 Todas las notificaciones repetidas programadas correctamente');
  }

  /// Obtiene el nombre del día de la semana
  static String _obtenerNombreDia(int dia) {
    switch (dia) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return 'Día $dia';
    }
  }

  static Future<void> cancelarNotificacion(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> cancelarTodasLasNotificaciones() async {
    await _notifications.cancelAll();
  }

  static Future<void> cancelarNotificacionesPorRango(int idBase, int cantidad) async {
    for (int i = 0; i < cantidad; i++) {
      await _notifications.cancel(idBase + i);
    }
  }

  /// Método de prueba para verificar que las notificaciones funcionan
  static Future<void> probarNotificacionInmediata() async {
    await initialize();
    
    print('🔔 Probando notificación inmediata...');
    
    final androidDetails = AndroidNotificationDetails(
      'recordatorios_canal',
      'Recordatorios',
      channelDescription: 'Notificaciones de recordatorios',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Programar una notificación para dentro de 5 segundos
    final fechaPrueba = DateTime.now().add(Duration(seconds: 5));
    final tzDateTime = tz.TZDateTime.from(fechaPrueba, tz.local);

    await _notifications.zonedSchedule(
      99999, // ID de prueba
      'Prueba de Notificación',
      'Si ves esto, las notificaciones están funcionando correctamente',
      tzDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('✅ Notificación de prueba programada para dentro de 5 segundos');
  }

  /// Verifica el estado de los permisos de notificaciones
  static Future<Map<String, dynamic>> verificarPermisos() async {
    await initialize();
    
    final estado = <String, dynamic>{
      'inicializado': _initialized,
    };

    if (Platform.isAndroid) {
      final androidInfo = await _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidInfo != null) {
        try {
          final notificacionesPermitidas = await androidInfo.areNotificationsEnabled();
          estado['notificacionesHabilitadas'] = notificacionesPermitidas;
        } catch (e) {
          estado['notificacionesHabilitadas'] = 'Error: $e';
        }

        // Nota: areExactAlarmsAllowed() no está disponible en todas las versiones del plugin
        // El permiso de alarmas exactas se solicita mediante requestExactAlarmsPermission()
        estado['alarmasExactasPermitidas'] = 'No verificable (método no disponible en esta versión)';
      }
    }

    print('📊 Estado de permisos:');
    estado.forEach((key, value) {
      print('   $key: $value');
    });

    return estado;
  }
}

