import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  final sdkPath = _getSdkPath();
  final rootUri = Platform.script.resolve('../');
  final includeUri = rootUri.resolve('src/include/');
  final entryPoints = [includeUri.resolve('llama.h')];
  final compilerOptions = [
    if (sdkPath != null) '-isysroot$sdkPath',
    '-I${includeUri.toFilePath()}',
  ];
  final generator = FfiGenerator(
    headers: Headers(
      entryPoints: entryPoints,
      include: (header) => entryPoints.contains(header),
      compilerOptions: compilerOptions,
    ),
    functions: .includeAll,
    enums: .includeAll,
    globals: .includeAll,
    macros: .includeAll,
    structs: .includeAll,
    typedefs: .includeAll,
    unions: .includeAll,
    unnamedEnums: .includeAll,
    output: Output(
      dartFile: rootUri.resolve('lib/src/ffi.g.dart'),
      sort: true,
      format: true,
      // style: NativeExternalBindings(assetId: ''),
    ),
  );
  generator.generate();
}

String? _getSdkPath() {
  if (!Platform.isMacOS) return null;
  final result = Process.runSync('xcrun', ['--show-sdk-path']);
  if (result.exitCode != 0) return null;
  return (result.stdout as String).trim();
}
