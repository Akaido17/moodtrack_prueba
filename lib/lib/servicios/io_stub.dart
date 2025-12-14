// Stub file para Web - define tipos que no existen en dart:html
// Este archivo solo se usa cuando NO es Web

class File {
  final String path;
  File(this.path);
  Future<File> writeAsBytes(List<int> bytes) async {
    throw UnimplementedError('File.writeAsBytes no está disponible en Web');
  }
}

class Directory {
  final String path;
  Directory(this.path);
}

