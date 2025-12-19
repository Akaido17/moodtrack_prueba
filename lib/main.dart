import 'package:flutter/material.dart';
import 'lib/Pantallas/Pantalla_registro_psicologo.dart';
import 'lib/Pantallas/Pantalla_login.dart';
import 'lib/Pantallas/Pantalla_registro.dart';
import 'lib/servicios/NotificacionesService.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar notificaciones en segundo plano (no bloquear el inicio de la app)
  NotificacionesService.initialize().catchError((error) {
    print('⚠️ Error al inicializar notificaciones (no crítico): $error');
  });
  runApp(AplicacionBienestar());
}

class AplicacionBienestar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoodTrack',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/', // Define la ruta inicial de la aplicación
      routes: {
        '/': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/registroPsicologo': (context) => RegistroPsicologo(),
      },
    );
  }
}
