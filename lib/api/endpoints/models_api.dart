import '../../core/program.dart';
import '../api.dart';
import '../api_call.dart';
import '../api_context.dart';

/// Models API endpoints for model management
class ModelsAPI {
  /// Register all models API endpoints
  static void register() {
    Api.registerCall(ApiCall(
      name: 'ListModels',
      description: 'List available models of a specific type',
      requiredPermissions: {'view_models'},
      allowGet: true,
      handler: _listModels,
    ));

    Api.registerCall(ApiCall(
      name: 'DescribeModel',
      description: 'Get detailed information about a model',
      requiredPermissions: {'view_models'},
      handler: _describeModel,
    ));

    Api.registerCall(ApiCall(
      name: 'ListModelTypes',
      description: 'List available model types',
      requiredPermissions: {'view_models'},
      allowGet: true,
      handler: _listModelTypes,
    ));

    Api.registerCall(ApiCall(
      name: 'RefreshModels',
      description: 'Refresh model list',
      requiredPermissions: {'view_models'},
      handler: _refreshModels,
    ));

    Api.registerCall(ApiCall(
      name: 'EditModelMetadata',
      description: 'Edit model metadata',
      requiredPermissions: {'edit_models'},
      handler: _editModelMetadata,
    ));

    Api.registerCall(ApiCall(
      name: 'DeleteModel',
      description: 'Delete a model file',
      requiredPermissions: {'delete_models'},
      handler: _deleteModel,
    ));

    Api.registerCall(ApiCall(
      name: 'ListLorasFor',
      description: 'List LoRAs compatible with a model',
      requiredPermissions: {'view_models'},
      handler: _listLorasFor,
    ));

    Api.registerCall(ApiCall(
      name: 'ListVAEsFor',
      description: 'List VAEs compatible with a model',
      requiredPermissions: {'view_models'},
      handler: _listVAEsFor,
    ));

    Api.registerCall(ApiCall(
      name: 'SelectModel',
      description: 'Select a model for generation',
      requiredPermissions: {'user'},
      handler: _selectModel,
    ));
  }

  /// List models of a specific type
  static Future<Map<String, dynamic>> _listModels(ApiContext ctx) async {
    final modelType = ctx.get<String>('type') ?? 'Stable-Diffusion';
    final path = ctx.get<String>('path') ?? '';
    final depth = ctx.get<int>('depth') ?? 1;

    final handler = Program.instance.t2iModelSets[modelType];
    if (handler == null) {
      return {
        'models': <Map<String, dynamic>>[],
        'folders': <String>[],
      };
    }

    final models = <Map<String, dynamic>>[];
    final folders = <String>{};

    for (final model in handler.models.values) {
      // Filter by path if specified
      if (path.isNotEmpty && !model.name.startsWith(path)) {
        continue;
      }

      // Track folders
      final parts = model.name.split('/');
      if (parts.length > 1) {
        for (var i = 0; i < parts.length - 1 && i < depth; i++) {
          folders.add(parts.sublist(0, i + 1).join('/'));
        }
      }

      // Only include models at the current depth
      final relativePath = path.isEmpty ? model.name : model.name.substring(path.length);
      final relParts = relativePath.split('/').where((p) => p.isNotEmpty).toList();
      if (relParts.length > depth) {
        continue;
      }

      models.add({
        'name': model.name,
        'title': model.title ?? model.name.split('/').last,
        'author': model.author,
        'description': model.description,
        'preview_image': model.previewImage,
        'model_class': model.modelClass,
        'compat_class': model.compatClass,
        'loaded': model.anyBackendsHaveLoaded,
        'metadata': model.metadata?.toJson(),
      });
    }

    return {
      'models': models,
      'folders': folders.toList()..sort(),
    };
  }

  /// Get detailed model info
  static Future<Map<String, dynamic>> _describeModel(ApiContext ctx) async {
    final modelType = ctx.require<String>('type');
    final modelName = ctx.require<String>('model');

    final handler = Program.instance.t2iModelSets[modelType];
    if (handler == null) {
      throw ApiException('Unknown model type: $modelType');
    }

    final model = handler.models[modelName];
    if (model == null) {
      throw ApiException('Model not found: $modelName');
    }

    return {
      'name': model.name,
      'type': model.type,
      'title': model.title,
      'author': model.author,
      'description': model.description,
      'preview_image': model.previewImage,
      'model_class': model.modelClass,
      'compat_class': model.compatClass,
      'file_path': model.filePath,
      'loaded': model.anyBackendsHaveLoaded,
      'metadata': model.metadata?.toJson(),
    };
  }

