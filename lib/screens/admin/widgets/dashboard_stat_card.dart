import 'package:flutter/material.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/widgets/app_components.dart';

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);

  return AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: AppDimensions.iconContainerSize,
          height: AppDimensions.iconContainerSize,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(
              AppDimensions.cardRadius,
            ),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),

        const SizedBox(height: AppDimensions.sectionSpacing),

        Text(
          title,
          style: theme.textTheme.titleMedium,
        ),

        const SizedBox(height: 8),

        Expanded(
  child: Align(
    alignment: Alignment.bottomLeft,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ),
),
      ],
    ),
  );
}
}
