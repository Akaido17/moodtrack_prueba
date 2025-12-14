import '../EstadoAnimo.dart';
import '../servicios/db_helper.dart';

/// Servicio para analizar estados de ánimo y detectar patrones basados en mhGAP
class AnalisisEstadosAnimo {
  final DBHelper _dbHelper = DBHelper();

  // Palabras clave para diferentes emociones y patrones
  static const List<String> _palabrasTristeza = [
    'triste', 'tristeza', 'deprimido', 'depresión', 'bajoneado', 'bajo ánimo',
    'sin ganas', 'no tengo ganas', 'cansado', 'fatiga', 'nada me motiva',
    'no disfruto', 'me da igual', 'vacío', 'vacío interior', 'desesperanza',
    'sin sentido', 'inútil', 'no tiene sentido', 'nada va a cambiar',
    'me siento mal', 'mal', 'malestar', 'dolor emocional'
  ];

  static const List<String> _palabrasAnhedonia = [
    'no disfruto', 'ya no disfruto', 'nada me gusta', 'todo me da igual',
    'sin interés', 'perdí interés', 'anhedonia'
  ];

  static const List<String> _palabrasSueno = [
    'no duermo', 'insomnio', 'duermo mal', 'despierto cansado',
    'duermo todo el día', 'sueño excesivo', 'fatiga', 'cansancio'
  ];

  static const List<String> _palabrasDesesperanza = [
    'no tiene sentido', 'inútil', 'nada va a cambiar', 'sin esperanza',
    'desesperanza', 'sin futuro', 'no hay salida'
  ];

  static const List<String> _palabrasFelicidad = [
    'feliz', 'contento', 'alegre', 'bien', 'genial', 'excelente',
    'maravilloso', 'fantástico', 'eufórico', 'euforia'
  ];

  static const List<String> _palabrasFelicidadIntensa = [
    'eufórico', 'euforia', 'no puedo parar', 'toda la energía',
    'quiero hacerlo todo', 'duermo poco pero energía', 'hiperactivo'
  ];

  static const List<String> _palabrasEnojo = [
    'enojado', 'enojo', 'ira', 'irritado', 'molesto', 'furioso',
    'rabia', 'rabioso', 'quiero romper', 'no aguanto', 'me sacan de quicio',
    'gritaría', 'agresivo', 'violento'
  ];

  static const List<String> _palabrasAnsiedad = [
    'ansiedad', 'ansioso', 'nervioso', 'preocupado', 'preocupación',
    'miedo', 'temor', 'angustia', 'pánico', 'ataque de pánico',
    'no puedo respirar', 'me tiembla', 'siento que me muero',
    'taquicardia', 'palpitaciones'
  ];

  static const List<String> _palabrasMiedo = [
    'miedo', 'temor', 'miedoso', 'asustado', 'pánico', 'todo me da miedo',
    'no quiero salir', 'no me siento seguro', 'inseguro', 'inseguridad'
  ];

