import 'package:flutter/material.dart';

enum AppAlertType { success, warning, error, info }

class AppAlert {
  const AppAlert._();

  static Future<void> success(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return _show(
      context,
      type: AppAlertType.success,
      title: title,
      message: message,
    );
  }

  static Future<void> warning(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return _show(
      context,
      type: AppAlertType.warning,
      title: title,
      message: message,
    );
  }

  static Future<void> error(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return _show(
      context,
      type: AppAlertType.error,
      title: title,
      message: message,
    );
  }

  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Ya',
    String cancelText = 'Batal',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AppAlertDialog(
        type: AppAlertType.warning,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        showCancel: true,
      ),
    );
    return result ?? false;
  }

  static Future<void> _show(
    BuildContext context, {
    required AppAlertType type,
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AppAlertDialog(
        type: type,
        title: title,
        message: message,
        confirmText: 'OK',
      ),
    );
  }
}

class _AppAlertDialog extends StatefulWidget {
  const _AppAlertDialog({
    required this.type,
    required this.title,
    required this.message,
    required this.confirmText,
    this.cancelText,
    this.showCancel = false,
  });

  final AppAlertType type;
  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final bool showCancel;

  @override
  State<_AppAlertDialog> createState() => _AppAlertDialogState();
}

class _AppAlertDialogState extends State<_AppAlertDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _AlertColors.fromType(widget.type);

    return FadeTransition(
      opacity: _fade,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260B3558),
                  blurRadius: 32,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnimatedAlertIcon(type: widget.type, colors: colors),
                const SizedBox(height: 18),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (widget.showCancel) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFD8DCE8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(widget.cancelText ?? 'Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.main,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(widget.confirmText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedAlertIcon extends StatelessWidget {
  const _AnimatedAlertIcon({
    required this.type,
    required this.colors,
  });

  final AppAlertType type;
  final _AlertColors colors;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      AppAlertType.success => Icons.check_rounded,
      AppAlertType.warning => Icons.priority_high_rounded,
      AppAlertType.error => Icons.close_rounded,
      AppAlertType.info => Icons.info_outline_rounded,
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: colors.soft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.main,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlertColors {
  const _AlertColors({
    required this.main,
    required this.soft,
  });

  final Color main;
  final Color soft;

  factory _AlertColors.fromType(AppAlertType type) {
    return switch (type) {
      AppAlertType.success => const _AlertColors(
          main: Color(0xFF10B981),
          soft: Color(0xFFDDFBEF),
        ),
      AppAlertType.warning => const _AlertColors(
          main: Color(0xFFF59E0B),
          soft: Color(0xFFFFF3D6),
        ),
      AppAlertType.error => const _AlertColors(
          main: Color(0xFFDC2626),
          soft: Color(0xFFFFE4E6),
        ),
      AppAlertType.info => const _AlertColors(
          main: Color(0xFF2563EB),
          soft: Color(0xFFEFF6FF),
        ),
    };
  }
}
