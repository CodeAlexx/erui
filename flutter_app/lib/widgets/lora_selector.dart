import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lora_provider.dart';

class LoraSelector extends ConsumerWidget {
  const LoraSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lorasAsync = ref.watch(loraListProvider);
    final selectedLoras = ref.watch(selectedLorasProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('LoRAs', style: TextStyle(fontWeight: FontWeight.bold)),
            lorasAsync.when(
              data: (loras) => IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _showLoraDialog(context, ref, loras),
                tooltip: 'Add LoRA',
              ),
              loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const Icon(Icons.error, size: 20),
            ),
          ],
        ),
        if (selectedLoras.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No LoRAs selected', style: TextStyle(color: Colors.grey, fontSize: 12)),
          )
        else
          ...selectedLoras.map((selected) => _buildSelectedLora(context, ref, selected)),
      ],
    );
  }

  Widget _buildSelectedLora(BuildContext context, WidgetRef ref, SelectedLora selected) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    selected.lora.title,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => ref.read(selectedLorasProvider.notifier).removeLora(selected.lora.name),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Strength:', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: selected.strength,
                    min: 0,
                    max: 2,
                    divisions: 40,
                    onChanged: (v) => ref.read(selectedLorasProvider.notifier).updateStrength(selected.lora.name, v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(selected.strength.toStringAsFixed(2), style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLoraDialog(BuildContext context, WidgetRef ref, List<LoraModel> loras) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select LoRA'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: loras.isEmpty
              ? const Center(child: Text('No LoRAs found'))
              : ListView.builder(
                  itemCount: loras.length,
                  itemBuilder: (context, index) {
                    final lora = loras[index];
                    return ListTile(
                      title: Text(lora.title, style: const TextStyle(fontSize: 13)),
                      dense: true,
                      onTap: () {
                        ref.read(selectedLorasProvider.notifier).addLora(lora);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