  /// Analiza los estados de ánimo de los últimos N días
  /// Retorna un mapa con información sobre el promedio de estados
  Future<Map<String, dynamic>> analizarUltimosDias(
    int usuarioId,
    int dias,
  ) async {
    try {
      print('═══════════════════════════════════════');
      print('📊 INICIANDO ANÁLISIS DE ESTADOS DE ÁNIMO');
      print('   Usuario ID: $usuarioId');
      print('   Días a analizar: $dias');
      print('═══════════════════════════════════════');
      
      // Obtener todos los estados de ánimo del usuario
      print('📡 Obteniendo estados de ánimo del backend...');
      final estados = await _dbHelper.getAllEstadosAnimo(usuarioId);
      print('📊 Total de estados obtenidos del backend: ${estados.length}');
      
      if (estados.isEmpty) {
        print('⚠️ No se encontraron estados de ánimo para el usuario $usuarioId');
        return {
          'success': true,
          'total': 0,
          'promedio': 0.0,
          'hayAlerta': false,
          'diasAnalizados': dias,
          'fechaLimite': DateTime.now(),
          'estadosRecientes': [],
          'mensaje': 'No hay estados de ánimo registrados',
        };
      }
      
      // Mostrar los primeros estados para depuración
      print('📋 Primeros estados obtenidos:');
      for (int i = 0; i < estados.length && i < 5; i++) {
        final estado = estados[i];
        print('   Estado $i: valor=${estado.estado}, fecha=${estado.fechaCreacion}, id=${estado.id}');
      }

      // Calcular la fecha límite (hace N días desde hoy, incluyendo hoy)
      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      final fechaLimite = hoy.subtract(Duration(days: dias - 1));
      
      print('📅 Hoy: $hoy');
      print('📅 Fecha límite (últimos $dias días, desde): $fechaLimite');
      
      // Filtrar estados de los últimos N días (incluyendo hoy)
      final estadosRecientes = estados.where((estado) {
        final fechaEstado = DateTime(
          estado.fechaCreacion.year,
          estado.fechaCreacion.month,
          estado.fechaCreacion.day,
        );
        final diferenciaDias = hoy.difference(fechaEstado).inDays;
        final esReciente = diferenciaDias >= 0 && diferenciaDias < dias;
        return esReciente;
      }).toList();

      print('📊 Estados en los últimos $dias días: ${estadosRecientes.length}');

      // Calcular el promedio de estados
      int total = estadosRecientes.length;
      double promedio = 0.0;

      if (total > 0) {
        int suma = estadosRecientes.fold(0, (sum, estado) => sum + estado.estado);
        promedio = suma / total;
        print('📊 Suma de estados: $suma, Total: $total, Promedio: ${promedio.toStringAsFixed(2)}');
      }

      // Realizar análisis de patrones mhGAP
      final patrones = await _analizarPatrones(estadosRecientes, dias);
      
      // Determinar si hay alerta (promedio <= 2 o patrones preocupantes)
      final hayAlerta = (promedio <= 2.0 && total > 0) || patrones['hayAlerta'] == true;

      print('═══════════════════════════════════════');
      print('📊 RESUMEN FINAL:');
      print('   Total estados: $total');
      print('   Promedio: ${promedio.toStringAsFixed(2)}');
      print('   Promedio <= 2.0: ${promedio <= 2.0}');
      print('   Patrones detectados: ${patrones['tipoPatron']}');
      print('   Hay alerta: $hayAlerta');
      print('═══════════════════════════════════════');

      return {
        'success': true,
        'total': total,
        'promedio': promedio,
        'hayAlerta': hayAlerta,
        'diasAnalizados': dias,
        'fechaLimite': fechaLimite,
        'estadosRecientes': estadosRecientes,
        'patrones': patrones,
      };
    } catch (e) {
      print('❌ Error al analizar estados de ánimo: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return {
        'success': false,
        'error': 'Error al analizar estados: $e',
        'hayAlerta': false,
        'promedio': 0.0,
      };
    }
  }

  /// Analiza patrones específicos basados en mhGAP
  Future<Map<String, dynamic>> _analizarPatrones(
    List<EstadoAnimo> estados,
    int diasAnalizados,
  ) async {
    if (estados.isEmpty) {
      return {
        'tipoPatron': 'ninguno',
        'hayAlerta': false,
        'mensaje': null,
        'sugerencias': [],
      };
    }

    // Ordenar estados por fecha (más reciente primero)
    estados.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

    // Análisis de tristeza (estado 1 o 2)
    final patronTristeza = _analizarTristeza(estados, diasAnalizados);
    if (patronTristeza['hayAlerta'] == true) {
      return patronTristeza;
    }

    // Análisis de felicidad (estado 4 o 5)
    final patronFelicidad = _analizarFelicidad(estados, diasAnalizados);
    if (patronFelicidad['hayAlerta'] == true) {
      return patronFelicidad;
    }

    // Análisis de enojo (estado 1 o 2 con palabras clave de enojo)
    final patronEnojo = _analizarEnojo(estados, diasAnalizados);
    if (patronEnojo['hayAlerta'] == true) {
      return patronEnojo;
    }

    // Análisis de ansiedad
    final patronAnsiedad = _analizarAnsiedad(estados, diasAnalizados);
    if (patronAnsiedad['hayAlerta'] == true) {
      return patronAnsiedad;
    }

    // Análisis de miedo
    final patronMiedo = _analizarMiedo(estados, diasAnalizados);
    if (patronMiedo['hayAlerta'] == true) {
      return patronMiedo;
    }

    // Análisis de neutralidad frecuente
    final patronNeutral = _analizarNeutralidad(estados, diasAnalizados);
    if (patronNeutral['hayAlerta'] == true) {
      return patronNeutral;
    }

    return {
      'tipoPatron': 'ninguno',
      'hayAlerta': false,
      'mensaje': null,
      'sugerencias': [],
    };
  }

