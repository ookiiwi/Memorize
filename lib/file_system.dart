import 'package:universal_io/io.dart';

class FileInfo {
  FileInfo(this.name, this.path, this.type);

  final String name;
  final String path;
  final FileSystemEntityType type;

  FileInfo copyWith({String? name, String? path, FileSystemEntityType? type}) {
    return FileInfo(
      name ?? this.name,
      path ?? this.path,
      type ?? this.type,
    );
  }
}
