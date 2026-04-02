import 'dart:io';

import 'package:hooks/hooks.dart';
import 'package:logging/src/logger.dart';

final class CmakeBuilder implements Builder {
  final String url;
  final String tag;

  CmakeBuilder({required this.url, required this.tag});

  @override
  Future<void> run({
    required BuildInput input,
    required BuildOutputBuilder output,
    required Logger? logger,
  }) async {
    logger?.info('git clone $url');
    await _runProcess('git', ['clone', url]);
    logger?.info('git checkout $tag');
    await _runProcess('git', ['checkout', tag]);
    logger?.info('cmake -B ${input.outputDirectory.toFilePath()}');
    await _runProcess('cmake', ['-B', input.outputDirectory.toFilePath()]);
    logger?.info(
      'cmake --build ${input.outputDirectory.toFilePath()} --config Release',
    );
    await _runProcess('cmake', [
      '--build',
      input.outputDirectory.toFilePath(),
      '--config',
      'Release',
    ]);
  }

  Future<void> _runProcess(String executable, List<String> arguments) async {
    final res = await Process.run(executable, arguments);
    final exitCode = res.exitCode;
    if (exitCode == 0) return;
    final message = '${res.stderr}';
    throw ProcessException(executable, arguments, message, exitCode);
  }
}
