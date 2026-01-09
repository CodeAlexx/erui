import 'dart:math';

/// Prompt Syntax Engine for EriUI
///
/// Parses and expands special prompt syntax before sending to the API.
/// Supports various dynamic prompt features like random selection, wildcards,
/// variables, and more.
///
/// Supported syntax:
/// - `<random:cat,dog,bird>` - randomly select one option
/// - `<wildcard:filename>` - load random line from wildcard file
/// - `<alternate:cat,dog>` - return items for alternating steps
/// - `<fromto[0.5]:cat,dog>` - swap at percentage through generation
/// - `<repeat[3]:word>` - repeat word N times
/// - `<trigger>` - insert model trigger phrase
/// - `<lora:name:weight>` - parse lora syntax
/// - `(word:1.5)` - weight syntax (passed through to API)
/// - `<var:name>` - reference a variable
/// - `<setvar[name]:value>` - set a variable
/// - `<comment:text>` - strip comments from output
class PromptSyntaxService {
  /// Random instance for consistent seeded randomness
  static Random? _random;

  /// Stored variables for the current expansion
  static final Map<String, String> _variables = {};

  /// Regular expressions for parsing syntax
  static final RegExp _randomRegex = RegExp(r'<random:([^>]+)>');
  static final RegExp _wildcardRegex = RegExp(r'<wildcard:([^>]+)>');
  static final RegExp _alternateRegex = RegExp(r'<alternate:([^>]+)>');
  static final RegExp _fromtoRegex = RegExp(r'<fromto\[([0-9.]+)\]:([^,>]+),([^>]+)>');
  static final RegExp _repeatRegex = RegExp(r'<repeat\[(\d+)\]:([^>]+)>');
  static final RegExp _triggerRegex = RegExp(r'<trigger>');
  static final RegExp _loraRegex = RegExp(r'<lora:([^:>]+)(?::([^>]+))?>');
  static final RegExp _setvarRegex = RegExp(r'<setvar\[([^\]]+)\]:([^>]+)>');
  static final RegExp _varRegex = RegExp(r'<var:([^>]+)>');
  static final RegExp _commentRegex = RegExp(r'<comment:[^>]*>');

  /// Expand all prompt syntax in the given prompt string
  ///
  /// [prompt] - The raw prompt containing syntax to expand
  /// [seed] - Optional seed for reproducible random selections
  /// [modelTrigger] - Optional trigger phrase for the current model
  /// [wildcards] - Map of wildcard filename to list of possible values
  /// [step] - Current generation step (for alternate/fromto)
  /// [totalSteps] - Total number of steps (for fromto percentage)
  ///
  /// Returns the expanded prompt string with all syntax processed
  static String expandPrompt(
    String prompt, {
    int? seed,
    String? modelTrigger,
    Map<String, List<String>>? wildcards,
    int step = 0,
    int totalSteps = 1,
  }) {
    // Initialize random with seed if provided
    _random = seed != null ? Random(seed) : Random();

    // Clear variables for fresh expansion
    _variables.clear();

    String result = prompt;

    // Process in order of dependency
    // 1. First, strip comments (they should not affect anything)
    result = _processComments(result);

    // 2. Set variables (must be done before variable references)
    result = _processSetVar(result);

    // 3. Expand variables (after they've been set)
    result = _processVar(result);

    // 4. Process wildcards (may contain other syntax)
    result = _processWildcards(result, wildcards);

    // 5. Process random selections
    result = _processRandom(result);

    // 6. Process alternates based on step
    result = _processAlternate(result, step);

    // 7. Process fromto based on progress percentage
    result = _processFromTo(result, step, totalSteps);

    // 8. Process repeat syntax
    result = _processRepeat(result);

    // 9. Process trigger placeholder
    result = _processTrigger(result, modelTrigger);

    // 10. Handle nested syntax by recursive expansion
    // Check if any syntax patterns still exist and re-expand if needed
    if (_containsSyntax(result) && result != prompt) {
      result = expandPrompt(
        result,
        seed: seed != null ? seed + 1 : null, // Modify seed for nested
        modelTrigger: modelTrigger,
        wildcards: wildcards,
        step: step,
        totalSteps: totalSteps,
      );
    }

    // Clean up extra whitespace
    result = _cleanWhitespace(result);

    return result;
  }

