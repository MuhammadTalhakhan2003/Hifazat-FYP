import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:hifazat_app/utils/app_colors.dart';
import 'package:hifazat_app/widgets/filter_dialog.dart';
import 'package:hifazat_app/widgets/incident_card.dart';
import 'package:provider/provider.dart';

/// Max width of the feed column on wide (web/tablet) screens.
const _maxContentWidth = 760.0;

class IncidentsListScreen extends StatefulWidget {
  const IncidentsListScreen({super.key});

  @override
  State<IncidentsListScreen> createState() => _IncidentsListScreenState();
}

class _IncidentsListScreenState extends State<IncidentsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<IncidentProvider>(context, listen: false);
    // Fetch initial data only if the list is empty
    if (provider.incidentList.isEmpty) {
      Future.microtask(() => provider.fetchIncidentList(isRefresh: true));
    }

    _scrollController.addListener(() {
      // Load the next page shortly before reaching the bottom.
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        provider.fetchIncidentList();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Provider.of<IncidentProvider>(context, listen: false).fetchIncidentList(isRefresh: true);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => const FilterDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Consumer<IncidentProvider>(
        builder: (context, provider, child) {
          final incidents = provider.incidentList;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            edgeOffset: 120,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidePadding = math.max(16.0, (constraints.maxWidth - _maxContentWidth) / 2);
                final padding = EdgeInsets.symmetric(horizontal: sidePadding);

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _FeedHeader(
                        contentPadding: padding,
                        onFilter: _showFilterDialog,
                        onRefresh: _onRefresh,
                      ),
                    ),
                    if (provider.isLoading)
                      SliverPadding(
                        padding: padding.copyWith(top: 20),
                        sliver: SliverList.builder(
                          itemCount: 3,
                          itemBuilder: (_, __) => const _SkeletonCard(),
                        ),
                      )
                    else if (provider.errorMessage != null && incidents.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _StatusMessage(
                          icon: Icons.wifi_off_rounded,
                          color: AppColors.danger,
                          title: "Couldn't load incidents",
                          message: provider.errorMessage!,
                          actionLabel: 'Try again',
                          actionIcon: Icons.refresh_rounded,
                          onAction: _onRefresh,
                        ),
                      )
                    else if (incidents.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _StatusMessage(
                          icon: Icons.travel_explore_rounded,
                          color: AppColors.primaryBlue,
                          title: 'No incidents found',
                          message: 'Try adjusting your filters or check back later.',
                          actionLabel: 'Adjust filters',
                          actionIcon: Icons.tune_rounded,
                          onAction: _showFilterDialog,
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: padding.copyWith(top: 20),
                        sliver: SliverList.builder(
                          itemCount: incidents.length,
                          itemBuilder: (context, index) {
                            final incident = incidents[index];
                            return _FadeIn(
                              key: ValueKey(incident.id),
                              child: IncidentCard(incident: incident),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: padding.copyWith(top: 8, bottom: 32),
                          child: provider.hasMoreIncidents
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                              : const _EndOfFeed(),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.contentPadding, required this.onFilter, required this.onRefresh});

  final EdgeInsets contentPadding;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(right: -50, top: -60, child: _bubble(200, 0.08)),
          Positioned(left: -40, bottom: -70, child: _bubble(160, 0.06)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: contentPadding.copyWith(top: 16, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Incidents Feed',
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Stay aware of what's happening around you",
                              style: TextStyle(color: Colors.white70, fontSize: 13.5),
                            ),
                          ],
                        ),
                      ),
                      _GlassIconButton(icon: Icons.tune_rounded, tooltip: 'Filter incidents', onPressed: onFilter),
                      const SizedBox(width: 8),
                      _GlassIconButton(icon: Icons.refresh_rounded, tooltip: 'Refresh', onPressed: onRefresh),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Search-style entry point into the filter dialog.
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 0,
                    child: InkWell(
                      onTap: onFilter,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, color: AppColors.textGrey),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Search by keyword, city or category',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textGrey, fontSize: 14.5),
                              ),
                            ),
                            Icon(Icons.filter_list_rounded, color: AppColors.primaryBlue),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bubble(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
      );
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Fades and slides a card in the first time it is built.
class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Pulsing placeholder shown while the first page loads.
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFE7EAF0), borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [_bar(38, 38), const SizedBox(width: 12), _bar(120, 14), const Spacer(), _bar(64, 22)]),
            const SizedBox(height: 16),
            _bar(220, 18),
            const SizedBox(height: 10),
            _bar(double.infinity, 12),
            const SizedBox(height: 6),
            _bar(260, 12),
            const SizedBox(height: 16),
            Row(children: [_bar(90, 26), const SizedBox(width: 8), _bar(140, 26)]),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 42, color: color),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndOfFeed extends StatelessWidget {
  const _EndOfFeed();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.success),
              SizedBox(width: 6),
              Text("You're all caught up", style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
