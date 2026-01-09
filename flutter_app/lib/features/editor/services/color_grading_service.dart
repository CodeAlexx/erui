import 'dart:io';
import 'dart:typed_data';

import '../models/color_grading_models.dart';
import '../models/editor_models.dart';

/// Service for applying color grading effects via FFmpeg
class ColorGradingService {
  /// FFmpeg binary path
  final String ffmpegPath;

  /// Temporary directory for processing
  final String tempDir;

  ColorGradingService({
    this.ffmpegPath = 'ffmpeg',
    String? tempDir,
  }) : tempDir = tempDir ?? Directory.systemTemp.path;

  /// Apply a LUT to an image frame
  Future<Uint8List?> applyLUT({
    required Uint8List inputFrame,
    required LUTFile lut,
    String format = 'png',
  }) async {
    final inputPath = '$tempDir/lut_input_${DateTime.now().millisecondsSinceEpoch}.$format';
    final outputPath = '$tempDir/lut_output_${DateTime.now().millisecondsSinceEpoch}.$format';

    try {
      // Write input frame
      await File(inputPath).writeAsBytes(inputFrame);

      // Apply LUT via FFmpeg
      final result = await Process.run(ffmpegPath, [
        '-y',
        '-i', inputPath,
        '-vf', lut.toFFmpegFilter(),
        '-frames:v', '1',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        print('FFmpeg LUT error: ${result.stderr}');
        return null;
      }

      // Read output
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return await outputFile.readAsBytes();
      }
      return null;
    } finally {
      // Cleanup
      await File(inputPath).delete().catchError((_) {});
      await File(outputPath).delete().catchError((_) {});
    }
  }

  /// Apply color wheels (lift/gamma/gain) to an image frame
  Future<Uint8List?> applyColorWheels({
    required Uint8List inputFrame,
    required ColorGrade grade,
    String format = 'png',
  }) async {
    final filter = grade.toFFmpegFilter();
    if (filter.isEmpty) return inputFrame;

    final inputPath = '$tempDir/cw_input_${DateTime.now().millisecondsSinceEpoch}.$format';
    final outputPath = '$tempDir/cw_output_${DateTime.now().millisecondsSinceEpoch}.$format';

    try {
      await File(inputPath).writeAsBytes(inputFrame);

      final result = await Process.run(ffmpegPath, [
        '-y',
        '-i', inputPath,
        '-vf', filter,
        '-frames:v', '1',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        print('FFmpeg color wheels error: ${result.stderr}');
        return null;
      }

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return await outputFile.readAsBytes();
      }
      return null;
    } finally {
      await File(inputPath).delete().catchError((_) {});
      await File(outputPath).delete().catchError((_) {});
    }
  }

  /// Apply HSL adjustment to an image frame
  Future<Uint8List?> applyHSLAdjustment({
    required Uint8List inputFrame,
    required List<HSLAdjustment> adjustments,
    String format = 'png',
  }) async {
    final filters = adjustments
        .map((a) => a.toFFmpegFilter())
        .where((f) => f.isNotEmpty)
        .toList();

    if (filters.isEmpty) return inputFrame;

    final inputPath = '$tempDir/hsl_input_${DateTime.now().millisecondsSinceEpoch}.$format';
    final outputPath = '$tempDir/hsl_output_${DateTime.now().millisecondsSinceEpoch}.$format';

    try {
      await File(inputPath).writeAsBytes(inputFrame);

      final result = await Process.run(ffmpegPath, [
        '-y',
        '-i', inputPath,
        '-vf', filters.join(','),
        '-frames:v', '1',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        print('FFmpeg HSL error: ${result.stderr}');
        return null;
      }

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return await outputFile.readAsBytes();
      }
      return null;
    } finally {
      await File(inputPath).delete().catchError((_) {});
      await File(outputPath).delete().catchError((_) {});
    }
  }

  /// Apply color curves to an image frame
  Future<Uint8List?> applyCurves({
    required Uint8List inputFrame,
    required List<ColorCurve> curves,
    String format = 'png',
  }) async {
    final filters = curves
        .map((c) => c.toFFmpegFilter())
        .where((f) => f.isNotEmpty)
        .toList();

    if (filters.isEmpty) return inputFrame;

    final inputPath = '$tempDir/curves_input_${DateTime.now().millisecondsSinceEpoch}.$format';
    final outputPath = '$tempDir/curves_output_${DateTime.now().millisecondsSinceEpoch}.$format';

    try {
      await File(inputPath).writeAsBytes(inputFrame);

      final result = await Process.run(ffmpegPath, [
        '-y',
        '-i', inputPath,
        '-vf', filters.join(','),
        '-frames:v', '1',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        print('FFmpeg curves error: ${result.stderr}');
        return null;
      }

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return await outputFile.readAsBytes();
      }
      return null;
    } finally {
      await File(inputPath).delete().catchError((_) {});
      await File(outputPath).delete().catchError((_) {});
    }
  }