  /// Parse and extract LoRA references from the prompt
  ///
  /// Returns a list of LoRA specifications in format "name:weight"
  /// The weight defaults to "1.0" if not specified
  static List<LoraReference> parseLoRAs(String prompt) {
    List<LoraReference> loras = [];

    for (Match match in _loraRegex.allMatches(prompt)) {
      String name = match.group(1)!.trim();
      String weightStr = match.group(2)?.trim() ?? '1.0';

      double weight;
      try {
        weight = double.parse(weightStr);
      } catch (e) {
        weight = 1.0;
      }

      loras.add(LoraReference(name: name, weight: weight));
    }

    return loras;
  }

  /// Remove LoRA syntax from prompt after parsing
  ///
  /// Returns the prompt with all <lora:...> tags removed
  static String removeLoRAs(String prompt) {
    return prompt.replaceAll(_loraRegex, '').trim();
  }

  /// Check if a string contains unprocessed syntax
  static bool containsSyntax(String text) {
    return _containsSyntax(text);
  }

  // ============================================================
  // Private Processing Methods
  // ============================================================

  /// Process <comment:...> syntax - strip from output
  static String _processComments(String prompt) {
    return prompt.replaceAll(_commentRegex, '');
  }

  /// Process <setvar[name]:value> syntax - set variable and remove from output
  static String _processSetVar(String prompt) {
    return prompt.replaceAllMapped(_setvarRegex, (match) {
      String name = match.group(1)!.trim();
      String value = match.group(2)!.trim();
      _variables[name] = value;
      return ''; // Remove the setvar syntax from output
    });
  }

  /// Process <var:name> syntax - replace with variable value
  static String _processVar(String prompt) {
    return prompt.replaceAllMapped(_varRegex, (match) {
      String name = match.group(1)!.trim();
      return _variables[name] ?? ''; // Return empty if variable not set
    });
  }

  /// Process <wildcard:filename> syntax - select random line from wildcard
  static String _processWildcards(
    String prompt,
    Map<String, List<String>>? wildcards,
  ) {
    if (wildcards == null || wildcards.isEmpty) {
      // Remove wildcard syntax if no wildcards provided
      return prompt.replaceAll(_wildcardRegex, '');
    }

    return prompt.replaceAllMapped(_wildcardRegex, (match) {
      String filename = match.group(1)!.trim();
      List<String>? options = wildcards[filename];

      if (options == null || options.isEmpty) {
        return ''; // No wildcard file found
      }

      // Select random option
      int index = _random!.nextInt(options.length);
      return options[index];
    });
  }

  /// Process <random:option1,option2,...> syntax
  static String _processRandom(String prompt) {
    return prompt.replaceAllMapped(_randomRegex, (match) {
      String optionsStr = match.group(1)!;
      List<String> options = _parseOptions(optionsStr);

      if (options.isEmpty) {
        return '';
      }

      int index = _random!.nextInt(options.length);
      return options[index].trim();
    });
  }

  /// Process <alternate:option1,option2> syntax based on step
  static String _processAlternate(String prompt, int step) {
    return prompt.replaceAllMapped(_alternateRegex, (match) {
      String optionsStr = match.group(1)!;
      List<String> options = _parseOptions(optionsStr);

      if (options.isEmpty) {
        return '';
      }

      // Cycle through options based on step
      int index = step % options.length;
      return options[index].trim();
    });
  }

  /// Process <fromto[percentage]:start,end> syntax
  static String _processFromTo(String prompt, int step, int totalSteps) {
    return prompt.replaceAllMapped(_fromtoRegex, (match) {
      String percentageStr = match.group(1)!;
      String startValue = match.group(2)!.trim();
      String endValue = match.group(3)!.trim();

      double percentage;
      try {
        percentage = double.parse(percentageStr);
      } catch (e) {
        percentage = 0.5; // Default to 50%
      }

      // Calculate current progress
      double progress = totalSteps > 1 ? step / (totalSteps - 1) : 0;

      // Return start value before percentage, end value after
      return progress < percentage ? startValue : endValue;
    });
  }

