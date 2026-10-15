import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayi_android/theme/app_colors.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  for (final (name, c) in [('light', AppColors.light), ('dark', AppColors.dark)]) {
    group('$name palette', () {
      // Text that people read must pass WCAG AA (4.5:1).
      final readable = {
        'text on background': (c.text, c.background),
        'text on surface': (c.text, c.surface),
        'muted on background': (c.muted, c.background),
        'muted on surface': (c.muted, c.surface),
        'button text on primary': (c.onPrimary, c.primary),
        'success chip': (c.successText, c.successSoft),
        'warning chip': (c.warningText, c.warningSoft),
        'danger chip / button': (c.dangerText, c.dangerSoft),
        'invoice badge': (c.invoice, c.invoiceSoft),
        'transfer badge': (c.transfer, c.transferSoft),
        'return badge': (c.returnC, c.returnSoft),
        'accent text': (c.accentText, c.accentSoft),
        'text on the primary tint': (c.onPrimarySoft, c.primarySoft),
        'text on done card': (c.text, c.successCard),
        'text on scanning card': (c.text, c.accentSoft),
      };
      readable.forEach((label, pair) {
        test('$label ≥ 4.5', () {
          final r = contrast(pair.$1, pair.$2);
          expect(r, greaterThanOrEqualTo(4.5), reason: '$label is ${r.toStringAsFixed(2)}:1');
        });
      });

      test('hints / disabled text ≥ 3 (still readable)', () {
        expect(contrast(c.faint, c.surface), greaterThanOrEqualTo(3.0));
        expect(contrast(c.disabledFg, c.disabledBg), greaterThanOrEqualTo(3.0));
      });

      test('medium contrast: main text is NOT harsh (< 16:1; pure black/white is 21:1)', () {
        expect(contrast(c.text, c.background), lessThan(16));
        expect(contrast(c.text, c.surface), lessThan(16));
      });
    });
  }
}