  /// Analiza patrones de tristeza
  Map<String, dynamic> _analizarTristeza(List<EstadoAnimo> estados, int dias) {
    final estadosTristes = estados.where((e) => e.estado <= 2).toList();
    final diasConTristeza = estadosTristes.length;
    
    // Detectar palabras clave en comentarios
    final comentarios = estadosTristes.map((e) => e.comentario.toLowerCase()).join(' ');
    final tienePalabrasTristeza = _palabrasTristeza.any((palabra) => comentarios.contains(palabra));
    final tieneAnhedonia = _palabrasAnhedonia.any((palabra) => comentarios.contains(palabra));
    final tieneProblemasSueno = _palabrasSueno.any((palabra) => comentarios.contains(palabra));
    final tieneDesesperanza = _palabrasDesesperanza.any((palabra) => comentarios.contains(palabra));

    // Patrón 1: Tristeza durante mayoría de días por más de 2 semanas
    if (dias >= 14 && diasConTristeza >= (dias * 0.7)) {
      return {
        'tipoPatron': 'tristeza_persistente',
        'hayAlerta': true,
        'severidad': tieneDesesperanza ? 'alta' : 'media',
        'mensaje': 'Notamos que llevas varios días sintiéndote con bajo ánimo. Esto puede ser señal de que necesitas apoyo.',
        'sugerencias': [
          '¿Te gustaría ver algunas estrategias para sentirte mejor?',
          'Considera hablar con un profesional de la salud mental',
          'Ejercicios de respiración y relajación',
          'Registro de gratitud diario',
        ],
        'recursos': ['respiración', 'relajación', 'gratitud'],
      };
    }

    // Patrón 2: Tristeza recurrente (3+ días en última semana)
    if (diasConTristeza >= 3) {
      String mensaje = 'Parece que has tenido varios días con bajo ánimo.';
      List<String> sugerencias = [
        '¿Quieres anotar algo que solía hacerte bien?',
        'Ejercicios de respiración',
        'Actividades pequeñas pueden ayudarte a reconectar',
      ];

      if (tieneAnhedonia) {
        mensaje += ' También notamos que mencionas pérdida de interés en actividades que antes disfrutabas.';
        sugerencias.insert(0, 'A veces cuando nos sentimos desanimados, actividades pequeñas pueden ayudarnos a reconectar.');
      }

      if (tieneProblemasSueno) {
        mensaje += ' Además, mencionas problemas con el sueño.';
        sugerencias.add('Rutina de higiene del sueño');
        sugerencias.add('Técnicas de relajación antes de dormir');
      }

      if (tieneDesesperanza) {
        return {
          'tipoPatron': 'tristeza_con_desesperanza',
          'hayAlerta': true,
          'severidad': 'alta',
          'mensaje': 'Lamentamos que estés pasando por un momento difícil. No estás solo. Hablar con alguien puede ayudarte.',
          'sugerencias': [
            '¿Quieres ver opciones de apoyo o líneas de ayuda cercanas?',
            'Contactar con un profesional de la salud mental',
            'Hablar con alguien de confianza',
          ],
          'recursos': ['apoyo_profesional', 'lineas_ayuda'],
        };
      }

      return {
        'tipoPatron': 'tristeza_recurrente',
        'hayAlerta': true,
        'severidad': 'media',
        'mensaje': mensaje,
        'sugerencias': sugerencias,
        'recursos': ['respiración', 'actividades'],
      };
    }

    return {'hayAlerta': false};
  }

