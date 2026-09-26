import 'package:flutter/material.dart';
import 'package:hifazat_app/api/models/user.dart';
import 'package:hifazat_app/auth/auth_provider.dart';
import 'package:hifazat_app/providers/user_provider.dart';
import 'package:hifazat_app/routes.dart';
import 'package:hifazat_app/utils/app_colors.dart';
import 'package:provider/provider.dart';

const _verifiedColor = AppColors.success;
const _warningColor = AppColors.warning;
const _dangerColor = AppColors.danger;
const _headerGradient = AppColors.headerGradient;

/// Reputation tiers, matching the backend formula
/// (10 per verified report, 1 per upvote, -2 per downvote, +50 if trusted).
class _Level {
  const _Level(this.name, this.minScore, this.icon, this.color);
  final String name;
  final int minScore;
  final IconData icon;
  final Color color;
}

const _levels = [
  _Level('Newcomer', 0, Icons.eco_outlined, Color(0xFF64748B)),
  _Level('Contributor', 25, Icons.volunteer_activism_outlined, AppColors.highlightBlue),
  _Level('Guardian', 100, Icons.shield_outlined, AppColors.accentPurple),
  _Level('Champion', 250, Icons.emoji_events_outlined, Color(0xFFD4A017)),
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).fetchCurrentUser();
    });
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.logout_rounded, color: _dangerColor),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to report incidents or vote.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _dangerColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _logout();
  }

  void _logout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    authProvider.logout(onLogout: userProvider.clearUser);
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.checkout, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final user = userProvider.user;
          if (user == null) {
            return userProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ErrorState(onRetry: () => userProvider.fetchCurrentUser(force: true));
          }

          final score = userProvider.reputation?.reputationScore;
          return RefreshIndicator(
            onRefresh: () => userProvider.fetchCurrentUser(force: true),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _ProfileHeader(user: user),
                _Constrained(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      _IdentitySection(user: user),
                      const SizedBox(height: 24),
                      _StatsRow(user: user, score: score),
                      const SizedBox(height: 16),
                      if (score != null) ...[
                        _LevelProgressCard(score: score),
                        const SizedBox(height: 16),
                      ],
                      _VerificationCard(isVerified: user.isVerified),
                      const SizedBox(height: 16),
                      _AccountDetailsCard(user: user),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Log out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _dangerColor,
                          side: BorderSide(color: _dangerColor.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Keeps content at a readable width on wide (web/tablet) screens.
class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final User user;

  static const _bannerHeight = 170.0;
  static const _avatarSize = 116.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _bannerHeight + _avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: _bannerHeight,
            decoration: const BoxDecoration(
              gradient: _headerGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: Stack(
                children: [
                  // Soft decorative circles.
                  const Positioned(right: -40, top: -50, child: _Bubble(size: 180, opacity: 0.08)),
                  const Positioned(left: -30, bottom: -60, child: _Bubble(size: 150, opacity: 0.06)),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          const Text(
                            'My Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (user.isStaff) const _Pill.onDark(icon: Icons.admin_panel_settings, label: 'Admin'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: _bannerHeight - _avatarSize / 2, child: _Avatar(user: user, size: _avatarSize)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.size});
  final User user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.profile?.avatarUrl;
    final ringGradient = user.isVerified
        ? const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF0EA5E9)])
        : const LinearGradient(colors: [Colors.white, Colors.white]);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ringGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: CircleAvatar(
              backgroundColor: AppColors.primaryBlue,
              foregroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
              child: Text(
                user.displayName.characters.first.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        if (user.isVerified)
          Positioned(
            right: 2,
            bottom: 4,
            child: Tooltip(
              message: 'Verified reporter',
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.verified, color: _verifiedColor, size: 28),
              ),
            ),
          ),
      ],
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                user.displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: _verifiedColor, size: 22),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text('@${user.username}', style: const TextStyle(color: AppColors.textGrey, fontSize: 15)),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            user.isVerified
                ? const _Pill(icon: Icons.verified_rounded, label: 'Verified reporter', color: _verifiedColor)
                : const _Pill(icon: Icons.gpp_maybe_outlined, label: 'Not verified', color: _warningColor),
            _Pill(
              icon: user.isStaff ? Icons.admin_panel_settings_outlined : Icons.person_outline,
              label: user.isStaff ? 'Admin' : 'Citizen',
              color: AppColors.primaryBlue,
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color}) : _onDark = false;
  const _Pill.onDark({required this.icon, required this.label})
      : color = Colors.white,
        _onDark = true;

  final IconData icon;
  final String label;
  final Color color;
  final bool _onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _onDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: _onDark ? 0.35 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding = const EdgeInsets.all(20), this.color, this.borderColor});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? const Color(0xFFE6E8EE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user, required this.score});
  final User user;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final level = score == null ? null : _levelFor(score!);
    return _SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Stat(
              icon: Icons.star_rounded,
              color: const Color(0xFFF59E0B),
              value: score?.toString() ?? '—',
              label: 'Reputation',
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE6E8EE)),
            _Stat(
              icon: level?.icon ?? Icons.hourglass_empty,
              color: level?.color ?? AppColors.textGrey,
              value: level?.name ?? '—',
              label: 'Level',
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE6E8EE)),
            _Stat(
              icon: user.isVerified ? Icons.verified_rounded : Icons.gpp_maybe_outlined,
              color: user.isVerified ? _verifiedColor : _warningColor,
              value: user.isVerified ? 'Verified' : 'Pending',
              label: 'Status',
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ],
      ),
    );
  }
}

