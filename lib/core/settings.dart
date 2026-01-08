import 'dart:io';
import '../utils/fds_parser.dart';
import '../utils/logging.dart';

/// EriUI Server Settings - complete parity with SwarmUI Settings.fds
class Settings {
  PathSettings paths = PathSettings();
  MetadataSettings metadata = MetadataSettings();
  NetworkSettings network = NetworkSettings();
  MaintenanceSettings maintenance = MaintenanceSettings();
  DefaultUserSettings defaultUser = DefaultUserSettings();
  BackendSettings backends = BackendSettings();
  UserAuthorizationSettings userAuthorization = UserAuthorizationSettings();
  LogSettings logs = LogSettings();
  UISettings ui = UISettings();
  WebHooksSettings webHooks = WebHooksSettings();
  PerformanceSettings performance = PerformanceSettings();

  bool isInstalled = false;
  String? installDate;
  String? installVersion;
  int nvidiaQueryRateLimitMS = 1000;
  String launchMode = 'web';
  bool addDebugData = false;
  bool showExperimentalFeatures = false;

  Settings();

  /// Load settings from FDS file
  factory Settings.fromFds(Map<String, dynamic> data) {
    final settings = Settings();

    // Paths
    if (data['Paths'] is Map) {
      settings.paths = PathSettings.fromFds(data['Paths'] as Map<String, dynamic>);
    }

    // Metadata
    if (data['Metadata'] is Map) {
      settings.metadata = MetadataSettings.fromFds(data['Metadata'] as Map<String, dynamic>);
    }

    // Network
    if (data['Network'] is Map) {
      settings.network = NetworkSettings.fromFds(data['Network'] as Map<String, dynamic>);
    }

    // Maintenance
    if (data['Maintenance'] is Map) {
      settings.maintenance = MaintenanceSettings.fromFds(data['Maintenance'] as Map<String, dynamic>);
    }

    // DefaultUser
    if (data['DefaultUser'] is Map) {
      settings.defaultUser = DefaultUserSettings.fromFds(data['DefaultUser'] as Map<String, dynamic>);
    }

    // Backends
    if (data['Backends'] is Map) {
      settings.backends = BackendSettings.fromFds(data['Backends'] as Map<String, dynamic>);
    }

    // UserAuthorization
    if (data['UserAuthorization'] is Map) {
      settings.userAuthorization = UserAuthorizationSettings.fromFds(data['UserAuthorization'] as Map<String, dynamic>);
    }

    // Logs
    if (data['Logs'] is Map) {
      settings.logs = LogSettings.fromFds(data['Logs'] as Map<String, dynamic>);
    }

    // UI
    if (data['UI'] is Map) {
      settings.ui = UISettings.fromFds(data['UI'] as Map<String, dynamic>);
    }

    // WebHooks
    if (data['WebHooks'] is Map) {
      settings.webHooks = WebHooksSettings.fromFds(data['WebHooks'] as Map<String, dynamic>);
    }

    // Performance
    if (data['Performance'] is Map) {
      settings.performance = PerformanceSettings.fromFds(data['Performance'] as Map<String, dynamic>);
    }

    // Top-level settings
    settings.isInstalled = data['IsInstalled'] == true || data['IsInstalled'] == 'true';
    settings.installDate = data['InstallDate']?.toString();
    settings.installVersion = data['InstallVersion']?.toString();
    settings.nvidiaQueryRateLimitMS = data['NvidiaQueryRateLimitMS'] as int? ?? 1000;
    settings.launchMode = data['LaunchMode']?.toString() ?? 'web';
    settings.addDebugData = data['AddDebugData'] == true;
    settings.showExperimentalFeatures = data['ShowExperimentalFeatures'] == true;

    return settings;
  }

  /// Convert to FDS Map for serialization
  Map<String, dynamic> toFds() {
    return {
      'Paths': paths.toFds(),
      'Metadata': metadata.toFds(),
      'Network': network.toFds(),
      'Maintenance': maintenance.toFds(),
      'DefaultUser': defaultUser.toFds(),
      'Backends': backends.toFds(),
      'UserAuthorization': userAuthorization.toFds(),
      'Logs': logs.toFds(),
      'UI': ui.toFds(),
      'WebHooks': webHooks.toFds(),
      'Performance': performance.toFds(),
      'IsInstalled': isInstalled,
      'InstallDate': installDate,
      'InstallVersion': installVersion,
      'NvidiaQueryRateLimitMS': nvidiaQueryRateLimitMS,
      'LaunchMode': launchMode,
      'AddDebugData': addDebugData,
      'ShowExperimentalFeatures': showExperimentalFeatures,
    };
  }

  /// Load settings from file
  static Future<Settings> loadFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      Logs.info('Settings file not found, using defaults: $path');
      return Settings();
    }

    try {
      final content = await file.readAsString();
      final data = FdsParser.parse(content);
      return Settings.fromFds(data);
    } catch (e) {
      Logs.error('Failed to load settings from $path: $e');
      return Settings();
    }
  }

  /// Save settings to file
  Future<void> saveToFile(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final content = FdsParser.serialize(toFds());
    await file.writeAsString(content);
  }
}

