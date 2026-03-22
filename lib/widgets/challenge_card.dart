import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/challenge.dart';

class ChallengeCard extends StatefulWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    this.highlightCompletion = false,
    this.onTap,
  });

  final Challenge challenge;
  final bool highlightCompletion;
  final VoidCallback? onTap;

  @override
  State<ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<ChallengeCard>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.95,
      upperBound: 1.0,
    )..value = 1.0;

    if (widget.highlightCompletion && widget.challenge.isCompleted) {
      _confettiController.play();
      _pulseController
        ..value = 0.95
        ..forward();
    }
  }

  @override
  void didUpdateWidget(covariant ChallengeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameCompleted =
        !oldWidget.challenge.isCompleted && widget.challenge.isCompleted;
    if ((widget.highlightCompletion || becameCompleted) &&
        widget.challenge.isCompleted) {
      _confettiController.play();
      _pulseController
        ..value = 0.95
        ..forward();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _typeColor(colorScheme, widget.challenge.challengeType);
    final progressPercent = (widget.challenge.progress * 100).clamp(0, 100);

    return ScaleTransition(
      scale: _pulseController,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                accent.withOpacity(0.14),
                colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: accent.withOpacity(0.35),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: accent.withOpacity(0.18),
                          child: Icon(
                            _typeIcon(widget.challenge.challengeType),
                            color: accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.challenge.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _RewardChip(points: widget.challenge.rewardPoints),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.challenge.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: widget.challenge.progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(99),
                      color: accent,
                      backgroundColor: accent.withOpacity(0.18),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${progressPercent.toStringAsFixed(0)}% completed',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: widget.challenge.isCompleted
                              ? Row(
                                  key: const ValueKey('done'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Completed',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                )
                              : Row(
                                  key: const ValueKey('active'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flag_rounded,
                                      size: 16,
                                      color: colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'In Progress',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.secondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    numberOfParticles: 18,
                    shouldLoop: false,
                    gravity: 0.3,
                    emissionFrequency: 0.06,
                    colors: [
                      colorScheme.primary,
                      colorScheme.secondary,
                      colorScheme.tertiary,
                      colorScheme.error,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(ColorScheme colorScheme, ChallengeType type) {
    switch (type) {
      case ChallengeType.daily:
        return colorScheme.primary;
      case ChallengeType.monthly:
        return colorScheme.tertiary;
      case ChallengeType.streak:
        return Colors.orange;
    }
  }

  IconData _typeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.daily:
        return Icons.today_rounded;
      case ChallengeType.monthly:
        return Icons.calendar_month_rounded;
      case ChallengeType.streak:
        return Icons.local_fire_department_rounded;
    }
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_rounded,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '+$points pts',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