_Level _levelFor(int score) => _levels.lastWhere((l) => score >= l.minScore, orElse: () => _levels.first);

class _LevelProgressCard extends StatelessWidget {
  const _LevelProgressCard({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final level = _levelFor(score);
    final index = _levels.indexOf(level);
    final next = index + 1 < _levels.length ? _levels[index + 1] : null;
    final progress = next == null
        ? 1.0
        : ((score - level.minScore) / (next.minScore - level.minScore)).clamp(0.0, 1.0);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: level.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(level.icon, color: level.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
                    ),
                    Text(
                      next == null
                          ? 'Highest level reached — thank you!'
                          : '${next.minScore - score} points to ${next.name}',
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: const Color(0xFFEDEFF4),
                valueColor: AlwaysStoppedAnimation(level.color),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Earn points: +10 per verified report, +1 per upvote.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.isVerified});
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final color = isVerified ? _verifiedColor : _warningColor;
    return _SectionCard(
      color: color.withValues(alpha: 0.06),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isVerified ? Icons.verified_user_rounded : Icons.shield_outlined, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isVerified ? 'You are a verified reporter' : 'Your account is not verified yet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isVerified
                ? 'Your reports show a verified badge, so the community can trust them more. '
                    'Verified reporters also receive a +50 reputation bonus.'
                : 'Verified reporters get a badge on their reports and a +50 reputation bonus. '
                    'Hifazat moderators grant verification to members with a record of accurate reports.',
            style: const TextStyle(color: AppColors.textDark, height: 1.45, fontSize: 14),
          ),
          if (!isVerified) ...[
            const SizedBox(height: 14),
            const _Step(icon: Icons.edit_note_rounded, text: 'Report incidents accurately, with clear details'),
            const _Step(icon: Icons.thumb_up_alt_outlined, text: 'Earn upvotes from the community'),
            const _Step(icon: Icons.fact_check_outlined, text: 'Moderators review and verify your account'),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _warningColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.textDark))),
        ],
      ),
    );
  }
}

class _AccountDetailsCard extends StatelessWidget {
  const _AccountDetailsCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final fullName = '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
    final rows = <Widget>[
      _DetailRow(icon: Icons.alternate_email_rounded, label: 'Username', value: user.username),
      _DetailRow(icon: Icons.mail_outline_rounded, label: 'Email', value: user.email.isEmpty ? 'Not provided' : user.email),
      if (fullName.isNotEmpty) _DetailRow(icon: Icons.badge_outlined, label: 'Full name', value: fullName),
      _DetailRow(
        icon: Icons.workspace_premium_outlined,
        label: 'Account type',
        value: user.isStaff ? 'Administrator' : 'Community member',
      ),
    ];

    return _SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Account details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) const Divider(height: 1, indent: 68, endIndent: 20, color: Color(0xFFEDEFF4)),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load your profile",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check your connection and try again.',
              style: TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