  /// Analiza patrones de felicidad
  Map<String, dynamic> _analizarFelicidad(List<EstadoAnimo> estados, int dias) {
    final estadosFelices = estados.where((e) => e.estado >= 4).toList();
    final diasConFelicidad = estadosFelices.length;
    final comentarios = estadosFelices.map((e) => e.comentario.toLowerCase()).join(' ');
    final tieneFelicidadIntensa = _palabrasFelicidadIntensa.any((palabra) => comentarios.contains(palabra));

    // Patrón 1: Felicidad recurrente o sostenida (≥4 días en la semana)
    if (diasConFelicidad >= 4) {
      if (tieneFelicidadIntensa) {
        return {
          'tipoPatron': 'felicidad_intensa',
          'hayAlerta': true,
          'severidad': 'media',
          'mensaje': 'Parece que estás experimentando mucha energía o entusiasmo. A veces, equilibrar momentos intensos con descanso también es importante.',
          'sugerencias': [
            'Considera una pausa o actividad de relajación',
            'Mantener rutinas de descanso',
            'Si este patrón se repite por varios días, considera hablar con un profesional',
          ],
          'recursos': ['relajación', 'equilibrio'],
        };
      }

      return {
        'tipoPatron': 'felicidad_recurrente',
        'hayAlerta': false,
        'mensaje': 'Parece que has tenido varios días positivos. ¿Quieres ver qué actividades o situaciones se repiten en esos días?',
        'sugerencias': [
          'Mantener tus rutinas y autocuidado',
          'Continuar registrando emociones para mantener el equilibrio',
        ],
        'recursos': ['estadísticas_bienestar'],
      };
    }

    // Patrón 2: Oscilaciones bruscas (feliz → triste)
    final estadosOrdenados = List<EstadoAnimo>.from(estados);
    estadosOrdenados.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
    
    bool hayOscilacion = false;
    for (int i = 1; i < estadosOrdenados.length; i++) {
      final diferencia = (estadosOrdenados[i].estado - estadosOrdenados[i-1].estado).abs();
      if (diferencia >= 3) {
        hayOscilacion = true;
        break;
      }
    }

    if (hayOscilacion && estados.length >= 3) {
      return {
        'tipoPatron': 'oscilaciones_bruscas',
        'hayAlerta': true,
        'severidad': 'media',
        'mensaje': 'Tus emociones han variado bastante últimamente. Esto puede pasar cuando vivimos momentos intensos.',
        'sugerencias': [
          '¿Quieres anotar qué situaciones influyeron en esos cambios?',
          'Ejercicios de regulación emocional',
          'Respiración y pausa consciente',
          'Journaling guiado',
        ],
        'recursos': ['regulación_emocional', 'respiración'],
      };
    }

    return {'hayAlerta': false};
  }

  /// Analiza patrones de enojo
  Map<String, dynamic> _analizarEnojo(List<EstadoAnimo> estados, int dias) {
    final comentarios = estados.map((e) => e.comentario.toLowerCase()).join(' ');
    final tienePalabrasEnojo = _palabrasEnojo.any((palabra) => comentarios.contains(palabra));
    
    if (!tienePalabrasEnojo) {
      return {'hayAlerta': false};
    }

    final estadosConEnojo = estados.where((e) {
      final comentario = e.comentario.toLowerCase();
      return _palabrasEnojo.any((palabra) => comentario.contains(palabra));
    }).toList();

    final diasConEnojo = estadosConEnojo.length;
    final tieneExpresionesIntensas = _palabrasEnojo.any((palabra) => 
      ['romper', 'no aguanto', 'gritaría', 'agresivo'].any((intensa) => 
        comentarios.contains(intensa)));

    // Enojo persistente (más de 2 semanas)
    if (dias >= 14 && diasConEnojo >= (dias * 0.5)) {
      return {
        'tipoPatron': 'enojo_persistente',
        'hayAlerta': true,
        'severidad': 'media',
        'mensaje': 'Parece que el enojo se repite con frecuencia. A veces esto puede ser señal de que algo nos está sobrecargando.',
        'sugerencias': [
          '¿Quieres explorar estrategias para manejarlo mejor?',
          'Módulo de manejo del estrés',
          'Identificación de desencadenantes',
        ],
        'recursos': ['manejo_estres', 'desencadenantes'],
      };
    }

    // Enojo recurrente (3+ días en última semana)
    if (diasConEnojo >= 3) {
      if (tieneExpresionesIntensas) {
        return {
          'tipoPatron': 'enojo_intenso',
          'hayAlerta': true,
          'severidad': 'alta',
          'mensaje': 'Parece que estás muy enojado. Respirar profundo o tomar un momento antes de actuar puede ayudarte a calmarte un poco.',
          'sugerencias': [
            'Técnica 4-7-8 de respiración',
            'Contar hasta 10',
            'Anotar pensamientos sin actuar',
            'Si el patrón persiste, sugerir hablar con alguien de confianza o profesional',
          ],
          'recursos': ['respiración_478', 'contención'],
        };
      }

      return {
        'tipoPatron': 'enojo_recurrente',
        'hayAlerta': true,
        'severidad': 'media',
        'mensaje': 'Parece que has tenido varios días con enojo o irritación. Esto puede ser señal de estrés o cansancio.',
        'sugerencias': [
          'Ejercicios de respiración o relajación muscular',
          'Breve pausa guiada (1 minuto)',
          'Ver formas de liberar tensión de manera saludable',
        ],
        'recursos': ['respiración', 'relajación'],
      };
    }

    // Enojo aislado
    return {
      'tipoPatron': 'enojo_aislado',
      'hayAlerta': false,
      'mensaje': 'Sentirse enojado a veces es normal. Registrar este momento puede ayudarte a entender qué lo generó.',
      'sugerencias': [
        '¿Quieres escribir qué pasó o qué te hizo sentir así?',
      ],
      'recursos': ['autorreflexión'],
    };
  }

