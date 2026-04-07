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

    final srcDir = input.outputDirectoryShared.resolve('src/');
    final dstDir = input.outputDirectory.resolve('dst/');
    final outDir = input.outputDirectory.resolve('out/');
    await Directory.fromUri(srcDir).create(recursive: true);
    await Directory.fromUri(dstDir).create(recursive: true);
    await Directory.fromUri(outDir).create(recursive: true);

    // git rev-parse --show-toplevel
    final topLevel = await runProcess(
      executable: git.uri,
      arguments: ['rev-parse', '--show-toplevel'],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: false,
    ).then((e) => e.stdout.trim());
    // git clone
    if (Uri.directory(topLevel) != srcDir) {
      await runProcess(
        executable: git.uri,
        arguments: ['clone', url, '.'],
        workingDirectory: srcDir,
        logger: logger,
        throwOnUnexpectedExitCode: true,
      );
    }
    // git checkout
    await runProcess(
      executable: git.uri,
      arguments: ['checkout', tag],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    // cmake -B
    await runProcess(
      executable: cmake.uri,
      arguments: [
        '-B',
        dstDir.toFilePath(),
        '-DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON',
        '-DCMAKE_BUILD_TYPE=Release',
        ..._getTargetArguments(input.config.code),
        '-DLLAMA_BUILD_COMMON=OFF',
        '-DLLAMA_BUILD_TESTS=OFF',
        '-DLLAMA_BUILD_TOOLS=OFF',
        '-DLLAMA_BUILD_EXAMPLES=OFF',
        '-DLLAMA_BUILD_SERVER=OFF',
        '-DLLAMA_BUILD_WEBUI=OFF',
        '-DLLAMA_TOOLS_INSTALL=OFF',
        '-DLLAMA_TESTS_INSTALL=OFF',
        '-DGGML_NATIVE=OFF',
      ],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    // cmake --build
    await runProcess(
      executable: cmake.uri,
      arguments: ['--build', dstDir.toFilePath()],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    // cmake --install
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
    final linkMode = getLinkMode(input.config.code.linkModePreference);
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

  List<String> _getTargetArguments(
    CodeConfig config,
  ) => switch (config.targetOS) {
    .macOS => [
      '-DCMAKE_OSX_ARCHITECTURES=${config.targetArchitecture.toOsxArchitecture()}',
      // '-DCMAKE_OSX_DEPLOYMENT_TARGET=${config.macOS.targetVersion}',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=13.3',
    ],
    .iOS => [
      '-DCMAKE_SYSTEM_NAME=iOS',
      '-DCMAKE_OSX_ARCHITECTURES=${config.targetArchitecture.toOsxArchitecture()}',
      '-DCMAKE_OSX_SYSROOT=${config.iOS.targetSdk.type}',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=${config.iOS.targetVersion}',
    ],
    .android => [
      '-DCMAKE_SYSTEM_NAME=Android',
      '-DANDROID_ABI=${config.targetArchitecture.toAndroidAbi()}',
    ],
    _ => [
      '-DCMAKE_SYSTEM_PROCESSOR=${config.targetArchitecture.toSystemProcessor()}',
    ],
  };
}

extension on Architecture {
  String toOsxArchitecture() => switch (this) {
    .arm64 => 'arm64',
    .x64 => 'x86_64',
    _ => throw UnsupportedError('Unsupported architecture: $this'),
  };

  String toAndroidAbi() => switch (this) {
    .arm => 'armeabi-v7a',
    .arm64 => 'arm64-v8a',
    .ia32 => 'x86',
    .x64 => 'x86_64',
    .riscv64 => 'riscv64',
    _ => throw UnsupportedError('Unsupported architecture: $this'),
  };

  String toSystemProcessor() => switch (this) {
    .arm => 'arm',
    .arm64 => 'arm64',
    .ia32 => 'x86',
    .riscv32 => 'riscv32',
    .riscv64 => 'riscv64',
    .x64 => 'x86_64',
    _ => throw UnsupportedError('Unsupported architecture: $this'),
  };
}
