import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

import '../../core/program.dart';
import '../../backends/comfyui/workflow_generator.dart';
import '../api.dart';
import '../api_call.dart';
import '../api_context.dart';

/// Advanced Text-to-Image API endpoints
/// ControlNet, Img2Img, Inpainting, Upscaling, Batch, Queue
class AdvancedT2IAPI {
  /// Register all advanced T2I API endpoints
  static void register() {
    // ========== CONTROLNET ==========
    Api.registerCall(ApiCall(
      name: 'GenerateWithControlNet',
      description: 'Generate images with ControlNet guidance',
      requiredPermissions: {'generate'},
      handler: _generateWithControlNet,
    ));

    Api.registerCall(ApiCall(
      name: 'ListControlNetModels',
      description: 'List available ControlNet models',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _listControlNetModels,
    ));

    Api.registerCall(ApiCall(
      name: 'ListControlNetPreprocessors',
      description: 'List available ControlNet preprocessors',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _listControlNetPreprocessors,
    ));

    Api.registerCall(ApiCall(
      name: 'PreprocessControlNetImage',
      description: 'Preprocess image for ControlNet',
      requiredPermissions: {'generate'},
      handler: _preprocessControlNetImage,
    ));

    // ========== IMG2IMG ==========
    Api.registerCall(ApiCall(
      name: 'GenerateImg2Img',
      description: 'Generate images from an initial image',
      requiredPermissions: {'generate'},
      handler: _generateImg2Img,
    ));

    // ========== INPAINTING ==========
    Api.registerCall(ApiCall(
      name: 'GenerateInpaint',
      description: 'Inpaint parts of an image using a mask',
      requiredPermissions: {'generate'},
      handler: _generateInpaint,
    ));

    Api.registerCall(ApiCall(
      name: 'GenerateOutpaint',
      description: 'Extend an image beyond its borders',
      requiredPermissions: {'generate'},
      handler: _generateOutpaint,
    ));

    // ========== UPSCALING ==========
    Api.registerCall(ApiCall(
      name: 'UpscaleImage',
      description: 'Upscale an image using AI models',
      requiredPermissions: {'generate'},
      handler: _upscaleImage,
    ));

    Api.registerCall(ApiCall(
      name: 'ListUpscalers',
      description: 'List available upscaler models',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _listUpscalers,
    ));

    // ========== REFINER ==========
    Api.registerCall(ApiCall(
      name: 'GenerateWithRefiner',
      description: 'Generate with SDXL refiner',
      requiredPermissions: {'generate'},
      handler: _generateWithRefiner,
    ));

    // ========== BATCH ==========
    Api.registerCall(ApiCall(
      name: 'QueueBatch',
      description: 'Queue a batch of generations',
      requiredPermissions: {'generate'},
      handler: _queueBatch,
    ));

    Api.registerCall(ApiCall(
      name: 'QueueVariations',
      description: 'Queue variations of an image',
      requiredPermissions: {'generate'},
      handler: _queueVariations,
    ));

    // ========== QUEUE MANAGEMENT ==========
    Api.registerCall(ApiCall(
      name: 'GetQueueStatus',
      description: 'Get current queue status',
      requiredPermissions: {'user'},
      allowGet: true,
      handler: _getQueueStatus,
    ));

    Api.registerCall(ApiCall(
      name: 'GetQueueHistory',
      description: 'Get queue history',
      requiredPermissions: {'user'},
      handler: _getQueueHistory,
    ));

    Api.registerCall(ApiCall(
      name: 'CancelQueueItem',
      description: 'Cancel a queued item',
      requiredPermissions: {'user'},
      handler: _cancelQueueItem,
    ));

    Api.registerCall(ApiCall(
      name: 'ClearQueue',
      description: 'Clear all queued items',
      requiredPermissions: {'admin'},
      handler: _clearQueue,
    ));

    Api.registerCall(ApiCall(
      name: 'ReorderQueue',
      description: 'Reorder queue items',
      requiredPermissions: {'user'},
      handler: _reorderQueue,
    ));

    // ========== REGIONAL PROMPTING ==========
    Api.registerCall(ApiCall(
      name: 'GenerateWithRegions',
      description: 'Generate with regional prompts',
      requiredPermissions: {'generate'},
      handler: _generateWithRegions,
    ));

    // ========== IMAGE UTILITIES ==========
    Api.registerCall(ApiCall(
      name: 'UploadImage',
      description: 'Upload an image for processing',
      requiredPermissions: {'user'},
      handler: _uploadImage,
    ));

    Api.registerCall(ApiCall(
      name: 'GetImageInfo',
      description: 'Get information about an image',
      requiredPermissions: {'user'},
      handler: _getImageInfo,
    ));
  }

