import 'dart:io';

import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';

import 'cmake_builder.dart';

void main(List<String> args) async {
  hierarchicalLoggingEnabled = true;
  final logger = Logger('hook.build')
    ..level = .ALL
    ..onRecord.listen((e) => print(e.message));
  // final root = Platform.script.resolve('../');
  // logger.info('root: $root');
  // final builder = CMakeBuilder.fromGit(
  //   name: 'llamma',
  //   gitUrl: 'git@github.com:ggml-org/llama.cpp.git',
  //   sourceDir: root.resolve('src'),
  //   outDir: null,
  //   gitBranch: 'b8611',
  //   // gitCommit: '',
  //   gitSubDir: '',
  //   defines: {},
  //   buildMode: .release,
  //   targets: null,
  //   generator: .defaultGenerator,
  //   toolset: null,
  //   logLevel: .STATUS,
  //   logger: logger,
  //   buildLocal: false,
  //   androidArgs: AndroidBuilderArgs(),
  //   appleArgs: AppleBuilderArgs(),
  //   useVcvars: true,
  //   parallelJobs: null,
  //   parallelUseAllProcessors: false,
  // );
  final builder = CmakeBuilder(
    url: 'git@github.com:ggml-org/llama.cpp.git',
    tag: 'b8611',
  );
  await build(
    args,
    (input, output) =>
        builder.run(input: input, output: output, logger: logger),
  );
}
