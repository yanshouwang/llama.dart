import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  final root = Platform.script.resolve('../');
  final generator = FfiGenerator(
    output: Output(dartFile: root.resolve('lib/src/ffi.g.dart')),
    headers: Headers(entryPoints: [root.resolve('')]),
  );
  generator.generate();
}