  /// Analiza patrones de ansiedad
  Map<String, dynamic> _analizarAnsiedad(List<EstadoAnimo> estados, int dias) {
    final comentarios = estados.map((e) => e.comentario.toLowerCase()).join(' ');
    final tienePalabrasAnsiedad = _palabrasAnsiedad.any((palabra) => comentarios.contains(palabra));
    
    if (!tienePalabrasAnsiedad) {
      return {'hayAlerta': false};
    }

    final estadosConAnsiedad = estados.where((e) {
      final comentario = e.comentario.toLowerCase();
      return _palabrasAnsiedad.any((palabra) => comentario.contains(palabra));
    }).toList();

    final diasConAnsiedad = estadosConAnsiedad.length;
    final tieneCrisis = ['no puedo respirar', 'me tiembla', 'siento que me muero', 'ataque de pánico']
        .any((crisis) => comentarios.contains(crisis));

    // Ansiedad intensa o crisis
    if (tieneCrisis) {
      return {
        'tipoPatron': 'ansiedad_crisis',
        'hayAlerta': true,
        'severidad': 'alta',
        'mensaje': 'Estás teniendo un momento de mucha ansiedad. No estás en peligro. Intenta respirar despacio y enfocar la mirada en algo estable.',
        'sugerencias': [
          'Guía paso a paso para controlar la respiración',
          'Técnica de anclaje 5-4-3-2-1',
          'Si se repite con frecuencia, sugerir consulta profesional',
        ],
        'recursos': ['respiración_crisis', 'anclaje'],
      };
    }

    // Ansiedad frecuente o diaria (5+ días en una semana)
    if (diasConAnsiedad >= 5) {
      return {
        'tipoPatron': 'ansiedad_frecuente',
        'hayAlerta': true,
        'severidad': 'media',
        'mensaje': 'Parece que la preocupación te acompaña con frecuencia. A veces, hablar o escribir sobre lo que te genera ansiedad ayuda a aliviarla.',
        'sugerencias': [
          'Ejercicio de respiración lenta',
          'Reestructuración cognitiva simple ("¿Qué evidencia tengo de este miedo?")',
          'Derivación opcional a apoyo profesional',
        ],
        'recursos': ['respiración', 'reestructuración_cognitiva'],
      };
    }

    // Ansiedad ocasional
    return {
      'tipoPatron': 'ansiedad_ocasional',
      'hayAlerta': false,
      'mensaje': 'Sentir ansiedad en algunos momentos es una respuesta natural al estrés. Registrar cuándo ocurre puede ayudarte a encontrar los detonantes.',
      'sugerencias': [
        'Respiración guiada',
        'Técnica de anclaje (5-4-3-2-1)',
      ],
      'recursos': ['respiración', 'anclaje'],
    };
  }

