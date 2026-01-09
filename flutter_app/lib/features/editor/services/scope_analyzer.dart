import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Data for waveform scope display
class WaveformData {
  /// Luma values per column (0.0-1.0)
  final List<List<double>> lumaColumns;

  /// RGB values per column (if parade mode)
  final List<List<double>>? redColumns;
  final List<List<double>>? greenColumns;
  final List<List<double>>? blueColumns;

  /// Width of the analyzed frame
  final int width;

  /// Height of the analyzed frame
  final int height;

  const WaveformData({
    required this.lumaColumns,
    this.redColumns,
    this.greenColumns,
    this.blueColumns,
    required this.width,
    required this.height,
  });

  /// Whether RGB parade data is available
  bool get hasRGBData =>
      redColumns != null && greenColumns != null && blueColumns != null;
}

/// Data for histogram display
class HistogramData {
  /// Red channel histogram (256 bins, 0.0-1.0 normalized)
  final List<double> red;

  /// Green channel histogram
  final List<double> green;

  /// Blue channel histogram
  final List<double> blue;

  /// Luminance histogram
  final List<double> luminance;

  /// Maximum value across all channels (for scaling)
  final double maxValue;

  const HistogramData({
    required this.red,
    required this.green,
    required this.blue,
    required this.luminance,
    required this.maxValue,
  });

  factory HistogramData.empty() {
    return HistogramData(
      red: List.filled(256, 0),
      green: List.filled(256, 0),
      blue: List.filled(256, 0),
      luminance: List.filled(256, 0),
      maxValue: 1.0,
    );
  }
}

/// Data for vectorscope display
class VectorscopeData {
  /// UV coordinate points (normalized -0.5 to 0.5)
  final List<Offset> points;

  /// Intensity values for each point (0.0-1.0)
  final List<double> intensities;

  /// Whether skin tone line should be displayed
  final bool showSkinToneLine;

  const VectorscopeData({
    required this.points,
    required this.intensities,
    this.showSkinToneLine = true,
  });

  factory VectorscopeData.empty() {
    return const VectorscopeData(
      points: [],
      intensities: [],
    );
  }
}

/// Display modes for waveform
enum WaveformMode {
  /// Luma only
  luma,

  /// RGB parade (side by side)
  rgbParade,

  /// RGB overlay
  rgbOverlay,
}

/// Service for analyzing video frames for scopes display
class ScopeAnalyzer {
  /// FFmpeg binary path
  final String ffmpegPath;

  /// Temporary directory
  final String tempDir;

  ScopeAnalyzer({
    this.ffmpegPath = 'ffmpeg',
    String? tempDir,
  }) : tempDir = tempDir ?? Directory.systemTemp.path;

  /// Extract waveform data from an image
  Future<WaveformData?> analyzeWaveform(
    Uint8List imageData, {
    int targetWidth = 256,
    WaveformMode mode = WaveformMode.luma,
  }) async {
    try {
      // Decode image
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width;
      final height = image.height;

      // Get pixel data
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final pixels = byteData.buffer.asUint8List();

      // Sample columns for waveform
      final sampleStep = math.max(1, width ~/ targetWidth);
      final numColumns = width ~/ sampleStep;

      final lumaColumns = <List<double>>[];
      final redColumns = <List<double>>[];
      final greenColumns = <List<double>>[];
      final blueColumns = <List<double>>[];

      for (int col = 0; col < numColumns; col++) {
        final x = col * sampleStep;
        final lumaValues = <double>[];
        final redValues = <double>[];
        final greenValues = <double>[];
        final blueValues = <double>[];

        for (int y = 0; y < height; y++) {
          final offset = (y * width + x) * 4;
          final r = pixels[offset] / 255.0;
          final g = pixels[offset + 1] / 255.0;
          final b = pixels[offset + 2] / 255.0;

          // Calculate luma (BT.709)
          final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          lumaValues.add(luma);

          if (mode != WaveformMode.luma) {
            redValues.add(r);
            greenValues.add(g);
            blueValues.add(b);
          }
        }

        lumaColumns.add(lumaValues);
        if (mode != WaveformMode.luma) {
          redColumns.add(redValues);
          greenColumns.add(greenValues);
          blueColumns.add(blueValues);
        }
      }

      image.dispose();

      return WaveformData(
        lumaColumns: lumaColumns,
        redColumns: mode != WaveformMode.luma ? redColumns : null,
        greenColumns: mode != WaveformMode.luma ? greenColumns : null,
        blueColumns: mode != WaveformMode.luma ? blueColumns : null,
        width: width,
        height: height,
      );
    } catch (e) {
      print('Waveform analysis error: $e');
      return null;
    }
  }

