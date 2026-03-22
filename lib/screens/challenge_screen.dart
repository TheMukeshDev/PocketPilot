import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../widgets/challenge_card.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({
    super.key,
    required this.stats,
    required this.challenges,
    required this.cycleStartDay,
    this.highlightChallengeId,
  });

  final GamificationStats stats;
  final List<Challenge> challenges;
  final int cycleStartDay;
  final String? highlightChallengeId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Challenges'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
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
                              'Gamification Dashboard',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Budget cycle starts on day $cycleStartDay each month.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${stats.totalPoints} pts',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final children = [
                        _StatTile(
                          icon: Icons.stars_rounded,
                          label: 'Total Points',
                          value: stats.totalPoints.toString(),
                        ),
                        _StatTile(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Current Streak',
                          value: '${stats.currentStreak} days',
                        ),
                        _StatTile(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Best Streak',
                          value: '${stats.bestStreak} days',
                        ),
                        _StatTile(
                          icon: Icons.military_tech_rounded,
                          label: 'Badges',
                          value: stats.badgesUnlocked.length.toString(),
                        ),
                      ];

                      if (compact) {
                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.2,
                          children: children,
                        );
                      }

                      return Row(
                        children: List.generate(children.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == children.length - 1 ? 0 : 10,
                              ),
                              child: children[index],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlocked Badges',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (stats.badgesUnlocked.isEmpty)
                    Text(
                      'No badges yet. Build a tracking streak to unlock Bronze, Silver, and Gold Saver badges.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: stats.badgesUnlocked
                          .map(
                            (badge) => Chip(
                              avatar:
                                  const Icon(Icons.workspace_premium_rounded),
                              label: Text(badge),
                              backgroundColor: colorScheme.secondaryContainer,
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Active Challenges',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...challenges.map(
            (challenge) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChallengeCard(
                challenge: challenge,
                highlightCompletion: highlightChallengeId == challenge.id,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _motivationMessage(stats),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  String _motivationMessage(GamificationStats stats) {
    if (stats.bestStreak >= 30) {
      return 'Legendary discipline! You are now a Gold Saver.';
    }
    if (stats.bestStreak >= 7) {
      return 'Amazing consistency! Keep the Silver Saver streak alive.';
    }
    if (stats.bestStreak >= 3) {
      return 'Great momentum! Bronze Saver unlocked — aim for Silver.';
    }
    return 'Start tracking today. Every bill added grows your streak and points.';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