  /// Analiza patrones de miedo
  Map<String, dynamic> _analizarMiedo(List<EstadoAnimo> estados, int dias) {
    final comentarios = estados.map((e) => e.comentario.toLowerCase()).join(' ');
    final tienePalabrasMiedo = _palabrasMiedo.any((palabra) => comentarios.contains(palabra));
    
    if (!tienePalabrasMiedo) {
      return {'hayAlerta': false};
    }

    final estadosConMiedo = estados.where((e) {
      final comentario = e.comentario.toLowerCase();
      return _palabrasMiedo.any((palabra) => comentario.contains(palabra));
    }).toList();

    final diasConMiedo = estadosConMiedo.length;
    final tieneMiedoGeneralizado = ['todo me da miedo', 'no quiero salir', 'no me siento seguro']
        .any((generalizado) => comentarios.contains(generalizado));

    // Miedo persistente o generalizado
    if (diasConMiedo >= 3 || tieneMiedoGeneralizado) {
      return {
        'tipoPatron': 'miedo_persistente',
        'hayAlerta': true,
        'severidad': 'media',
        'mensaje': 'Notamos que el miedo aparece a menudo. Hablar de lo que te preocupa o buscar apoyo puede ayudarte a recuperar calma.',
        'sugerencias': [
          'Actividades que brinden sensación de control (rutinas, respiración, caminatas cortas)',
          'Hablar con alguien de confianza',
        ],
        'recursos': ['control', 'rutinas'],
      };
    }

    // Miedo ocasional
    return {
      'tipoPatron': 'miedo_ocasional',
      'hayAlerta': false,
      'mensaje': 'El miedo puede ayudarnos a cuidarnos, pero cuando aparece seguido, puede ser agotador.',
      'sugerencias': [
        'Permitir que el usuario anote "qué lo hizo sentir así"',
      ],
      'recursos': ['autorreflexión'],
    };
  }

  /// Analiza patrones de neutralidad
  Map<String, dynamic> _analizarNeutralidad(List<EstadoAnimo> estados, int dias) {
    final estadosNeutrales = estados.where((e) => e.estado == 3).toList();
    final diasNeutrales = estadosNeutrales.length;

    // Neutralidad frecuente (mayoría de días)
    if (diasNeutrales >= (dias * 0.7)) {
      return {
        'tipoPatron': 'neutralidad_frecuente',
        'hayAlerta': true,
        'severidad': 'baja',
        'mensaje': 'Parece que has estado en un estado neutral últimamente. A veces esto refleja equilibrio, pero si sientes desconexión o vacío, puede ser útil explorarlo.',
        'sugerencias': [
          '¿Te sientes tranquilo o más bien apagado?',
          'Esto ayuda a distinguir bienestar de anhedonia',
        ],
        'recursos': ['autoconciencia'],
      };
    }

    return {'hayAlerta': false};
  }

  /// Verifica si se debe mostrar una alerta (promedio <= 2 en últimos 3 días o patrones preocupantes)
  Future<bool> debeMostrarAlerta(int usuarioId, {int dias = 3}) async {
    final resultado = await analizarUltimosDias(usuarioId, dias);
    return resultado['hayAlerta'] == true;
  }

  /// Obtiene el resumen de estados para mostrar en la alerta
  Future<Map<String, dynamic>> obtenerResumenAlerta(int usuarioId, {int dias = 3}) async {
    final resultado = await analizarUltimosDias(usuarioId, dias);
    
    if (resultado['success'] == true) {
      final patrones = resultado['patrones'] ?? {};
      return {
        'promedio': resultado['promedio'] ?? 0.0,
        'total': resultado['total'] ?? 0,
        'dias': dias,
        'tipoPatron': patrones['tipoPatron'] ?? 'promedio_bajo',
        'mensaje': patrones['mensaje'] ?? 'Tu promedio de estados está por debajo de 2.0.',
        'sugerencias': patrones['sugerencias'] ?? [],
        'recursos': patrones['recursos'] ?? [],
        'severidad': patrones['severidad'] ?? 'media',
      };
    }
    
    return {
      'promedio': 0.0,
      'total': 0,
      'dias': dias,
      'tipoPatron': 'ninguno',
      'mensaje': null,
      'sugerencias': [],
      'recursos': [],
    };
  }
}
