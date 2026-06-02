import 'package:flutter/material.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.suffixIcon,
    this.enabled = true,
    this.autovalidateMode,
    this.fillColor,
    this.focusFillColor,
    this.borderColor,
    this.focusBorderColor,
    this.iconColor,
    this.focusIconColor,
    this.borderRadius = 12,
    this.textStyle,
    this.hintStyle,
    this.labelStyle,
    this.floatingLabelBehavior,
    this.onFieldSubmitted,
    this.autofillHints,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.showCounter = true,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final Color? fillColor;
  final Color? focusFillColor;
  final Color? borderColor;
  final Color? focusBorderColor;
  final Color? iconColor;
  final Color? focusIconColor;
  final double borderRadius;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final TextStyle? labelStyle;
  final FloatingLabelBehavior? floatingLabelBehavior;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool showCounter;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final fill = widget.fillColor ?? palette.cardSurface;
    final focusFill = widget.focusFillColor ?? palette.softSurface;
    final border = widget.borderColor ?? palette.divider;
    final focusBorder = widget.focusBorderColor ?? palette.brandPrimary;
    final icon = widget.iconColor ?? palette.textSecondary;
    final focusIcon = widget.focusIconColor ?? palette.brandPrimary;
    final textStyle =
        widget.textStyle ??
        AppTypography.body.copyWith(color: palette.textPrimary);
    final hintStyle =
        widget.hintStyle ??
        AppTypography.body.copyWith(color: palette.textSecondary);
    final labelStyle =
        widget.labelStyle ??
        AppTypography.caption.copyWith(color: palette.textSecondary);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onFieldSubmitted,
        textInputAction: widget.textInputAction,
        enabled: widget.enabled,
        autovalidateMode: widget.autovalidateMode,
        autofillHints: widget.autofillHints,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        textCapitalization: widget.textCapitalization,
        maxLength: widget.maxLength,
        buildCounter: widget.showCounter
            ? null
            : (
                BuildContext context, {
                required int currentLength,
                required bool isFocused,
                required int? maxLength,
              }) => null,
        style: textStyle,
        decoration: InputDecoration(
          hintText: widget.hintText,
          labelText: widget.labelText,
          hintStyle: hintStyle,
          labelStyle: labelStyle,
          floatingLabelStyle: labelStyle,
          floatingLabelBehavior:
              widget.floatingLabelBehavior ?? FloatingLabelBehavior.auto,
          prefixIcon: widget.prefixIcon == null
              ? null
              : Icon(
                  widget.prefixIcon,
                  color: _isFocused ? focusIcon : icon,
                  size: 20,
                ),
          suffixIcon: widget.suffixIcon,
          contentPadding: AppSpacing.inputContent,
          filled: true,
          fillColor: _isFocused ? focusFill : fill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            borderSide: BorderSide(color: focusBorder, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            borderSide: BorderSide(color: errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            borderSide: BorderSide(color: errorColor, width: 1.6),
          ),
        ),
      ),
    );
  }
}