/// Path-related settings
class PathSettings {
  String modelRoot = 'Models';
  int downloadToRootID = 0;
  String sdModelFolder = 'Stable-Diffusion';
  String sdLoraFolder = 'Lora';
  String sdLycorisFolder = 'LyCORIS';
  String sdVAEFolder = 'VAE';
  String sdEmbeddingFolder = 'Embeddings';
  String sdControlNetsFolder = 'controlnet';
  String sdClipFolder = 'clip';
  String sdClipVisionFolder = 'clip_vision';
  String dataPath = 'Data';
  String outputPath = 'Output';
  String wildcardsFolder = 'Wildcards';
  bool appendUserNameToOutputPath = true;
  bool recycleDeletedImages = false;
  bool recycleDeletedModels = false;
  bool clearStrayModelData = false;
  bool editMetadataAcrossAllDups = false;
  bool downloaderAlwaysResave = false;

  PathSettings();

  factory PathSettings.fromFds(Map<String, dynamic> data) {
    final p = PathSettings();
    p.modelRoot = data['ModelRoot']?.toString() ?? 'Models';
    p.downloadToRootID = data['DownloadToRootID'] as int? ?? 0;
    p.sdModelFolder = data['SDModelFolder']?.toString() ?? 'Stable-Diffusion';
    p.sdLoraFolder = data['SDLoraFolder']?.toString() ?? 'Lora';
    p.sdLycorisFolder = data['SDLycorisFolder']?.toString() ?? 'LyCORIS';
    p.sdVAEFolder = data['SDVAEFolder']?.toString() ?? 'VAE';
    p.sdEmbeddingFolder = data['SDEmbeddingFolder']?.toString() ?? 'Embeddings';
    p.sdControlNetsFolder = data['SDControlNetsFolder']?.toString() ?? 'controlnet';
    p.sdClipFolder = data['SDClipFolder']?.toString() ?? 'clip';
    p.sdClipVisionFolder = data['SDClipVisionFolder']?.toString() ?? 'clip_vision';
    p.dataPath = data['DataPath']?.toString() ?? 'Data';
    p.outputPath = data['OutputPath']?.toString() ?? 'Output';
    p.wildcardsFolder = data['WildcardsFolder']?.toString() ?? 'Wildcards';
    p.appendUserNameToOutputPath = data['AppendUserNameToOutputPath'] != false;
    p.recycleDeletedImages = data['RecycleDeletedImages'] == true;
    p.recycleDeletedModels = data['RecycleDeletedModels'] == true;
    p.clearStrayModelData = data['ClearStrayModelData'] == true;
    p.editMetadataAcrossAllDups = data['EditMetadataAcrossAllDups'] == true;
    p.downloaderAlwaysResave = data['DownloaderAlwaysResave'] == true;
    return p;
  }

  Map<String, dynamic> toFds() {
    return {
      'ModelRoot': modelRoot,
      'DownloadToRootID': downloadToRootID,
      'SDModelFolder': sdModelFolder,
      'SDLoraFolder': sdLoraFolder,
      'SDLycorisFolder': sdLycorisFolder,
      'SDVAEFolder': sdVAEFolder,
      'SDEmbeddingFolder': sdEmbeddingFolder,
      'SDControlNetsFolder': sdControlNetsFolder,
      'SDClipFolder': sdClipFolder,
      'SDClipVisionFolder': sdClipVisionFolder,
      'DataPath': dataPath,
      'OutputPath': outputPath,
      'WildcardsFolder': wildcardsFolder,
      'AppendUserNameToOutputPath': appendUserNameToOutputPath,
      'RecycleDeletedImages': recycleDeletedImages,
      'RecycleDeletedModels': recycleDeletedModels,
      'ClearStrayModelData': clearStrayModelData,
      'EditMetadataAcrossAllDups': editMetadataAcrossAllDups,
      'DownloaderAlwaysResave': downloaderAlwaysResave,
    };
  }
}

/// Metadata-related settings
class MetadataSettings {
  bool modelMetadataPerFolder = false;
  bool imageMetadataPerFolder = true;
  bool xlDefaultAsXL1 = false;
  bool editMetadataWriteJSON = false;
  bool imageMetadataIncludeModelHash = true;
  int modelMetadataSpacerKilobytes = 64;

  MetadataSettings();

  factory MetadataSettings.fromFds(Map<String, dynamic> data) {
    final m = MetadataSettings();
    m.modelMetadataPerFolder = data['ModelMetadataPerFolder'] == true;
    m.imageMetadataPerFolder = data['ImageMetadataPerFolder'] != false;
    m.xlDefaultAsXL1 = data['XLDefaultAsXL1'] == true;
    m.editMetadataWriteJSON = data['EditMetadataWriteJSON'] == true;
    m.imageMetadataIncludeModelHash = data['ImageMetadataIncludeModelHash'] != false;
    m.modelMetadataSpacerKilobytes = data['ModelMetadataSpacerKilobytes'] as int? ?? 64;
    return m;
  }

