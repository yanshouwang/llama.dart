import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/src/logger.dart';

import 'logger.dart';
import 'tools.dart';
import 'utils/run_process.dart';

final class CMakeBuilder implements Builder {
  final String url;
  final String tag;
  final String assetName;

  CMakeBuilder({required this.url, required this.tag, required this.assetName});

  @override
  Future<void> run({
    required BuildInput input,
    required BuildOutputBuilder output,
    Logger? logger,
  }) async {
    logger ??= createDefaultLogger();
    if (!input.config.buildCodeAssets) {
      logger.info(
        'config.buildAssetTypes did not contain CodeAssets, '
        'skipping CodeAsset $assetName build.',
      );
      return;
    }
    final git = await Tools.git.resolve(logger: logger);
    final cmake = await Tools.cmake.resolve(logger: logger);

    final srcDir = input.outputDirectory.resolve('src/');
    final dstDir = input.outputDirectory.resolve('dst/');
    final outDir = input.outputDirectory.resolve('out/');
    await Directory.fromUri(srcDir).create(recursive: true);
    await Directory.fromUri(dstDir).create(recursive: true);
    await Directory.fromUri(outDir).create(recursive: true);

    final isInsideGitDir = await runProcess(
      executable: git.uri,
      arguments: ['rev-parse', '--is-inside-git-dir'],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: false,
    ).then((e) => bool.parse(e.stdout.trim()));
    if (!isInsideGitDir) {
      await runProcess(
        executable: git.uri,
        arguments: ['clone', url, '.'],
        workingDirectory: srcDir,
        logger: logger,
        throwOnUnexpectedExitCode: true,
      );
    }
    await runProcess(
      executable: git.uri,
      arguments: ['checkout', tag],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    await runProcess(
      executable: cmake.uri,
      arguments: [
        '-B',
        dstDir.toFilePath(),
        '-DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON',
      ],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    await runProcess(
      executable: cmake.uri,
      arguments: ['--build', dstDir.toFilePath(), '--config', 'Release'],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    await runProcess(
      executable: cmake.uri,
      arguments: [
        '--install',
        dstDir.toFilePath(),
        '--prefix',
        outDir.toFilePath(),
      ],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );

    final libDir = outDir.resolve('lib/');
    final libs = await Directory.fromUri(libDir).list().toList();
    for (var lib in libs) {
      logger.info('lib: ${lib.uri.toFilePath()}');
    }
    // output.assets.code.addAll([
    //   CodeAsset(
    //     package: input.packageName,
    //     name: assetName,
    //     linkMode: DynamicLoadingBundled(),
    //   ),
    // ]);
  }
}
