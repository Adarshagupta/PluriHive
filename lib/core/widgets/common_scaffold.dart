import 'package:flutter/material.dart';
import '../theme/app_constants.dart';

/// Standardized scaffold with gradient background
class CommonScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final bool showGradientBackground;
  final Widget? decorationWidget;

  const CommonScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.showGradientBackground = true,
    this.decorationWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: showGradientBackground
          ? Container(
              decoration: const BoxDecoration(
                gradient: AppGradients.background,
              ),
              child: Stack(
                children: [
                  if (decorationWidget != null) decorationWidget!,
                  body,
                ],
              ),
            )
          : body,
    );
  }
}