  Map<String, dynamic> toFds() {
    return {
      'ModelMetadataPerFolder': modelMetadataPerFolder,
      'ImageMetadataPerFolder': imageMetadataPerFolder,
      'XLDefaultAsXL1': xlDefaultAsXL1,
      'EditMetadataWriteJSON': editMetadataWriteJSON,
      'ImageMetadataIncludeModelHash': imageMetadataIncludeModelHash,
      'ModelMetadataSpacerKilobytes': modelMetadataSpacerKilobytes,
    };
  }
}

/// Network-related settings
class NetworkSettings {
  String? externalURL;
  String host = 'localhost';
  int port = 7801;
  bool portCanChange = true;
  int backendStartingPort = 7820;
  bool backendPortRandomize = false;
  String? cloudflaredPath;
  String authBypassIPs = '127.0.0.1,::1,::ffff:127.0.0.1';
  String? requiredAuthorization;
  bool enableSpecialDevForwarding = false;
  int outputCacheSeconds = 30;
  String? accessControlAllowOrigin;
  int maxXForwardedFor = 3;
  int maxNetworkRequestMegabytes = 200;

  NetworkSettings();

  factory NetworkSettings.fromFds(Map<String, dynamic> data) {
    final n = NetworkSettings();
    n.externalURL = _parseNullableString(data['ExternalURL']);
    n.host = data['Host']?.toString() ?? 'localhost';
    n.port = data['Port'] as int? ?? 7801;
    n.portCanChange = data['PortCanChange'] != false;
    n.backendStartingPort = data['BackendStartingPort'] as int? ?? 7820;
    n.backendPortRandomize = data['BackendPortRandomize'] == true;
    n.cloudflaredPath = _parseNullableString(data['CloudflaredPath']);
    n.authBypassIPs = data['AuthBypassIPs']?.toString() ?? '127.0.0.1,::1,::ffff:127.0.0.1';
    n.requiredAuthorization = _parseNullableString(data['RequiredAuthorization']);
    n.enableSpecialDevForwarding = data['EnableSpecialDevForwarding'] == true;
    n.outputCacheSeconds = data['OutputCacheSeconds'] as int? ?? 30;
    n.accessControlAllowOrigin = _parseNullableString(data['AccessControlAllowOrigin']);
    n.maxXForwardedFor = data['MaxXForwardedFor'] as int? ?? 3;
    n.maxNetworkRequestMegabytes = data['MaxNetworkRequestMegabytes'] as int? ?? 200;
    return n;
  }

  Map<String, dynamic> toFds() {
    return {
      'ExternalURL': externalURL ?? r'\x',
      'Host': host,
      'Port': port,
      'PortCanChange': portCanChange,
      'BackendStartingPort': backendStartingPort,
      'BackendPortRandomize': backendPortRandomize,
      'CloudflaredPath': cloudflaredPath ?? r'\x',
      'AuthBypassIPs': authBypassIPs,
      'RequiredAuthorization': requiredAuthorization ?? r'\x',
      'EnableSpecialDevForwarding': enableSpecialDevForwarding,
      'OutputCacheSeconds': outputCacheSeconds,
      'AccessControlAllowOrigin': accessControlAllowOrigin ?? r'\x',
      'MaxXForwardedFor': maxXForwardedFor,
      'MaxNetworkRequestMegabytes': maxNetworkRequestMegabytes,
    };
  }
}

/// Maintenance settings
class MaintenanceSettings {
  bool checkForUpdates = true;
  bool autoPullDevUpdates = false;
  double restartAfterHours = 0;
  String restartHoursAllowed = '';
  String restartDayAllowed = '';
  bool restartOnGpuCriticalError = false;
  int gitTimeoutMinutes = 1;
  int userDBBackups = 3;

  MaintenanceSettings();

  factory MaintenanceSettings.fromFds(Map<String, dynamic> data) {
    final m = MaintenanceSettings();
    m.checkForUpdates = data['CheckForUpdates'] != false;
    m.autoPullDevUpdates = data['AutoPullDevUpdates'] == true;
    m.restartAfterHours = (data['RestartAfterHours'] as num?)?.toDouble() ?? 0;
    m.restartHoursAllowed = _parseNullableString(data['RestartHoursAllowed']) ?? '';
    m.restartDayAllowed = _parseNullableString(data['RestartDayAllowed']) ?? '';
    m.restartOnGpuCriticalError = data['RestartOnGpuCriticalError'] == true;
    m.gitTimeoutMinutes = data['GitTimeoutMinutes'] as int? ?? 1;
    m.userDBBackups = data['UserDBBackups'] as int? ?? 3;
    return m;
  }

  Map<String, dynamic> toFds() {
    return {
      'CheckForUpdates': checkForUpdates,
      'AutoPullDevUpdates': autoPullDevUpdates,
      'RestartAfterHours': restartAfterHours,
      'RestartHoursAllowed': restartHoursAllowed.isEmpty ? r'\x' : restartHoursAllowed,
      'RestartDayAllowed': restartDayAllowed.isEmpty ? r'\x' : restartDayAllowed,
      'RestartOnGpuCriticalError': restartOnGpuCriticalError,
      'GitTimeoutMinutes': gitTimeoutMinutes,
      'UserDBBackups': userDBBackups,
    };
  }
}

