import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/core/constants/app_colors.dart';
import 'package:zyncro/core/theme/app_theme.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/design_system/tokens/zyncro_colors.dart';

void main() {
  test('le thème clair reprend exactement la palette historique', () {
    const c = ZyncroColors.light;
    expect(c.primary, AppColors.primary);
    expect(c.primaryDark, AppColors.primaryDark);
    expect(c.secondary, AppColors.secondary);
    expect(c.accent, AppColors.accent);
    expect(c.background, AppColors.background);
    expect(c.surface, AppColors.surface);
    expect(c.textPrimary, AppColors.textPrimary);
    expect(c.textSecondary, AppColors.textSecondary);
    expect(c.border, AppColors.border);
    expect(c.error, AppColors.error);
  });

  testWidgets('context.colors lit l\'extension du thème (shell compris)', (
    tester,
  ) async {
    late ZyncroColors seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themed(const Color(0xFFE85D75)),
        home: Builder(
          builder: (context) {
            seen = context.colors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.primary, AppColors.primary);
    expect(seen.background, AppColors.background);
  });

  test('lerp et copyWith', () {
    const c = ZyncroColors.light;
    expect(c.lerp(c, 0.5).primary, c.primary);
    expect(c.copyWith(error: Colors.black).error, Colors.black);
  });
}
