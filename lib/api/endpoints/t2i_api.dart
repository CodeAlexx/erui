import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

import '../../core/program.dart';
import '../../accounts/gen_claim.dart';
import '../../backends/comfyui/comfyui_client.dart';
import '../../backends/comfyui/comfyui_websocket.dart';
import '../../backends/comfyui/workflow_generator.dart';
import '../../utils/logging.dart';
import '../api.dart';
import '../api_call.dart';
import '../api_context.dart';

/// Text-to-Image API endpoints
class T2IAPI {
  /// ComfyUI client instance
  static ComfyUIClient? _comfyClient;
  static ComfyUIWebSocket? _comfyWs;

  /// Get or create ComfyUI client (default port 8199 = EriUI's ComfyUI)
  static ComfyUIClient get comfyClient {
    _comfyClient ??= ComfyUIClient(
      baseUrl: Program.instance.commandLineFlags['comfy_url'] ??
          'http://${Program.instance.commandLineFlags['comfy_host'] ?? 'localhost'}:${Program.instance.commandLineFlags['comfy_port'] ?? '8199'}',
    );
    return _comfyClient!;
  }

  /// Get or create ComfyUI WebSocket (default port 8199 = EriUI's ComfyUI)
  static ComfyUIWebSocket get comfyWs {
    _comfyWs ??= ComfyUIWebSocket(
      baseUrl: Program.instance.commandLineFlags['comfy_url'] ??
          'http://${Program.instance.commandLineFlags['comfy_host'] ?? 'localhost'}:${Program.instance.commandLineFlags['comfy_port'] ?? '8199'}',
    );
    return _comfyWs!;
  }

  /// Register all T2I API endpoints
  static void register() {
    Api.registerCall(ApiCall(
      name: 'GenerateText2Image',
      description: 'Generate images from text prompt',
      requiredPermissions: {'generate'},
      handler: _generateText2Image,
    ));

    Api.registerCall(ApiCall(
      name: 'GenerateText2ImageWS',
      description: 'Generate images with WebSocket progress updates',
      requiredPermissions: {'generate'},
      handler: _generateText2ImageWS,
    ));

    Api.registerCall(ApiCall(
      name: 'GetCurrentGenerationStatus',
      description: 'Get status of current generation',
      requiredPermissions: {'user'},
      handler: _getCurrentGenerationStatus,
    ));

    Api.registerCall(ApiCall(
      name: 'InterruptGeneration',
      description: 'Interrupt current generation',
      requiredPermissions: {'user'},
      handler: _interruptGeneration,
    ));

    Api.registerCall(ApiCall(
      name: 'ListSamplers',
      description: 'List available samplers',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _listSamplers,
    ));

    Api.registerCall(ApiCall(
      name: 'ListSchedulers',
      description: 'List available schedulers',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _listSchedulers,
    ));

    Api.registerCall(ApiCall(
      name: 'GetParamDefaults',
      description: 'Get default parameter values',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _getParamDefaults,
    ));

    Api.registerCall(ApiCall(
      name: 'ListT2IParams',
      description: 'List all T2I parameters',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _listT2IParams,
    ));

    Api.registerCall(ApiCall(
      name: 'GetImage',
      description: 'Get generated image by filename',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _getImage,
    ));
  }