/// Default user settings
class DefaultUserSettings {
  OutPathBuilderSettings outPathBuilder = OutPathBuilderSettings();
  FileFormatSettings fileFormat = FileFormatSettings();
  UserUISettings ui = UserUISettings();
  ParamParsingSettings paramParsing = ParamParsingSettings();
  VAESettings vaes = VAESettings();
  AudioSettings audio = AudioSettings();
  AutoCompleteSettings autoComplete = AutoCompleteSettings();

  bool saveFiles = true;
  bool starNoFolders = false;
  List<String> roles = ['owner'];
  String theme = 'modern_dark';
  bool centerImageAlwaysGrow = false;
  bool autoSwapImagesIncludesFullView = false;
  String buttonsUnderMainImages = '';
  String imageMetadataFormat = 'auto';
  bool resetBatchSizeToOne = false;
  String hintFormat = 'BUTTON';
  double hoverDelaySeconds = 0.5;
  int maxPromptLines = 10;
  int maxImagesInMiniGrid = 1;
  int maxImagesInHistory = 1000;
  int maxImagesScannedInHistory = 10000;
  bool imageHistoryUsePreviews = true;
  int maxSimulPreviews = 1;
  bool enterKeyGenerates = true;
  double generateForeverDelay = 0.1;
  int generateForeverQueueSize = 1;
  double parameterMemoryDurationHours = 6;
  String language = 'en';
  String reuseParamExcludeList = 'wildcardseed';

  DefaultUserSettings();

  factory DefaultUserSettings.fromFds(Map<String, dynamic> data) {
    final d = DefaultUserSettings();
    if (data['OutPathBuilder'] is Map) {
      d.outPathBuilder = OutPathBuilderSettings.fromFds(data['OutPathBuilder'] as Map<String, dynamic>);
    }
    if (data['FileFormat'] is Map) {
      d.fileFormat = FileFormatSettings.fromFds(data['FileFormat'] as Map<String, dynamic>);
    }
    if (data['UI'] is Map) {
      d.ui = UserUISettings.fromFds(data['UI'] as Map<String, dynamic>);
    }
    if (data['ParamParsing'] is Map) {
      d.paramParsing = ParamParsingSettings.fromFds(data['ParamParsing'] as Map<String, dynamic>);
    }
    if (data['VAEs'] is Map) {
      d.vaes = VAESettings.fromFds(data['VAEs'] as Map<String, dynamic>);
    }
    if (data['Audio'] is Map) {
      d.audio = AudioSettings.fromFds(data['Audio'] as Map<String, dynamic>);
    }
    if (data['AutoComplete'] is Map) {
      d.autoComplete = AutoCompleteSettings.fromFds(data['AutoComplete'] as Map<String, dynamic>);
    }

    d.saveFiles = data['SaveFiles'] != false;
    d.starNoFolders = data['StarNoFolders'] == true;
    if (data['Roles'] is List) {
      d.roles = (data['Roles'] as List).map((e) => e.toString()).toList();
    }
    d.theme = data['Theme']?.toString() ?? 'modern_dark';
    d.centerImageAlwaysGrow = data['CenterImageAlwaysGrow'] == true;
    d.autoSwapImagesIncludesFullView = data['AutoSwapImagesIncludesFullView'] == true;
    d.buttonsUnderMainImages = _parseNullableString(data['ButtonsUnderMainImages']) ?? '';
    d.imageMetadataFormat = data['ImageMetadataFormat']?.toString() ?? 'auto';
    d.resetBatchSizeToOne = data['ResetBatchSizeToOne'] == true;
    d.hintFormat = data['HintFormat']?.toString() ?? 'BUTTON';
    d.hoverDelaySeconds = (data['HoverDelaySeconds'] as num?)?.toDouble() ?? 0.5;
    d.maxPromptLines = data['MaxPromptLines'] as int? ?? 10;
    d.maxImagesInMiniGrid = data['MaxImagesInMiniGrid'] as int? ?? 1;
    d.maxImagesInHistory = data['MaxImagesInHistory'] as int? ?? 1000;
    d.maxImagesScannedInHistory = data['MaxImagesScannedInHistory'] as int? ?? 10000;
    d.imageHistoryUsePreviews = data['ImageHistoryUsePreviews'] != false;
    d.maxSimulPreviews = data['MaxSimulPreviews'] as int? ?? 1;
    d.enterKeyGenerates = data['EnterKeyGenerates'] != false;
    d.generateForeverDelay = (data['GenerateForeverDelay'] as num?)?.toDouble() ?? 0.1;
    d.generateForeverQueueSize = data['GenerateForeverQueueSize'] as int? ?? 1;
    d.parameterMemoryDurationHours = (data['ParameterMemoryDurationHours'] as num?)?.toDouble() ?? 6;
    d.language = data['Language']?.toString() ?? 'en';
    d.reuseParamExcludeList = data['ReuseParamExcludeList']?.toString() ?? 'wildcardseed';

    return d;
  }

