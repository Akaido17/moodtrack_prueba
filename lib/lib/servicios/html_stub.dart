// Stub file para plataformas no-web - define tipos que no existen fuera de dart:html
// Este archivo solo se usa cuando NO es Web

class Blob {
  final List<dynamic> data;
  Blob(this.data);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) {
    throw UnimplementedError('Url.createObjectUrlFromBlob no está disponible fuera de Web');
  }
  static void revokeObjectUrl(String url) {
    throw UnimplementedError('Url.revokeObjectUrl no está disponible fuera de Web');
  }
}

class AnchorElement {
  String? href;
  AnchorElement({this.href});
  void setAttribute(String name, String value) {}
  void click() {}
}

