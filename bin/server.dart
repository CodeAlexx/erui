import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart' hide Response;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// EriUI Server - Unified Training + Inference
/// Connects Flutter frontend to ComfyUI (inference) and OneTrainer (training)
void main(List<String> args) async {
  final host = _getArg(args, 'host', '0.0.0.0');
  final port = int.parse(_getArg(args, 'port', '7802'));
  final comfyUrl = _getArg(args, 'comfy-url', 'http://localhost:8189');
  final trainerUrl = _getArg(args, 'trainer-url', 'http://localhost:8000');
  // EriUI output directory - fully standalone from SwarmUI
  final outputDir = _getArg(args, 'output-dir', '/home/alex/eriui/output');

  print('Starting EriUI Server (Standalone Mode)...');
  print('ComfyUI backend: $comfyUrl');
  print('OneTrainer backend: $trainerUrl');
  print('Output directory: $outputDir');

  final comfy = ComfyUIProxy(comfyUrl);
  final trainer = OneTrainerProxy(trainerUrl);
  final api = EriUIApi(comfy, trainer, outputDir: outputDir);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(api.router);

  final server = await shelf_io.serve(handler, host, port);
  print('EriUI Server running at http://${server.address.host}:${server.port}');
  print('Press Ctrl+C to stop');

  ProcessSignal.sigint.watch().first.then((_) async {
    print('Shutting down...');
    await trainer.disconnect();
    await server.close();
    exit(0);
  });
}

String _getArg(List<String> args, String name, String defaultValue) {
  for (final arg in args) {
    if (arg.startsWith('--$name=')) return arg.substring('--$name='.length);
  }
  return defaultValue;
}

class ComfyUIProxy {
  final String baseUrl;
  final Dio _dio;
  WebSocketChannel? _ws;
  String? _clientId;
  final _completions = <String, Completer<Map<String, dynamic>>>{};

  ComfyUIProxy(this.baseUrl) : _dio = Dio(BaseOptions(baseUrl: baseUrl));

  String get clientId => _clientId ??= const Uuid().v4();