  Map<String, dynamic> toFds() {
    return {
      'OutPathBuilder': outPathBuilder.toFds(),
      'FileFormat': fileFormat.toFds(),
      'UI': ui.toFds(),
      'ParamParsing': paramParsing.toFds(),
      'VAEs': vaes.toFds(),
      'Audio': audio.toFds(),
      'AutoComplete': autoComplete.toFds(),
      'SaveFiles': saveFiles,
      'StarNoFolders': starNoFolders,
      'Roles': roles,
      'Theme': theme,
      'CenterImageAlwaysGrow': centerImageAlwaysGrow,
      'AutoSwapImagesIncludesFullView': autoSwapImagesIncludesFullView,
      'ButtonsUnderMainImages': buttonsUnderMainImages.isEmpty ? r'\x' : buttonsUnderMainImages,
      'ImageMetadataFormat': imageMetadataFormat,
      'ResetBatchSizeToOne': resetBatchSizeToOne,
      'HintFormat': hintFormat,
      'HoverDelaySeconds': hoverDelaySeconds,
      'MaxPromptLines': maxPromptLines,
      'MaxImagesInMiniGrid': maxImagesInMiniGrid,
      'MaxImagesInHistory': maxImagesInHistory,
      'MaxImagesScannedInHistory': maxImagesScannedInHistory,
      'ImageHistoryUsePreviews': imageHistoryUsePreviews,
      'MaxSimulPreviews': maxSimulPreviews,
      'EnterKeyGenerates': enterKeyGenerates,
      'GenerateForeverDelay': generateForeverDelay,
      'GenerateForeverQueueSize': generateForeverQueueSize,
      'ParameterMemoryDurationHours': parameterMemoryDurationHours,
      'Language': language,
      'ReuseParamExcludeList': reuseParamExcludeList,
    };
  }
}

/// Output path builder settings
class OutPathBuilderSettings {
  String format = 'raw/[year]-[month]-[day]/[hour][minute][request_time_inc]-[prompt]-[model]';
  int maxLenPerPart = 40;
  bool modelPathsSkipFolders = false;

  OutPathBuilderSettings();

  factory OutPathBuilderSettings.fromFds(Map<String, dynamic> data) {
    final o = OutPathBuilderSettings();
    o.format = data['Format']?.toString() ??
        'raw/[year]-[month]-[day]/[hour][minute][request_time_inc]-[prompt]-[model]';
    o.maxLenPerPart = data['MaxLenPerPart'] as int? ?? 40;
    o.modelPathsSkipFolders = data['ModelPathsSkipFolders'] == true;
    return o;
  }

  Map<String, dynamic> toFds() => {
    'Format': format,
    'MaxLenPerPart': maxLenPerPart,
    'ModelPathsSkipFolders': modelPathsSkipFolders,
  };
}

/// File format settings
class FileFormatSettings {
  String imageFormat = 'PNG';
  int imageQuality = 100;
  bool saveMetadata = true;
  String stealthMetadata = 'false';
  int dpi = 0;
  bool saveTextFileMetadata = false;
  bool reformatTransientImages = false;

  FileFormatSettings();

  factory FileFormatSettings.fromFds(Map<String, dynamic> data) {
    final f = FileFormatSettings();
    f.imageFormat = data['ImageFormat']?.toString() ?? 'PNG';
    f.imageQuality = data['ImageQuality'] as int? ?? 100;
    f.saveMetadata = data['SaveMetadata'] != false;
    f.stealthMetadata = data['StealthMetadata']?.toString() ?? 'false';
    f.dpi = data['DPI'] as int? ?? 0;
    f.saveTextFileMetadata = data['SaveTextFileMetadata'] == true;
    f.reformatTransientImages = data['ReformatTransientImages'] == true;
    return f;
  }

  Map<String, dynamic> toFds() => {
    'ImageFormat': imageFormat,
    'ImageQuality': imageQuality,
    'SaveMetadata': saveMetadata,
    'StealthMetadata': stealthMetadata,
    'DPI': dpi,
    'SaveTextFileMetadata': saveTextFileMetadata,
    'ReformatTransientImages': reformatTransientImages,
  };
}

/// User UI settings
class UserUISettings {
  bool tagMoveHotkeyEnabled = false;
  bool checkIfSureBeforeDelete = true;
  String presetListDetailsFields = '';
  bool copyTriggerPhraseWithTrailingComma = false;
  bool removeInterruptedGens = false;
  String hideErrorMessages = '';
  String deleteImageBehavior = 'next';
  bool imageShiftingCycles = true;
  bool defaultHideMetadataInFullview = false;

  UserUISettings();

  factory UserUISettings.fromFds(Map<String, dynamic> data) {
    final u = UserUISettings();
    u.tagMoveHotkeyEnabled = data['TagMoveHotkeyEnabled'] == true;
    u.checkIfSureBeforeDelete = data['CheckIfSureBeforeDelete'] != false;
    u.presetListDetailsFields = _parseNullableString(data['PresetListDetailsFields']) ?? '';
    u.copyTriggerPhraseWithTrailingComma = data['CopyTriggerPhraseWithTrailingComma'] == true;
    u.removeInterruptedGens = data['RemoveInterruptedGens'] == true;
    u.hideErrorMessages = _parseNullableString(data['HideErrorMessages']) ?? '';
    u.deleteImageBehavior = data['DeleteImageBehavior']?.toString() ?? 'next';
    u.imageShiftingCycles = data['ImageShiftingCycles'] != false;
    u.defaultHideMetadataInFullview = data['DefaultHideMetadataInFullview'] == true;
    return u;
  }

