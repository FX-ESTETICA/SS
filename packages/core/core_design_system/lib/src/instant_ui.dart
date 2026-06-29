import 'package:flutter/material.dart';

class InstantPageRoute<T> extends PageRouteBuilder<T> {
  InstantPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog = false,
  }) : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) {
            return builder(context);
          },
        );
}

class ImmersivePageRoute<T> extends PageRouteBuilder<T> {
  ImmersivePageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog = false,
  }) : super(
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (context, animation, secondaryAnimation) {
            return builder(context);
          },
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.028),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.992, end: 1.0).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        );
}

class InstantUI {
  const InstantUI._();

  static Route<T> pageRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return InstantPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }

  static Future<T?> pushPage<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return push<T>(
      context,
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }

  static Future<T?> push<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      pageRoute<T>(
        builder: builder,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Route<T> immersivePageRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return ImmersivePageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }

  static Future<T?> pushImmersive<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      immersivePageRoute<T>(
        builder: builder,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Future<T?> pushReplacementImmersive<T extends Object?, TO extends Object?>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    TO? result,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      immersivePageRoute<T>(
        builder: builder,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
      ),
      result: result,
    );
  }

  static Future<T?> replacePage<T extends Object?, TO extends Object?>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    TO? result,
  }) {
    return pushReplacement<T, TO>(
      context,
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      result: result,
    );
  }

  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    TO? result,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      pageRoute<T>(
        builder: builder,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
      ),
      result: result,
    );
  }

  static Future<T?> showSheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    Color? backgroundColor,
    bool isScrollControlled = false,
    ShapeBorder? shape,
    bool useSafeArea = false,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showBottomSheet<T>(
      context,
      builder: builder,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      shape: shape,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
  }

  static Future<T?> showBottomSheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    Color? backgroundColor,
    bool isScrollControlled = false,
    ShapeBorder? shape,
    bool useSafeArea = false,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      shape: shape,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: builder,
    );
  }

  static Future<T?> showInstantDialog<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
    Color barrierColor = const Color(0x8A000000),
  }) {
    return showDialog<T>(
      context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
    );
  }

  static Future<T?> showDialog<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
    Color barrierColor = const Color(0x8A000000),
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return builder(dialogContext);
      },
    );
  }
}

extension InstantBuildContext on BuildContext {
  Future<T?> pushInstant<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return InstantUI.pushPage<T>(
      this,
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }

  Future<T?> replaceWithInstant<T extends Object?, TO extends Object?>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    TO? result,
  }) {
    return InstantUI.replacePage<T, TO>(
      this,
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      result: result,
    );
  }

  Future<T?> pushImmersive<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return InstantUI.pushImmersive<T>(
      this,
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }

  Future<T?> replaceWithImmersive<T extends Object?, TO extends Object?>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    TO? result,
  }) {
    return InstantUI.pushReplacementImmersive<T, TO>(
      this,
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      result: result,
    );
  }

  Future<T?> showInstantSheet<T>({
    required WidgetBuilder builder,
    Color? backgroundColor,
    bool isScrollControlled = false,
    ShapeBorder? shape,
    bool useSafeArea = false,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return InstantUI.showSheet<T>(
      this,
      builder: builder,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      shape: shape,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
  }

  Future<T?> showInstantDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
    Color barrierColor = const Color(0x8A000000),
  }) {
    return InstantUI.showInstantDialog<T>(
      this,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
    );
  }
}
