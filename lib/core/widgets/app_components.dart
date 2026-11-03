import 'package:flutter/material.dart';

import '../../../core/constants/dimensions.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: AppDimensions.tinySpacing),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.cardPadding),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title, subtitle: subtitle),
        const SizedBox(height: AppDimensions.contentSpacing),
        child,
      ],
    );
  }
}

class AppIconContainer extends StatelessWidget {
  const AppIconContainer({
    super.key,
    required this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: AppDimensions.iconContainerSize,
      height: AppDimensions.iconContainerSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      child: Icon(
        icon,
        size: AppDimensions.iconSize,
        color: foregroundColor ?? theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.buttonHeight,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon ?? Icons.check_rounded, size: AppDimensions.iconSize),
        label: Text(label),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          icon ?? Icons.arrow_forward_rounded,
          size: AppDimensions.iconSize,
        ),
        label: Text(label),
      ),
    );
  }
}

class ScreenPadding extends StatelessWidget {
  const ScreenPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      child: child,
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final IconData? icon;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: [
          if (icon != null) ...[
            AppIconContainer(
              icon: icon!,
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppDimensions.smallSpacing),
          ],
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: alignment == CrossAxisAlignment.center
                ? TextAlign.center
                : TextAlign.start,
          ),
          const SizedBox(height: AppDimensions.tinySpacing),
          Text(
            value,
            style: theme.textTheme.titleLarge,
            softWrap: true,
            textAlign: alignment == CrossAxisAlignment.center
                ? TextAlign.center
                : TextAlign.start,
          ),
        ],
      ),
    );
  }
}

class ResponsiveMetricGrid extends StatelessWidget {
  const ResponsiveMetricGrid({
    super.key,
    required this.children,
    this.minChildWidth = 180,
    this.mainAxisExtent,
  });

  final List<Widget> children;
  final double minChildWidth;
  final double? mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = (width / minChildWidth).floor().clamp(1, 4);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppDimensions.contentSpacing,
            mainAxisSpacing: AppDimensions.contentSpacing,
            mainAxisExtent: mainAxisExtent,
            childAspectRatio: mainAxisExtent == null ? 1.4 : 1,
          ),
          itemBuilder: (_, index) => children[index],
        );
      },
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.isOpen});

  final String label;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOpen ? theme.colorScheme.primary : theme.colorScheme.error;

    return Chip(
      label: Text(label),
      avatar: Icon(
        isOpen ? Icons.check_circle_outline : Icons.pause_circle_outline,
        size: 18,
        color: color,
      ),
      side: BorderSide(color: color.withValues(alpha: 0.18)),
      backgroundColor: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconContainer(icon: icon),
              const SizedBox(height: AppDimensions.contentSpacing),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.tinySpacing),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
