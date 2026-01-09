import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../services/storage_service.dart';
import '../../services/api_service.dart';

/// Usage Analytics Screen
///
/// Displays comprehensive usage statistics including:
/// - Total generations count
/// - Images vs Videos breakdown
/// - Most used models chart/list
/// - Most used LoRAs chart/list
/// - Generation time statistics (avg, min, max)
/// - Daily/weekly/monthly usage chart
/// - Storage usage display
/// - Export stats to JSON
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateRangeFilter _dateFilter = DateRangeFilter.allTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load analytics data on init
    Future.microtask(() {
      ref.read(analyticsProvider.notifier).loadAnalytics();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Analytics'),
        actions: [
          // Date filter dropdown
          PopupMenuButton<DateRangeFilter>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Filter by date',
            onSelected: (filter) {
              setState(() => _dateFilter = filter);
              ref.read(analyticsProvider.notifier).setDateFilter(filter);
            },
            itemBuilder: (context) => DateRangeFilter.values.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Row(
                  children: [
                    if (_dateFilter == filter)
                      Icon(Icons.check, size: 18, color: colorScheme.primary),
                    if (_dateFilter != filter) const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(_getFilterLabel(filter)),
                  ],
                ),
              );
            }).toList(),
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(analyticsProvider.notifier).loadAnalytics(),
          ),
          // Export button
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to JSON',
            onPressed: analytics.isLoading
                ? null
                : () => _exportToJson(context, analytics),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Models & LoRAs', icon: Icon(Icons.view_module)),
            Tab(text: 'Timeline', icon: Icon(Icons.timeline)),
          ],
        ),
      ),
      body: analytics.isLoading
          ? const Center(child: CircularProgressIndicator())
          : analytics.error != null
              ? _buildErrorState(analytics.error!)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(analytics: analytics),
                    _ModelsTab(analytics: analytics),
                    _TimelineTab(analytics: analytics),
                  ],
                ),
    );
  }

  Widget _buildErrorState(String error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text('Failed to load analytics', style: TextStyle(color: colorScheme.error)),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => ref.read(analyticsProvider.notifier).loadAnalytics(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _getFilterLabel(DateRangeFilter filter) {
    switch (filter) {
      case DateRangeFilter.today:
        return 'Today';
      case DateRangeFilter.last7Days:
        return 'Last 7 Days';
      case DateRangeFilter.last30Days:
        return 'Last 30 Days';
      case DateRangeFilter.last90Days:
        return 'Last 90 Days';
      case DateRangeFilter.thisMonth:
        return 'This Month';
      case DateRangeFilter.thisYear:
        return 'This Year';
      case DateRangeFilter.allTime:
        return 'All Time';
    }
  }

  Future<void> _exportToJson(BuildContext context, AnalyticsState analytics) async {
    try {
      final json = analytics.toJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      // Let user pick save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Analytics',
        fileName: 'eriui_analytics_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported to ${file.path}'),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Overview tab with summary statistics
class _OverviewTab extends StatelessWidget {
  final AnalyticsState analytics;

  const _OverviewTab({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards row
          _SummaryCardsGrid(analytics: analytics),
          const SizedBox(height: 24),

          // Images vs Videos breakdown
          _SectionHeader(title: 'Generation Types', icon: Icons.pie_chart),
          const SizedBox(height: 12),
          _GenerationTypeBreakdown(analytics: analytics),
          const SizedBox(height: 24),

          // Generation time statistics
          _SectionHeader(title: 'Generation Time', icon: Icons.timer),
          const SizedBox(height: 12),
          _GenerationTimeStats(analytics: analytics),
          const SizedBox(height: 24),

          // Storage usage
          _SectionHeader(title: 'Storage Usage', icon: Icons.storage),
          const SizedBox(height: 12),
          _StorageUsageCard(analytics: analytics),
        ],
      ),
    );
  }
}

/// Summary cards grid
class _SummaryCardsGrid extends StatelessWidget {
  final AnalyticsState analytics;

  const _SummaryCardsGrid({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCard(
              title: 'Total Generations',
              value: _formatNumber(analytics.totalGenerations),
              icon: Icons.auto_awesome,
              color: Colors.blue,
            ),
            _StatCard(
              title: 'Images',
              value: _formatNumber(analytics.totalImages),
              icon: Icons.image,
              color: Colors.green,
            ),
            _StatCard(
              title: 'Videos',
              value: _formatNumber(analytics.totalVideos),
              icon: Icons.videocam,
              color: Colors.purple,
            ),
            _StatCard(
              title: 'Models Used',
              value: analytics.modelUsage.length.toString(),
              icon: Icons.view_module,
              color: Colors.orange,
            ),
          ],
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Single stat card
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Images vs Videos breakdown
class _GenerationTypeBreakdown extends StatelessWidget {
  final AnalyticsState analytics;

  const _GenerationTypeBreakdown({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = analytics.totalImages + analytics.totalVideos;
    final imagePercent = total > 0 ? (analytics.totalImages / total * 100) : 0.0;
    final videoPercent = total > 0 ? (analytics.totalVideos / total * 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Visual bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: [
                    if (analytics.totalImages > 0)
                      Expanded(
                        flex: analytics.totalImages,
                        child: Container(color: Colors.green),
                      ),
                    if (analytics.totalVideos > 0)
                      Expanded(
                        flex: analytics.totalVideos,
                        child: Container(color: Colors.purple),
                      ),
                    if (total == 0)
                      Expanded(
                        child: Container(color: colorScheme.surfaceContainerHighest),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendItem(
                  color: Colors.green,
                  label: 'Images',
                  value: '${analytics.totalImages} (${imagePercent.toStringAsFixed(1)}%)',
                ),
                _LegendItem(
                  color: Colors.purple,
                  label: 'Videos',
                  value: '${analytics.totalVideos} (${videoPercent.toStringAsFixed(1)}%)',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Legend item for charts
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

/// Generation time statistics
class _GenerationTimeStats extends StatelessWidget {
  final AnalyticsState analytics;

  const _GenerationTimeStats({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _TimeStatItem(
                label: 'Average',
                value: _formatDuration(analytics.avgGenerationTime),
                icon: Icons.trending_flat,
                color: colorScheme.primary,
              ),
            ),
            Container(
              width: 1,
              height: 60,
              color: colorScheme.outlineVariant,
            ),
            Expanded(
              child: _TimeStatItem(
                label: 'Minimum',
                value: _formatDuration(analytics.minGenerationTime),
                icon: Icons.speed,
                color: Colors.green,
              ),
            ),
            Container(
              width: 1,
              height: 60,
              color: colorScheme.outlineVariant,
            ),
            Expanded(
              child: _TimeStatItem(
                label: 'Maximum',
                value: _formatDuration(analytics.maxGenerationTime),
                icon: Icons.hourglass_bottom,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '-';
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }
}

/// Time stat item
class _TimeStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TimeStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

/// Storage usage card
class _StorageUsageCard extends StatelessWidget {
  final AnalyticsState analytics;

  const _StorageUsageCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usedPercent = analytics.totalStorageBytes > 0
        ? (analytics.usedStorageBytes / analytics.totalStorageBytes * 100)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatBytes(analytics.usedStorageBytes),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'of ${_formatBytes(analytics.totalStorageBytes)}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usedPercent / 100,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  usedPercent > 90
                      ? colorScheme.error
                      : usedPercent > 70
                          ? Colors.orange
                          : colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${usedPercent.toStringAsFixed(1)}% used',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                Text(
                  '${_formatBytes(analytics.totalStorageBytes - analytics.usedStorageBytes)} free',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Breakdown by type
            Row(
              children: [
                Expanded(
                  child: _StorageBreakdownItem(
                    label: 'Images',
                    bytes: analytics.imageStorageBytes,
                    icon: Icons.image,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StorageBreakdownItem(
                    label: 'Videos',
                    bytes: analytics.videoStorageBytes,
                    icon: Icons.videocam,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

/// Storage breakdown item
class _StorageBreakdownItem extends StatelessWidget {
  final String label;
  final int bytes;
  final IconData icon;
  final Color color;

  const _StorageBreakdownItem({
    required this.label,
    required this.bytes,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
              Text(
                _formatBytes(bytes),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

/// Models & LoRAs tab
class _ModelsTab extends StatelessWidget {
  final AnalyticsState analytics;

  const _ModelsTab({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Most used models
          _SectionHeader(title: 'Most Used Models', icon: Icons.view_module),
          const SizedBox(height: 12),
          _UsageList(
            items: analytics.modelUsage,
            maxItems: 10,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),

          // Most used LoRAs
          _SectionHeader(title: 'Most Used LoRAs', icon: Icons.layers),
          const SizedBox(height: 12),
          analytics.loraUsage.isEmpty
              ? _EmptyUsageCard(message: 'No LoRA usage data')
              : _UsageList(
                  items: analytics.loraUsage,
                  maxItems: 10,
                  color: Colors.orange,
                ),
        ],
      ),
    );
  }
}

/// Usage list for models/LoRAs
class _UsageList extends StatelessWidget {
  final Map<String, int> items;
  final int maxItems;
  final Color color;

  const _UsageList({
    required this.items,
    required this.maxItems,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sortedItems = items.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayItems = sortedItems.take(maxItems).toList();
    final maxCount = displayItems.isNotEmpty ? displayItems.first.value : 1;

    if (displayItems.isEmpty) {
      return _EmptyUsageCard(message: 'No usage data');
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayItems.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: colorScheme.outlineVariant,
        ),
        itemBuilder: (context, index) {
          final item = displayItems[index];
          final percent = maxCount > 0 ? item.value / maxCount : 0.0;
          final displayName = _getDisplayName(item.key);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.value}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 4,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getDisplayName(String fullName) {
    final parts = fullName.split('/');
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }
}

/// Empty usage card
class _EmptyUsageCard extends StatelessWidget {
  final String message;

  const _EmptyUsageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 32, color: colorScheme.outlineVariant),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Timeline tab with daily/weekly/monthly charts
class _TimelineTab extends StatefulWidget {
  final AnalyticsState analytics;

  const _TimelineTab({required this.analytics});

  @override
  State<_TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<_TimelineTab> {
  TimelineGrouping _grouping = TimelineGrouping.daily;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grouping selector
          Row(
            children: [
              const _SectionHeader(title: 'Usage Over Time', icon: Icons.show_chart),
              const Spacer(),
              SegmentedButton<TimelineGrouping>(
                segments: const [
                  ButtonSegment(value: TimelineGrouping.daily, label: Text('Day')),
                  ButtonSegment(value: TimelineGrouping.weekly, label: Text('Week')),
                  ButtonSegment(value: TimelineGrouping.monthly, label: Text('Month')),
                ],
                selected: {_grouping},
                onSelectionChanged: (selection) {
                  setState(() => _grouping = selection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TimelineChart(
            data: _getGroupedData(),
            grouping: _grouping,
          ),
          const SizedBox(height: 24),

          // Recent activity
          const _SectionHeader(title: 'Recent Activity', icon: Icons.history),
          const SizedBox(height: 12),
          _RecentActivityList(activities: widget.analytics.recentActivity),
        ],
      ),
    );
  }

  Map<DateTime, int> _getGroupedData() {
    switch (_grouping) {
      case TimelineGrouping.daily:
        return widget.analytics.dailyUsage;
      case TimelineGrouping.weekly:
        return widget.analytics.weeklyUsage;
      case TimelineGrouping.monthly:
        return widget.analytics.monthlyUsage;
    }
  }
}

/// Timeline chart
class _TimelineChart extends StatelessWidget {
  final Map<DateTime, int> data;
  final TimelineGrouping grouping;

  const _TimelineChart({
    required this.data,
    required this.grouping,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.bar_chart, size: 48, color: colorScheme.outlineVariant),
                const SizedBox(height: 8),
                Text(
                  'No usage data for this period',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxValue = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Chart
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: sortedEntries.map((entry) {
                  final height = maxValue > 0 ? (entry.value / maxValue * 180) : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Tooltip(
                        message: '${_formatDate(entry.key)}: ${entry.value}',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (entry.value > 0)
                              Text(
                                '${entry.value}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            Container(
                              height: height.clamp(2.0, 180.0),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // X-axis labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (sortedEntries.isNotEmpty)
                  Text(
                    _formatDate(sortedEntries.first.key),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (sortedEntries.length > 1)
                  Text(
                    _formatDate(sortedEntries.last.key),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    switch (grouping) {
      case TimelineGrouping.daily:
        return DateFormat('MMM d').format(date);
      case TimelineGrouping.weekly:
        return 'Week ${DateFormat('w').format(date)}';
      case TimelineGrouping.monthly:
        return DateFormat('MMM yyyy').format(date);
    }
  }
}

/// Recent activity list
class _RecentActivityList extends StatelessWidget {
  final List<ActivityEntry> activities;

  const _RecentActivityList({required this.activities});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (activities.isEmpty) {
      return _EmptyUsageCard(message: 'No recent activity');
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.take(20).length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: colorScheme.outlineVariant,
        ),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return ListTile(
            leading: Icon(
              activity.isVideo ? Icons.videocam : Icons.image,
              color: activity.isVideo ? Colors.purple : Colors.green,
            ),
            title: Text(
              activity.modelName ?? 'Unknown model',
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatActivityTime(activity.timestamp),
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
            trailing: activity.duration != null
                ? Text(
                    '${activity.duration!.inSeconds}s',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  )
                : null,
          );
        },
      ),
    );
  }

  String _formatActivityTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return DateFormat('MMM d, y').format(time);
  }
}

// =============================================================================
// State Management
// =============================================================================

/// Analytics provider
final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AnalyticsNotifier(apiService);
});

/// Date range filter
enum DateRangeFilter {
  today,
  last7Days,
  last30Days,
  last90Days,
  thisMonth,
  thisYear,
  allTime,
}

/// Timeline grouping
enum TimelineGrouping {
  daily,
  weekly,
  monthly,
}

/// Activity entry
class ActivityEntry {
  final DateTime timestamp;
  final String? modelName;
  final bool isVideo;
  final Duration? duration;
  final String? prompt;

  const ActivityEntry({
    required this.timestamp,
    this.modelName,
    this.isVideo = false,
    this.duration,
    this.prompt,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      modelName: json['model'] as String?,
      isVideo: json['is_video'] as bool? ?? false,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
      prompt: json['prompt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'model': modelName,
        'is_video': isVideo,
        'duration': duration?.inSeconds,
        'prompt': prompt,
      };
}

/// Analytics state
class AnalyticsState {
  final bool isLoading;
  final String? error;
  final DateRangeFilter dateFilter;

  // Summary stats
  final int totalGenerations;
  final int totalImages;
  final int totalVideos;

  // Model/LoRA usage
  final Map<String, int> modelUsage;
  final Map<String, int> loraUsage;

  // Time statistics
  final Duration avgGenerationTime;
  final Duration minGenerationTime;
  final Duration maxGenerationTime;

  // Timeline data
  final Map<DateTime, int> dailyUsage;
  final Map<DateTime, int> weeklyUsage;
  final Map<DateTime, int> monthlyUsage;

  // Recent activity
  final List<ActivityEntry> recentActivity;

  // Storage
  final int usedStorageBytes;
  final int totalStorageBytes;
  final int imageStorageBytes;
  final int videoStorageBytes;

  const AnalyticsState({
    this.isLoading = false,
    this.error,
    this.dateFilter = DateRangeFilter.allTime,
    this.totalGenerations = 0,
    this.totalImages = 0,
    this.totalVideos = 0,
    this.modelUsage = const {},
    this.loraUsage = const {},
    this.avgGenerationTime = Duration.zero,
    this.minGenerationTime = Duration.zero,
    this.maxGenerationTime = Duration.zero,
    this.dailyUsage = const {},
    this.weeklyUsage = const {},
    this.monthlyUsage = const {},
    this.recentActivity = const [],
    this.usedStorageBytes = 0,
    this.totalStorageBytes = 0,
    this.imageStorageBytes = 0,
    this.videoStorageBytes = 0,
  });

  AnalyticsState copyWith({
    bool? isLoading,
    String? error,
    DateRangeFilter? dateFilter,
    int? totalGenerations,
    int? totalImages,
    int? totalVideos,
    Map<String, int>? modelUsage,
    Map<String, int>? loraUsage,
    Duration? avgGenerationTime,
    Duration? minGenerationTime,
    Duration? maxGenerationTime,
    Map<DateTime, int>? dailyUsage,
    Map<DateTime, int>? weeklyUsage,
    Map<DateTime, int>? monthlyUsage,
    List<ActivityEntry>? recentActivity,
    int? usedStorageBytes,
    int? totalStorageBytes,
    int? imageStorageBytes,
    int? videoStorageBytes,
  }) {
    return AnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      dateFilter: dateFilter ?? this.dateFilter,
      totalGenerations: totalGenerations ?? this.totalGenerations,
      totalImages: totalImages ?? this.totalImages,
      totalVideos: totalVideos ?? this.totalVideos,
      modelUsage: modelUsage ?? this.modelUsage,
      loraUsage: loraUsage ?? this.loraUsage,
      avgGenerationTime: avgGenerationTime ?? this.avgGenerationTime,
      minGenerationTime: minGenerationTime ?? this.minGenerationTime,
      maxGenerationTime: maxGenerationTime ?? this.maxGenerationTime,
      dailyUsage: dailyUsage ?? this.dailyUsage,
      weeklyUsage: weeklyUsage ?? this.weeklyUsage,
      monthlyUsage: monthlyUsage ?? this.monthlyUsage,
      recentActivity: recentActivity ?? this.recentActivity,
      usedStorageBytes: usedStorageBytes ?? this.usedStorageBytes,
      totalStorageBytes: totalStorageBytes ?? this.totalStorageBytes,
      imageStorageBytes: imageStorageBytes ?? this.imageStorageBytes,
      videoStorageBytes: videoStorageBytes ?? this.videoStorageBytes,
    );
  }

  /// Convert state to JSON for export
  Map<String, dynamic> toJson() => {
        'export_date': DateTime.now().toIso8601String(),
        'date_filter': dateFilter.name,
        'summary': {
          'total_generations': totalGenerations,
          'total_images': totalImages,
          'total_videos': totalVideos,
        },
        'model_usage': modelUsage,
        'lora_usage': loraUsage,
        'generation_time': {
          'average_seconds': avgGenerationTime.inSeconds,
          'min_seconds': minGenerationTime.inSeconds,
          'max_seconds': maxGenerationTime.inSeconds,
        },
        'timeline': {
          'daily': dailyUsage.map((k, v) => MapEntry(k.toIso8601String(), v)),
          'weekly': weeklyUsage.map((k, v) => MapEntry(k.toIso8601String(), v)),
          'monthly': monthlyUsage.map((k, v) => MapEntry(k.toIso8601String(), v)),
        },
        'storage': {
          'used_bytes': usedStorageBytes,
          'total_bytes': totalStorageBytes,
          'image_bytes': imageStorageBytes,
          'video_bytes': videoStorageBytes,
        },
        'recent_activity': recentActivity.map((a) => a.toJson()).toList(),
      };
}

/// Analytics notifier
class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final ApiService _apiService;

  AnalyticsNotifier(this._apiService) : super(const AnalyticsState());

  /// Load analytics data
  Future<void> loadAnalytics() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load from local storage first (cached data)
      await _loadFromLocalStorage();

      // Try to fetch fresh data from API
      await _fetchFromApi();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Set date filter and reload
  void setDateFilter(DateRangeFilter filter) {
    state = state.copyWith(dateFilter: filter);
    loadAnalytics();
  }

  /// Load cached analytics from local storage
  Future<void> _loadFromLocalStorage() async {
    final cachedData = StorageService.getMap('analytics_cache');
    if (cachedData != null) {
      _applyAnalyticsData(cachedData);
    }
  }

  /// Fetch analytics from API
  Future<void> _fetchFromApi() async {
    try {
      // Calculate date range based on filter
      final dateRange = _getDateRange(state.dateFilter);

      // Fetch analytics data from backend
      final response = await _apiService.post<Map<String, dynamic>>(
        '/API/GetAnalytics',
        data: {
          'start_date': dateRange.start.toIso8601String(),
          'end_date': dateRange.end.toIso8601String(),
        },
      );

      if (response.isSuccess && response.data != null) {
        _applyAnalyticsData(response.data!);
        // Cache the data
        await StorageService.setMap('analytics_cache', response.data!);
      }
    } catch (e) {
      // If API fails, use local tracking data
      await _loadLocalTrackingData();
    }
  }

  /// Load locally tracked analytics data
  Future<void> _loadLocalTrackingData() async {
    // Load generation history from local storage
    final history = StorageService.getStringList('generation_history') ?? [];
    final modelCounts = <String, int>{};
    final loraCounts = <String, int>{};
    int imageCount = 0;
    int videoCount = 0;
    final dailyCounts = <DateTime, int>{};
    final durations = <int>[];
    final activities = <ActivityEntry>[];

    for (final entry in history) {
      try {
        final data = jsonDecode(entry) as Map<String, dynamic>;
        final timestamp = DateTime.parse(data['timestamp'] as String);
        final model = data['model'] as String?;
        final isVideo = data['is_video'] as bool? ?? false;
        final duration = data['duration'] as int?;

        // Count by type
        if (isVideo) {
          videoCount++;
        } else {
          imageCount++;
        }

        // Count by model
        if (model != null) {
          modelCounts[model] = (modelCounts[model] ?? 0) + 1;
        }

        // Count LoRAs
        final loras = data['loras'] as List?;
        if (loras != null) {
          for (final lora in loras) {
            final loraName = lora as String;
            loraCounts[loraName] = (loraCounts[loraName] ?? 0) + 1;
          }
        }

        // Daily counts
        final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
        dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;

        // Durations
        if (duration != null) {
          durations.add(duration);
        }

        // Activity entry
        activities.add(ActivityEntry(
          timestamp: timestamp,
          modelName: model,
          isVideo: isVideo,
          duration: duration != null ? Duration(seconds: duration) : null,
        ));
      } catch (e) {
        // Skip invalid entries
      }
    }

    // Calculate duration stats
    Duration avgDuration = Duration.zero;
    Duration minDuration = Duration.zero;
    Duration maxDuration = Duration.zero;

    if (durations.isNotEmpty) {
      final totalSeconds = durations.reduce((a, b) => a + b);
      avgDuration = Duration(seconds: totalSeconds ~/ durations.length);
      minDuration = Duration(seconds: durations.reduce((a, b) => a < b ? a : b));
      maxDuration = Duration(seconds: durations.reduce((a, b) => a > b ? a : b));
    }

    // Calculate weekly and monthly from daily
    final weeklyCounts = <DateTime, int>{};
    final monthlyCounts = <DateTime, int>{};

    for (final entry in dailyCounts.entries) {
      // Weekly (start of week)
      final weekStart = entry.key.subtract(Duration(days: entry.key.weekday - 1));
      final weekKey = DateTime(weekStart.year, weekStart.month, weekStart.day);
      weeklyCounts[weekKey] = (weeklyCounts[weekKey] ?? 0) + entry.value;

      // Monthly
      final monthKey = DateTime(entry.key.year, entry.key.month);
      monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + entry.value;
    }

    // Sort activities by timestamp (most recent first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    state = state.copyWith(
      totalGenerations: imageCount + videoCount,
      totalImages: imageCount,
      totalVideos: videoCount,
      modelUsage: modelCounts,
      loraUsage: loraCounts,
      avgGenerationTime: avgDuration,
      minGenerationTime: minDuration,
      maxGenerationTime: maxDuration,
      dailyUsage: dailyCounts,
      weeklyUsage: weeklyCounts,
      monthlyUsage: monthlyCounts,
      recentActivity: activities,
    );
  }

  /// Apply analytics data from response
  void _applyAnalyticsData(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final timeData = data['generation_time'] as Map<String, dynamic>? ?? {};
    final timeline = data['timeline'] as Map<String, dynamic>? ?? {};
    final storage = data['storage'] as Map<String, dynamic>? ?? {};

    state = state.copyWith(
      totalGenerations: summary['total_generations'] as int? ?? 0,
      totalImages: summary['total_images'] as int? ?? 0,
      totalVideos: summary['total_videos'] as int? ?? 0,
      modelUsage: _parseUsageMap(data['model_usage']),
      loraUsage: _parseUsageMap(data['lora_usage']),
      avgGenerationTime: Duration(seconds: timeData['average_seconds'] as int? ?? 0),
      minGenerationTime: Duration(seconds: timeData['min_seconds'] as int? ?? 0),
      maxGenerationTime: Duration(seconds: timeData['max_seconds'] as int? ?? 0),
      dailyUsage: _parseTimelineMap(timeline['daily']),
      weeklyUsage: _parseTimelineMap(timeline['weekly']),
      monthlyUsage: _parseTimelineMap(timeline['monthly']),
      usedStorageBytes: storage['used_bytes'] as int? ?? 0,
      totalStorageBytes: storage['total_bytes'] as int? ?? 0,
      imageStorageBytes: storage['image_bytes'] as int? ?? 0,
      videoStorageBytes: storage['video_bytes'] as int? ?? 0,
      recentActivity: _parseActivityList(data['recent_activity']),
    );
  }

  Map<String, int> _parseUsageMap(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) {
      return data.map((k, v) => MapEntry(k, (v as num).toInt()));
    }
    return {};
  }

  Map<DateTime, int> _parseTimelineMap(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) {
      return data.map((k, v) => MapEntry(DateTime.parse(k), (v as num).toInt()));
    }
    return {};
  }

  List<ActivityEntry> _parseActivityList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data
          .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get date range for filter
  DateTimeRange _getDateRange(DateRangeFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case DateRangeFilter.today:
        return DateTimeRange(start: today, end: now);
      case DateRangeFilter.last7Days:
        return DateTimeRange(start: today.subtract(const Duration(days: 7)), end: now);
      case DateRangeFilter.last30Days:
        return DateTimeRange(start: today.subtract(const Duration(days: 30)), end: now);
      case DateRangeFilter.last90Days:
        return DateTimeRange(start: today.subtract(const Duration(days: 90)), end: now);
      case DateRangeFilter.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case DateRangeFilter.thisYear:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case DateRangeFilter.allTime:
        return DateTimeRange(start: DateTime(2020, 1, 1), end: now);
    }
  }

  /// Record a new generation (call this when generation completes)
  Future<void> recordGeneration({
    required String model,
    required bool isVideo,
    Duration? duration,
    List<String>? loras,
    String? prompt,
  }) async {
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'model': model,
      'is_video': isVideo,
      'duration': duration?.inSeconds,
      'loras': loras,
      'prompt': prompt,
    };

    // Add to local history
    final history = StorageService.getStringList('generation_history') ?? [];
    history.insert(0, jsonEncode(entry));

    // Keep last 10000 entries
    if (history.length > 10000) {
      history.removeRange(10000, history.length);
    }

    await StorageService.setStringList('generation_history', history);

    // Update current state
    final newActivity = ActivityEntry(
      timestamp: DateTime.now(),
      modelName: model,
      isVideo: isVideo,
      duration: duration,
      prompt: prompt,
    );

    state = state.copyWith(
      totalGenerations: state.totalGenerations + 1,
      totalImages: isVideo ? state.totalImages : state.totalImages + 1,
      totalVideos: isVideo ? state.totalVideos + 1 : state.totalVideos,
      modelUsage: {
        ...state.modelUsage,
        model: (state.modelUsage[model] ?? 0) + 1,
      },
      recentActivity: [newActivity, ...state.recentActivity.take(99)],
    );
  }
}