  Map<String, dynamic> toFds() => {
    'TagMoveHotkeyEnabled': tagMoveHotkeyEnabled,
    'CheckIfSureBeforeDelete': checkIfSureBeforeDelete,
    'PresetListDetailsFields': presetListDetailsFields.isEmpty ? r'\x' : presetListDetailsFields,
    'CopyTriggerPhraseWithTrailingComma': copyTriggerPhraseWithTrailingComma,
    'RemoveInterruptedGens': removeInterruptedGens,
    'HideErrorMessages': hideErrorMessages.isEmpty ? r'\x' : hideErrorMessages,
    'DeleteImageBehavior': deleteImageBehavior,
    'ImageShiftingCycles': imageShiftingCycles,
    'DefaultHideMetadataInFullview': defaultHideMetadataInFullview,
  };
}

/// Parameter parsing settings
class ParamParsingSettings {
  bool allowLoraStacking = true;

  ParamParsingSettings();

  factory ParamParsingSettings.fromFds(Map<String, dynamic> data) {
    final p = ParamParsingSettings();
    p.allowLoraStacking = data['AllowLoraStacking'] != false;
    return p;
  }

  Map<String, dynamic> toFds() => {
    'AllowLoraStacking': allowLoraStacking,
  };
}

/// VAE override settings
class VAESettings {
  String defaultSDXLVAE = 'None';
  String defaultSDv1VAE = 'None';
  String defaultSVDVAE = 'None';
  String defaultFluxVAE = 'None';
  String defaultFlux2VAE = 'None';
  String defaultSD3VAE = 'None';
  String defaultMochiVAE = 'None';

  VAESettings();

  factory VAESettings.fromFds(Map<String, dynamic> data) {
    final v = VAESettings();
    v.defaultSDXLVAE = data['DefaultSDXLVAE']?.toString() ?? 'None';
    v.defaultSDv1VAE = data['DefaultSDv1VAE']?.toString() ?? 'None';
    v.defaultSVDVAE = data['DefaultSVDVAE']?.toString() ?? 'None';
    v.defaultFluxVAE = data['DefaultFluxVAE']?.toString() ?? 'None';
    v.defaultFlux2VAE = data['DefaultFlux2VAE']?.toString() ?? 'None';
    v.defaultSD3VAE = data['DefaultSD3VAE']?.toString() ?? 'None';
    v.defaultMochiVAE = data['DefaultMochiVAE']?.toString() ?? 'None';
    return v;
  }

  Map<String, dynamic> toFds() => {
    'DefaultSDXLVAE': defaultSDXLVAE,
    'DefaultSDv1VAE': defaultSDv1VAE,
    'DefaultSVDVAE': defaultSVDVAE,
    'DefaultFluxVAE': defaultFluxVAE,
    'DefaultFlux2VAE': defaultFlux2VAE,
    'DefaultSD3VAE': defaultSD3VAE,
    'DefaultMochiVAE': defaultMochiVAE,
  };
}

/// Audio settings
class AudioSettings {
  String completionSound = '';
  double volume = 0.5;

  AudioSettings();

  factory AudioSettings.fromFds(Map<String, dynamic> data) {
    final a = AudioSettings();
    a.completionSound = _parseNullableString(data['CompletionSound']) ?? '';
    a.volume = (data['Volume'] as num?)?.toDouble() ?? 0.5;
    return a;
  }

  Map<String, dynamic> toFds() => {
    'CompletionSound': completionSound.isEmpty ? r'\x' : completionSound,
    'Volume': volume,
  };
}

/// Auto-complete settings
class AutoCompleteSettings {
  String source = '';
  bool escapeParens = true;
  String suffix = '';
  String matchMode = 'Bucketed';
  String sortMode = 'Active';
  String spacingMode = 'None';

  AutoCompleteSettings();

  factory AutoCompleteSettings.fromFds(Map<String, dynamic> data) {
    final a = AutoCompleteSettings();
    a.source = _parseNullableString(data['Source']) ?? '';
    a.escapeParens = data['EscapeParens'] != false;
    a.suffix = _parseNullableString(data['Suffix']) ?? '';
    a.matchMode = data['MatchMode']?.toString() ?? 'Bucketed';
    a.sortMode = data['SortMode']?.toString() ?? 'Active';
    a.spacingMode = data['SpacingMode']?.toString() ?? 'None';
    return a;
  }

  Map<String, dynamic> toFds() => {
    'Source': source.isEmpty ? r'\x' : source,
    'EscapeParens': escapeParens,
    'Suffix': suffix.isEmpty ? r'\x' : suffix,
    'MatchMode': matchMode,
    'SortMode': sortMode,
    'SpacingMode': spacingMode,
  };
}