  /// Calculate histogram from image data
  Future<HistogramData?> analyzeHistogram(Uint8List imageData) async {
    try {
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final pixels = byteData.buffer.asUint8List();
      final pixelCount = pixels.length ~/ 4;

      // Initialize histogram bins
      final redHist = List<int>.filled(256, 0);
      final greenHist = List<int>.filled(256, 0);
      final blueHist = List<int>.filled(256, 0);
      final lumaHist = List<int>.filled(256, 0);

      // Count pixels
      for (int i = 0; i < pixelCount; i++) {
        final offset = i * 4;
        final r = pixels[offset];
        final g = pixels[offset + 1];
        final b = pixels[offset + 2];

        redHist[r]++;
        greenHist[g]++;
        blueHist[b]++;

        // Calculate luma
        final luma = ((0.2126 * r + 0.7152 * g + 0.0722 * b)).round().clamp(0, 255);
        lumaHist[luma]++;
      }

      // Find max for normalization
      int maxVal = 1;
      for (int i = 0; i < 256; i++) {
        maxVal = math.max(maxVal, redHist[i]);
        maxVal = math.max(maxVal, greenHist[i]);
        maxVal = math.max(maxVal, blueHist[i]);
        maxVal = math.max(maxVal, lumaHist[i]);
      }

      // Normalize
      final red = redHist.map((v) => v / maxVal).toList();
      final green = greenHist.map((v) => v / maxVal).toList();
      final blue = blueHist.map((v) => v / maxVal).toList();
      final luminance = lumaHist.map((v) => v / maxVal).toList();

      image.dispose();

      return HistogramData(
        red: red,
        green: green,
        blue: blue,
        luminance: luminance,
        maxValue: maxVal.toDouble(),
      );
    } catch (e) {
      print('Histogram analysis error: $e');
      return null;
    }
  }

  /// Calculate vectorscope data from image
  Future<VectorscopeData?> analyzeVectorscope(
    Uint8List imageData, {
    int sampleRate = 4, // Sample every Nth pixel for performance
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width;
      final height = image.height;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final pixels = byteData.buffer.asUint8List();

      final points = <Offset>[];
      final intensities = <double>[];

      // Sample pixels and convert to UV space
      for (int y = 0; y < height; y += sampleRate) {
        for (int x = 0; x < width; x += sampleRate) {
          final offset = (y * width + x) * 4;
          final r = pixels[offset] / 255.0;
          final g = pixels[offset + 1] / 255.0;
          final b = pixels[offset + 2] / 255.0;

          // Convert RGB to YUV (BT.709)
          // final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          final u = -0.1146 * r - 0.3854 * g + 0.5 * b;
          final v = 0.5 * r - 0.4542 * g - 0.0458 * b;

          // Calculate intensity (saturation)
          final intensity = math.sqrt(u * u + v * v) * 2;

          points.add(Offset(u, -v)); // Flip v for display
          intensities.add(intensity.clamp(0.0, 1.0));
        }
      }

      image.dispose();

      return VectorscopeData(
        points: points,
        intensities: intensities,
        showSkinToneLine: true,
      );
    } catch (e) {
      print('Vectorscope analysis error: $e');
      return null;
    }
  }

  /// Generate waveform image using FFmpeg
  Future<Uint8List?> generateWaveformImage(
    String videoPath,
    double timestamp, {
    int width = 320,
    int height = 200,
    WaveformMode mode = WaveformMode.luma,
  }) async {
    final outputPath = '$tempDir/waveform_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      String filter;
      switch (mode) {
        case WaveformMode.luma:
          filter = 'waveform=mode=row:components=1:c=1';
          break;
        case WaveformMode.rgbParade:
          filter = 'waveform=mode=row:components=7:display=parade';
          break;
        case WaveformMode.rgbOverlay:
          filter = 'waveform=mode=row:components=7:display=overlay';
          break;
      }

      final result = await Process.run(ffmpegPath, [
        '-y',
        '-ss', timestamp.toString(),
        '-i', videoPath,
        '-vf', '$filter,scale=$width:$height',
        '-frames:v', '1',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        print('FFmpeg waveform error: ${result.stderr}');
        return null;
      }

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return await outputFile.readAsBytes();
      }
      return null;
    } finally {
      await File(outputPath).delete().catchError((_) {});
    }
  }

  /// Generate vectorscope image using FFmpeg
  Future<Uint8List?> generateVectorscopeImage(
    String videoPath,
    double timestamp, {
    int size = 200,
  }) async {
    final outputPath = '$tempDir/vectorscope_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      final result = await Process.run(ffmpegPath, [
        '-y',
        '-ss', timestamp.toString(),
        '-i', videoPath,
        '-vf', 'vectorscope=mode=color:envelope=instant,scale=$size:$size',
        '-frames:v', '1',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        print('FFmpeg vectorscope error: ${result.stderr}');
        return null;
      }

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return await outputFile.readAsBytes();
      }
      return null;
    } finally {
      await File(outputPath).delete().catchError((_) {});
    }
  }

  /// Generate histogram image using FFmpeg
  Future<Uint8List?> generateHistogramImage(
    String videoPath,
    double timestamp, {
    int width = 320,
    int height = 200,
  }) async {
    final outputPath = '$tempDir/histogram_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      final result = await Process.run(ffmpegPath, [
        '-y',
        '-ss', timestamp.toString(),
        '-i', videoPath,
        '-vf', 'histogram=display_mode=overlay:level_height=$height,scale=$width:$height',
        '-frames:v', '1',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        print('FFmpeg histogram error: ${result.stderr}');
        return null;
      }

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        return await outputFile.readAsBytes();
      }
      return null;
    } finally {
      await File(outputPath).delete().catchError((_) {});
    }
  }
}

/// Calculate IRE value from normalized luma (0-1)
double lumaToIRE(double luma) {
  // Video black = 7.5 IRE, white = 100 IRE for NTSC
  // For digital, 0 = 0 IRE, 1 = 100 IRE
  return luma * 100;
}

/// Standard IRE levels for reference lines
const ireReferenceLevels = [0, 7.5, 10, 20, 50, 70, 90, 100];

/// Skin tone line angle in degrees (approximately 123 degrees in vectorscope)
const skinToneAngle = 123.0;
