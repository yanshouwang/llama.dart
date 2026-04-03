import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  final root = Platform.script.resolve('../');
  final generator = FfiGenerator(
    headers: Headers(
      entryPoints: [root.resolve('src/llama.cpp/include/llama.h')],
      compilerOptions: [
        '-Isrc/llama.cpp/include',
        '-Isrc/llama.cpp/ggml/include',
        '-Isrc/llama.cpp/tools/mtmd',
      ],
    ),
    output: Output(dartFile: root.resolve('lib/src/ffi.g.dart')),
  );
  generator.generate();
}