  /// Process <repeat[count]:text> syntax
  static String _processRepeat(String prompt) {
    return prompt.replaceAllMapped(_repeatRegex, (match) {
      String countStr = match.group(1)!;
      String text = match.group(2)!.trim();

      int count;
      try {
        count = int.parse(countStr);
      } catch (e) {
        count = 1;
      }

      // Limit repeat count to prevent abuse
      count = count.clamp(0, 100);

      if (count <= 0) {
        return '';
      }

      return List.filled(count, text).join(' ');
    });
  }

  /// Process <trigger> syntax - insert model trigger phrase
  static String _processTrigger(String prompt, String? modelTrigger) {
    if (modelTrigger == null || modelTrigger.isEmpty) {
      return prompt.replaceAll(_triggerRegex, '');
    }

    return prompt.replaceAll(_triggerRegex, modelTrigger);
  }

  /// Parse comma-separated options, handling nested parentheses
  static List<String> _parseOptions(String optionsStr) {
    List<String> options = [];
    StringBuffer current = StringBuffer();
    int parenDepth = 0;
    int bracketDepth = 0;
    int angleDepth = 0;

    for (int i = 0; i < optionsStr.length; i++) {
      String char = optionsStr[i];

      if (char == '(' || char == '[' || char == '<') {
        if (char == '(') parenDepth++;
        if (char == '[') bracketDepth++;
        if (char == '<') angleDepth++;
        current.write(char);
      } else if (char == ')' || char == ']' || char == '>') {
        if (char == ')') parenDepth--;
        if (char == ']') bracketDepth--;
        if (char == '>') angleDepth--;
        current.write(char);
      } else if (char == ',' &&
          parenDepth == 0 &&
          bracketDepth == 0 &&
          angleDepth == 0) {
        // Split here
        String option = current.toString().trim();
        if (option.isNotEmpty) {
          options.add(option);
        }
        current.clear();
      } else {
        current.write(char);
      }
    }

    // Add last option
    String lastOption = current.toString().trim();
    if (lastOption.isNotEmpty) {
      options.add(lastOption);
    }

    return options;
  }

  /// Check if the text still contains unprocessed syntax
  static bool _containsSyntax(String text) {
    return _randomRegex.hasMatch(text) ||
        _wildcardRegex.hasMatch(text) ||
        _alternateRegex.hasMatch(text) ||
        _fromtoRegex.hasMatch(text) ||
        _repeatRegex.hasMatch(text) ||
        _triggerRegex.hasMatch(text) ||
        _setvarRegex.hasMatch(text) ||
        _varRegex.hasMatch(text) ||
        _commentRegex.hasMatch(text);
  }

