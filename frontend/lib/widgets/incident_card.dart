import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hifazat_app/api/models/incident.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:hifazat_app/routes.dart';
import 'package:hifazat_app/utils/app_colors.dart';
import 'package:hifazat_app/widgets/comment_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CardStyle {
  final IconData icon;
  final Color color;
  const CardStyle({required this.icon, required this.color});
}

CardStyle cardStyleForCategory(String categoryName) {
  switch (categoryName.toLowerCase()) {
    case 'terrorism & extremism':
      return const CardStyle(icon: FontAwesomeIcons.bomb, color: Color(0xFF1F2937));
    case 'violent crime & homicide':
      return const CardStyle(icon: FontAwesomeIcons.gun, color: Color(0xFFC62828));
    case 'kidnapping & abduction':
      return const CardStyle(icon: FontAwesomeIcons.handcuffs, color: Color(0xFF455A64));
    case 'organized crime & trafficking':
      return const CardStyle(icon: FontAwesomeIcons.briefcase, color: Color(0xFF6D4C41));
    case 'theft & robbery':
      return const CardStyle(icon: FontAwesomeIcons.mask, color: Color(0xFFE65100));
    case 'scams & fraud':
      return const CardStyle(icon: FontAwesomeIcons.userSecret, color: Color(0xFF7B1FA2));
    case 'sexual violence & abuse':
      return const CardStyle(icon: FontAwesomeIcons.userSlash, color: Color(0xFFAD1457));
    case 'public order & governance offenses':
      return const CardStyle(icon: FontAwesomeIcons.gavel, color: Color(0xFF3949AB));
    case 'accidents & disasters':
      return const CardStyle(icon: FontAwesomeIcons.carBurst, color: Color(0xFF2E7D32));
    case 'cybercrime & digital offenses':
      return const CardStyle(icon: FontAwesomeIcons.laptopCode, color: Color(0xFF0277BD));
    case 'drug crimes':
      return const CardStyle(icon: FontAwesomeIcons.pills, color: Color(0xFF00796B));
    default:
      return const CardStyle(icon: FontAwesomeIcons.circleQuestion, color: Color(0xFF64748B));
  }
}

/// "Just now", "5m ago", "3h ago", "2d ago", else a short date.
String relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date.toLocal());
  if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(date.toLocal());
}

class IncidentCard extends StatefulWidget {
  final Incident incident;
  const IncidentCard({super.key, required this.incident});