/// Backend settings
class BackendSettings {
  int maxBackendInitAttempts = 3;
  int maxTimeoutMinutes = 120;
  int perRequestTimeoutMinutes = 10080;
  int maxRequestsForcedOrder = 20;
  bool unrestrictedMaxT2iSimultaneous = false;
  double clearVRAMAfterMinutes = 10;
  double clearSystemRAMAfterMinutes = 60;
  bool alwaysRefreshOnLoad = true;
  String modelLoadOrderPreference = 'last_used';
  bool allBackendsLoadFast = false;

  BackendSettings();

  factory BackendSettings.fromFds(Map<String, dynamic> data) {
    final b = BackendSettings();
    b.maxBackendInitAttempts = data['MaxBackendInitAttempts'] as int? ?? 3;
    b.maxTimeoutMinutes = data['MaxTimeoutMinutes'] as int? ?? 120;
    b.perRequestTimeoutMinutes = data['PerRequestTimeoutMinutes'] as int? ?? 10080;
    b.maxRequestsForcedOrder = data['MaxRequestsForcedOrder'] as int? ?? 20;
    b.unrestrictedMaxT2iSimultaneous = data['UnrestrictedMaxT2iSimultaneous'] == true;
    b.clearVRAMAfterMinutes = (data['ClearVRAMAfterMinutes'] as num?)?.toDouble() ?? 10;
    b.clearSystemRAMAfterMinutes = (data['ClearSystemRAMAfterMinutes'] as num?)?.toDouble() ?? 60;
    b.alwaysRefreshOnLoad = data['AlwaysRefreshOnLoad'] != false;
    b.modelLoadOrderPreference = data['ModelLoadOrderPreference']?.toString() ?? 'last_used';
    b.allBackendsLoadFast = data['AllBackendsLoadFast'] == true;
    return b;
  }

  Map<String, dynamic> toFds() => {
    'MaxBackendInitAttempts': maxBackendInitAttempts,
    'MaxTimeoutMinutes': maxTimeoutMinutes,
    'PerRequestTimeoutMinutes': perRequestTimeoutMinutes,
    'MaxRequestsForcedOrder': maxRequestsForcedOrder,
    'UnrestrictedMaxT2iSimultaneous': unrestrictedMaxT2iSimultaneous,
    'ClearVRAMAfterMinutes': clearVRAMAfterMinutes,
    'ClearSystemRAMAfterMinutes': clearSystemRAMAfterMinutes,
    'AlwaysRefreshOnLoad': alwaysRefreshOnLoad,
    'ModelLoadOrderPreference': modelLoadOrderPreference,
    'AllBackendsLoadFast': allBackendsLoadFast,
  };
}

/// User authorization settings
class UserAuthorizationSettings {
  bool authorizationRequired = false;
  bool allowLocalhostBypass = true;
  String instanceTitle = 'Local';
  String loginNotice = 'This is a local instance not yet configured for shared usage.';

  UserAuthorizationSettings();

  factory UserAuthorizationSettings.fromFds(Map<String, dynamic> data) {
    final u = UserAuthorizationSettings();
    u.authorizationRequired = data['AuthorizationRequired'] == true;
    u.allowLocalhostBypass = data['AllowLocalhostBypass'] != false;
    u.instanceTitle = data['InstanceTitle']?.toString() ?? 'Local';
    u.loginNotice = data['LoginNotice']?.toString() ??
        'This is a local instance not yet configured for shared usage.';
    return u;
  }

  Map<String, dynamic> toFds() => {
    'AuthorizationRequired': authorizationRequired,
    'AllowLocalhostBypass': allowLocalhostBypass,
    'InstanceTitle': instanceTitle,
    'LoginNotice': loginNotice,
  };
}

/// Log settings
class LogSettings {
  String logLevel = 'Info';
  bool saveLogToFile = false;
  String logsPath = 'Logs/[year]-[month]/[day]-[hour]-[minute].log';
  int repeatTimestampAfterMinutes = 10;

  LogSettings();

  factory LogSettings.fromFds(Map<String, dynamic> data) {
    final l = LogSettings();
    l.logLevel = data['LogLevel']?.toString() ?? 'Info';
    l.saveLogToFile = data['SaveLogToFile'] == true;
    l.logsPath = data['LogsPath']?.toString() ?? 'Logs/[year]-[month]/[day]-[hour]-[minute].log';
    l.repeatTimestampAfterMinutes = data['RepeatTimestampAfterMinutes'] as int? ?? 10;
    return l;
  }

  Map<String, dynamic> toFds() => {
    'LogLevel': logLevel,
    'SaveLogToFile': saveLogToFile,
    'LogsPath': logsPath,
    'RepeatTimestampAfterMinutes': repeatTimestampAfterMinutes,
  };
}

/// UI settings
class UISettings {
  String overrideWelcomeMessage = '';
  String extraWelcomeInfo = '';
  bool allowAnimatedPreviews = true;

  UISettings();

  factory UISettings.fromFds(Map<String, dynamic> data) {
    final u = UISettings();
    u.overrideWelcomeMessage = _parseNullableString(data['OverrideWelcomeMessage']) ?? '';
    u.extraWelcomeInfo = _parseNullableString(data['ExtraWelcomeInfo']) ?? '';
    u.allowAnimatedPreviews = data['AllowAnimatedPreviews'] != false;
    return u;
  }

