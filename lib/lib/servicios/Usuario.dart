import 'package:shared_preferences/shared_preferences.dart';

class UsuarioService {
  static Future<void> guardarUsuario(int id, String email, {int? tipoUsuario}) async {
    try {
      print('═══════════════════════════════════');
      print('💾 Guardando usuario en SharedPreferences...');
      print('🆔 ID: $id');
      print('📧 Email: $email');
      print('👤 Tipo Usuario: $tipoUsuario');
      
      final prefs = await SharedPreferences.getInstance();
      
      final idGuardado = await prefs.setInt('usuario_id', id);
      print('✅ usuario_id guardado: $idGuardado');
      
      final emailGuardado = await prefs.setString('usuario_email', email);
      print('✅ usuario_email guardado: $emailGuardado');
      
      if (tipoUsuario != null) {
        final tipoGuardado = await prefs.setInt('tipo_usuario', tipoUsuario);
        print('✅ tipo_usuario guardado: $tipoGuardado');
      }
      
      // Verificar que se guardó correctamente
      final idVerificado = prefs.getInt('usuario_id');
      final emailVerificado = prefs.getString('usuario_email');
      final tipoVerificado = prefs.getInt('tipo_usuario');
      
      print('🔍 Verificación después de guardar:');
      print('   usuario_id: $idVerificado');
      print('   usuario_email: $emailVerificado');
      print('   tipo_usuario: $tipoVerificado');
      print('═══════════════════════════════════');
      
      if (idVerificado == null || emailVerificado == null || emailVerificado.isEmpty) {
        throw Exception('Error: No se pudo verificar que los datos se guardaron correctamente');
      }
    } catch (e) {
      print('❌ ERROR al guardar usuario: $e');
      rethrow;
    }
  }

  static Future<int?> obtenerUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('usuario_id');
  }

  static Future<String?> obtenerUsuarioEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('usuario_email');
  }

  static Future<int?> obtenerTipoUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tipo_usuario');
  }

  static Future<void> limpiarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_id');
    await prefs.remove('usuario_email');
    await prefs.remove('tipo_usuario');
  }
}