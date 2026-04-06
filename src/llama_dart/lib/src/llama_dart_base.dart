// TODO: Put public facing types in this file.

import 'package:ffi/ffi.dart';

import 'ffi.g.dart';

/// Checks if you are awesome. Spoiler: you are.
class Awesome {
  bool get isAwesome => true;

  String getSystemInfo() {
    // llama_backend_init();
    final systemInfo = llama_print_system_info().cast<Utf8>().toDartString();
    return systemInfo;
  }
}
