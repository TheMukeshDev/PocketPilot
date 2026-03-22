import 'package:flutter/material.dart';

import '../models/challenge.dart';

class PointsHistoryCard extends StatelessWidget {
  const PointsHistoryCard({
    super.key,
    required this.history,
    this.onViewAll,
  });

  final List<PointsHistoryEntry> history;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Points History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (onViewAll != null)
                    TextButton(
                      onPressed: onViewAll,
                      child: const Text('View All'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 40,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No points earned yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete challenges to earn points!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Points History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...history.take(5).map((entry) => _PointsHistoryItem(entry: entry)),
          ],
        ),
      ),
    );
  }
}

class _PointsHistoryItem extends StatelessWidget {
  const _PointsHistoryItem({required this.entry});

  final PointsHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _typeColor(entry.challengeType).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _typeIcon(entry.challengeType),
              color: _typeColor(entry.challengeType),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(entry.earnedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${entry.pointsEarned}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (entry.savedAmount > 0) ...[
                const SizedBox(height: 2),
                Text(
                  'Saved ₹${entry.savedAmount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.secondary,
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _typeColor(ChallengeType type) {
    switch (type) {
      case ChallengeType.daily:
        return const Color(0xFF4CAF50);
      case ChallengeType.weekly:
        return const Color(0xFF2196F3);
      case ChallengeType.streak:
        return const Color(0xFFFF9800);
    }
  }

  IconData _typeIcon(ChallengeType type) {
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

class PointsHistoryFullScreen extends StatelessWidget {
  const PointsHistoryFullScreen({
    super.key,
    required this.history,
  });

  final List<PointsHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final totalPoints = history.fold<int>(0, (sum, e) => sum + e.pointsEarned);
    final totalSaved = history.fold<int>(0, (sum, e) => sum + e.savedAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Points History'),
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No points history yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete challenges to see your points here!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$totalPoints',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Total Points',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 60,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        Column(
                          children: [
                            Icon(
                              Icons.savings_rounded,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹$totalSaved',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Total Saved',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 60,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        Column(
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: Theme.of(context).colorScheme.tertiary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${history.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Challenges',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All Earnings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                ...history.map((entry) => _PointsHistoryDetailItem(entry: entry)),
              ],
            ),
    );
  }
}

class _PointsHistoryDetailItem extends StatelessWidget {
  const _PointsHistoryDetailItem({required this.entry});

  final PointsHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _typeColor(entry.challengeType).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _typeIcon(entry.challengeType),
                color: _typeColor(entry.challengeType),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(entry.earnedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+${entry.pointsEarned} pts',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (entry.savedAmount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Saved ₹${entry.savedAmount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Color _typeColor(ChallengeType type) {
    switch (type) {
      case ChallengeType.daily:
        return const Color(0xFF4CAF50);
      case ChallengeType.weekly:
        return const Color(0xFF2196F3);
      case ChallengeType.streak:
        return const Color(0xFFFF9800);
    }
  }

  IconData _typeIcon(ChallengeType type) {
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
