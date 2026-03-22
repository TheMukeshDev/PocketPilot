import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/prediction_service.dart';

enum InsightStatus { safe, caution, danger }

class OverspendInsightCard extends StatefulWidget {
  const OverspendInsightCard({super.key, required this.prediction});

  final PredictionResult prediction;

  @override
  State<OverspendInsightCard> createState() => _OverspendInsightCardState();
}

class _OverspendInsightCardState extends State<OverspendInsightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  InsightStatus get _status {
    final prediction = widget.prediction;
    if (prediction.isLikelyToOverspend) {
      if (prediction.overspendPercent > 30) {
        return InsightStatus.danger;
      }
      return InsightStatus.caution;
    }
    return InsightStatus.safe;
  }

  double get _spendProgress {
    final p = widget.prediction;
    if (p.availableBudget <= 0) return 0;
    final progress = (p.predictedMonthSpend / (p.availableBudget + p.predictedMonthSpend));
    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getGradientColors(isDark),
          ),
          boxShadow: [
            BoxShadow(
              color: _getShadowColor().withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getAccentColor().withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildStatusChip(),
                const SizedBox(height: 16),
                _buildInsightText(),
                const SizedBox(height: 20),
                _buildProgressSection(),
                const SizedBox(height: 20),
                _buildMetricsGrid(),
                if (widget.prediction.isLikelyToOverspend) ...[
                  const SizedBox(height: 16),
                  _buildSuggestion(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors(bool isDark) {
    final accent = _getAccentColor();
    switch (_status) {
      case InsightStatus.safe:
        return isDark
            ? [accent.withOpacity(0.15), accent.withOpacity(0.05)]
            : [accent.withOpacity(0.08), accent.withOpacity(0.02)];
      case InsightStatus.caution:
        return [
          const Color(0xFFF59E0B).withOpacity(isDark ? 0.2 : 0.1),
          const Color(0xFFF59E0B).withOpacity(isDark ? 0.05 : 0.02),
        ];
      case InsightStatus.danger:
        return [
          const Color(0xFFEF4444).withOpacity(isDark ? 0.2 : 0.1),
          const Color(0xFFEF4444).withOpacity(isDark ? 0.05 : 0.02),
        ];
    }
  }

  Color _getAccentColor() {
    switch (_status) {
      case InsightStatus.safe:
        return const Color(0xFF10B981);
      case InsightStatus.caution:
        return const Color(0xFFF59E0B);
      case InsightStatus.danger:
        return const Color(0xFFEF4444);
    }
  }

  Color _getShadowColor() {
    switch (_status) {
      case InsightStatus.safe:
        return const Color(0xFF10B981);
      case InsightStatus.caution:
        return const Color(0xFFF59E0B);
      case InsightStatus.danger:
        return const Color(0xFFEF4444);
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getAccentColor().withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.psychology_rounded,
            color: _getAccentColor(),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Spending Insight',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _getAccentColor(),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Smart prediction for your budget',
                style: TextStyle(
                  fontSize: 12,
                  color: _getAccentColor().withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _buildSparkleIcon(),
      ],
    );
  }

  Widget _buildSparkleIcon() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _getAccentColor().withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.auto_awesome,
        color: _getAccentColor().withOpacity(0.8),
        size: 14,
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = _status;
    String label;
    IconData icon;

    switch (status) {
      case InsightStatus.safe:
        label = 'On Track';
        icon = Icons.check_circle_rounded;
        break;
      case InsightStatus.caution:
        label = 'Slight Risk';
        icon = Icons.warning_amber_rounded;
        break;
      case InsightStatus.danger:
        label = 'High Overspend Risk';
        icon = Icons.error_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _getAccentColor().withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _getAccentColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _getAccentColor(),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _getAccentColor(),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightText() {
    final p = widget.prediction;
    String mainText;
    String emoji;

    switch (_status) {
      case InsightStatus.safe:
        emoji = '🎯';
        mainText = 'You\'re on track!\n'
            'At your current pace, you\'ll stay comfortably within your ₹${p.availableBudget} budget.';
        break;
      case InsightStatus.caution:
        emoji = '⚠️';
        mainText = 'Slow down a bit.\n'
            'You might exceed your budget by ₹${p.overspendAmount.toStringAsFixed(0)} if spending continues.';
        break;
      case InsightStatus.danger:
        emoji = '🚨';
        mainText = 'High overspend alert!\n'
            'At this rate, you\'ll likely overspend by ₹${p.overspendAmount.toStringAsFixed(0)} (${p.overspendPercent.toStringAsFixed(0)}%).';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _getAccentColor().withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mainText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _getAccentColor(),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final p = widget.prediction;
    final progress = _spendProgress;
    final color = _getAccentColor();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Predicted vs Budget',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCircularProgress(progress, color),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildProgressLabel(
              'Predicted',
              '₹${p.predictedMonthSpend.toStringAsFixed(0)}',
              color,
            ),
            Container(
              width: 1,
              height: 30,
              color: color.withOpacity(0.2),
            ),
            _buildProgressLabel(
              'Budget',
              '₹${p.availableBudget}',
              color,
            ),
            Container(
              width: 1,
              height: 30,
              color: color.withOpacity(0.2),
            ),
            _buildProgressLabel(
              'Difference',
              _status == InsightStatus.safe
                  ? '₹${(p.availableBudget - p.predictedMonthSpend).toStringAsFixed(0)}'
                  : '₹${p.overspendAmount.toStringAsFixed(0)}',
              color,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularProgress(double progress, Color color) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(120, 120),
            painter: _CircularProgressPainter(
              progress: progress,
              color: color,
              backgroundColor: color.withOpacity(0.15),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '₹${widget.prediction.predictedMonthSpend.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                'of ₹${widget.prediction.availableBudget}',
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLabel(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    final p = widget.prediction;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _getAccentColor().withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _getAccentColor().withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Metrics',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _getAccentColor().withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  Icons.trending_up_rounded,
                  'Daily Avg',
                  '₹${p.dailyAverageSpend.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  Icons.calendar_today_rounded,
                  'Cycle Day',
                  '${p.currentDay}/${p.daysInMonth}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  Icons.schedule_rounded,
                  'Days Left',
                  '${p.remainingDays} days',
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  Icons.account_balance_wallet_rounded,
                  'Budget Left',
                  '₹${p.availableBudget}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value) {
    final color = _getAccentColor();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestion() {
    final p = widget.prediction;
    final color = _getAccentColor();

    String suggestion;
    IconData icon;

    if (p.overspendAmount > 500) {
      suggestion = '💡 Tip: Cut spending by ₹${p.cutFoodPerDayTip}/day for the remaining ${p.remainingDays} days to stay within budget.';
      icon = Icons.lightbulb_outline_rounded;
    } else {
      suggestion = '💡 Consider skipping one OTT subscription this month to cover the gap.';
      icon = Icons.tips_and_updates_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Suggestion',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 10.0;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