  Map<String, dynamic> toFds() => {
    'OverrideWelcomeMessage': overrideWelcomeMessage.isEmpty ? r'\x' : overrideWelcomeMessage,
    'ExtraWelcomeInfo': extraWelcomeInfo.isEmpty ? r'\x' : extraWelcomeInfo,
    'AllowAnimatedPreviews': allowAnimatedPreviews,
  };
}

/// WebHooks settings
class WebHooksSettings {
  String queueStartWebhook = '';
  String queueStartWebhookData = '';
  String queueEndWebhook = '';
  String queueEndWebhookData = '';
  String everyGenWebhook = '';
  String everyGenWebhookData = '';
  String manualGenWebhook = '';
  String manualGenWebhookData = '';
  String serverStartWebhook = '';
  String serverStartWebhookData = '';
  String serverShutdownWebhook = '';
  String serverShutdownWebhookData = '';
  int queueEndDelay = 1;

  WebHooksSettings();

  factory WebHooksSettings.fromFds(Map<String, dynamic> data) {
    final w = WebHooksSettings();
    w.queueStartWebhook = _parseNullableString(data['QueueStartWebhook']) ?? '';
    w.queueStartWebhookData = _parseNullableString(data['QueueStartWebhookData']) ?? '';
    w.queueEndWebhook = _parseNullableString(data['QueueEndWebhook']) ?? '';
    w.queueEndWebhookData = _parseNullableString(data['QueueEndWebhookData']) ?? '';
    w.everyGenWebhook = _parseNullableString(data['EveryGenWebhook']) ?? '';
    w.everyGenWebhookData = _parseNullableString(data['EveryGenWebhookData']) ?? '';
    w.manualGenWebhook = _parseNullableString(data['ManualGenWebhook']) ?? '';
    w.manualGenWebhookData = _parseNullableString(data['ManualGenWebhookData']) ?? '';
    w.serverStartWebhook = _parseNullableString(data['ServerStartWebhook']) ?? '';
    w.serverStartWebhookData = _parseNullableString(data['ServerStartWebhookData']) ?? '';
    w.serverShutdownWebhook = _parseNullableString(data['ServerShutdownWebhook']) ?? '';
    w.serverShutdownWebhookData = _parseNullableString(data['ServerShutdownWebhookData']) ?? '';
    w.queueEndDelay = data['QueueEndDelay'] as int? ?? 1;
    return w;
  }

  Map<String, dynamic> toFds() => {
    'QueueStartWebhook': queueStartWebhook.isEmpty ? r'\x' : queueStartWebhook,
    'QueueStartWebhookData': queueStartWebhookData.isEmpty ? r'\x' : queueStartWebhookData,
    'QueueEndWebhook': queueEndWebhook.isEmpty ? r'\x' : queueEndWebhook,
    'QueueEndWebhookData': queueEndWebhookData.isEmpty ? r'\x' : queueEndWebhookData,
    'EveryGenWebhook': everyGenWebhook.isEmpty ? r'\x' : everyGenWebhook,
    'EveryGenWebhookData': everyGenWebhookData.isEmpty ? r'\x' : everyGenWebhookData,
    'ManualGenWebhook': manualGenWebhook.isEmpty ? r'\x' : manualGenWebhook,
    'ManualGenWebhookData': manualGenWebhookData.isEmpty ? r'\x' : manualGenWebhookData,
    'ServerStartWebhook': serverStartWebhook.isEmpty ? r'\x' : serverStartWebhook,
    'ServerStartWebhookData': serverStartWebhookData.isEmpty ? r'\x' : serverStartWebhookData,
    'ServerShutdownWebhook': serverShutdownWebhook.isEmpty ? r'\x' : serverShutdownWebhook,
    'ServerShutdownWebhookData': serverShutdownWebhookData.isEmpty ? r'\x' : serverShutdownWebhookData,
    'QueueEndDelay': queueEndDelay,
  };
}

/// Performance settings
class PerformanceSettings {
  double imageDataValidationChance = 0.05;
  bool doBackendDataCache = false;
  bool allowGpuSpecificOptimizations = true;
  int modelListSanityCap = 5000;

  PerformanceSettings();

  factory PerformanceSettings.fromFds(Map<String, dynamic> data) {
    final p = PerformanceSettings();
    p.imageDataValidationChance = (data['ImageDataValidationChance'] as num?)?.toDouble() ?? 0.05;
    p.doBackendDataCache = data['DoBackendDataCache'] == true;
    p.allowGpuSpecificOptimizations = data['AllowGpuSpecificOptimizations'] != false;
    p.modelListSanityCap = data['ModelListSanityCap'] as int? ?? 5000;
    return p;
  }

  Map<String, dynamic> toFds() => {
    'ImageDataValidationChance': imageDataValidationChance,
    'DoBackendDataCache': doBackendDataCache,
    'AllowGpuSpecificOptimizations': allowGpuSpecificOptimizations,
    'ModelListSanityCap': modelListSanityCap,
  };
}

/// Helper to parse SwarmUI's empty string representation
String? _parseNullableString(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  if (str == r'\x' || str.isEmpty) return null;
  return str;
}
