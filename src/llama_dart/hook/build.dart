import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'cmake/cmake_builder.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final root = input.packageRoot;
    root.resolve('src');
    if (input.config.buildCodeAssets) {
      final builder = CMakeBuilder(
        url: 'git@github.com:ggml-org/llama.cpp.git',
        tag: 'b8611',
        name: 'llama',
        assetName: 'src/ffi.g.dart',
      );
      await builder.run(input: input, output: output);
    }
  });
}
