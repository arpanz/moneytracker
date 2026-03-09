import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/theme/spacing.dart';

/// Custom calculator-style amount input widget.
///
/// Displays a large formatted amount at the top and a 4x3 numpad grid.
/// Supports up to 10 integer digits + 2 decimal places.
class AmountInputWidget extends StatefulWidget {
  /// Initial amount value (e.g. 1500.50).
  final double initialAmount;

  /// Called whenever the amount changes.
  final ValueChanged<double> onAmountChanged;

  /// Currency symbol shown before the amount.
  final String currencySymbol;

  /// Color accent for the amount display text.
  final Color? amountColor;

  const AmountInputWidget({
    super.key,
    this.initialAmount = 0.0,
    required this.onAmountChanged,
    this.currencySymbol = AppConstants.currencySymbol,
    this.amountColor,
  });

  @override
  State<AmountInputWidget> createState() => _AmountInputWidgetState();
}

class _AmountInputWidgetState extends State<AmountInputWidget> {
  /// Raw string representation of the entered digits (e.g. "150050" for 1500.50).
  String _rawInput = '';

  /// Whether a decimal point has been entered.
  bool _hasDecimal = false;

  /// Number of digits after the decimal point.
  int _decimalDigits = 0;

  /// Maximum integer digits (before decimal).
  static const int _maxIntegerDigits = 10;

  /// Maximum decimal digits.
  static const int _maxDecimalDigits = 2;

  final NumberFormat _formatter = NumberFormat('#,##,###.##', 'en_IN');

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount > 0) {
      _initFromAmount(widget.initialAmount);
    }
  }

  void _initFromAmount(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    if (decimalPart == '00') {
      _rawInput = integerPart;
      _hasDecimal = false;
      _decimalDigits = 0;
    } else if (decimalPart.endsWith('0')) {
      _rawInput = '$integerPart${decimalPart[0]}';
      _hasDecimal = true;
      _decimalDigits = 1;
    } else {
      _rawInput = '$integerPart$decimalPart';
      _hasDecimal = true;
      _decimalDigits = 2;
    }
  }

  double get _currentAmount {
    if (_rawInput.isEmpty) return 0.0;
    if (!_hasDecimal) {
      return double.tryParse(_rawInput) ?? 0.0;
    }
    final intLen = _rawInput.length - _decimalDigits;
    final intPart = _rawInput.substring(0, intLen);
    final decPart = _rawInput.substring(intLen);
    return double.tryParse('$intPart.$decPart') ?? 0.0;
  }

  String get _displayText {
    final amount = _currentAmount;
    if (_rawInput.isEmpty) return '0';

    if (!_hasDecimal) {
      return _formatter.format(amount.truncate());
    }

    final intPart = amount.truncate();
    final formattedInt = _formatter.format(intPart);
    final intLen = _rawInput.length - _decimalDigits;
    final decPart = _rawInput.substring(intLen);
    return '$formattedInt.$decPart';
  }

  void _onDigitPressed(String digit) {
    HapticFeedback.lightImpact();

    if (_hasDecimal) {
      if (_decimalDigits >= _maxDecimalDigits) return;
      _decimalDigits++;
    } else {
      // Count current integer digits
      final currentIntDigits = _rawInput.length;
      if (currentIntDigits >= _maxIntegerDigits) return;
      // Don't allow leading zeros for integer part
      if (_rawInput == '0' && digit == '0') return;
      if (_rawInput == '0' && digit != '0') {
        _rawInput = '';
      }
    }

    setState(() {
      _rawInput += digit;
    });
    widget.onAmountChanged(_currentAmount);
  }

  void _onDecimalPressed() {
    HapticFeedback.lightImpact();
    if (_hasDecimal) return;

    setState(() {
      _hasDecimal = true;
      if (_rawInput.isEmpty) {
        _rawInput = '0';
      }
    });
    widget.onAmountChanged(_currentAmount);
  }

  void _onBackspacePressed() {
    HapticFeedback.mediumImpact();
    if (_rawInput.isEmpty) return;

    setState(() {
      if (_hasDecimal && _decimalDigits > 0) {
        _rawInput = _rawInput.substring(0, _rawInput.length - 1);
        _decimalDigits--;
        if (_decimalDigits == 0) {
          _hasDecimal = false;
        }
      } else if (_hasDecimal && _decimalDigits == 0) {
        // Just remove the decimal point state
        _hasDecimal = false;
      } else {
        _rawInput = _rawInput.substring(0, _rawInput.length - 1);
      }
    });
    widget.onAmountChanged(_currentAmount);
  }

  void _onClearAll() {
    HapticFeedback.heavyImpact();
    setState(() {
      _rawInput = '';
      _hasDecimal = false;
      _decimalDigits = 0;
    });
    widget.onAmountChanged(0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayColor =
        widget.amountColor ?? theme.colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Amount Display ──
        Padding(
          padding: Spacing.horizontalMd,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  widget.currencySymbol,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: displayColor.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  _hasDecimal && _decimalDigits == 0
                      ? '$_displayText.'
                      : _displayText,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: displayColor,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: Spacing.lg),

        // ── Numpad Grid ──
        _buildNumpad(context),
      ],
    );
  }

  Widget _buildNumpad(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = theme.colorScheme.surfaceContainerHighest;
    final textColor = theme.colorScheme.onSurface;

    return Padding(
      padding: Spacing.horizontalMd,
      child: Column(
        children: [
          _buildRow(['1', '2', '3'], buttonColor, textColor),
          const SizedBox(height: Spacing.sm),
          _buildRow(['4', '5', '6'], buttonColor, textColor),
          const SizedBox(height: Spacing.sm),
          _buildRow(['7', '8', '9'], buttonColor, textColor),
          const SizedBox(height: Spacing.sm),
          _buildBottomRow(buttonColor, textColor),
        ],
      ),
    );
  }

  Widget _buildRow(
    List<String> digits,
    Color buttonColor,
    Color textColor,
  ) {
    return Row(
      children: digits.map((digit) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _NumpadButton(
              label: digit,
              color: buttonColor,
              textColor: textColor,
              onTap: () => _onDigitPressed(digit),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow(Color buttonColor, Color textColor) {
    return Row(
      children: [
        // Decimal point
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _NumpadButton(
              label: '.',
              color: buttonColor,
              textColor: textColor,
              onTap: _onDecimalPressed,
            ),
          ),
        ),
        // Zero
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _NumpadButton(
              label: '0',
              color: buttonColor,
              textColor: textColor,
              onTap: () => _onDigitPressed('0'),
            ),
          ),
        ),
        // Backspace
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _NumpadButton(
              icon: Icons.backspace_outlined,
              color: buttonColor,
              textColor: textColor,
              onTap: _onBackspacePressed,
              onLongPress: _onClearAll,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Numpad Button ───────────────────────────────────────────────────────────

class _NumpadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NumpadButton({
    this.label,
    this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: Radii.borderMd,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: Radii.borderMd,
        child: SizedBox(
          height: 56,
          child: Center(
            child: icon != null
                ? Icon(icon, color: textColor, size: 24)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
