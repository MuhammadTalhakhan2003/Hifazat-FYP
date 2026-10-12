// Shared layout for the login, registration and forgot-password screens
import 'package:flutter/material.dart';
import 'package:hifazat_app/utils/app_colors.dart';

class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = false,
  });

  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          final formCard = _FormCard(title: title, subtitle: subtitle, child: child);

          if (isWide) {
            return Row(
              children: [
                const Expanded(child: _BrandPanel(expanded: true)),
                Expanded(
                  child: Stack(
                    children: [
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: formCard,
                        ),
                      ),
                      if (showBackButton) const _BackButton(color: AppColors.textDark),
                    ],
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              // Gradient band behind the top of the card
              Container(height: 280, decoration: const BoxDecoration(gradient: AppColors.headerGradient)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: Column(
                      children: [
                        const _BrandPanel(expanded: false),
                        const SizedBox(height: 24),
                        formCard,
                      ],
                    ),
                  ),
                ),
              ),
              if (showBackButton) const _BackButton(color: Colors.white),
            ],
          );
        },
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final Color color;
  const _BackButton({required this.color});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: color),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _FormCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.4)),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final bool expanded;
  const _BrandPanel({required this.expanded});

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      padding: EdgeInsets.all(expanded ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Icon(Icons.shield_outlined, size: expanded ? 48 : 36, color: Colors.white),
    );

    const name = Text(
      'Hifazat',
      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
    );
    final tagline = Text(
      'Stay aware. Stay safe. Together.',
      style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85)),
    );

    if (!expanded) {
      return Column(children: [logo, const SizedBox(height: 12), name, const SizedBox(height: 4), tagline]);
    }

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      padding: const EdgeInsets.all(56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          logo,
          const SizedBox(height: 24),
          name,
          const SizedBox(height: 8),
          tagline,
          const SizedBox(height: 40),
          const _Feature(icon: Icons.map_outlined, text: 'See incidents reported around you on a live map'),
          const _Feature(icon: Icons.whatshot_outlined, text: 'Spot high-risk areas with predicted hotspots'),
          const _Feature(icon: Icons.campaign_outlined, text: 'Report incidents and keep your community informed'),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Flexible(
            child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

/// Full-width primary button that shows a spinner while [isLoading].
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const AuthSubmitButton({super.key, required this.label, required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: AppColors.primaryBlue.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