  /// Build a complete FFmpeg filter chain for all color grading
  String buildFilterChain({
    ColorGrade? grade,
    LUTFile? lut,
    List<HSLAdjustment>? hslAdjustments,
    List<ColorCurve>? curves,
  }) {
    final filters = <String>[];

    // Apply in order: grade -> HSL -> curves -> LUT
    if (grade != null && grade.enabled) {
      final gradeFilter = grade.toFFmpegFilter();
      if (gradeFilter.isNotEmpty) filters.add(gradeFilter);
    }

    if (hslAdjustments != null) {
      for (final adj in hslAdjustments) {
        final hslFilter = adj.toFFmpegFilter();
        if (hslFilter.isNotEmpty) filters.add(hslFilter);
      }
    }

    if (curves != null) {
      for (final curve in curves) {
        final curveFilter = curve.toFFmpegFilter();
        if (curveFilter.isNotEmpty) filters.add(curveFilter);
      }
    }

    // LUT should typically be applied last
    if (lut != null) {
      filters.add(lut.toFFmpegFilter());
    }

    return filters.join(',');
  }

  /// Apply all color grading to an image frame
  Future<Uint8List?> applyAllGrading({
    required Uint8List inputFrame,
    ColorGrade? grade,
    LUTFile? lut,
    List<HSLAdjustment>? hslAdjustments,
    List<ColorCurve>? curves,
    String format = 'png',
  }) async {
    final filterChain = buildFilterChain(
      grade: grade,
      lut: lut,
      hslAdjustments: hslAdjustments,
      curves: curves,
    );

    if (filterChain.isEmpty) return inputFrame;

    final inputPath = '$tempDir/grade_input_${DateTime.now().millisecondsSinceEpoch}.$format';
    final outputPath = '$tempDir/grade_output_${DateTime.now().millisecondsSinceEpoch}.$format';

    try {
      await File(inputPath).writeAsBytes(inputFrame);

      final result = await Process.run(ffmpegPath, [
        '-y',
        '-i', inputPath,
        '-vf', filterChain,
        '-frames:v', '1',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        print('FFmpeg grading error: ${result.stderr}');
        return null;
      }

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return await outputFile.readAsBytes();
      }
      return null;
    } finally {
      await File(inputPath).delete().catchError((_) {});
      await File(outputPath).delete().catchError((_) {});
    }
  }

  /// Generate a preview thumbnail for a LUT
  Future<Uint8List?> generateLUTPreview({
    required Uint8List referenceImage,
    required LUTFile lut,
    int size = 100,
  }) async {
    final inputPath = '$tempDir/lut_preview_in_${DateTime.now().millisecondsSinceEpoch}.png';
    final outputPath = '$tempDir/lut_preview_out_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      await File(inputPath).writeAsBytes(referenceImage);

      final result = await Process.run(ffmpegPath, [
        '-y',
        '-i', inputPath,
        '-vf', '${lut.toFFmpegFilter()},scale=$size:$size:force_original_aspect_ratio=decrease',
        '-frames:v', '1',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        return null;
      }

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return await outputFile.readAsBytes();
      }
      return null;
    } finally {
      await File(inputPath).delete().catchError((_) {});
      await File(outputPath).delete().catchError((_) {});
    }
  }

  /// Parse a .cube LUT file to extract metadata
  Future<Map<String, dynamic>?> parseLUTFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final lines = await file.readAsLines();
      final metadata = <String, dynamic>{
        'path': path,
        'name': path.split('/').last.replaceAll('.cube', ''),
      };

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('TITLE')) {
          metadata['title'] = trimmed.substring(5).trim().replaceAll('"', '');
        } else if (trimmed.startsWith('LUT_3D_SIZE')) {
          metadata['size'] = int.tryParse(trimmed.substring(11).trim());
        } else if (trimmed.startsWith('DOMAIN_MIN')) {
          metadata['domainMin'] = trimmed.substring(10).trim();
        } else if (trimmed.startsWith('DOMAIN_MAX')) {
          metadata['domainMax'] = trimmed.substring(10).trim();
        } else if (!trimmed.startsWith('#') && trimmed.contains(' ')) {
          // First data line reached, stop parsing metadata
          break;
        }
      }

      return metadata;
    } catch (e) {
      print('Error parsing LUT file: $e');
      return null;
    }
  }

  /// List all LUT files in a directory
  Future<List<LUTFile>> scanLUTDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final luts = <LUTFile>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.cube')) {
        final metadata = await parseLUTFile(entity.path);
        if (metadata != null) {
          luts.add(LUTFile(
            id: generateId(),
            name: metadata['title'] ?? metadata['name'] ?? 'Unknown',
            path: entity.path,
          ));
        }
      }
    }

    return luts;
  }
}
