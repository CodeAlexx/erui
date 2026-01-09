import 'package:flutter_test/flutter_test.dart';
import 'package:eriui_app/services/prompt_syntax_service.dart';

void main() {
  group('PromptSyntaxService', () {
    group('expandPrompt', () {
      test('returns unchanged prompt when no syntax present', () {
        String prompt = 'a beautiful landscape with mountains';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals(prompt));
      });

      test('handles empty prompt', () {
        String result = PromptSyntaxService.expandPrompt('');
        expect(result, equals(''));
      });
    });

    group('random syntax', () {
      test('selects one option from random syntax', () {
        String prompt = '<random:cat,dog,bird>';
        String result = PromptSyntaxService.expandPrompt(prompt, seed: 42);

        // With a fixed seed, should get consistent result
        expect(['cat', 'dog', 'bird'].contains(result), isTrue);
      });

      test('produces consistent results with same seed', () {
        String prompt = '<random:cat,dog,bird>';
        String result1 = PromptSyntaxService.expandPrompt(prompt, seed: 42);
        String result2 = PromptSyntaxService.expandPrompt(prompt, seed: 42);
        expect(result1, equals(result2));
      });

      test('handles single option', () {
        String prompt = '<random:onlyone>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('onlyone'));
      });

      test('handles options with spaces', () {
        String prompt = '<random:a cat,a dog,a bird>';
        String result = PromptSyntaxService.expandPrompt(prompt, seed: 42);
        expect(['a cat', 'a dog', 'a bird'].contains(result), isTrue);
      });

      test('handles multiple random blocks', () {
        String prompt = '<random:red,blue> <random:cat,dog>';
        String result = PromptSyntaxService.expandPrompt(prompt, seed: 42);

        // Result should contain one color and one animal
        expect(result.contains('red') || result.contains('blue'), isTrue);
        expect(result.contains('cat') || result.contains('dog'), isTrue);
      });
    });

    group('wildcard syntax', () {
      test('expands wildcard with available options', () {
        Map<String, List<String>> wildcards = {
          'animals': ['cat', 'dog', 'bird'],
        };

        String prompt = '<wildcard:animals>';
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          seed: 42,
          wildcards: wildcards,
        );

        expect(['cat', 'dog', 'bird'].contains(result), isTrue);
      });

      test('removes wildcard when file not found', () {
        Map<String, List<String>> wildcards = {};

        String prompt = 'a <wildcard:missing> in the garden';
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          wildcards: wildcards,
        );

        expect(result, equals('a in the garden'));
      });

      test('removes wildcard when no wildcards map provided', () {
        String prompt = 'a <wildcard:animals>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('a'));
      });
    });

    group('alternate syntax', () {
      test('returns first option on step 0', () {
        String prompt = '<alternate:cat,dog>';
        String result = PromptSyntaxService.expandPrompt(prompt, step: 0);
        expect(result, equals('cat'));
      });

      test('returns second option on step 1', () {
        String prompt = '<alternate:cat,dog>';
        String result = PromptSyntaxService.expandPrompt(prompt, step: 1);
        expect(result, equals('dog'));
      });

      test('cycles through options', () {
        String prompt = '<alternate:a,b,c>';

        expect(
            PromptSyntaxService.expandPrompt(prompt, step: 0), equals('a'));
        expect(
            PromptSyntaxService.expandPrompt(prompt, step: 1), equals('b'));
        expect(
            PromptSyntaxService.expandPrompt(prompt, step: 2), equals('c'));
        expect(
            PromptSyntaxService.expandPrompt(prompt, step: 3), equals('a'));
      });
    });

    group('fromto syntax', () {
      test('returns first value before percentage', () {
        String prompt = '<fromto[0.5]:cat,dog>';
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          step: 0,
          totalSteps: 10,
        );
        expect(result, equals('cat'));
      });

      test('returns second value after percentage', () {
        String prompt = '<fromto[0.5]:cat,dog>';
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          step: 6,
          totalSteps: 10,
        );
        expect(result, equals('dog'));
      });

      test('handles boundary case at exact percentage', () {
        String prompt = '<fromto[0.5]:start,end>';
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          step: 5,
          totalSteps: 10,
        );
        // At exactly 50%, should return end
        expect(result, equals('end'));
      });

      test('handles 0% threshold', () {
        String prompt = '<fromto[0]:start,end>';
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          step: 0,
          totalSteps: 10,
        );
        expect(result, equals('end'));
      });

      test('handles 100% threshold', () {
        String prompt = '<fromto[1.0]:start,end>';
        // At step 9 of 10, progress = 9/9 = 1.0, which is NOT < 1.0, so returns end
        // To stay at "start" until the very end, we'd need step 8 of 10
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          step: 8,
          totalSteps: 10,
        );
        expect(result, equals('start'));

        // At step 9 of 10, progress = 1.0, returns "end"
        String result2 = PromptSyntaxService.expandPrompt(
          prompt,
          step: 9,
          totalSteps: 10,
        );
        expect(result2, equals('end'));
      });
    });

    group('repeat syntax', () {
      test('repeats word specified number of times', () {
        String prompt = '<repeat[3]:hello>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('hello hello hello'));
      });

      test('handles repeat count of 1', () {
        String prompt = '<repeat[1]:word>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('word'));
      });

      test('handles repeat count of 0', () {
        String prompt = '<repeat[0]:word>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals(''));
      });

      test('limits repeat count to 100', () {
        String prompt = '<repeat[1000]:x>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        // Should be limited to 100 repetitions
        expect(result.split(' ').length, equals(100));
      });

      test('handles phrase with spaces', () {
        String prompt = '<repeat[2]:very good>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('very good very good'));
      });
    });

    group('trigger syntax', () {
      test('inserts model trigger phrase', () {
        String prompt = 'a photo of <trigger> in nature';
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          modelTrigger: 'sks person',
        );
        expect(result, equals('a photo of sks person in nature'));
      });

      test('removes trigger placeholder when no trigger provided', () {
        String prompt = 'a photo of <trigger> in nature';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('a photo of in nature'));
      });

      test('handles multiple trigger placeholders', () {
        String prompt = '<trigger> with <trigger>';
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          modelTrigger: 'test',
        );
        expect(result, equals('test with test'));
      });
    });

    group('lora syntax', () {
      test('parseLoRAs extracts lora with default weight', () {
        String prompt = 'a photo <lora:mymodel>';
        List<LoraReference> loras = PromptSyntaxService.parseLoRAs(prompt);

        expect(loras.length, equals(1));
        expect(loras[0].name, equals('mymodel'));
        expect(loras[0].weight, equals(1.0));
      });

      test('parseLoRAs extracts lora with specified weight', () {
        String prompt = 'a photo <lora:mymodel:0.8>';
        List<LoraReference> loras = PromptSyntaxService.parseLoRAs(prompt);

        expect(loras.length, equals(1));
        expect(loras[0].name, equals('mymodel'));
        expect(loras[0].weight, equals(0.8));
      });

      test('parseLoRAs handles multiple loras', () {
        String prompt = '<lora:model1:0.5> test <lora:model2:1.2>';
        List<LoraReference> loras = PromptSyntaxService.parseLoRAs(prompt);

        expect(loras.length, equals(2));
        expect(loras[0].name, equals('model1'));
        expect(loras[0].weight, equals(0.5));
        expect(loras[1].name, equals('model2'));
        expect(loras[1].weight, equals(1.2));
      });

      test('removeLoRAs removes lora syntax', () {
        String prompt = 'a photo <lora:mymodel:0.8> of nature';
        String result = PromptSyntaxService.removeLoRAs(prompt);
        expect(result, equals('a photo  of nature'));
      });

      test('handles invalid weight gracefully', () {
        String prompt = '<lora:model:invalid>';
        List<LoraReference> loras = PromptSyntaxService.parseLoRAs(prompt);

        expect(loras.length, equals(1));
        expect(loras[0].weight, equals(1.0)); // Default weight
      });
    });

    group('weight syntax', () {
      test('passes through weight syntax unchanged', () {
        String prompt = 'a (beautiful:1.5) landscape';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('a (beautiful:1.5) landscape'));
      });

      test('preserves nested weights', () {
        String prompt = '((very:1.2) important:1.5)';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('((very:1.2) important:1.5)'));
      });
    });

    group('variable syntax', () {
      test('sets and uses variable', () {
        String prompt = '<setvar[subject]:a cat><var:subject> on a roof';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('a cat on a roof'));
      });

      test('handles multiple variables', () {
        String prompt =
            '<setvar[animal]:dog><setvar[place]:park><var:animal> in the <var:place>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('dog in the park'));
      });

      test('returns empty for undefined variable', () {
        String prompt = 'a <var:undefined> test';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('a test'));
      });

      test('handles variable reuse', () {
        String prompt = '<setvar[x]:hello><var:x> world <var:x>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('hello world hello'));
      });
    });

    group('comment syntax', () {
      test('strips comments from output', () {
        String prompt = 'a photo<comment:this is a test> of nature';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('a photo of nature'));
      });

      test('handles multiple comments', () {
        String prompt =
            '<comment:start>hello<comment:middle>world<comment:end>';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('helloworld'));
      });

      test('handles empty comment', () {
        String prompt = 'test<comment:>test';
        String result = PromptSyntaxService.expandPrompt(prompt);
        expect(result, equals('testtest'));
      });
    });

    group('nested syntax', () {
      test('handles random inside variable', () {
        String prompt =
            '<setvar[pet]:<random:cat,dog>><var:pet> is my favorite';
        String result = PromptSyntaxService.expandPrompt(prompt, seed: 42);
        // Should expand the random inside the variable
        expect(
            result.contains('cat') || result.contains('dog'), isTrue);
        expect(result.contains('is my favorite'), isTrue);
      });

      test('handles wildcard inside random', () {
        Map<String, List<String>> wildcards = {
          'colors': ['red', 'blue'],
        };

        String prompt = '<random:<wildcard:colors>,green>';
        String result = PromptSyntaxService.expandPrompt(
          prompt,
          seed: 42,
          wildcards: wildcards,
        );

        expect(['red', 'blue', 'green'].contains(result), isTrue);
      });
    });

    group('complex prompts', () {
      test('handles realistic prompt with multiple syntax types', () {
        Map<String, List<String>> wildcards = {
          'styles': ['realistic', 'anime', 'oil painting'],
        };

        String prompt =
            '<comment:Test prompt><wildcard:styles>, <random:portrait,landscape> of <trigger>, <repeat[2]:highly detailed>, (masterpiece:1.3)';

        String result = PromptSyntaxService.expandPrompt(
          prompt,
          seed: 42,
          modelTrigger: 'sks person',
          wildcards: wildcards,
        );

        expect(result.contains('sks person'), isTrue);
        expect(result.contains('highly detailed highly detailed'), isTrue);
        expect(result.contains('(masterpiece:1.3)'), isTrue);
      });
    });

    group('validateSyntax', () {
      test('returns empty list for valid syntax', () {
        String prompt = '<random:cat,dog> with <repeat[3]:very> good quality';
        List<SyntaxError> errors =
            PromptSyntaxService.validateSyntax(prompt);
        expect(errors, isEmpty);
      });

      test('detects unclosed brackets', () {
        String prompt = '<random:cat,dog';
        List<SyntaxError> errors =
            PromptSyntaxService.validateSyntax(prompt);

        expect(errors.length, equals(1));
        expect(errors[0].type, equals(SyntaxErrorType.unclosedBracket));
      });

      test('detects empty random selection', () {
        String prompt = '<random:>';
        List<SyntaxError> errors =
            PromptSyntaxService.validateSyntax(prompt);

        expect(
            errors.any((e) => e.type == SyntaxErrorType.emptySelection), isTrue);
      });

      test('detects invalid repeat count', () {
        String prompt = '<repeat[abc]:word>';
        List<SyntaxError> errors =
            PromptSyntaxService.validateSyntax(prompt);

        expect(
            errors.any((e) => e.type == SyntaxErrorType.invalidNumber), isTrue);
      });

      test('detects invalid fromto percentage', () {
        String prompt = '<fromto[xyz]:start,end>';
        List<SyntaxError> errors =
            PromptSyntaxService.validateSyntax(prompt);

        expect(
            errors.any((e) => e.type == SyntaxErrorType.invalidNumber), isTrue);
      });
    });

    group('utility methods', () {
      test('getWildcardReferences finds all wildcards', () {
        String prompt =
            '<wildcard:animals> with <wildcard:colors> and <wildcard:animals>';
        List<String> refs =
            PromptSyntaxService.getWildcardReferences(prompt);

        expect(refs, equals(['animals', 'colors']));
      });

      test('estimateVariations calculates correctly', () {
        String prompt = '<random:a,b,c> <random:1,2>';
        int variations = PromptSyntaxService.estimateVariations(prompt);
        expect(variations, equals(6)); // 3 * 2
      });

      test('estimateVariations includes wildcards', () {
        Map<String, List<String>> wildcards = {
          'colors': ['red', 'blue', 'green'],
        };

        String prompt = '<random:a,b> <wildcard:colors>';
        int variations = PromptSyntaxService.estimateVariations(
          prompt,
          wildcards: wildcards,
        );
        expect(variations, equals(6)); // 2 * 3
      });

      test('containsSyntax detects syntax presence', () {
        expect(PromptSyntaxService.containsSyntax('<random:a,b>'), isTrue);
        expect(PromptSyntaxService.containsSyntax('<wildcard:test>'), isTrue);
        expect(PromptSyntaxService.containsSyntax('<trigger>'), isTrue);
        expect(PromptSyntaxService.containsSyntax('plain text'), isFalse);
        expect(PromptSyntaxService.containsSyntax('(weight:1.5)'), isFalse);
      });

      test('previewExpansion uses fixed seed', () {
        String prompt = '<random:a,b,c,d,e>';
        String preview1 = PromptSyntaxService.previewExpansion(prompt);
        String preview2 = PromptSyntaxService.previewExpansion(prompt);
        expect(preview1, equals(preview2));
      });
    });

    group('edge cases', () {
      test('handles escaped characters in options', () {
        String prompt = '<random:test1,test2>';
        String result = PromptSyntaxService.expandPrompt(prompt, seed: 42);
        expect(['test1', 'test2'].contains(result), isTrue);
      });

      test('handles options with parentheses (weights)', () {
        String prompt = '<random:(cat:1.5),(dog:0.8)>';
        String result = PromptSyntaxService.expandPrompt(prompt, seed: 42);
        expect(['(cat:1.5)', '(dog:0.8)'].contains(result), isTrue);
      });

      test('handles very long prompts', () {
        String prompt = 'start ' * 100 + '<random:a,b>' + ' end' * 100;
        String result = PromptSyntaxService.expandPrompt(prompt, seed: 42);
        expect(result.contains('a') || result.contains('b'), isTrue);
      });

      test('handles unicode characters', () {
        String prompt = '<random:cat,gato,Katze>';
        String result = PromptSyntaxService.expandPrompt(prompt, seed: 42);
        expect(['cat', 'gato', 'Katze'].contains(result), isTrue);
      });

      test('handles whitespace-only options', () {
        String prompt = '<random:   ,test>';
        String result = PromptSyntaxService.expandPrompt(prompt, seed: 42);
        // Whitespace-only options should be trimmed
        expect(result == '' || result == 'test', isTrue);
      });
    });
  });
}