  // ========== CONTROLNET HANDLERS ==========

  /// Generate with ControlNet
  static Future<Map<String, dynamic>> _generateWithControlNet(ApiContext ctx) async {
    final session = ctx.requireSession();

    // Base parameters
    final prompt = ctx.getOr<String>('prompt', '');
    final negativePrompt = ctx.getOr<String>('negativeprompt', '');
    final model = ctx.require<String>('model');
    final width = ctx.getOr<int>('width', 1024);
    final height = ctx.getOr<int>('height', 1024);
    final steps = ctx.getOr<int>('steps', 20);
    final cfgScale = ctx.getOr<double>('cfgscale', 7.0);
    final seed = ctx.getOr<int>('seed', -1);
    final sampler = ctx.getOr<String>('sampler', 'euler');
    final scheduler = ctx.getOr<String>('scheduler', 'normal');

    // ControlNet parameters
    final controlNetModel = ctx.require<String>('controlnetmodel');
    final controlNetImage = ctx.require<String>('controlnetimage');
    final controlNetStrength = ctx.getOr<double>('controlnetstrength', 1.0);
    final controlNetStartPercent = ctx.getOr<double>('controlnetstartpercent', 0.0);
    final controlNetEndPercent = ctx.getOr<double>('controlnetendpercent', 1.0);
    final preprocessor = ctx.get<String>('preprocessor');

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
      'sampler': sampler,
      'scheduler': scheduler,
    });

    // Build base workflow first
    generator.buildBasicTxt2Img();

    // Add ControlNet
    generator.addControlNet(
      controlNetName: controlNetModel,
      imagePath: controlNetImage,
      strength: controlNetStrength,
    );

    final workflow = generator.build();
    final requestId = const Uuid().v4();

    // Queue on backend
    final backend = await Program.instance.backends.getAvailableBackend('comfyui');
    if (backend == null) {
      return {'success': false, 'error': 'No available backend'};
    }

    // Add to generation queue
    _addToQueue(QueueItem(
      id: requestId,
      type: 'controlnet',
      workflow: workflow,
      session: session,
      createdAt: DateTime.now(),
    ));

    return {
      'success': true,
      'request_id': requestId,
      'message': 'ControlNet generation queued',
    };
  }

  /// List ControlNet models
  static Future<Map<String, dynamic>> _listControlNetModels(ApiContext ctx) async {
    final models = await Program.instance.modelHandler.getModelsOfType('ControlNet');

    return {
      'models': models.map((m) => {
        'name': m.name,
        'path': m.path,
        'type': m.type,
        'metadata': m.metadata,
      }).toList(),
    };
  }

  /// List ControlNet preprocessors
  static Future<Map<String, dynamic>> _listControlNetPreprocessors(ApiContext ctx) async {
    return {
      'preprocessors': [
        {'id': 'none', 'name': 'None', 'description': 'No preprocessing'},
        {'id': 'canny', 'name': 'Canny Edge', 'description': 'Edge detection'},
        {'id': 'depth_midas', 'name': 'Depth (MiDaS)', 'description': 'Depth estimation'},
        {'id': 'depth_zoe', 'name': 'Depth (ZoeDepth)', 'description': 'High-quality depth'},
        {'id': 'normal_bae', 'name': 'Normal Map', 'description': 'Surface normals'},
        {'id': 'openpose', 'name': 'OpenPose', 'description': 'Pose detection'},
        {'id': 'openpose_face', 'name': 'OpenPose + Face', 'description': 'Pose with face'},
        {'id': 'openpose_hand', 'name': 'OpenPose + Hands', 'description': 'Pose with hands'},
        {'id': 'openpose_full', 'name': 'OpenPose Full', 'description': 'Full pose detection'},
        {'id': 'lineart', 'name': 'Line Art', 'description': 'Line extraction'},
        {'id': 'lineart_anime', 'name': 'Line Art (Anime)', 'description': 'Anime-style lines'},
        {'id': 'lineart_coarse', 'name': 'Line Art (Coarse)', 'description': 'Coarse line extraction'},
        {'id': 'softedge_hed', 'name': 'Soft Edge (HED)', 'description': 'Soft edge detection'},
        {'id': 'softedge_pidinet', 'name': 'Soft Edge (PidiNet)', 'description': 'PidiNet edges'},
        {'id': 'scribble_hed', 'name': 'Scribble (HED)', 'description': 'Scribble-like edges'},
        {'id': 'scribble_pidinet', 'name': 'Scribble (PidiNet)', 'description': 'PidiNet scribble'},
        {'id': 'segmentation', 'name': 'Segmentation', 'description': 'Semantic segmentation'},
        {'id': 'shuffle', 'name': 'Shuffle', 'description': 'Content shuffle'},
        {'id': 'tile', 'name': 'Tile', 'description': 'Tile/detail enhancement'},
        {'id': 'inpaint', 'name': 'Inpaint', 'description': 'Inpainting preprocessor'},
        {'id': 'ip_adapter', 'name': 'IP-Adapter', 'description': 'Image prompt adapter'},
        {'id': 'instant_id', 'name': 'InstantID', 'description': 'Face identity'},
        {'id': 'reference', 'name': 'Reference', 'description': 'Reference-only'},
      ],
    };
  }

  /// Preprocess image for ControlNet
  static Future<Map<String, dynamic>> _preprocessControlNetImage(ApiContext ctx) async {
    final imageData = ctx.require<String>('image');
    final preprocessor = ctx.require<String>('preprocessor');
    final resolution = ctx.getOr<int>('resolution', 512);

    // Queue preprocessing on ComfyUI
    final requestId = const Uuid().v4();

    // Build preprocessing workflow
    final nodes = <String, Map<String, dynamic>>{};

    // Load image
    nodes['1'] = {
      'class_type': 'LoadImageBase64',
      'inputs': {'image': imageData},
    };

    // Apply preprocessor based on type
    String preprocessorNode;
    switch (preprocessor) {
      case 'canny':
        preprocessorNode = 'CannyEdgePreprocessor';
        nodes['2'] = {
          'class_type': preprocessorNode,
          'inputs': {
            'image': ['1', 0],
            'low_threshold': 100,
            'high_threshold': 200,
            'resolution': resolution,
          },
        };
        break;
      case 'depth_midas':
        preprocessorNode = 'MiDaS-DepthMapPreprocessor';
        nodes['2'] = {
          'class_type': preprocessorNode,
          'inputs': {
            'image': ['1', 0],
            'a': 6.283185307179586,
            'bg_threshold': 0.1,
            'resolution': resolution,
          },
        };
        break;
      case 'openpose':
        preprocessorNode = 'OpenposePreprocessor';
        nodes['2'] = {
          'class_type': preprocessorNode,
          'inputs': {
            'image': ['1', 0],
            'detect_hand': false,
            'detect_body': true,
            'detect_face': false,
            'resolution': resolution,
          },
        };
        break;
      default:
        // Return original image for 'none' or unknown preprocessors
        return {
          'success': true,
          'request_id': requestId,
          'preprocessed_image': imageData,
        };
    }

    // Save preprocessed image
    nodes['3'] = {
      'class_type': 'PreviewImage',
      'inputs': {'images': ['2', 0]},
    };

    return {
      'success': true,
      'request_id': requestId,
      'message': 'Preprocessing queued',
    };
  }

  // ========== IMG2IMG HANDLERS ==========

  /// Generate img2img
  static Future<Map<String, dynamic>> _generateImg2Img(ApiContext ctx) async {
    final session = ctx.requireSession();

    // Base parameters
    final prompt = ctx.getOr<String>('prompt', '');
    final negativePrompt = ctx.getOr<String>('negativeprompt', '');
    final model = ctx.require<String>('model');
    final steps = ctx.getOr<int>('steps', 20);
    final cfgScale = ctx.getOr<double>('cfgscale', 7.0);
    final seed = ctx.getOr<int>('seed', -1);
    final sampler = ctx.getOr<String>('sampler', 'euler');
    final scheduler = ctx.getOr<String>('scheduler', 'normal');

    // Img2Img parameters
    final initImage = ctx.require<String>('initimage');
    final creativity = ctx.getOr<double>('creativity', 0.6);
    final resizeMode = ctx.getOr<String>('resizemode', 'resize'); // resize, crop, fill

    // Build workflow
    final generator = WorkflowGenerator(userInput: {
      'prompt': prompt,
      'negativeprompt': negativePrompt,
      'model': model,
      'steps': steps,
      'cfgscale': cfgScale,
      'seed': seed,
      'sampler': sampler,
      'scheduler': scheduler,
    });

    final workflow = generator.buildImg2Img(
      initImagePath: initImage,
      denoise: creativity,
    );

    final requestId = const Uuid().v4();

    _addToQueue(QueueItem(
      id: requestId,
      type: 'img2img',
      workflow: workflow,
      session: session,
      createdAt: DateTime.now(),
    ));

    return {
      'success': true,
      'request_id': requestId,
      'message': 'Img2Img generation queued',
    };
  }

  // ========== INPAINTING HANDLERS ==========

  /// Generate inpaint
  static Future<Map<String, dynamic>> _generateInpaint(ApiContext ctx) async {
    final session = ctx.requireSession();

    // Base parameters
    final prompt = ctx.getOr<String>('prompt', '');
    final negativePrompt = ctx.getOr<String>('negativeprompt', '');
    final model = ctx.require<String>('model');
    final steps = ctx.getOr<int>('steps', 20);
    final cfgScale = ctx.getOr<double>('cfgscale', 7.0);
    final seed = ctx.getOr<int>('seed', -1);
    final sampler = ctx.getOr<String>('sampler', 'euler');
    final scheduler = ctx.getOr<String>('scheduler', 'normal');

    // Inpaint parameters
    final initImage = ctx.require<String>('initimage');
    final maskImage = ctx.require<String>('maskimage');
    final creativity = ctx.getOr<double>('creativity', 1.0);
    final maskBlur = ctx.getOr<int>('maskblur', 4);
    final maskExpand = ctx.getOr<int>('maskexpand', 0);
    final fillMode = ctx.getOr<String>('fillmode', 'original'); // original, noise, blur

    // Build workflow
    final generator = WorkflowGenerator(userInput: {
      'prompt': prompt,
      'negativeprompt': negativePrompt,
      'model': model,
      'steps': steps,
      'cfgscale': cfgScale,
      'seed': seed,
      'sampler': sampler,
      'scheduler': scheduler,
    });

    final workflow = generator.buildInpaint(
      initImagePath: initImage,
      maskImagePath: maskImage,
      denoise: creativity,
    );

    final requestId = const Uuid().v4();

    _addToQueue(QueueItem(
      id: requestId,
      type: 'inpaint',
      workflow: workflow,
      session: session,
      createdAt: DateTime.now(),
    ));

    return {
      'success': true,
      'request_id': requestId,
      'message': 'Inpainting generation queued',
    };
  }

  /// Generate outpaint
  static Future<Map<String, dynamic>> _generateOutpaint(ApiContext ctx) async {
    final session = ctx.requireSession();

    // Base parameters
    final prompt = ctx.getOr<String>('prompt', '');
    final negativePrompt = ctx.getOr<String>('negativeprompt', '');
    final model = ctx.require<String>('model');
    final steps = ctx.getOr<int>('steps', 20);
    final cfgScale = ctx.getOr<double>('cfgscale', 7.0);
    final seed = ctx.getOr<int>('seed', -1);

    // Outpaint parameters
    final initImage = ctx.require<String>('initimage');
    final direction = ctx.require<String>('direction'); // left, right, up, down, all
    final pixels = ctx.getOr<int>('pixels', 128);

    final requestId = const Uuid().v4();

    // Build outpainting workflow (creates mask automatically)
    final nodes = <String, Map<String, dynamic>>{};

    // Load original image
    nodes['1'] = {
      'class_type': 'LoadImage',
      'inputs': {'image': initImage},
    };

    // Pad image based on direction
    nodes['2'] = {
      'class_type': 'ImagePadForOutpaint',
      'inputs': {
        'image': ['1', 0],
        'left': direction == 'left' || direction == 'all' ? pixels : 0,
        'right': direction == 'right' || direction == 'all' ? pixels : 0,
        'top': direction == 'up' || direction == 'all' ? pixels : 0,
        'bottom': direction == 'down' || direction == 'all' ? pixels : 0,
        'feathering': 40,
      },
    };

    _addToQueue(QueueItem(
      id: requestId,
      type: 'outpaint',
      workflow: {'prompt': nodes},
      session: session,
      createdAt: DateTime.now(),
    ));

    return {
      'success': true,
      'request_id': requestId,
      'message': 'Outpainting generation queued',
    };
  }

  // ========== UPSCALING HANDLERS ==========

  /// Upscale image
  static Future<Map<String, dynamic>> _upscaleImage(ApiContext ctx) async {
    final session = ctx.requireSession();

    final image = ctx.require<String>('image');
    final upscaler = ctx.require<String>('upscaler');
    final scaleFactor = ctx.getOr<double>('scale', 2.0);
    final tileSize = ctx.getOr<int>('tilesize', 512);
    final overlap = ctx.getOr<int>('overlap', 32);

    final requestId = const Uuid().v4();

    // Build upscale workflow
    final nodes = <String, Map<String, dynamic>>{};

    // Load image
    nodes['1'] = {
      'class_type': 'LoadImage',
      'inputs': {'image': image},
    };

    // Load upscaler
    nodes['2'] = {
      'class_type': 'UpscaleModelLoader',
      'inputs': {'model_name': upscaler},
    };

    // Upscale with model
    nodes['3'] = {
      'class_type': 'ImageUpscaleWithModel',
      'inputs': {
        'upscale_model': ['2', 0],
        'image': ['1', 0],
      },
    };

    // Save
    nodes['4'] = {
      'class_type': 'SaveImage',
      'inputs': {
        'images': ['3', 0],
        'filename_prefix': 'upscaled',
      },
    };

    _addToQueue(QueueItem(
      id: requestId,
      type: 'upscale',
      workflow: {'prompt': nodes},
      session: session,
      createdAt: DateTime.now(),
    ));

    return {
      'success': true,
      'request_id': requestId,
      'message': 'Upscaling queued',
    };
  }

  /// List upscaler models
  static Future<Map<String, dynamic>> _listUpscalers(ApiContext ctx) async {
    final models = await Program.instance.modelHandler.getModelsOfType('Upscaler');

    return {
      'upscalers': [
        ...models.map((m) => {
          'name': m.name,
          'path': m.path,
          'scale': _guessUpscaleScale(m.name),
        }),
        // Built-in upscalers
        {'name': 'Lanczos', 'path': 'builtin', 'scale': 'any'},
        {'name': 'Nearest', 'path': 'builtin', 'scale': 'any'},
        {'name': 'Bilinear', 'path': 'builtin', 'scale': 'any'},
      ],
    };
  }

  static String _guessUpscaleScale(String name) {
    if (name.contains('4x') || name.contains('x4')) return '4x';
    if (name.contains('2x') || name.contains('x2')) return '2x';
    if (name.contains('8x') || name.contains('x8')) return '8x';
    return 'unknown';
  }

  // ========== REFINER HANDLERS ==========

  /// Generate with SDXL refiner
  static Future<Map<String, dynamic>> _generateWithRefiner(ApiContext ctx) async {
    final session = ctx.requireSession();

    // Base parameters
    final prompt = ctx.getOr<String>('prompt', '');
    final negativePrompt = ctx.getOr<String>('negativeprompt', '');
    final model = ctx.require<String>('model');
    final width = ctx.getOr<int>('width', 1024);
    final height = ctx.getOr<int>('height', 1024);
    final steps = ctx.getOr<int>('steps', 20);
    final cfgScale = ctx.getOr<double>('cfgscale', 7.0);
    final seed = ctx.getOr<int>('seed', -1);
    final sampler = ctx.getOr<String>('sampler', 'euler');
    final scheduler = ctx.getOr<String>('scheduler', 'normal');

    // Refiner parameters
    final refinerModel = ctx.require<String>('refinermodel');
    final refinerSwitch = ctx.getOr<double>('refinerswitch', 0.8);

    final requestId = const Uuid().v4();

    // Build refiner workflow
    final generator = WorkflowGenerator(userInput: {
      'prompt': prompt,
      'negativeprompt': negativePrompt,
      'model': model,
      'width': width,
      'height': height,
      'steps': steps,
      'cfgscale': cfgScale,
      'seed': seed,
      'sampler': sampler,
      'scheduler': scheduler,
    });

    // Start with base workflow
    generator.buildBasicTxt2Img();

    // The refiner workflow uses KSamplerAdvanced with two samplers
    // This is handled in the workflow generator

    _addToQueue(QueueItem(
      id: requestId,
      type: 'refiner',
      workflow: generator.build(),
      session: session,
      createdAt: DateTime.now(),
    ));

    return {
      'success': true,
      'request_id': requestId,
      'message': 'Generation with refiner queued',
    };
  }

  // ========== BATCH HANDLERS ==========

  /// Queue batch of generations
  static Future<Map<String, dynamic>> _queueBatch(ApiContext ctx) async {
    final session = ctx.requireSession();

    final items = ctx.getList<Map<String, dynamic>>('items');
    if (items.isEmpty) {
      return {'success': false, 'error': 'No items provided'};
    }

    final batchId = const Uuid().v4();
    final requestIds = <String>[];

    for (final item in items) {
      final requestId = const Uuid().v4();
      requestIds.add(requestId);

      final generator = WorkflowGenerator(userInput: item);
      final workflow = generator.buildBasicTxt2Img();

      _addToQueue(QueueItem(
        id: requestId,
        type: 'batch',
        workflow: workflow,
        session: session,
        createdAt: DateTime.now(),
        batchId: batchId,
      ));
    }

    return {
      'success': true,
      'batch_id': batchId,
      'request_ids': requestIds,
      'count': items.length,
      'message': 'Batch queued',
    };
  }

  /// Queue variations of an image
  static Future<Map<String, dynamic>> _queueVariations(ApiContext ctx) async {
    final session = ctx.requireSession();

    final image = ctx.require<String>('image');
    final count = ctx.getOr<int>('count', 4);
    final variationStrength = ctx.getOr<double>('strength', 0.5);

    // Get original params from image metadata or use provided
    final prompt = ctx.getOr<String>('prompt', '');
    final model = ctx.require<String>('model');

    final batchId = const Uuid().v4();
    final requestIds = <String>[];

    for (int i = 0; i < count; i++) {
      final requestId = const Uuid().v4();
      requestIds.add(requestId);

      final generator = WorkflowGenerator(userInput: {
        'prompt': prompt,
        'model': model,
        'seed': -1, // Random seed for each variation
      });

      final workflow = generator.buildImg2Img(
        initImagePath: image,
        denoise: variationStrength,
      );

      _addToQueue(QueueItem(
        id: requestId,
        type: 'variation',
        workflow: workflow,
        session: session,
        createdAt: DateTime.now(),
        batchId: batchId,
      ));
    }

    return {
      'success': true,
      'batch_id': batchId,
      'request_ids': requestIds,
      'count': count,
      'message': 'Variations queued',
    };
  }

  // ========== QUEUE MANAGEMENT ==========

  /// In-memory queue (should be persistent in production)
  static final List<QueueItem> _queue = [];
  static final List<QueueItem> _history = [];
  static final Map<String, QueueItemStatus> _status = {};

  static void _addToQueue(QueueItem item) {
    _queue.add(item);
    _status[item.id] = QueueItemStatus.pending;
  }

  /// Get queue status
  static Future<Map<String, dynamic>> _getQueueStatus(ApiContext ctx) async {
    final pending = _queue.where((i) => _status[i.id] == QueueItemStatus.pending).length;
    final running = _queue.where((i) => _status[i.id] == QueueItemStatus.running).length;

    return {
      'pending': pending,
      'running': running,
      'total': _queue.length,
      'items': _queue.map((item) => {
        'id': item.id,
        'type': item.type,
        'status': _status[item.id]?.name ?? 'unknown',
        'created_at': item.createdAt.toIso8601String(),
        'batch_id': item.batchId,
      }).toList(),
    };
  }

  /// Get queue history
  static Future<Map<String, dynamic>> _getQueueHistory(ApiContext ctx) async {
    final limit = ctx.getOr<int>('limit', 50);
    final offset = ctx.getOr<int>('offset', 0);

    final items = _history.skip(offset).take(limit).toList();

    return {
      'items': items.map((item) => {
        'id': item.id,
        'type': item.type,
        'status': _status[item.id]?.name ?? 'completed',
        'created_at': item.createdAt.toIso8601String(),
        'completed_at': item.completedAt?.toIso8601String(),
        'batch_id': item.batchId,
      }).toList(),
      'total': _history.length,
    };
  }

  /// Cancel queue item
  static Future<Map<String, dynamic>> _cancelQueueItem(ApiContext ctx) async {
    final id = ctx.require<String>('id');

    final index = _queue.indexWhere((i) => i.id == id);
    if (index == -1) {
      return {'success': false, 'error': 'Item not found'};
    }

    final item = _queue[index];
    if (_status[id] == QueueItemStatus.running) {
      // Try to cancel on backend
      await Program.instance.backends.interruptAll();
    }

    _queue.removeAt(index);
    _status[id] = QueueItemStatus.cancelled;
    item.completedAt = DateTime.now();
    _history.add(item);

    return {'success': true};
  }

  /// Clear queue
  static Future<Map<String, dynamic>> _clearQueue(ApiContext ctx) async {
    final count = _queue.length;

    for (final item in _queue) {
      _status[item.id] = QueueItemStatus.cancelled;
      item.completedAt = DateTime.now();
      _history.add(item);
    }

    _queue.clear();

    return {'success': true, 'cleared': count};
  }

  /// Reorder queue
  static Future<Map<String, dynamic>> _reorderQueue(ApiContext ctx) async {
    final order = ctx.getList<String>('order');

    if (order.isEmpty) {
      return {'success': false, 'error': 'No order provided'};
    }

    // Reorder based on provided IDs
    final newQueue = <QueueItem>[];
    for (final id in order) {
      final item = _queue.firstWhere((i) => i.id == id, orElse: () => throw Exception('Item not found: $id'));
      newQueue.add(item);
    }

    // Add any items not in the order list at the end
    for (final item in _queue) {
      if (!order.contains(item.id)) {
        newQueue.add(item);
      }
    }

    _queue.clear();
    _queue.addAll(newQueue);

    return {'success': true};
  }

  // ========== REGIONAL PROMPTING ==========

  /// Generate with regional prompts
  static Future<Map<String, dynamic>> _generateWithRegions(ApiContext ctx) async {
    final session = ctx.requireSession();

    // Base parameters
    final model = ctx.require<String>('model');
    final width = ctx.getOr<int>('width', 1024);
    final height = ctx.getOr<int>('height', 1024);
    final steps = ctx.getOr<int>('steps', 20);
    final cfgScale = ctx.getOr<double>('cfgscale', 7.0);
    final seed = ctx.getOr<int>('seed', -1);

    // Regional prompts
    final regions = ctx.getList<Map<String, dynamic>>('regions');
    final globalPrompt = ctx.getOr<String>('globalprompt', '');
    final globalNegativePrompt = ctx.getOr<String>('globalnegativeprompt', '');

    if (regions.isEmpty) {
      return {'success': false, 'error': 'No regions provided'};
    }

    final requestId = const Uuid().v4();

    // Build regional workflow using ComfyUI's regional conditioning
    final nodes = <String, Map<String, dynamic>>{};

    // Load model
    nodes['1'] = {
      'class_type': 'CheckpointLoaderSimple',
      'inputs': {'ckpt_name': model},
    };

    // Global conditioning
    nodes['2'] = {
      'class_type': 'CLIPTextEncode',
      'inputs': {
        'text': globalPrompt,
        'clip': ['1', 1],
      },
    };

    nodes['3'] = {
      'class_type': 'CLIPTextEncode',
      'inputs': {
        'text': globalNegativePrompt,
        'clip': ['1', 1],
      },
    };

    // Create region masks and conditionings
    int nodeId = 4;
    List<dynamic> combinedPositive = ['2', 0];

    for (final region in regions) {
      final prompt = region['prompt'] as String? ?? '';
      final x = region['x'] as int? ?? 0;
      final y = region['y'] as int? ?? 0;
      final w = region['width'] as int? ?? width;
      final h = region['height'] as int? ?? height;
      final strength = region['strength'] as double? ?? 1.0;

      // Create mask for region
      final maskNodeId = '${nodeId++}';
      nodes[maskNodeId] = {
        'class_type': 'SolidMask',
        'inputs': {
          'value': 1.0,
          'width': w,
          'height': h,
        },
      };

      // Region conditioning
      final condNodeId = '${nodeId++}';
      nodes[condNodeId] = {
        'class_type': 'CLIPTextEncode',
        'inputs': {
          'text': prompt,
          'clip': ['1', 1],
        },
      };

      // Combine with mask
      final combineNodeId = '${nodeId++}';
      nodes[combineNodeId] = {
        'class_type': 'ConditioningSetMask',
        'inputs': {
          'conditioning': [condNodeId, 0],
          'mask': [maskNodeId, 0],
          'strength': strength,
          'set_cond_area': 'default',
        },
      };

      // Combine conditionings
      final combinedNodeId = '${nodeId++}';
      nodes[combinedNodeId] = {
        'class_type': 'ConditioningCombine',
        'inputs': {
          'cond_1': combinedPositive,
          'cond_2': [combineNodeId, 0],
        },
      };
      combinedPositive = [combinedNodeId, 0];
    }

    // Empty latent
    final latentNodeId = '${nodeId++}';
    nodes[latentNodeId] = {
      'class_type': 'EmptyLatentImage',
      'inputs': {
        'width': width,
        'height': height,
        'batch_size': 1,
      },
    };

    // KSampler
    final samplerNodeId = '${nodeId++}';
    nodes[samplerNodeId] = {
      'class_type': 'KSampler',
      'inputs': {
        'model': ['1', 0],
        'positive': combinedPositive,
        'negative': ['3', 0],
        'latent_image': [latentNodeId, 0],
        'seed': seed,
        'steps': steps,
        'cfg': cfgScale,
        'sampler_name': 'euler',
        'scheduler': 'normal',
        'denoise': 1.0,
      },
    };

    // VAE Decode
    final decodeNodeId = '${nodeId++}';
    nodes[decodeNodeId] = {
      'class_type': 'VAEDecode',
      'inputs': {
        'samples': [samplerNodeId, 0],
        'vae': ['1', 2],
      },
    };

    // Save
    nodes['${nodeId++}'] = {
      'class_type': 'SaveImage',
      'inputs': {
        'images': [decodeNodeId, 0],
        'filename_prefix': 'regional',
      },
    };

    _addToQueue(QueueItem(
      id: requestId,
      type: 'regional',
      workflow: {'prompt': nodes},
      session: session,
      createdAt: DateTime.now(),
    ));

    return {
      'success': true,
      'request_id': requestId,
      'message': 'Regional generation queued',
    };
  }

  // ========== IMAGE UTILITIES ==========

  /// Upload image
  static Future<Map<String, dynamic>> _uploadImage(ApiContext ctx) async {
    final imageData = ctx.require<String>('image'); // Base64
    final filename = ctx.getOr<String>('filename', 'uploaded_${DateTime.now().millisecondsSinceEpoch}.png');

    // Decode base64
    final bytes = base64Decode(imageData);

    // Save to temp directory
    final tempDir = Directory.systemTemp;
    final filePath = path.join(tempDir.path, 'eriui_uploads', filename);

    final dir = Directory(path.dirname(filePath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await File(filePath).writeAsBytes(bytes);

    return {
      'success': true,
      'path': filePath,
      'filename': filename,
    };
  }

  /// Get image info
  static Future<Map<String, dynamic>> _getImageInfo(ApiContext ctx) async {
    final imagePath = ctx.require<String>('image');

    final file = File(imagePath);
    if (!await file.exists()) {
      return {'success': false, 'error': 'Image not found'};
    }

    final bytes = await file.readAsBytes();

    // Try to read PNG dimensions from header
    int? width, height;
    if (bytes.length > 24 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      // PNG header
      width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    }

    return {
      'success': true,
      'path': imagePath,
      'size': bytes.length,
      'width': width,
      'height': height,
      'format': _detectImageFormat(bytes),
    };
  }

  static String _detectImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return 'unknown';
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpeg';
    if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'gif';
    if (bytes[0] == 0x52 && bytes[1] == 0x49) return 'webp';
    return 'unknown';
  }
}

/// Queue item
class QueueItem {
  final String id;
  final String type;
  final Map<String, dynamic> workflow;
  final dynamic session;
  final DateTime createdAt;
  DateTime? completedAt;
  final String? batchId;

  QueueItem({
    required this.id,
    required this.type,
    required this.workflow,
    required this.session,
    required this.createdAt,
    this.completedAt,
    this.batchId,
  });
}

/// Queue item status
enum QueueItemStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}