  /// Generate images from text prompt
  static Future<Map<String, dynamic>> _generateText2Image(ApiContext ctx) async {
    final session = ctx.requireSession();

    // Get generation parameters
    final prompt = ctx.getOr<String>('prompt', '');
    final negativePrompt = ctx.getOr<String>('negativeprompt', '');
    final model = ctx.require<String>('model');
    final width = ctx.getOr<int>('width', 1024);
    final height = ctx.getOr<int>('height', 1024);
    final steps = ctx.getOr<int>('steps', 20);
    final cfgScale = ctx.getOr<double>('cfgscale', 7.0);
    final seed = ctx.getOr<int>('seed', -1);
    final images = ctx.getOr<int>('images', 1);
    final sampler = ctx.getOr<String>('sampler', 'euler');
    final scheduler = ctx.getOr<String>('scheduler', 'normal');

    // Create claim
    final claim = session.claim(gens: images);

    try {
      // Build workflow
      final generator = WorkflowGenerator(userInput: {
        'prompt': prompt,
        'negativeprompt': negativePrompt,
        'model': model,
        'width': width,
        'height': height,
        'steps': steps,
        'cfgscale': cfgScale,
        'seed': seed,
        'images': images,
        'sampler': sampler,
        'scheduler': scheduler,
      });

      final workflow = generator.buildBasicTxt2Img();

      // Ensure WebSocket is connected for progress tracking
      if (!comfyWs.isConnected) {
        await comfyWs.connect();
      }

      // Queue on ComfyUI
      final response = await comfyClient.queuePrompt(
        workflow: workflow['prompt'] as Map<String, dynamic>,
        clientId: comfyWs.clientId,
      );

      if (response.hasErrors) {
        return {
          'success': false,
          'error': 'Workflow errors: ${response.nodeErrors}',
        };
      }

      // Wait for completion
      final result = await comfyWs.waitForCompletion(
        response.promptId,
        timeout: const Duration(minutes: 10),
      );

      if (!result.success) {
        return {
          'success': false,
          'error': result.error ?? 'Generation failed',
        };
      }

      // Get output images
      final outputImages = <Map<String, dynamic>>[];
      if (result.outputs != null) {
        for (final nodeOutput in result.outputs!.values) {
          if (nodeOutput is Map && nodeOutput['images'] != null) {
            for (final img in nodeOutput['images'] as List) {
              final imgMap = img as Map<String, dynamic>;
              outputImages.add({
                'filename': imgMap['filename'],
                'subfolder': imgMap['subfolder'] ?? '',
                'type': imgMap['type'] ?? 'output',
              });
            }
          }
        }
      }

      return {
        'success': true,
        'prompt_id': response.promptId,
        'images': outputImages,
        'seed': generator.seed,
      };
    } catch (e, stack) {
      Logs.error('Generation error: $e', e, stack);
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      claim.dispose();
    }
  }

