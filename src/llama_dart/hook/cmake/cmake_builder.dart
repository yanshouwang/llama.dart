import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/src/logger.dart';
import 'package:path/path.dart' as path;

import 'link_mode.dart';
import 'logger.dart';
import 'tools.dart';
import 'utils/run_process.dart';

final class CMakeBuilder implements Builder {
  final String url;
  final String tag;
  final String name;
  final String assetName;

  CMakeBuilder({
    required this.url,
    required this.tag,
    required this.name,
    required this.assetName,
  });

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

    final topLevel = await runProcess(
      executable: git.uri,
      arguments: ['rev-parse', '--show-toplevel'],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: false,
    ).then((e) => e.stdout.trim());
    logger.info('topLevel: $topLevel');
    if (Uri.directory(topLevel) != srcDir) {
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

    final linkMode = getLinkMode(input.config.code.linkModePreference);
    final libDir = outDir.resolve('lib/');
    final libName = input.config.code.targetOS.libraryFileName(name, linkMode);
    final libExt = path.extension(libName);
    final libAsset = CodeAsset(
      package: input.packageName,
      name: assetName,
      linkMode: linkMode,
      file: libDir.resolve(libName),
    );
    output.assets.code.add(libAsset);

    final entities = await Directory.fromUri(libDir).list().toList();
    final files = entities.whereType<File>().toList();
    for (final file in files) {
      final filePath = file.path;
      final fileName = path.basename(filePath);
      final fileNameWithoutExt = path.basenameWithoutExtension(filePath);
      final fileExt = path.extension(filePath);
      if (fileName == libName || fileExt != libExt) continue;
      final fileAsset = CodeAsset(
        package: input.packageName,
        name: 'src/ffi/$fileNameWithoutExt.g.dart',
        linkMode: linkMode,
        file: file.uri,
      );
      output.assets.code.add(fileAsset);
    }
  }
}