  @override
  State<IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends State<IncidentCard> {
  final TextEditingController _commentController = TextEditingController();
  bool _showComments = false;
  bool _sendingComment = false;

  void _toggleComments(IncidentProvider provider) {
    setState(() => _showComments = !_showComments);
    if (_showComments) provider.fetchComments(widget.incident.id);
  }

  Future<void> _onVote(bool isUpvote) async {
    final provider = Provider.of<IncidentProvider>(context, listen: false);
    final ok = await provider.voteOnIncident(widget.incident.id, isUpvote);
    if (!ok && mounted) {
      _showSnack('Could not register your vote. Please sign in and try again.');
    }
  }

  Future<void> _onAddComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;

    setState(() => _sendingComment = true);
    final provider = Provider.of<IncidentProvider>(context, listen: false);
    final success = await provider.addCommentToIncident(widget.incident.id, text);
    if (!mounted) return;
    setState(() => _sendingComment = false);
    if (success) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } else {
      _showSnack('Failed to add comment. Please try again.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IncidentProvider>(
      builder: (context, provider, child) {
        final incident = provider.incidentList.firstWhere(
          (i) => i.id == widget.incident.id,
          orElse: () => widget.incident,
        );
        final props = incident.properties;
        final userVote = provider.userVoteStatus[incident.id];
        final style = cardStyleForCategory(props.categoryName);
        final commentCount = provider.commentsByIncidentId[incident.id]?.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Category accent strip.
              Positioned(left: 0, top: 0, bottom: 0, width: 5, child: ColoredBox(color: style.color)),
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.incidentDetail, arguments: incident.id),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CategoryHeader(style: style, category: props.categoryName, date: props.incidentDate),
                            const SizedBox(height: 14),
                            Text(
                              props.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                                height: 1.3,
                              ),
                            ),
                            if ((props.description ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                props.description!.trim(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF4B5563), height: 1.45, fontSize: 14),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaChip(
                                    icon: Icons.location_on_outlined, label: props.cityName ?? 'Unknown location'),
                                _MetaChip(
                                  icon: Icons.calendar_today_outlined,
                                  label: DateFormat.yMMMd().add_jm().format(props.incidentDate.toLocal()),
                                ),
                                if ((props.reportedByUsername ?? '').isNotEmpty)
                                  _MetaChip(icon: Icons.person_outline, label: '@${props.reportedByUsername}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    LayoutBuilder(builder: (context, constraints) {
                      // On phones, show icon-only actions so the row fits.
                      final compact = constraints.maxWidth < 440;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            _VoteButton(
                              icon: Icons.thumb_up_alt_outlined,
                              activeIcon: Icons.thumb_up_alt,
                              count: props.upvotes ?? 0,
                              isActive: userVote == 'up',
                              activeColor: AppColors.success,
                              tooltip: 'Confirm this report',
                              onPressed: () => _onVote(true),
                            ),
                            const SizedBox(width: 8),
                            _VoteButton(
                              icon: Icons.thumb_down_alt_outlined,
                              activeIcon: Icons.thumb_down_alt,
                              count: props.downvotes ?? 0,
                              isActive: userVote == 'down',
                              activeColor: AppColors.danger,
                              tooltip: 'Dispute this report',
                              onPressed: () => _onVote(false),
                            ),
                            const Spacer(),
                            _ActionButton(
                              icon: _showComments ? Icons.chat_bubble : Icons.chat_bubble_outline,
                              label: compact
                                  ? (commentCount?.toString() ?? '')
                                  : (commentCount == null ? 'Comments' : 'Comments ($commentCount)'),
                              tooltip: 'Comments',
                              highlighted: _showComments,
                              onPressed: () => _toggleComments(provider),
                            ),
                            const SizedBox(width: 4),
                            _ActionButton(
                              icon: Icons.arrow_forward_rounded,
                              label: compact ? '' : 'Details',
                              tooltip: 'View details',
                              trailingIcon: true,
                              onPressed: () =>
                                  Navigator.pushNamed(context, AppRoutes.incidentDetail, arguments: incident.id),
                            ),
                          ],
                        ),
                      );
                    }),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _showComments
                          ? _buildCommentsSection(provider, incident.id)
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentsSection(IncidentProvider provider, int incidentId) {
    final comments = provider.commentsByIncidentId[incidentId];
    final isLoading = provider.areCommentsLoading[incidentId] ?? false;

    return Container(
      color: const Color(0xFFF8F9FC),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading && comments == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
          if (comments != null)
            for (final comment in comments) CommentWidget(comment: comment, incidentId: incidentId),
          if (!isLoading && comments != null && comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.forum_outlined, color: AppColors.textGrey, size: 28),
                  SizedBox(height: 6),
                  Text('No comments yet. Be the first to share an update.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: const BoxDecoration(gradient: AppColors.headerGradient, shape: BoxShape.circle),
                child: IconButton(
                  tooltip: 'Send',
                  onPressed: _sendingComment ? null : _onAddComment,
                  icon: _sendingComment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.style, required this.category, required this.date});
  final CardStyle style;
  final String category;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FaIcon(style.icon, size: 16, color: style.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: style.color, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text(relativeTime(date),
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textDark, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : const Color(0xFF6B7280);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? activeColor.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(isActive ? activeIcon : icon, key: ValueKey(isActive), size: 17, color: color),
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: Text(
                    '$count',
                    key: ValueKey(count),
                    style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.highlighted = false,
    this.trailingIcon = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool highlighted;
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.accentPurple : AppColors.primaryBlue;
    final iconWidget = Icon(icon, size: 17, color: color);
    if (label.isEmpty) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: iconWidget,
        style: IconButton.styleFrom(
          backgroundColor: highlighted ? AppColors.accentPurple.withValues(alpha: 0.08) : null,
        ),
      );
    }
    final text = Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13));
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          backgroundColor: highlighted ? AppColors.accentPurple.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children:
              trailingIcon ? [text, const SizedBox(width: 4), iconWidget] : [iconWidget, const SizedBox(width: 6), text],
        ),
      ),
    );
  }
}
