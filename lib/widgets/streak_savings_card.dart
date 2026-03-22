import 'package:flutter/material.dart';

import '../models/challenge.dart';

class StreakSavingsCard extends StatelessWidget {
  const StreakSavingsCard({
    super.key,
    required this.stats,
    required this.challenges,
    this.onViewHistory,
    this.onViewPointsLog,
  });

  final GamificationStats stats;
  final List<Challenge> challenges;
  final VoidCallback? onViewHistory;
  final VoidCallback? onViewPointsLog;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalSavedThisWeek = _calculateWeeklySavings();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Savings Journey',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep up the great work!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${stats.totalPoints} pts',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StreakStat(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFF9800),
                    label: 'Current Streak',
                    value: '${stats.currentStreak}',
                    suffix: 'days',
                    bgColor: const Color(0xFFFFF3E0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StreakStat(
                    icon: Icons.emoji_events_rounded,
                    iconColor: const Color(0xFF4CAF50),
                    label: 'Best Streak',
                    value: '${stats.bestStreak}',
                    suffix: 'days',
                    bgColor: const Color(0xFFE8F5E9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StreakStat(
                    icon: Icons.savings_rounded,
                    iconColor: colorScheme.primary,
                    label: 'This Week',
                    value: '₹$totalSavedThisWeek',
                    suffix: 'saved',
                    bgColor: colorScheme.primaryContainer.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Active Challenges',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ...challenges.map(
              (challenge) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChallengeMini(
                  challenge: challenge,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewHistory,
                    icon: const Icon(Icons.leaderboard_rounded, size: 18),
                    label: const Text('View History'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onViewPointsLog,
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Points Log'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _calculateWeeklySavings() {
    if (challenges.isEmpty) return 0;
    
    final weeklyChallenge = challenges.firstWhere(
      (c) => c.challengeType == ChallengeType.weekly,
      orElse: () => challenges.first,
    );
    
    final target = weeklyChallenge.targetAmount;
    final saved = (weeklyChallenge.progress * target).round();
    return saved;
  }
}

class _StreakStat extends StatelessWidget {
  const _StreakStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.suffix,
    required this.bgColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String suffix;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
          ),
          Text(
            suffix,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChallengeMini extends StatelessWidget {
  const _ChallengeMini({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (challenge.progress * 100).round();
    final challengeColor = _getChallengeColor(challenge.challengeType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: challengeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: challengeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getChallengeIcon(challenge.challengeType),
            color: challengeColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: challenge.progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: challengeColor.withOpacity(0.2),
                  color: challengeColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: challenge.isCompleted
                  ? const Color(0xFF4CAF50)
                  : challengeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              challenge.isCompleted ? '✓ Done' : '$progress%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: challenge.isCompleted
                        ? Colors.white
                        : challengeColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getChallengeColor(ChallengeType type) {
    switch (type) {
      case ChallengeType.daily:
        return const Color(0xFF4CAF50);
      case ChallengeType.weekly:
        return const Color(0xFF2196F3);
      case ChallengeType.streak:
        return const Color(0xFFFF9800);
    }
  }

  IconData _getChallengeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.daily:
        return Icons.today_rounded;
      case ChallengeType.weekly:
        return Icons.calendar_view_week_rounded;
      case ChallengeType.streak:
        return Icons.local_fire_department_rounded;
    }
  }
}