  /// List available model types
  static Future<Map<String, dynamic>> _listModelTypes(ApiContext ctx) async {
    final types = Program.instance.t2iModelSets.keys.toList();

    return {
      'types': types.map((type) {
        final handler = Program.instance.t2iModelSets[type]!;
        return {
          'id': type,
          'name': type,
          'count': handler.models.length,
        };
      }).toList(),
    };
  }

  /// Refresh model list
  static Future<Map<String, dynamic>> _refreshModels(ApiContext ctx) async {
    final modelType = ctx.get<String>('type');

    if (modelType != null) {
      final handler = Program.instance.t2iModelSets[modelType];
      if (handler != null) {
        await handler.refresh();
      }
    } else {
      await Program.instance.refreshAllModelSets();
    }

    return {'success': true};
  }

  /// Edit model metadata
  static Future<Map<String, dynamic>> _editModelMetadata(ApiContext ctx) async {
    final modelType = ctx.require<String>('type');
    final modelName = ctx.require<String>('model');
    final updates = ctx.getMap('metadata');

    final handler = Program.instance.t2iModelSets[modelType];
    if (handler == null) {
      throw ApiException('Unknown model type: $modelType');
    }

    final model = handler.models[modelName];
    if (model == null) {
      throw ApiException('Model not found: $modelName');
    }

    // Apply updates
    if (updates.containsKey('title')) {
      model.title = updates['title'] as String?;
    }
    if (updates.containsKey('author')) {
      model.author = updates['author'] as String?;
    }
    if (updates.containsKey('description')) {
      model.description = updates['description'] as String?;
    }

    // TODO: Save metadata to file

    return {'success': true};
  }

  /// Delete a model
  static Future<Map<String, dynamic>> _deleteModel(ApiContext ctx) async {
    final modelType = ctx.require<String>('type');
    final modelName = ctx.require<String>('model');

    final handler = Program.instance.t2iModelSets[modelType];
    if (handler == null) {
      throw ApiException('Unknown model type: $modelType');
    }

    final model = handler.models[modelName];
    if (model == null) {
      throw ApiException('Model not found: $modelName');
    }

    // TODO: Delete file and remove from handler

    return {'success': true};
  }

  /// List compatible LoRAs
  static Future<Map<String, dynamic>> _listLorasFor(ApiContext ctx) async {
    final modelName = ctx.require<String>('model');

    final sdHandler = Program.instance.t2iModelSets['Stable-Diffusion'];
    final loraHandler = Program.instance.t2iModelSets['LoRA'];

    if (sdHandler == null || loraHandler == null) {
      return {'loras': <Map<String, dynamic>>[]};
    }

    final model = sdHandler.models[modelName];
    if (model == null) {
      throw ApiException('Model not found: $modelName');
    }

    // Filter LoRAs by compatibility
    final modelClass = model.modelClass ?? '';
    final loras = loraHandler.models.values.where((lora) {
      // TODO: Implement proper compatibility checking
      return true;
    }).map((lora) => {
      'name': lora.name,
      'title': lora.title ?? lora.name,
      'preview': lora.previewImage,
    }).toList();

    return {'loras': loras};
  }

  /// List compatible VAEs
  static Future<Map<String, dynamic>> _listVAEsFor(ApiContext ctx) async {
    final modelName = ctx.require<String>('model');

    final sdHandler = Program.instance.t2iModelSets['Stable-Diffusion'];
    final vaeHandler = Program.instance.t2iModelSets['VAE'];

    if (sdHandler == null || vaeHandler == null) {
      return {'vaes': <Map<String, dynamic>>[]};
    }

    final model = sdHandler.models[modelName];
    if (model == null) {
      throw ApiException('Model not found: $modelName');
    }

    // Filter VAEs by compatibility
    final vaes = vaeHandler.models.values.map((vae) => {
      'name': vae.name,
      'title': vae.title ?? vae.name,
    }).toList();

    // Add "None" option
    vaes.insert(0, {'name': 'None', 'title': 'None (use model default)'});

    return {'vaes': vaes};
  }

  /// Select model for generation (with loading)
  static Future<Map<String, dynamic>> _selectModel(ApiContext ctx) async {
    final modelType = ctx.get<String>('type') ?? 'Stable-Diffusion';
    final modelName = ctx.require<String>('model');

    final handler = Program.instance.t2iModelSets[modelType];
    if (handler == null) {
      throw ApiException('Unknown model type: $modelType');
    }

    final model = handler.models[modelName];
    if (model == null) {
      throw ApiException('Model not found: $modelName');
    }

    // TODO: Trigger model loading on backend

    return {
      'success': true,
      'model': modelName,
      'model_class': model.modelClass,
    };
  }
}
