# App Theme System Guide

This document provides an overview of how to use the unified theme system throughout the app.

## Theme Structure

The theme system is organized into several files:

- `app_colors.dart` - Color definitions following Material Design conventions
- `app_typography.dart` - Text styles for different typographic needs
- `app_dimensions.dart` - Spacing, padding, and sizing constants
- `app_widget_themes.dart` - Widget-specific theme definitions
- `app_theme.dart` - Main theme file that combines everything

## How to Use the Theme

### In Your Widgets

Always use theme values from the appropriate theme files instead of hard-coding values:

```dart
// ✅ DO THIS: Use theme values
Widget build(BuildContext context) {
  // Access theme data
  final theme = Theme.of(context);
  
  return Container(
    padding: AppSpacing.paddingMedium,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.radiusMedium,
    ),
    child: Text(
      'Hello World',
      style: AppTypography.bodyLarge,
    ),
  );
}

// ❌ DON'T DO THIS: Hard-code values
Widget build(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      'Hello World',
      style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
    ),
  );
}
```

### For Colors

Use `AppColors` class constants:

```dart
Container(
  color: AppColors.primary,
  child: Text('Button', style: TextStyle(color: AppColors.onPrimary)),
)
```

### For Typography

Use `AppTypography` styles:

```dart
Text('Heading', style: AppTypography.headingLarge)
Text('Body text', style: AppTypography.bodyMedium)
```

### For Spacing and Dimensions

Use `AppSpacing` and `AppRadius` constants:

```dart
Padding(
  padding: AppSpacing.paddingMedium,
  child: Container(
    decoration: BoxDecoration(
      borderRadius: AppRadius.radiusLarge,
    ),
  ),
)
```

### For Themed Widgets

For widgets that automatically use theme data, you don't need to specify styling:

```dart
// These widgets will automatically use theme styling
ElevatedButton(
  onPressed: () {},
  child: Text('Styled Button'),
)

Card(
  child: Padding(
    padding: AppSpacing.paddingMedium,
    child: Text('Styled Card'),
  ),
)
```

## Consistent Theme Application

To maintain a consistent look and feel:

1. **Never hard-code colors** - Always use `AppColors` constants
2. **Use predefined spacing** - Use `AppSpacing` instead of arbitrary values
3. **Follow typography guidelines** - Use `AppTypography` for text styling
4. **Leverage themed widgets** - Let the theme system do the work

## Extending the Theme

If you need to add new theme values:

1. Add them to the appropriate file (`app_colors.dart`, `app_dimensions.dart`, etc.)
2. Follow the naming conventions of existing values
3. Document the new values with comments explaining their purpose