  /// Clean up extra whitespace in the result
  static String _cleanWhitespace(String text) {
    // Replace multiple spaces with single space
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    // Remove spaces around commas
    text = text.replaceAll(RegExp(r'\s*,\s*'), ', ');
    // Trim leading/trailing whitespace
    return text.trim();
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Generate a preview of what the expanded prompt might look like
  ///
  /// Useful for showing users what their syntax will produce
  static String previewExpansion(
    String prompt, {
    String? modelTrigger,
    Map<String, List<String>>? wildcards,
  }) {
    return expandPrompt(
      prompt,
      seed: 42, // Use fixed seed for preview consistency
      modelTrigger: modelTrigger,
      wildcards: wildcards,
    );
  }

  /// Validate prompt syntax and return any errors
  ///
  /// Returns a list of syntax errors found, or empty list if valid
  static List<SyntaxError> validateSyntax(String prompt) {
    List<SyntaxError> errors = [];

    // Check for unclosed angle brackets
    int openAngles = '<'.allMatches(prompt).length;
    int closeAngles = '>'.allMatches(prompt).length;
    if (openAngles != closeAngles) {
      errors.add(SyntaxError(
        type: SyntaxErrorType.unclosedBracket,
        message: 'Unclosed angle bracket: $openAngles open, $closeAngles close',
      ));
    }

    // Check for empty random/alternate selections
    RegExp emptyRandom = RegExp(r'<random:>');
    if (emptyRandom.hasMatch(prompt)) {
      errors.add(SyntaxError(
        type: SyntaxErrorType.emptySelection,
        message: 'Empty random selection: <random:>',
      ));
    }

    RegExp emptyAlternate = RegExp(r'<alternate:>');
    if (emptyAlternate.hasMatch(prompt)) {
      errors.add(SyntaxError(
        type: SyntaxErrorType.emptySelection,
        message: 'Empty alternate selection: <alternate:>',
      ));
    }

    // Check for invalid repeat count
    RegExp invalidRepeat = RegExp(r'<repeat\[([^\]]*)\]:');
    for (Match match in invalidRepeat.allMatches(prompt)) {
      String countStr = match.group(1)!;
      if (int.tryParse(countStr) == null) {
        errors.add(SyntaxError(
          type: SyntaxErrorType.invalidNumber,
          message: 'Invalid repeat count: $countStr',
        ));
      }
    }

    // Check for invalid fromto percentage
    RegExp invalidFromto = RegExp(r'<fromto\[([^\]]*)\]:');
    for (Match match in invalidFromto.allMatches(prompt)) {
      String percentStr = match.group(1)!;
      if (double.tryParse(percentStr) == null) {
        errors.add(SyntaxError(
          type: SyntaxErrorType.invalidNumber,
          message: 'Invalid fromto percentage: $percentStr',
        ));
      }
    }

    // Check for undefined variables (variables referenced but not set)
    Set<String> definedVars = {};
    for (Match match in _setvarRegex.allMatches(prompt)) {
      definedVars.add(match.group(1)!.trim());
    }

    for (Match match in _varRegex.allMatches(prompt)) {
      String varName = match.group(1)!.trim();
      // Check if variable is defined before its use
      int varDefPos = prompt.indexOf('<setvar[$varName]:');
      int varUsePos = match.start;
      if (varDefPos == -1 || varDefPos > varUsePos) {
        // Variable might be external, just warn
        // Not an error since variables can come from outside
      }
    }

    return errors;
  }

  /// Get all wildcard references in the prompt
  ///
  /// Useful for preloading wildcards before expansion
  static List<String> getWildcardReferences(String prompt) {
    List<String> wildcards = [];
    for (Match match in _wildcardRegex.allMatches(prompt)) {
      String filename = match.group(1)!.trim();
      if (!wildcards.contains(filename)) {
        wildcards.add(filename);
      }
    }
    return wildcards;
  }

  /// Count how many variations a prompt can produce
  ///
  /// Returns estimated count (may be approximate for nested syntax)
  static int estimateVariations(
    String prompt, {
    Map<String, List<String>>? wildcards,
  }) {
    int variations = 1;

    // Count random options
    for (Match match in _randomRegex.allMatches(prompt)) {
      List<String> options = _parseOptions(match.group(1)!);
      if (options.isNotEmpty) {
        variations *= options.length;
      }
    }

    // Count wildcard options
    if (wildcards != null) {
      for (Match match in _wildcardRegex.allMatches(prompt)) {
        String filename = match.group(1)!.trim();
        List<String>? options = wildcards[filename];
        if (options != null && options.isNotEmpty) {
          variations *= options.length;
        }
      }
    }

    return variations;
  }
}

/// Represents a LoRA reference parsed from the prompt
class LoraReference {
  /// Name/path of the LoRA
  final String name;

  /// Weight/strength of the LoRA (default 1.0)
  final double weight;

  const LoraReference({
    required this.name,
    this.weight = 1.0,
  });

  @override
  String toString() => 'LoRA($name:$weight)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoraReference &&
        other.name == name &&
        other.weight == weight;
  }

  @override
  int get hashCode => name.hashCode ^ weight.hashCode;
}

/// Types of syntax errors that can be detected
enum SyntaxErrorType {
  unclosedBracket,
  emptySelection,
  invalidNumber,
  undefinedVariable,
  invalidSyntax,
}

/// Represents a syntax error found during validation
class SyntaxError {
  final SyntaxErrorType type;
  final String message;
  final int? position;

  const SyntaxError({
    required this.type,
    required this.message,
    this.position,
  });

  @override
  String toString() => 'SyntaxError($type): $message';
}
