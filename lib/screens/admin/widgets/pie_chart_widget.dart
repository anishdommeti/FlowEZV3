import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/dimensions.dart';

class PieChartWidget extends StatelessWidget {
  const PieChartWidget({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<PieChartSectionData> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppDimensions.sectionSpacing),
            AspectRatio(
              aspectRatio: 1.1,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2.0,
                  centerSpaceRadius: 42.0,
                  sections: sections.isEmpty
                      ? [
                          PieChartSectionData(
                            value: 1.0,
                            color: theme.colorScheme.surfaceContainerHighest,
                            title: 'No data',
                            radius: 56.0,
                            titleStyle: theme.textTheme.bodySmall,
                          ),
                        ]
                      : sections,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