  /// Generate with WebSocket progress (returns request ID for tracking)
  static Future<Map<String, dynamic>> _generateText2ImageWS(ApiContext ctx) async {
    final session = ctx.requireSession();

    // Same parameter extraction as above
    final prompt = ctx.getOr<String>('prompt', '');
    final negativePrompt = ctx.getOr<String>('negativeprompt', '');
    final model = ctx.require<String>('model');
    final width = ctx.getOr<int>('width', 1024);
    final height = ctx.getOr<int>('height', 1024);
    final steps = ctx.getOr<int>('steps', 20);
    final cfgScale = ctx.getOr<double>('cfgscale', 7.0);
    final seed = ctx.getOr<int>('seed', -1);
    final images = ctx.getOr<int>('images', 1);
    final sampler = ctx.getOr<String>('sampler', 'euler');
    final scheduler = ctx.getOr<String>('scheduler', 'normal');

    final claim = session.claim(gens: images);

    try {
      final generator = WorkflowGenerator(userInput: {
        'prompt': prompt,
        'negativeprompt': negativePrompt,
        'model': model,
        'width': width,
        'height': height,
        'steps': steps,
        'cfgscale': cfgScale,
        'seed': seed,
        'images': images,
        'sampler': sampler,
        'scheduler': scheduler,
      });

      final workflow = generator.buildBasicTxt2Img();

      if (!comfyWs.isConnected) {
        await comfyWs.connect();
      }

      final response = await comfyClient.queuePrompt(
        workflow: workflow['prompt'] as Map<String, dynamic>,
        clientId: comfyWs.clientId,
      );

      if (response.hasErrors) {
        claim.dispose();
        return {
          'success': false,
          'error': 'Workflow errors: ${response.nodeErrors}',
        };
      }

      // Return immediately with prompt ID - client can track via WebSocket
      return {
        'success': true,
        'prompt_id': response.promptId,
        'queued': images,
        'seed': generator.seed,
        'ws_client_id': comfyWs.clientId,
      };
    } catch (e) {
      claim.dispose();
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get current generation status
  static Future<Map<String, dynamic>> _getCurrentGenerationStatus(ApiContext ctx) async {
    try {
      final queueStatus = await comfyClient.getQueueStatus();

      return {
        'queue_pending': queueStatus.queuePending,
        'queue_running': queueStatus.queueRunning,
        'connected': comfyClient.isConnected,
      };
    } catch (e) {
      return {
        'queue_pending': 0,
        'queue_running': 0,
        'connected': false,
        'error': e.toString(),
      };
    }
  }

  /// Interrupt current generation
  static Future<Map<String, dynamic>> _interruptGeneration(ApiContext ctx) async {
    try {
      await comfyClient.interrupt();
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// List available samplers
  static Future<Map<String, dynamic>> _listSamplers(ApiContext ctx) async {
    try {
      final samplers = await comfyClient.getSamplers();
      if (samplers.isNotEmpty) {
        return {'samplers': samplers};
      }
    } catch (e) {
      Logs.warning('Could not fetch samplers from ComfyUI: $e');
    }

    // Default samplers
    return {
      'samplers': [
        'euler', 'euler_ancestral', 'heun', 'heunpp2',
        'dpm_2', 'dpm_2_ancestral', 'lms', 'dpm_fast',
        'dpm_adaptive', 'dpmpp_2s_ancestral', 'dpmpp_sde',
        'dpmpp_sde_gpu', 'dpmpp_2m', 'dpmpp_2m_sde',
        'dpmpp_2m_sde_gpu', 'dpmpp_3m_sde', 'dpmpp_3m_sde_gpu',
        'ddpm', 'lcm', 'ddim', 'uni_pc', 'uni_pc_bh2',
      ]
    };
  }

  /// List available schedulers
  static Future<Map<String, dynamic>> _listSchedulers(ApiContext ctx) async {
    try {
      final schedulers = await comfyClient.getSchedulers();
      if (schedulers.isNotEmpty) {
        return {'schedulers': schedulers};
      }
    } catch (e) {
      Logs.warning('Could not fetch schedulers from ComfyUI: $e');
    }

    return {
      'schedulers': [
        'normal', 'karras', 'exponential', 'sgm_uniform',
        'simple', 'ddim_uniform', 'beta', 'ays', 'gits',
      ]
    };
  }

  /// Get default parameter values
  static Future<Map<String, dynamic>> _getParamDefaults(ApiContext ctx) async {
    return {
      'prompt': '',
      'negativeprompt': '',
      'width': 1024,
      'height': 1024,
      'steps': 20,
      'cfgscale': 7.0,
      'seed': -1,
      'images': 1,
      'sampler': 'euler',
      'scheduler': 'normal',
    };
  }

  /// List all T2I parameters
  static Future<Map<String, dynamic>> _listT2IParams(ApiContext ctx) async {
    final params = [
      {'id': 'prompt', 'name': 'Prompt', 'type': 'text', 'default': '', 'group': 'prompt'},
      {'id': 'negativeprompt', 'name': 'Negative Prompt', 'type': 'text', 'default': '', 'group': 'prompt'},
      {'id': 'model', 'name': 'Model', 'type': 'model', 'subtype': 'Stable-Diffusion', 'default': '', 'group': 'core'},
      {'id': 'images', 'name': 'Images', 'type': 'integer', 'default': 1, 'min': 1, 'max': 100, 'group': 'core'},
      {'id': 'steps', 'name': 'Steps', 'type': 'integer', 'default': 20, 'min': 1, 'max': 150, 'group': 'core'},
      {'id': 'cfgscale', 'name': 'CFG Scale', 'type': 'decimal', 'default': 7.0, 'min': 0.0, 'max': 30.0, 'group': 'core'},
      {'id': 'seed', 'name': 'Seed', 'type': 'integer', 'default': -1, 'group': 'core'},
      {'id': 'width', 'name': 'Width', 'type': 'integer', 'default': 1024, 'min': 64, 'max': 8192, 'step': 64, 'group': 'resolution'},
      {'id': 'height', 'name': 'Height', 'type': 'integer', 'default': 1024, 'min': 64, 'max': 8192, 'step': 64, 'group': 'resolution'},
      {'id': 'sampler', 'name': 'Sampler', 'type': 'dropdown', 'default': 'euler', 'group': 'sampling'},
      {'id': 'scheduler', 'name': 'Scheduler', 'type': 'dropdown', 'default': 'normal', 'group': 'sampling'},
    ];

    final groups = [
      {'id': 'prompt', 'name': 'Prompt', 'order': -100, 'open': true},
      {'id': 'core', 'name': 'Core Parameters', 'order': -50, 'open': true},
      {'id': 'resolution', 'name': 'Resolution', 'order': -40, 'open': false},
      {'id': 'sampling', 'name': 'Sampling', 'order': -30, 'open': false},
    ];

    return {'params': params, 'groups': groups};
  }

  /// Get a generated image
  static Future<Map<String, dynamic>> _getImage(ApiContext ctx) async {
    final filename = ctx.require<String>('filename');
    final subfolder = ctx.getOr<String>('subfolder', '');
    final type = ctx.getOr<String>('type', 'output');

    try {
      final imageData = await comfyClient.getImage(
        filename: filename,
        subfolder: subfolder,
        type: type,
      );

      // Return base64 encoded image
      return {
        'success': true,
        'image': base64Encode(imageData),
        'filename': filename,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