  Future<bool> testConnection() async {
    try {
      final resp = await _dio.get('/system_stats');
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getSystemStats() async {
    final resp = await _dio.get('/system_stats');
    return resp.data as Map<String, dynamic>;
  }

  Future<List<String>> getModels() async {
    try {
      final resp = await _dio.get('/object_info/CheckpointLoaderSimple');
      final data = resp.data as Map<String, dynamic>;
      final input = data['CheckpointLoaderSimple']?['input']?['required']?['ckpt_name'];
      if (input is List && input.isNotEmpty && input[0] is List) {
        return (input[0] as List).map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('Error getting models: $e');
    }
    return [];
  }

  Future<List<String>> getDiffusionModels() async {
    try {
      final resp = await _dio.get('/object_info/UNETLoader');
      final data = resp.data as Map<String, dynamic>;
      final input = data['UNETLoader']?['input']?['required']?['unet_name'];
      if (input is List && input.isNotEmpty && input[0] is List) {
        return (input[0] as List).map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('Error getting diffusion models: $e');
    }
    return [];
  }

  Future<List<String>> getVAEs() async {
    try {
      final resp = await _dio.get('/object_info/VAELoader');
      final data = resp.data as Map<String, dynamic>;
      final input = data['VAELoader']?['input']?['required']?['vae_name'];
      if (input is List && input.isNotEmpty && input[0] is List) {
        return (input[0] as List).map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('Error getting VAEs: $e');
    }
    return [];
  }

  Future<List<String>> getCLIPs() async {
    try {
      final resp = await _dio.get('/object_info/DualCLIPLoader');
      final data = resp.data as Map<String, dynamic>;
      final input = data['DualCLIPLoader']?['input']?['required']?['clip_name1'];
      if (input is List && input.isNotEmpty && input[0] is List) {
        return (input[0] as List).map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('Error getting CLIPs: $e');
    }
    return [];
  }

  Future<List<String>> getSamplers() async {
    try {
      final resp = await _dio.get('/object_info/KSampler');
      final data = resp.data as Map<String, dynamic>;
      final input = data['KSampler']?['input']?['required']?['sampler_name'];
      if (input is List && input.isNotEmpty && input[0] is List) {
        return (input[0] as List).map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('Error getting samplers: $e');
    }
    return ['euler', 'euler_ancestral', 'dpm_2', 'dpmpp_2m', 'dpmpp_sde', 'ddim'];
  }

  Future<List<String>> getSchedulers() async {
    try {
      final resp = await _dio.get('/object_info/KSampler');
      final data = resp.data as Map<String, dynamic>;
      final input = data['KSampler']?['input']?['required']?['scheduler'];
      if (input is List && input.isNotEmpty && input[0] is List) {
        return (input[0] as List).map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('Error getting schedulers: $e');
    }
    return ['normal', 'karras', 'exponential', 'simple'];
  }

  Future<void> connectWebSocket() async {
    if (_ws != null) return;
    final wsUrl = baseUrl.replaceFirst('http', 'ws') + '/ws?clientId=$clientId';
    _ws = WebSocketChannel.connect(Uri.parse(wsUrl));
    _ws!.stream.listen((data) {
      if (data is String) {
        try {
          final msg = jsonDecode(data) as Map<String, dynamic>;
          _handleMessage(msg);
        } catch (e) {
          print('WS parse error: $e');
        }
      }
    }, onError: (e) {
      print('WS error: $e');
      _ws = null;
    }, onDone: () {
      print('WS closed');
      _ws = null;
    });
  }

  final _progress = <String, Map<String, dynamic>>{};

  Map<String, dynamic>? getProgress(String promptId) => _progress[promptId];

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    final data = msg['data'] as Map<String, dynamic>? ?? {};
    print('WS message: type=$type, data=$data');
    if (type == 'progress') {
      final value = data['value'] as int? ?? 0;
      final max = data['max'] as int? ?? 1;
      final promptId = data['prompt_id'] as String?;
      if (promptId != null) {
        _progress[promptId] = {'step': value, 'total': max, 'status': 'generating'};
        print('Progress updated: $promptId -> step $value/$max');
      }
    } else if (type == 'executing') {
      final promptId = data['prompt_id'] as String?;
      final node = data['node'] as String?;
      if (promptId != null && node == null && _completions.containsKey(promptId)) {
        // Don't set status here - let _waitForCompletion do it with images
        print('Execution complete for $promptId, signaling completer');
        _completions[promptId]!.complete({'success': true});
        _completions.remove(promptId);
      }
    } else if (type == 'execution_error') {
      final promptId = data['prompt_id'] as String?;
      if (promptId != null && _completions.containsKey(promptId)) {
        _progress[promptId] = {'status': 'error', 'error': data['exception_message'] ?? 'Error'};
        _completions[promptId]!.complete({'success': false, 'error': data['exception_message'] ?? 'Error'});
        _completions.remove(promptId);
      }
    }
  }

  Future<Map<String, dynamic>> generate({
    required String prompt, String negativePrompt = '', required String model,
    int width = 1024, int height = 1024, int steps = 20, double cfg = 7.0,
    int seed = -1, String sampler = 'euler', String scheduler = 'normal',
    List<Map<String, dynamic>>? loras, String modelType = 'checkpoint',
  }) async {
    await connectWebSocket();
    final actualSeed = seed < 0 ? Random().nextInt(1 << 32) : seed;
    final workflow = _buildWorkflow(prompt: prompt, negativePrompt: negativePrompt, model: model,
      width: width, height: height, steps: steps, cfg: cfg, seed: actualSeed, sampler: sampler, scheduler: scheduler, loras: loras, modelType: modelType);

    final resp = await _dio.post('/prompt', data: {'prompt': workflow, 'client_id': clientId});
    if (resp.statusCode != 200) return {'success': false, 'error': 'Failed to queue'};

    final promptId = (resp.data as Map<String, dynamic>)['prompt_id'] as String;
    final completer = Completer<Map<String, dynamic>>();
    _completions[promptId] = completer;

    try {
      final result = await completer.future.timeout(const Duration(minutes: 10),
        onTimeout: () => {'success': false, 'error': 'Timeout'});
      if (result['success'] == true) {
        await Future.delayed(const Duration(milliseconds: 500));
        final history = await _dio.get('/history/$promptId');
        final historyData = history.data as Map<String, dynamic>?;
        final outputs = historyData?[promptId]?['outputs'] as Map<String, dynamic>?;
        final images = <Map<String, dynamic>>[];
        if (outputs != null) {
          for (final nodeOut in outputs.values) {
            if (nodeOut is Map && nodeOut['images'] != null) {
              for (final img in nodeOut['images'] as List) {
                images.add({'filename': img['filename'], 'subfolder': img['subfolder'] ?? '', 'type': img['type'] ?? 'output'});
              }
            }
          }
        }
        return {'success': true, 'prompt_id': promptId, 'seed': actualSeed, 'images': images};
      }
      return result;
    } catch (e) {
      _completions.remove(promptId);
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<int>> getImage(String filename, {String subfolder = '', String type = 'output'}) async {
    final resp = await _dio.get('/view', queryParameters: {'filename': filename, 'subfolder': subfolder, 'type': type},
      options: Options(responseType: ResponseType.bytes));
    return resp.data as List<int>;
  }

  Map<String, dynamic> _buildWorkflow({required String prompt, required String negativePrompt, required String model,
    required int width, required int height, required int steps, required double cfg, required int seed,
    required String sampler, required String scheduler, List<Map<String, dynamic>>? loras, String modelType = 'checkpoint'}) {

    final workflow = <String, dynamic>{};

    // Model and CLIP/VAE sources
    var modelSource = <dynamic>[];
    var clipSource = <dynamic>[];
    var vaeSource = <dynamic>[];

    if (modelType == 'diffusion_model') {
      // z_image/Lumina2 models need UNETLoader + qwen_3_4b CLIP + ae VAE
      workflow["4"] = {"class_type": "UNETLoader", "inputs": {"unet_name": model, "weight_dtype": "default"}};
      workflow["11"] = {"class_type": "CLIPLoader", "inputs": {
        "clip_name": "qwen_3_4b.safetensors",
        "type": "lumina2"
      }};
      workflow["12"] = {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}};
      modelSource = ["4", 0];
      clipSource = ["11", 0];
      vaeSource = ["12", 0];
    } else {
      // Regular checkpoint includes model, CLIP, and VAE
      workflow["4"] = {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": model}};
      modelSource = ["4", 0];
      clipSource = ["4", 1];
      vaeSource = ["4", 2];
    }

    // Common nodes
    workflow["5"] = {"class_type": "EmptyLatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}};

    // Add LoRA nodes if any
    if (loras != null && loras.isNotEmpty) {
      var nodeId = 20;
      for (final lora in loras) {
        final loraName = lora['name'] as String? ?? '';
        final strength = (lora['strength'] as num?)?.toDouble() ?? 1.0;
        if (loraName.isNotEmpty) {
          workflow["$nodeId"] = {
            "class_type": "LoraLoader",
            "inputs": {
              "lora_name": loraName,
              "strength_model": strength,
              "strength_clip": strength,
              "model": modelSource,
              "clip": clipSource,
            }
          };
          modelSource = ["$nodeId", 0];
          clipSource = ["$nodeId", 1];
          nodeId++;
        }
      }
    }

    // Text encoders and sampler
    workflow["6"] = {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": clipSource}};
    workflow["7"] = {"class_type": "CLIPTextEncode", "inputs": {"text": negativePrompt, "clip": clipSource}};
    workflow["3"] = {"class_type": "KSampler", "inputs": {"seed": seed, "steps": steps, "cfg": cfg, "sampler_name": sampler,
      "scheduler": scheduler, "denoise": 1, "model": modelSource, "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}};

    // Decode and save
    workflow["8"] = {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": vaeSource}};
    workflow["9"] = {"class_type": "SaveImage", "inputs": {"filename_prefix": "EriUI", "images": ["8", 0]}};

    return workflow;
  }

  Future<void> interrupt() async => await _dio.post('/interrupt');

  /// Build Wan2.2 T2V (text-to-video) workflow
  Map<String, dynamic> _buildVideoWorkflow({
    required String prompt,
    String negativePrompt = '',
    required String model, // e.g. wan2.2_t2v_14B_fp16.safetensors
    int width = 848,
    int height = 480,
    int frames = 81,
    int steps = 20,
    double cfg = 6.0,
    int seed = -1,
    String sampler = 'uni_pc',
    String scheduler = 'normal',
    int fps = 24,
    List<Map<String, dynamic>>? loras,
    String? clipModel,
    String? vaeModel,
    String videoFormat = 'webp',
    bool isI2V = false, // image-to-video mode
    String? initImage, // for i2v mode
    String? explicitHighNoise, // Explicit high noise model from UI
    String? explicitLowNoise,  // Explicit low noise model from UI
  }) {
    final workflow = <String, dynamic>{};

    // Determine model files based on model name
    // Wan2.2 uses dual models (high_noise + low_noise)
    final isWan22 = model.toLowerCase().contains('wan2.2') ||
                    (model.toLowerCase().contains('wan') && (model.contains('high_noise') || model.contains('low_noise')));
    final useDoubleModel = isWan22 && !model.contains('vace');

    // Use explicit models from UI if provided, otherwise derive them
    String highNoiseModel;
    String lowNoiseModel;

    if (explicitHighNoise != null && explicitLowNoise != null) {
      // Use explicit models from UI
      highNoiseModel = explicitHighNoise;
      lowNoiseModel = explicitLowNoise;
      print('Using explicit dual models: high=$highNoiseModel, low=$lowNoiseModel');
    } else if (useDoubleModel) {
      // Derive both model names from whichever one user selected
      highNoiseModel = model;
      lowNoiseModel = model;

      if (model.contains('high_noise')) {
        highNoiseModel = model;
        lowNoiseModel = model.replaceAll('high_noise', 'low_noise');
      } else if (model.contains('low_noise')) {
        lowNoiseModel = model;
        highNoiseModel = model.replaceAll('low_noise', 'high_noise');
      } else {
        // Model doesn't specify - assume we need to add the suffix
        final ext = model.endsWith('.safetensors') ? '.safetensors' : (model.endsWith('.gguf') ? '.gguf' : '');
        final base = model.replaceAll(ext, '');
        highNoiseModel = '${base}_high_noise$ext';
        lowNoiseModel = '${base}_low_noise$ext';
      }
      print('Derived dual models: high=$highNoiseModel, low=$lowNoiseModel');
    } else {
      // Single model workflow
      highNoiseModel = model;
      lowNoiseModel = model;
    }

    // Auto-detect CLIP and VAE
    final autoClip = clipModel ?? 'umt5_xxl_fp8_e4m3fn_scaled.safetensors';
    final autoVae = vaeModel ?? 'wan_2.1_vae.safetensors';

    // Node ID tracking
    var nodeId = 1;

    // Load diffusion models
    // Use dual models if Wan2.2 detected OR explicit models provided
    final useDualModels = useDoubleModel || (explicitHighNoise != null && explicitLowNoise != null);
    if (useDualModels) {
      // Wan2.2 uses two models: high_noise and low_noise
      workflow["${nodeId}"] = {
        "class_type": "UNETLoader",
        "inputs": {"unet_name": highNoiseModel, "weight_dtype": "default"}
      };
      final highNoiseNode = "${nodeId}";
      nodeId++;

      workflow["${nodeId}"] = {
        "class_type": "UNETLoader",
        "inputs": {"unet_name": lowNoiseModel, "weight_dtype": "default"}
      };
      final lowNoiseNode = "${nodeId}";
      nodeId++;

      // Store model sources
      workflow["_high_noise_model"] = [highNoiseNode, 0];
      workflow["_low_noise_model"] = [lowNoiseNode, 0];
    } else {
      // Single model workflow
      workflow["${nodeId}"] = {
        "class_type": "UNETLoader",
        "inputs": {"unet_name": model, "weight_dtype": "default"}
      };
      workflow["_model"] = ["${nodeId}", 0];
      nodeId++;
    }

    // Load CLIP
    workflow["${nodeId}"] = {
      "class_type": "CLIPLoader",
      "inputs": {"clip_name": autoClip, "type": "wan"}
    };
    final clipNode = "${nodeId}";
    var clipSource = [clipNode, 0];
    nodeId++;

    // Load VAE
    workflow["${nodeId}"] = {
      "class_type": "VAELoader",
      "inputs": {"vae_name": autoVae}
    };
    final vaeNode = "${nodeId}";
    final vaeSource = [vaeNode, 0];
    nodeId++;

    // Get model source (for LoRA chaining)
    var modelSource = useDualModels ? workflow["_high_noise_model"] : workflow["_model"];

    // Add LoRA nodes if any
    if (loras != null && loras.isNotEmpty) {
      for (final lora in loras) {
        final loraName = lora['name'] as String? ?? '';
        final strength = (lora['strength'] as num?)?.toDouble() ?? 1.0;
        if (loraName.isNotEmpty) {
          workflow["${nodeId}"] = {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {
              "lora_name": loraName,
              "strength_model": strength,
              "model": modelSource,
            }
          };
          modelSource = ["${nodeId}", 0];
          nodeId++;
        }
      }
    }

    // CLIP Text Encode
    workflow["${nodeId}"] = {
      "class_type": "CLIPTextEncode",
      "inputs": {"text": prompt, "clip": clipSource}
    };
    final positiveNode = "${nodeId}";
    nodeId++;

    workflow["${nodeId}"] = {
      "class_type": "CLIPTextEncode",
      "inputs": {"text": negativePrompt, "clip": clipSource}
    };
    final negativeNode = "${nodeId}";
    nodeId++;

    // Empty video latent
    workflow["${nodeId}"] = {
      "class_type": "EmptyHunyuanLatentVideo",
      "inputs": {"width": width, "height": height, "length": frames, "batch_size": 1}
    };
    final latentNode = "${nodeId}";
    nodeId++;

    // Sampler - use WanVideoSampler if available, otherwise KSampler
    workflow["${nodeId}"] = {
      "class_type": "KSampler",
      "inputs": {
        "seed": seed < 0 ? Random().nextInt(1 << 32) : seed,
        "steps": steps,
        "cfg": cfg,
        "sampler_name": sampler,
        "scheduler": scheduler,
        "denoise": 1.0,
        "model": modelSource,
        "positive": [positiveNode, 0],
        "negative": [negativeNode, 0],
        "latent_image": [latentNode, 0],
      }
    };
    final samplerNode = "${nodeId}";
    nodeId++;

    // VAE Decode for video
    workflow["${nodeId}"] = {
      "class_type": "VAEDecode",
      "inputs": {"samples": [samplerNode, 0], "vae": vaeSource}
    };
    final decodeNode = "${nodeId}";
    nodeId++;

    // Save video based on format
    final saveClass = switch (videoFormat) {
      'webp' => 'SaveAnimatedWEBP',
      'gif' => 'SaveAnimatedWEBP', // ComfyUI uses same node
      'mp4' => 'SaveVideo',
      'webm' => 'SaveVideo',
      _ => 'SaveAnimatedWEBP',
    };

    workflow["${nodeId}"] = {
      "class_type": saveClass,
      "inputs": {
        "filename_prefix": "EriUI_video",
        "fps": fps,
        "images": [decodeNode, 0],
        if (videoFormat == 'webp') "lossless": false,
        if (videoFormat == 'webp') "quality": 85,
        if (videoFormat == 'webp') "method": "default",
      }
    };
    nodeId++;

    // Clean up internal tracking keys
    workflow.remove("_high_noise_model");
    workflow.remove("_low_noise_model");
    workflow.remove("_model");

    return workflow;
  }

  /// Build LTX-2 video workflow from template
  Map<String, dynamic> _buildLTX2Workflow({
    required String prompt,
    String negativePrompt = '',
    required String model,
    int width = 768,
    int height = 512,
    int frames = 121,
    int steps = 20,
    double cfg = 3.0,
    int seed = -1,
    String? loraModel,
    double loraStrength = 1.0,
  }) {
    // LTX-2 API workflow - simplified direct node construction
    final workflow = <String, dynamic>{};

    // Node 1: Checkpoint loader
    workflow["1"] = {
      "class_type": "CheckpointLoaderSimple",
      "inputs": {"ckpt_name": model}
    };

    // Node 2: CLIP loader for Gemma
    workflow["2"] = {
      "class_type": "LTXVGemmaCLIPModelLoader",
      "inputs": {"clip_name": "gemma_3_12B_it.safetensors"}
    };

    // Node 3: Positive prompt
    workflow["3"] = {
      "class_type": "CLIPTextEncode",
      "inputs": {"text": prompt, "clip": ["2", 0]}
    };

    // Node 4: Negative prompt
    workflow["4"] = {
      "class_type": "CLIPTextEncode",
      "inputs": {"text": negativePrompt, "clip": ["2", 0]}
    };

    // Node 5: Empty latent
    workflow["5"] = {
      "class_type": "EmptyLTXVLatentVideo",
      "inputs": {"width": width, "height": height, "length": frames, "batch_size": 1}
    };

    // Node 6: Scheduler
    workflow["6"] = {
      "class_type": "LTXVScheduler",
      "inputs": {"steps": steps, "max_shift": 2.05, "base_shift": 0.95, "stretch": true, "terminal": 0.1}
    };

    // Node 7: Sampler select
    workflow["7"] = {
      "class_type": "KSamplerSelect",
      "inputs": {"sampler_name": "euler"}
    };

    // Node 8: Model reference (with optional LoRA)
    var modelRef = ["1", 0];
    if (loraModel != null && loraModel.isNotEmpty) {
      workflow["20"] = {
        "class_type": "LoraLoaderModelOnly",
        "inputs": {"model": ["1", 0], "lora_name": loraModel, "strength_model": loraStrength}
      };
      modelRef = ["20", 0];
    }

    // Node 9: Sampler
    workflow["9"] = {
      "class_type": "SamplerCustomAdvanced",
      "inputs": {
        "noise": ["10", 0],
        "guider": ["11", 0],
        "sampler": ["7", 0],
        "sigmas": ["6", 0],
        "latent_image": ["5", 0]
      }
    };

    // Node 10: Random noise
    workflow["10"] = {
      "class_type": "RandomNoise",
      "inputs": {"noise_seed": seed}
    };

    // Node 11: CFG guider
    workflow["11"] = {
      "class_type": "CFGGuider",
      "inputs": {"model": modelRef, "positive": ["3", 0], "negative": ["4", 0], "cfg": cfg}
    };

    // Node 12: VAE Decode
    workflow["12"] = {
      "class_type": "VAEDecode",
      "inputs": {"samples": ["9", 0], "vae": ["1", 2]}
    };

    // Node 13: Save video
    workflow["13"] = {
      "class_type": "SaveVideo",
      "inputs": {"video": ["12", 0], "filename_prefix": "EriUI_LTX2", "format": "mp4", "codec": "auto"}
    };

    return workflow;
  }

  /// Get available video models from diffusion_models folder
  Future<List<Map<String, dynamic>>> getVideoModels() async {
    try {
      final models = await getDiffusionModels();
      final videoModels = <Map<String, dynamic>>[];

      for (final model in models) {
        final name = model.toLowerCase();
        String? videoType;
        String? architecture;

        if (name.contains('wan')) {
          architecture = 'wan';
          if (name.contains('t2v')) {
            videoType = 't2v';
          } else if (name.contains('i2v')) {
            videoType = 'i2v';
          } else if (name.contains('vace')) {
            videoType = 'vace';
          }
        } else if (name.contains('hunyuan') && name.contains('video')) {
          architecture = 'hunyuan';
          videoType = 't2v';
        } else if (name.contains('ltx')) {
          architecture = 'ltx';
          videoType = 't2v';
        } else if (name.contains('mochi')) {
          architecture = 'mochi';
          videoType = 't2v';
        } else if (name.contains('svd') || name.contains('stable_video')) {
          architecture = 'svd';
          videoType = 'i2v';
        }

        if (videoType != null) {
          videoModels.add({
            'name': model,
            'type': videoType,
            'architecture': architecture,
            'display_name': model.replaceAll('.safetensors', '').replaceAll('.gguf', ''),
          });
        }
      }

      return videoModels;
    } catch (e) {
      print('Error getting video models: $e');
      return [];
    }
  }
}

/// OneTrainer Proxy - Training backend communication
class OneTrainerProxy {
  final String baseUrl;
  final Dio _dio;
  WebSocketChannel? _ws;
  final _trainingState = <String, dynamic>{
    'is_training': false,
    'status': 'idle',
    'progress': null,
  };
  final _stateController = StreamController<Map<String, dynamic>>.broadcast();

  OneTrainerProxy(this.baseUrl) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;
  Map<String, dynamic> get currentState => Map.from(_trainingState);

  Future<bool> testConnection() async {
    try {
      final resp = await _dio.get('/health');
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> connectWebSocket() async {
    if (_ws != null) return;
    try {
      final wsUrl = baseUrl.replaceFirst('http', 'ws') + '/ws';
      _ws = WebSocketChannel.connect(Uri.parse(wsUrl));
      _ws!.stream.listen(
        (data) {
          if (data is String) {
            try {
              final msg = jsonDecode(data) as Map<String, dynamic>;
              _handleTrainingMessage(msg);
            } catch (e) {
              print('Training WS parse error: $e');
            }
          }
        },
        onError: (e) {
          print('Training WS error: $e');
          _ws = null;
        },
        onDone: () {
          print('Training WS closed');
          _ws = null;
        },
      );
      print('Connected to OneTrainer WebSocket');
    } catch (e) {
      print('Failed to connect to OneTrainer WebSocket: $e');
    }
  }

  void _handleTrainingMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    final data = msg['data'] as Map<String, dynamic>? ?? msg;

    switch (type) {
      case 'connected':
        _trainingState.addAll(data);
        break;
      case 'status':
        _trainingState['status'] = data['status'];
        _trainingState['is_training'] = data['is_training'] ?? _trainingState['is_training'];
        break;
      case 'progress':
        _trainingState['progress'] = data;
        _trainingState['is_training'] = true;
        break;
      case 'sample':
        _trainingState['latest_sample'] = data;
        break;
      case 'error':
        _trainingState['error'] = data['message'] ?? data['error'];
        break;
      case 'complete':
        _trainingState['is_training'] = false;
        _trainingState['status'] = 'completed';
        break;
      default:
        _trainingState.addAll(data);
    }

    _stateController.add(Map.from(_trainingState));
    print('Training state updated: ${_trainingState['status']}');
  }

  Future<void> disconnect() async {
    await _ws?.sink.close();
    _ws = null;
    await _stateController.close();
  }

  // Training Control APIs
  Future<Map<String, dynamic>> startTraining(String configPath, {String? secretsPath}) async {
    try {
      final resp = await _dio.post('/api/training/start', data: {
        'config_path': configPath,
        if (secretsPath != null) 'secrets_path': secretsPath,
      });
      _trainingState['is_training'] = true;
      _trainingState['status'] = 'starting';
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> stopTraining() async {
    try {
      final resp = await _dio.post('/api/training/stop');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final resp = await _dio.get('/api/training/status');
      final data = resp.data as Map<String, dynamic>;
      _trainingState['is_training'] = data['is_training'] ?? false;
      _trainingState['status'] = data['status'] ?? 'unknown';
      return data;
    } catch (e) {
      return {'is_training': false, 'status': 'disconnected', 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> getProgress() async {
    try {
      final resp = await _dio.get('/api/training/progress');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> triggerSample() async {
    try {
      final resp = await _dio.post('/api/training/sample');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> triggerBackup() async {
    try {
      final resp = await _dio.post('/api/training/backup');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> triggerSave() async {
    try {
      final resp = await _dio.post('/api/training/save');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  // Config APIs
  Future<Map<String, dynamic>> listPresets({String? configDir}) async {
    try {
      final resp = await _dio.get('/api/config/presets', queryParameters: {
        if (configDir != null) 'config_dir': configDir,
      });
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'presets': [], 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> loadPreset(String name, {String? configDir}) async {
    try {
      final resp = await _dio.get('/api/config/presets/$name', queryParameters: {
        if (configDir != null) 'config_dir': configDir,
      });
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> savePreset(String name, Map<String, dynamic> config, {String? configDir}) async {
    try {
      final resp = await _dio.post('/api/config/presets/$name',
        data: {'config': config},
        queryParameters: {if (configDir != null) 'config_dir': configDir},
      );
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> saveTempConfig(Map<String, dynamic> config) async {
    try {
      final resp = await _dio.post('/api/config/save-temp', data: {'config': config});
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> validateConfig(Map<String, dynamic> config) async {
    try {
      final resp = await _dio.post('/api/config/validate', data: {'config': config});
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'valid': false, 'errors': [_extractError(e)]};
    }
  }

  // System APIs
  Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final resp = await _dio.get('/api/system/info');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> listBaseModels() async {
    try {
      final resp = await _dio.get('/api/system/models');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'models': [], 'error': _extractError(e)};
    }
  }

  // Concepts API
  Future<Map<String, dynamic>> listConcepts() async {
    try {
      final resp = await _dio.get('/api/concepts');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'concepts': [], 'error': _extractError(e)};
    }
  }

  // Samples API
  Future<Map<String, dynamic>> listSamples() async {
    try {
      final resp = await _dio.get('/api/samples');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'samples': [], 'error': _extractError(e)};
    }
  }

  // TensorBoard API
  Future<Map<String, dynamic>> getTensorBoardStatus() async {
    try {
      final resp = await _dio.get('/api/tensorboard/status');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'running': false, 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> startTensorBoard({String? logDir}) async {
    try {
      final resp = await _dio.post('/api/tensorboard/start', data: {
        if (logDir != null) 'log_dir': logDir,
      });
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  // Filesystem API (for browsing datasets, models)
  Future<Map<String, dynamic>> browse(String path) async {
    try {
      final resp = await _dio.get('/api/filesystem/browse', queryParameters: {'path': path});
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'entries': [], 'error': _extractError(e)};
    }
  }

  // Caption API
  Future<Map<String, dynamic>> autoCaptionDataset(String datasetPath, {String? model}) async {
    try {
      final resp = await _dio.post('/api/caption/auto', data: {
        'dataset_path': datasetPath,
        if (model != null) 'model': model,
      });
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  // Queue API
  Future<Map<String, dynamic>> getQueue() async {
    try {
      final resp = await _dio.get('/api/queue');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'queue': [], 'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> addToQueue(Map<String, dynamic> job) async {
    try {
      final resp = await _dio.post('/api/queue/add', data: job);
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': _extractError(e)};
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) return data['detail'] ?? data['error'] ?? e.message ?? 'Unknown error';
      return e.message ?? 'Connection error';
    }
    return e.toString();
  }
}

class EriUIApi {
  final ComfyUIProxy comfy;
  final OneTrainerProxy trainer;
  final String outputDir;
  final String workflowDir;
  final _sessions = <String, Map<String, dynamic>>{};
  final _results = <String, Map<String, dynamic>>{};

  EriUIApi(this.comfy, this.trainer, {
    this.outputDir = '/home/alex/eriui/output',
    this.workflowDir = '/home/alex/eriui/workflows',
  });

  Handler get router => (Request request) async {
    final path = request.url.path;
    try {
      Map<String, dynamic> body = {};
      if (request.method == 'POST' || request.method == 'PUT') {
        final str = await request.readAsString();
        if (str.isNotEmpty) body = jsonDecode(str) as Map<String, dynamic>;
      }

      // ============ INFERENCE ENDPOINTS ============
      if (path.endsWith('GetNewSession')) return _json(await _getNewSession());
      if (path.endsWith('GetServerInfo') || path.endsWith('GetSystemStatus')) return _json(await _getSystemStatus());
      if (path.endsWith('ListModels') || path.endsWith('ListT2IModels')) return _json(await _listModels(body));
      if (path.endsWith('ListSamplers')) return _json({'samplers': await comfy.getSamplers()});
      if (path.endsWith('ListSchedulers')) return _json({'schedulers': await comfy.getSchedulers()});
      if (path.endsWith('ListLoras')) return _json(await _listLorasWithPreviews());
      if (path.endsWith('ListDiffusionModels')) return _json(await _listDiffusionModels());
      if (path.endsWith('ListVideoModels')) return _json(await _listVideoModels());
      if (path.endsWith('ListVAEs')) return _json(await _listVAEs());
      if (path.endsWith('GenerateText2Image') || path.endsWith('GenerateText2ImageWS')) return _json(await _generate(body));
      if (path.endsWith('GetProgress')) return _json(_getProgress(body));
      if (path.endsWith('GetImage')) return await _getImage(body, request);
      if (path.endsWith('InterruptGeneration')) { await comfy.interrupt(); return _json({'success': true}); }
      if (path.contains('GetModelPreview')) return await _getModelPreview(request);
      if (path.contains('ViewSpecial')) return await _proxySwarmPreview(request);
      if (path.endsWith('ListImages') || path.endsWith('ListHistory')) return _json(await _listHistory(body));
      if (path.endsWith('GetHistoryImage')) return await _getHistoryImage(request);

      // ============ TRAINING ENDPOINTS ============
      // Training Control
      if (path.contains('/training/start')) return _json(await trainer.startTraining(
        body['config_path'] as String? ?? '', secretsPath: body['secrets_path'] as String?));
      if (path.contains('/training/stop')) return _json(await trainer.stopTraining());
      if (path.contains('/training/status')) return _json(await trainer.getStatus());
      if (path.contains('/training/progress')) return _json(await trainer.getProgress());
      if (path.contains('/training/sample')) return _json(await trainer.triggerSample());
      if (path.contains('/training/backup')) return _json(await trainer.triggerBackup());
      if (path.contains('/training/save')) return _json(await trainer.triggerSave());
      if (path.contains('/training/state')) return _json(trainer.currentState);

      // Config Management
      if (path.contains('/config/presets') && request.method == 'GET') {
        final name = _extractPathParam(path, 'presets');
        if (name != null) return _json(await trainer.loadPreset(name));
        return _json(await trainer.listPresets());
      }
      if (path.contains('/config/presets') && request.method == 'POST') {
        final name = _extractPathParam(path, 'presets');
        if (name != null) return _json(await trainer.savePreset(name, body['config'] ?? body));
        return _json({'error': 'Preset name required'}, 400);
      }
      if (path.contains('/config/save-temp')) return _json(await trainer.saveTempConfig(body['config'] ?? body));
      if (path.contains('/config/validate')) return _json(await trainer.validateConfig(body['config'] ?? body));
      if (path.contains('/config/current') && request.method == 'GET') {
        // Return cached config or fetch from trainer
        return _json({'config': trainer.currentState['config'] ?? {}});
      }

      // System Info (training-specific)
      if (path.contains('/system/info')) return _json(await trainer.getSystemInfo());
      if (path.contains('/system/models') && path.contains('training')) return _json(await trainer.listBaseModels());

      // Concepts
      if (path.contains('/concepts')) return _json(await trainer.listConcepts());

      // Samples (training samples, not inference)
      if (path.contains('/training/samples') || path.contains('/samples/list')) return _json(await trainer.listSamples());

      // TensorBoard
      if (path.contains('/tensorboard/status')) return _json(await trainer.getTensorBoardStatus());
      if (path.contains('/tensorboard/start')) return _json(await trainer.startTensorBoard(logDir: body['log_dir'] as String?));

      // Filesystem browsing
      if (path.contains('/filesystem/browse')) {
        final browsePath = request.url.queryParameters['path'] ?? body['path'] as String? ?? '/';
        return _json(await trainer.browse(browsePath));
      }

      // Caption
      if (path.contains('/caption/auto')) return _json(await trainer.autoCaptionDataset(
        body['dataset_path'] as String? ?? '', model: body['model'] as String?));

      // Queue
      if (path.contains('/queue') && request.method == 'GET') return _json(await trainer.getQueue());
      if (path.contains('/queue/add')) return _json(await trainer.addToQueue(body));

      // Trainer connection status
      if (path.contains('/trainer/status') || path.contains('/trainer/health')) {
        final connected = await trainer.testConnection();
        return _json({'connected': connected, 'state': trainer.currentState});
      }

      // ============ WORKFLOW ENDPOINTS ============
      // List all workflows
      if (path.endsWith('/workflows') && request.method == 'GET') {
        return _json(await _listWorkflows());
      }
      // Read specific workflow
      if (path.contains('/workflows/') && request.method == 'GET' && !path.endsWith('/workflows/execute')) {
        final name = _extractPathParam(path, 'workflows');
        if (name != null) return _json(await _readWorkflow(name));
      }
      // Save workflow
      if (path.contains('/workflows/') && request.method == 'POST' && !path.endsWith('/workflows/execute')) {
        final name = _extractPathParam(path, 'workflows');
        if (name != null) return _json(await _saveWorkflow(name, body));
        return _json({'error': 'Workflow name required'}, 400);
      }
      // Delete workflow
      if (path.contains('/workflows/') && request.method == 'DELETE') {
        final name = _extractPathParam(path, 'workflows');
        if (name != null) return _json(await _deleteWorkflow(name));
        return _json({'error': 'Workflow name required'}, 400);
      }
      // Execute workflow with template filling
      if (path.endsWith('/workflows/execute') && request.method == 'POST') {
        return _json(await _executeWorkflow(body));
      }
      // Get workflow preview image
      if (path.contains('/workflows/preview/')) {
        final name = _extractPathParam(path, 'preview');
        if (name != null) return await _getWorkflowPreview(name);
      }

      // Root path - return unified server info
      if (path.isEmpty || path == '/' || path == 'api' || path == 'API') {
        final trainerConnected = await trainer.testConnection();
        final comfyConnected = await comfy.testConnection();
        return _json({
          'name': 'EriUI',
          'version': '0.1.0',
          'status': 'running',
          'backends': {
            'comfyui': {'connected': comfyConnected, 'url': comfy.baseUrl},
            'onetrainer': {'connected': trainerConnected, 'url': trainer.baseUrl},
          }
        });
      }

      return _json({'error': 'Unknown: $path'}, 404);
    } catch (e) {
      print('API error: $e');
      return _json({'error': e.toString()}, 500);
    }
  };

  String? _extractPathParam(String path, String after) {
    final parts = path.split('/');
    final idx = parts.indexOf(after);
    if (idx >= 0 && idx < parts.length - 1) {
      final param = parts[idx + 1];
      if (param.isNotEmpty && !param.contains('?')) return param;
    }
    return null;
  }

  Future<Map<String, dynamic>> _getNewSession() async {
    final id = const Uuid().v4();
    _sessions[id] = {'created': DateTime.now().toIso8601String(), 'permissions': ['user', 'generate']};
    return {'session_id': id, 'permissions': ['user', 'generate']};
  }

  Future<Map<String, dynamic>> _listModels(Map<String, dynamic> body) async {
    final subtype = (body['model_type'] as String? ?? body['subtype'] as String? ?? 'Stable-Diffusion').toLowerCase();

    // Route to appropriate model type
    switch (subtype) {
      case 'lora':
      case 'loras':
        return await _listLorasWithPreviews();
      case 'vae':
      case 'vaes':
        return await _listVAEs();
      case 'clip':
      case 'clips':
      case 'text_encoder':
      case 'text_encoders':
        return await _listCLIPs();
      case 'embedding':
      case 'embeddings':
        return await _listEmbeddings();
      case 'controlnet':
      case 'controlnets':
        return await _listControlNets();
      default:
        // Stable-Diffusion / checkpoints / diffusion_models
        return await _listCheckpoints();
    }
  }

  Future<Map<String, dynamic>> _listCheckpoints() async {
    List<Map<String, dynamic>> allFiles = [];

    // Regular checkpoints
    final checkpoints = await comfy.getModels();
    allFiles.addAll(checkpoints.map((m) => {
      'name': m,
      'path': m,
      'type': 'checkpoint',
      'title': m.replaceAll('.safetensors', '').replaceAll('.ckpt', ''),
      'preview_image': '/API/GetModelPreview?model=${Uri.encodeComponent(m)}&type=Stable-Diffusion',
    }));

    // Diffusion models (z_image/Lumina2)
    final diffModels = await comfy.getDiffusionModels();
    for (final m in diffModels) {
      // Only add z_image models (Lumina2 compatible)
      if (m.contains('z_image')) {
        allFiles.add({
          'name': m,
          'path': m,
          'type': 'diffusion_model',
          'title': '[Lumina2] ${m.replaceAll('.safetensors', '')}',
          'preview_image': '/API/GetModelPreview?model=${Uri.encodeComponent(m)}&type=diffusion_models',
        });
      }
    }

    return {
      'files': allFiles,
      'models': allFiles,
    };
  }

  Future<Map<String, dynamic>> _listLorasWithPreviews() async {
    try {
      final resp = await comfy._dio.get('/object_info/LoraLoader');
      final data = resp.data as Map<String, dynamic>;
      final input = data['LoraLoader']?['input']?['required']?['lora_name'];
      if (input is List && input.isNotEmpty && input[0] is List) {
        final loras = (input[0] as List).map((e) => e.toString()).toList();
        final files = loras.map((l) => {
          'name': l,
          'path': l,
          'type': 'lora',
          'title': l.replaceAll('.safetensors', ''),
          'preview_image': '/API/GetModelPreview?model=${Uri.encodeComponent(l)}&type=Lora',
        }).toList();
        return {'files': files, 'loras': files};
      }
    } catch (e) {
      print('Error getting loras: $e');
    }
    return {'files': [], 'loras': []};
  }

  Future<Map<String, dynamic>> _listCLIPs() async {
    final clips = await comfy.getCLIPs();
    final files = clips.map((c) => {
      'name': c,
      'path': c,
      'type': 'clip',
      'title': c.replaceAll('.safetensors', ''),
      'preview_image': '/API/GetModelPreview?model=${Uri.encodeComponent(c)}&type=clip',
    }).toList();
    return {'files': files};
  }

  Future<Map<String, dynamic>> _listEmbeddings() async {
    try {
      final resp = await comfy._dio.get('/embeddings');
      if (resp.data is List) {
        final embeddings = (resp.data as List).map((e) => e.toString()).toList();
        final files = embeddings.map((e) => {
          'name': e,
          'path': e,
          'type': 'embedding',
          'title': e.replaceAll('.pt', '').replaceAll('.safetensors', ''),
        }).toList();
        return {'files': files};
      }
    } catch (e) {
      print('Error getting embeddings: $e');
    }
    return {'files': []};
  }

  Future<Map<String, dynamic>> _listControlNets() async {
    try {
      final resp = await comfy._dio.get('/object_info/ControlNetLoader');
      final data = resp.data as Map<String, dynamic>;
      final input = data['ControlNetLoader']?['input']?['required']?['control_net_name'];
      if (input is List && input.isNotEmpty && input[0] is List) {
        final controlnets = (input[0] as List).map((e) => e.toString()).toList();
        final files = controlnets.map((c) => {
          'name': c,
          'path': c,
          'type': 'controlnet',
          'title': c.replaceAll('.safetensors', ''),
          'preview_image': '/API/GetModelPreview?model=${Uri.encodeComponent(c)}&type=ControlNet',
        }).toList();
        return {'files': files};
      }
    } catch (e) {
      print('Error getting controlnets: $e');
    }
    return {'files': []};
  }

  Future<Map<String, dynamic>> _listDiffusionModels() async {
    final models = await comfy.getDiffusionModels();
    final files = models.map((m) => {
      'name': m,
      'path': m,
      'type': 'diffusion_model',
      'title': m.replaceAll('.safetensors', ''),
    }).toList();
    return {'files': files};
  }

  Future<Map<String, dynamic>> _listVAEs() async {
    final vaes = await comfy.getVAEs();
    final files = vaes.map((v) => {
      'name': v,
      'path': v,
      'type': 'vae',
      'title': v.replaceAll('.safetensors', ''),
      'preview_image': '/API/GetModelPreview?model=${Uri.encodeComponent(v)}&type=VAE',
    }).toList();
    return {'files': files};
  }

  /// List video models (t2v, i2v) from diffusion_models folder
  Future<Map<String, dynamic>> _listVideoModels() async {
    final videoModels = await comfy.getVideoModels();
    return {
      'files': videoModels,
      'models': videoModels,
      't2v': videoModels.where((m) => m['type'] == 't2v').toList(),
      'i2v': videoModels.where((m) => m['type'] == 'i2v').toList(),
    };
  }

  /// List image history from EriUI output folder
  Future<Map<String, dynamic>> _listHistory(Map<String, dynamic> body) async {
    final path = body['path'] as String? ?? '';
    final depth = body['depth'] as int? ?? 5;
    final maxImages = body['max'] as int? ?? 100;

    // EriUI output folder (standalone - no SwarmUI dependency)
    final outputDirectory = Directory(outputDir);
    if (!await outputDirectory.exists()) {
      // Create output directory if it doesn't exist
      await outputDirectory.create(recursive: true);
      return {'files': [], 'folders': []};
    }

    final files = <Map<String, dynamic>>[];
    final folders = <String>{};

    await _scanOutputFolder(outputDirectory, '', depth, files, folders, maxImages);

    // Sort by date descending (newest first)
    files.sort((a, b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));

    return {
      'files': files.take(maxImages).toList(),
      'folders': folders.toList()..sort((a, b) => b.compareTo(a)),
    };
  }

  Future<void> _scanOutputFolder(Directory dir, String relativePath, int depth,
      List<Map<String, dynamic>> files, Set<String> folders, int maxFiles) async {
    if (depth <= 0 || files.length >= maxFiles) return;

    try {
      await for (final entity in dir.list()) {
        if (files.length >= maxFiles) break;

        final name = entity.path.split('/').last;
        final entityRelPath = relativePath.isEmpty ? name : '$relativePath/$name';

        if (entity is Directory) {
          // Skip hidden folders and preview folders
          if (name.startsWith('.') || name == 'Starred') continue;
          folders.add(entityRelPath);
          await _scanOutputFolder(entity, entityRelPath, depth - 1, files, folders, maxFiles);
        } else if (entity is File) {
          // Only include image files
          final ext = name.toLowerCase().split('.').last;
          if (!['png', 'jpg', 'jpeg', 'webp'].contains(ext)) continue;
          if (name.contains('.swarmpreview.')) continue;

          final stat = await entity.stat();
          final metadata = await _extractImageMetadata(entity.path);

          files.add({
            'src': entityRelPath,
            'name': name,
            'path': entityRelPath,
            'url': '/API/GetHistoryImage?path=${Uri.encodeComponent(entityRelPath)}',
            'date': stat.modified.toIso8601String(),
            'size': stat.size,
            'metadata': metadata,
          });
        }
      }
    } catch (e) {
      print('Error scanning $dir: $e');
    }
  }

  /// Extract metadata from PNG image (embedded in "parameters" text chunk)
  Future<Map<String, dynamic>?> _extractImageMetadata(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      // First try to read .swarm.json sidecar file
      final jsonPath = imagePath.replaceAll(RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false), '.swarm.json');
      final jsonFile = File(jsonPath);
      if (await jsonFile.exists()) {
        final jsonContent = await jsonFile.readAsString();
        try {
          final parsed = jsonDecode(jsonContent);
          if (parsed is Map<String, dynamic>) {
            return parsed;
          }
        } catch (_) {}
      }

      // For PNG files, try to read embedded metadata from PNG text chunk
      if (imagePath.toLowerCase().endsWith('.png')) {
        final bytes = await file.readAsBytes();
        final metadata = _extractPngTextChunk(bytes, 'parameters');
        if (metadata != null && metadata.isNotEmpty) {
          try {
            // Try parsing as JSON
            final parsed = jsonDecode(metadata);
            if (parsed is Map<String, dynamic>) {
              return parsed;
            }
          } catch (_) {
            // Return raw metadata string
            return {'raw_parameters': metadata};
          }
        }
      }

      return null;
    } catch (e) {
      print('Error extracting metadata from $imagePath: $e');
      return null;
    }
  }

  /// Extract text chunk from PNG file
  String? _extractPngTextChunk(List<int> bytes, String keyword) {
    try {
      // PNG signature: 137 80 78 71 13 10 26 10
      if (bytes.length < 8) return null;

      int offset = 8; // Skip PNG signature

      while (offset < bytes.length - 12) {
        // Read chunk length (big endian)
        final length = (bytes[offset] << 24) | (bytes[offset + 1] << 16) |
                       (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += 4;

        // Read chunk type
        final type = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        offset += 4;

        if (type == 'tEXt' || type == 'iTXt') {
          final data = bytes.sublist(offset, offset + length);
          // Find null separator between keyword and value
          final nullIndex = data.indexOf(0);
          if (nullIndex > 0) {
            final key = String.fromCharCodes(data.sublist(0, nullIndex));
            if (key.toLowerCase() == keyword.toLowerCase()) {
              // For iTXt, skip compression flag, method, language, and translated keyword
              int valueStart = nullIndex + 1;
              if (type == 'iTXt' && valueStart < data.length) {
                // Skip compression flag and method
                valueStart += 2;
                // Skip language tag (null terminated)
                while (valueStart < data.length && data[valueStart] != 0) valueStart++;
                valueStart++; // Skip null
                // Skip translated keyword (null terminated)
                while (valueStart < data.length && data[valueStart] != 0) valueStart++;
                valueStart++; // Skip null
              }
              if (valueStart < data.length) {
                return String.fromCharCodes(data.sublist(valueStart));
              }
            }
          }
        }

        offset += length + 4; // Skip chunk data and CRC

        if (type == 'IEND') break;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Serve history image
  Future<Response> _getHistoryImage(Request request) async {
    final path = request.url.queryParameters['path'] ?? '';
    if (path.isEmpty) {
      return Response.notFound('Missing path parameter');
    }

    // Prevent directory traversal
    if (path.contains('..')) {
      return Response.forbidden('Invalid path');
    }

    // Use EriUI output directory (standalone - no SwarmUI dependency)
    final imagePath = '$outputDir/$path';
    final file = File(imagePath);

    if (!await file.exists()) {
      return Response.notFound('Image not found');
    }

    final bytes = await file.readAsBytes();
    final ext = path.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };

    return Response.ok(bytes, headers: {'Content-Type': contentType});
  }

  Map<String, dynamic> _getProgress(Map<String, dynamic> body) {
    final promptId = body['prompt_id'] as String? ?? body['generation_id'] as String? ?? '';
    final progress = comfy.getProgress(promptId);
    if (progress != null) {
      return progress;
    }
    return {'status': 'unknown'};
  }

  Future<Map<String, dynamic>> _generate(Map<String, dynamic> body) async {
    print('Generate request body: $body');
    final modelRaw = body['model'];
    final model = (modelRaw is String) ? modelRaw : '';
    if (model.isEmpty) {
      print('ERROR: No model selected');
      return {'success': false, 'error': 'No model selected'};
    }

    // Detect generation mode: video or image
    final isVideoMode = body['video_mode'] == true ||
        body['frames'] != null ||
        model.contains('t2v') ||
        model.contains('i2v') ||
        model.contains('wan2') ||
        model.contains('hunyuan') && model.contains('video') ||
        model.contains('ltx') ||
        model.contains('mochi') ||
        model.contains('svd');

    // Detect if this is a diffusion_model (UNET-only) vs checkpoint
    final modelType = body['model_type'] as String? ??
        (model.contains('z_image') || model.contains('turbo') ? 'diffusion_model' : 'checkpoint');
    print('Using model: $model (type: $modelType, video: $isVideoMode)');

    // Parse LoRAs from request
    List<Map<String, dynamic>>? loras;
    final lorasRaw = body['loras'];
    if (lorasRaw is List) {
      loras = lorasRaw.map((l) => l as Map<String, dynamic>).toList();
      print('Using ${loras.length} LoRAs');
    }

    // Start generation async and return immediately
    final actualSeed = body['seed'] as int? ?? -1;
    final seed = actualSeed < 0 ? Random().nextInt(1 << 32) : actualSeed;

    // Queue the prompt and get prompt_id immediately
    await comfy.connectWebSocket();

    Map<String, dynamic> workflow;
    final isLTX2 = model.toLowerCase().contains('ltx');

    if (isVideoMode && isLTX2) {
      // Build LTX-2 video workflow
      final loraModel = loras?.isNotEmpty == true ? loras!.first['name'] as String? : null;
      final loraStrength = loras?.isNotEmpty == true ? (loras!.first['strength'] as num?)?.toDouble() ?? 1.0 : 1.0;
      workflow = comfy._buildLTX2Workflow(
        prompt: body['prompt'] as String? ?? '',
        negativePrompt: body['negativeprompt'] as String? ?? body['negative_prompt'] as String? ?? '',
        model: model,
        width: body['width'] as int? ?? 768,
        height: body['height'] as int? ?? 512,
        frames: body['frames'] as int? ?? 121,
        steps: body['steps'] as int? ?? 20,
        cfg: (body['cfgscale'] as num?)?.toDouble() ?? (body['cfg'] as num?)?.toDouble() ?? 3.0,
        seed: seed,
        loraModel: loraModel,
        loraStrength: loraStrength,
      );
      print('Built LTX-2 workflow with ${workflow.length} nodes');
    } else if (isVideoMode) {
      // Build Wan/other video workflow
      workflow = comfy._buildVideoWorkflow(
        prompt: body['prompt'] as String? ?? '',
        negativePrompt: body['negativeprompt'] as String? ?? body['negative_prompt'] as String? ?? '',
        model: model,
        width: body['width'] as int? ?? 848,
        height: body['height'] as int? ?? 480,
        frames: body['frames'] as int? ?? 81,
        steps: body['steps'] as int? ?? 20,
        cfg: (body['cfgscale'] as num?)?.toDouble() ?? (body['cfg'] as num?)?.toDouble() ?? 6.0,
        seed: seed,
        sampler: body['sampler'] as String? ?? 'uni_pc',
        scheduler: body['scheduler'] as String? ?? 'normal',
        fps: body['fps'] as int? ?? 24,
        loras: loras,
        clipModel: body['clip_model'] as String?,
        vaeModel: body['vae_model'] as String?,
        videoFormat: body['video_format'] as String? ?? body['format'] as String? ?? 'webp',
        isI2V: model.contains('i2v'),
        initImage: body['init_image'] as String?,
        // Explicit dual-model for Wan
        explicitHighNoise: body['high_noise_model'] as String?,
        explicitLowNoise: body['low_noise_model'] as String?,
      );
      print('Built video workflow with ${workflow.length} nodes');
    } else {
      // Build image workflow
      workflow = comfy._buildWorkflow(
        prompt: body['prompt'] as String? ?? '',
        negativePrompt: body['negativeprompt'] as String? ?? '',
        model: model,
        width: body['width'] as int? ?? 1024,
        height: body['height'] as int? ?? 1024,
        steps: body['steps'] as int? ?? 20,
        cfg: (body['cfgscale'] as num?)?.toDouble() ?? 7.0,
        seed: seed,
        sampler: body['sampler'] as String? ?? 'euler',
        scheduler: body['scheduler'] as String? ?? 'normal',
        loras: loras,
        modelType: modelType,
      );
    }

    final resp = await comfy._dio.post('/prompt', data: {'prompt': workflow, 'client_id': comfy.clientId});
    if (resp.statusCode != 200) return {'success': false, 'error': 'Failed to queue'};

    final promptId = (resp.data as Map<String, dynamic>)['prompt_id'] as String;

    // Initialize progress tracking
    comfy._progress[promptId] = {
      'step': 0,
      'total': body['steps'] ?? 20,
      'status': 'queued',
      'seed': seed,
      'is_video': isVideoMode,
    };

    // Run completion handler in background (don't await)
    _waitForCompletion(promptId, seed, isVideo: isVideoMode);

    // Return immediately with prompt_id
    return {
      'success': true,
      'generation_id': promptId,
      'seed': seed,
      'status': 'generating',
      'is_video': isVideoMode,
    };
  }

  /// Background handler that waits for generation to complete and stores results
  Future<void> _waitForCompletion(String promptId, int seed, {bool isVideo = false}) async {
    final completer = Completer<Map<String, dynamic>>();
    comfy._completions[promptId] = completer;

    try {
      final result = await completer.future.timeout(const Duration(minutes: 10),
        onTimeout: () => {'success': false, 'error': 'Timeout'});

      if (result['success'] == true) {
        await Future.delayed(const Duration(milliseconds: 500));
        final history = await comfy._dio.get('/history/$promptId');
        final historyData = history.data as Map<String, dynamic>?;
        final outputs = historyData?[promptId]?['outputs'] as Map<String, dynamic>?;
        final images = <String>[];
        if (outputs != null) {
          for (final nodeOut in outputs.values) {
            if (nodeOut is Map && nodeOut['images'] != null) {
              for (final img in nodeOut['images'] as List) {
                images.add('/API/GetImage?filename=${img['filename']}&subfolder=${img['subfolder'] ?? ''}&type=${img['type'] ?? 'output'}');
              }
            }
          }
        }
        // Store completed result
        _results[promptId] = {'images': images, 'seed': seed};
        comfy._progress[promptId] = {'status': 'completed', 'images': images, 'seed': seed};
        print('Generation $promptId completed with ${images.length} images');
      } else {
        comfy._progress[promptId] = {'status': 'error', 'error': result['error'] ?? 'Unknown error'};
      }
    } catch (e) {
      comfy._progress[promptId] = {'status': 'error', 'error': e.toString()};
      comfy._completions.remove(promptId);
    }
  }

  Future<Response> _getImage(Map<String, dynamic> body, Request request) async {
    final filename = body['filename'] as String? ?? request.url.queryParameters['filename'] ?? '';
    final subfolder = body['subfolder'] as String? ?? request.url.queryParameters['subfolder'] ?? '';
    final type = body['type'] as String? ?? request.url.queryParameters['type'] ?? 'output';
    final data = await comfy.getImage(filename, subfolder: subfolder, type: type);
    final ct = filename.endsWith('.jpg') || filename.endsWith('.jpeg') ? 'image/jpeg' : 'image/png';
    return Response.ok(data, headers: {'Content-Type': ct});
  }

  Future<Map<String, dynamic>> _getSystemStatus() async {
    try {
      if (await comfy.testConnection()) {
        return {'connected': true, 'backend': 'ComfyUI', 'stats': await comfy.getSystemStats()};
      }
    } catch (e) {}
    return {'connected': false};
  }

  /// Get model preview image - returns placeholder (standalone mode)
  /// TODO: Future - generate previews from ComfyUI or store locally
  Future<Response> _getModelPreview(Request request) async {
    final modelName = request.url.queryParameters['model'] ?? '';
    final modelType = request.url.queryParameters['type'] ?? 'Stable-Diffusion';

    // Check for local preview image first
    final previewPath = '$outputDir/previews/${modelType.toLowerCase()}/${modelName.replaceAll('.safetensors', '.jpg')}';
    final previewFile = File(previewPath);
    if (await previewFile.exists()) {
      final bytes = await previewFile.readAsBytes();
      return Response.ok(bytes, headers: {'Content-Type': 'image/jpeg'});
    }

    // Return styled placeholder SVG (standalone - no SwarmUI dependency)
    final displayName = modelName.replaceAll('.safetensors', '').replaceAll('.ckpt', '');
    final shortName = displayName.length > 12 ? '${displayName.substring(0, 12)}...' : displayName;
    final placeholder = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <rect fill="#1a1a2e" width="100" height="100"/>
      <rect fill="#2a2a4e" x="10" y="10" width="80" height="80" rx="8"/>
      <text x="50" y="45" text-anchor="middle" fill="#8888aa" font-size="10" font-family="sans-serif">$shortName</text>
      <text x="50" y="62" text-anchor="middle" fill="#555577" font-size="8" font-family="sans-serif">$modelType</text>
    </svg>''';
    return Response.ok(placeholder, headers: {'Content-Type': 'image/svg+xml'});
  }

  /// ViewSpecial endpoint - returns placeholder (standalone mode)
  Future<Response> _proxySwarmPreview(Request request) async {
    // Standalone mode - return placeholder instead of proxying to SwarmUI
    const placeholder = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <rect fill="#1a1a2e" width="100" height="100"/>
      <text x="50" y="55" text-anchor="middle" fill="#555577" font-size="10">Preview</text>
    </svg>''';
    return Response.ok(placeholder, headers: {'Content-Type': 'image/svg+xml'});
  }

  // ============ WORKFLOW MANAGEMENT ============

  /// List all available workflows
  Future<Map<String, dynamic>> _listWorkflows() async {
    final workflows = <Map<String, dynamic>>[];

    // Scan examples directory
    final examplesDir = Directory('$workflowDir/examples');
    if (await examplesDir.exists()) {
      await for (final file in examplesDir.list()) {
        if (file is File && file.path.endsWith('.json')) {
          final wf = await _loadWorkflowMeta(file, isExample: true);
          if (wf != null) workflows.add(wf);
        }
      }
    }

    // Scan custom directory
    final customDir = Directory('$workflowDir/custom');
    if (await customDir.exists()) {
      await for (final file in customDir.list()) {
        if (file is File && file.path.endsWith('.json')) {
          final wf = await _loadWorkflowMeta(file, isExample: false);
          if (wf != null) workflows.add(wf);
        }
      }
    }

    // Sort by name
    workflows.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return {'workflows': workflows};
  }

  /// Load workflow metadata (without full prompt data)
  Future<Map<String, dynamic>?> _loadWorkflowMeta(File file, {required bool isExample}) async {
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final name = file.path.split('/').last.replaceAll('.json', '');

      return {
        'name': data['name'] ?? name,
        'filename': name,
        'description': data['description'] ?? '',
        'tags': data['tags'] ?? [],
        'preview_image': data['preview_image'],
        'is_example': isExample,
        'enable_in_generate': data['enable_in_generate'] ?? true,
        'modified': (await file.stat()).modified.toIso8601String(),
      };
    } catch (e) {
      print('Error loading workflow ${file.path}: $e');
      return null;
    }
  }

  /// Read full workflow data
  Future<Map<String, dynamic>> _readWorkflow(String name) async {
    // Sanitize name to prevent path traversal
    final safeName = name.replaceAll(RegExp(r'[/\\.]'), '_');

    // Try custom first, then examples
    var file = File('$workflowDir/custom/$safeName.json');
    if (!await file.exists()) {
      file = File('$workflowDir/examples/$safeName.json');
    }

    if (!await file.exists()) {
      return {'error': 'Workflow not found: $name'};
    }

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return {'workflow': data};
    } catch (e) {
      return {'error': 'Failed to read workflow: $e'};
    }
  }

  /// Save workflow to custom directory
  Future<Map<String, dynamic>> _saveWorkflow(String name, Map<String, dynamic> body) async {
    // Sanitize name
    final safeName = name.replaceAll(RegExp(r'[/\\]'), '_').replaceAll('..', '_');
    if (safeName.isEmpty) return {'error': 'Invalid workflow name'};

    // Ensure custom directory exists
    final customDir = Directory('$workflowDir/custom');
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }

    final file = File('$workflowDir/custom/$safeName.json');

    try {
      // Add metadata
      final workflow = Map<String, dynamic>.from(body);
      workflow['name'] = workflow['name'] ?? safeName;
      workflow['modified'] = DateTime.now().toIso8601String();
      if (workflow['created'] == null) {
        workflow['created'] = workflow['modified'];
      }

      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(workflow));
      return {'success': true, 'name': safeName};
    } catch (e) {
      return {'error': 'Failed to save workflow: $e'};
    }
  }

  /// Delete workflow from custom directory (cannot delete examples)
  Future<Map<String, dynamic>> _deleteWorkflow(String name) async {
    final safeName = name.replaceAll(RegExp(r'[/\\]'), '_').replaceAll('..', '_');

    final file = File('$workflowDir/custom/$safeName.json');
    if (!await file.exists()) {
      return {'error': 'Workflow not found or is an example (cannot delete)'};
    }

    try {
      await file.delete();
      return {'success': true};
    } catch (e) {
      return {'error': 'Failed to delete workflow: $e'};
    }
  }

  /// Execute workflow with template filling
  Future<Map<String, dynamic>> _executeWorkflow(Map<String, dynamic> body) async {
    final workflowName = body['workflow'] as String?;
    var prompt = body['prompt'] as Map<String, dynamic>?;
    final params = body['params'] as Map<String, dynamic>? ?? body;

    // Load workflow if name provided
    if (workflowName != null && prompt == null) {
      final wfData = await _readWorkflow(workflowName);
      if (wfData.containsKey('error')) return wfData;
      final workflow = wfData['workflow'] as Map<String, dynamic>;
      prompt = workflow['prompt'] as Map<String, dynamic>?;
    }

    if (prompt == null) {
      return {'error': 'No workflow prompt provided'};
    }

    // Fill template tags
    final filledPrompt = _fillWorkflowTemplate(prompt, params);

    // Execute via ComfyUI
    await comfy.connectWebSocket();
    final resp = await comfy._dio.post('/prompt', data: {
      'prompt': filledPrompt,
      'client_id': comfy.clientId,
    });

    if (resp.statusCode != 200) {
      return {'success': false, 'error': 'Failed to queue workflow'};
    }

    final promptId = (resp.data as Map<String, dynamic>)['prompt_id'] as String;

    // Initialize progress tracking
    comfy._progress[promptId] = {
      'step': 0,
      'total': params['steps'] ?? 20,
      'status': 'queued',
      'seed': params['seed'] ?? -1,
    };

    // Run completion handler in background
    _waitForCompletion(promptId, params['seed'] as int? ?? -1);

    return {
      'success': true,
      'generation_id': promptId,
      'status': 'generating',
    };
  }

  /// Fill ${tag:default} templates in workflow
  Map<String, dynamic> _fillWorkflowTemplate(Map<String, dynamic> prompt, Map<String, dynamic> params) {
    var json = jsonEncode(prompt);

    // Pattern: ${tag} or ${tag:default}
    final pattern = RegExp(r'\$\{([^}:]+)(?::([^}]*))?\}');

    json = json.replaceAllMapped(pattern, (match) {
      final tag = match.group(1)!;
      final defaultValue = match.group(2) ?? '';

      // Normalize tag names (negative_prompt -> negativeprompt)
      final normalizedTag = tag.replaceAll('_', '').toLowerCase();

      // Try exact match, then normalized
      dynamic value = params[tag] ?? params[normalizedTag];

      // Common tag mappings
      value ??= switch (tag) {
        'prompt' => params['prompt'] ?? params['positive_prompt'] ?? defaultValue,
        'negative_prompt' || 'negativeprompt' => params['negative_prompt'] ?? params['negativeprompt'] ?? defaultValue,
        'seed' => params['seed'] ?? -1,
        'steps' => params['steps'] ?? int.tryParse(defaultValue) ?? 20,
        'cfg' || 'cfg_scale' || 'cfgscale' => params['cfg'] ?? params['cfgscale'] ?? params['cfg_scale'] ?? double.tryParse(defaultValue) ?? 7.0,
        'width' => params['width'] ?? int.tryParse(defaultValue) ?? 1024,
        'height' => params['height'] ?? int.tryParse(defaultValue) ?? 1024,
        'sampler' || 'sampler_name' => params['sampler'] ?? defaultValue,
        'scheduler' => params['scheduler'] ?? defaultValue,
        'model' || 'ckpt_name' => params['model'] ?? defaultValue,
        'denoise' => params['denoise'] ?? double.tryParse(defaultValue) ?? 1.0,
        _ => defaultValue,
      };

      // Handle random seed
      if ((tag == 'seed' || tag.contains('seed')) && (value == -1 || value == '-1')) {
        value = Random().nextInt(1 << 32);
      }

      // Format value for JSON
      if (value is String) {
        // Escape quotes and backslashes for JSON string
        return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      }
      return value.toString();
    });

    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// Get workflow preview image
  Future<Response> _getWorkflowPreview(String name) async {
    final safeName = name.replaceAll(RegExp(r'[/\\.]'), '_');

    // Try custom first, then examples
    var file = File('$workflowDir/custom/$safeName.json');
    if (!await file.exists()) {
      file = File('$workflowDir/examples/$safeName.json');
    }

    if (!await file.exists()) {
      return _workflowPlaceholderSvg(name);
    }

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final previewImage = data['preview_image'] as String?;

      if (previewImage != null && previewImage.isNotEmpty) {
        // Base64 encoded image
        if (previewImage.startsWith('data:image/')) {
          final parts = previewImage.split(',');
          if (parts.length == 2) {
            final mimeType = parts[0].split(':')[1].split(';')[0];
            final bytes = base64Decode(parts[1]);
            return Response.ok(bytes, headers: {'Content-Type': mimeType});
          }
        }
        // File path
        final imageFile = File(previewImage);
        if (await imageFile.exists()) {
          final bytes = await imageFile.readAsBytes();
          final ext = previewImage.split('.').last.toLowerCase();
          final mimeType = switch (ext) {
            'png' => 'image/png',
            'jpg' || 'jpeg' => 'image/jpeg',
            'webp' => 'image/webp',
            _ => 'application/octet-stream',
          };
          return Response.ok(bytes, headers: {'Content-Type': mimeType});
        }
      }
    } catch (e) {
      print('Error loading workflow preview: $e');
    }

    return _workflowPlaceholderSvg(name);
  }

  /// Generate placeholder SVG for workflow
  Response _workflowPlaceholderSvg(String name) {
    final shortName = name.length > 15 ? '${name.substring(0, 15)}...' : name;
    final placeholder = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80">
      <rect fill="#1e1e2e" width="120" height="80" rx="6"/>
      <rect fill="#2a2a4e" x="8" y="8" width="104" height="64" rx="4"/>
      <circle cx="25" cy="28" r="8" fill="#4a4a6e"/>
      <circle cx="60" cy="28" r="8" fill="#5a5a8e"/>
      <circle cx="95" cy="28" r="8" fill="#4a4a6e"/>
      <line x1="33" y1="28" x2="52" y2="28" stroke="#6a6a9e" stroke-width="2"/>
      <line x1="68" y1="28" x2="87" y2="28" stroke="#6a6a9e" stroke-width="2"/>
      <text x="60" y="58" text-anchor="middle" fill="#8888aa" font-size="9" font-family="sans-serif">$shortName</text>
    </svg>''';
    return Response.ok(placeholder, headers: {'Content-Type': 'image/svg+xml'});
  }

  Response _json(Map<String, dynamic> data, [int status = 200]) =>
    Response(status, body: jsonEncode(data), headers: {'Content-Type': 'application/json'});
}
