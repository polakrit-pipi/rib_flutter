import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';
import '../services/api_service.dart';

class ResultScreen extends StatelessWidget {
  final AnalysisResult result;

  const ResultScreen({super.key, required this.result});

  @override
Widget build(BuildContext context) {
  final info = _verdictInfo(result.verdict);

  return Scaffold(
    backgroundColor: AppColors.bgBase,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Analysis Result',
        style: AppTextStyles.title,
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border,
        ),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1440,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildVerdictSummary(info),

                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return Column(
                        children: [
                          _buildSegmentationImage(info),
                          const SizedBox(height: 16),
                          _buildAssessmentPanel(info),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildSegmentationImage(info),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _buildAssessmentPanel(info),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                _buildColorLegend(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildVerdictSummary(_VerdictInfo info) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: info.color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: info.color.withValues(alpha: 0.30),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: info.color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            info.icon,
            color: Colors.white,
            size: 26,
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.badge,
                style: TextStyle(
                  color: info.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                info.headline,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                info.subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Text(
            info.action,
            style: TextStyle(
              color: info.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}



  Widget _buildSegmentationImage(_VerdictInfo info) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Segmentation image',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Lung · Rib 9 · Overlap',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),

        const Divider(
          height: 1,
          color: AppColors.border,
        ),

        Container(
          color: const Color(0xFF171A1F),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 800,
                maxHeight: 760,
              ),
              child: result.resultImageBytes != null
                  ? Image.memory(
                      result.resultImageBytes!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    )
                  : const SizedBox(
                      height: 500,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textMuted,
                          size: 36,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildAssessmentPanel(_VerdictInfo info) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Text(
            'Assessment',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const Divider(
          height: 1,
          color: AppColors.border,
        ),

        _CheckMetricRow(
          label: 'Confidence',
          value: result.ribConf.toStringAsFixed(2),
          passed: result.ribConf >= 0.89,
        ),

        const Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: AppColors.border,
        ),

        _CheckMetricRow(
          label: 'IoU Score',
          value: result.iou.toStringAsFixed(2),
          passed: result.iou > 0.85,
        ),

        if (result.verdictReason.isNotEmpty) ...[
          const Divider(
            height: 1,
            color: AppColors.border,
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assessment reason',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.verdictReason,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],

        const Divider(
          height: 1,
          color: AppColors.border,
        ),

        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          childrenPadding: const EdgeInsets.only(
            bottom: 8,
          ),
          shape: const Border(),
          collapsedShape: const Border(),
          title: const Text(
            'Technical details',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            _ResultMetricRow(
              label: 'Lung Area',
              value: '${_formatPx(result.lungArea)} px',
            ),
            _ResultMetricRow(
              label: 'Rib 9 Area',
              value: '${_formatPx(result.ribArea)} px',
            ),
            _ResultMetricRow(
              label: 'Overlap Area',
              value: '${_formatPx(result.overlapArea)} px',
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildColorLegend() {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.border,
      ),
    ),
    child: Row(
      children: [
        const Text(
          'Overlay legend',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(width: 24),

        const _MiniLegendItem(
          color: AppColors.lungBlue,
          label: 'Lung',
        ),

        const SizedBox(width: 20),

        const _MiniLegendItem(
          color: AppColors.ribRed,
          label: 'Rib 9',
        ),

        const SizedBox(width: 20),

        const _MiniLegendItem(
          color: AppColors.overlapMagenta,
          label: 'Overlap',
        ),
      ],
    ),
  );
}

  _VerdictInfo _verdictInfo(AnalysisVerdict verdict) {
  switch (verdict) {
    case AnalysisVerdict.pass:
      return const _VerdictInfo(
        badge: 'PASS',
        headline: 'ภาพผ่านเกณฑ์',
        subtitle: 'สามารถใช้ภาพนี้ต่อได้',
        action: 'No additional review required',
        color: AppColors.pass,
        icon: Icons.check_rounded,
      );

    case AnalysisVerdict.fail:
      return const _VerdictInfo(
        badge: 'FAIL',
        headline: 'ภาพไม่ผ่านเกณฑ์',
        subtitle: 'ไม่ควรใช้ภาพนี้ต่อ',
        action: 'Consider repeating the acquisition',
        color: AppColors.fail,
        icon: Icons.close_rounded,
      );

    case AnalysisVerdict.needsReview:
      return const _VerdictInfo(
        badge: 'NEED REVIEW',
        headline: 'ต้องตรวจสอบเพิ่มเติม',
        subtitle: 'ผลยังไม่แน่ชัด กรุณาตรวจสอบภาพด้วยสายตา',
        action: 'Manual review required',
        color: AppColors.review,
        icon: Icons.priority_high_rounded,
      );

    case AnalysisVerdict.unknown:
      return const _VerdictInfo(
        badge: 'UNKNOWN',
        headline: 'ไม่สามารถสรุปผลได้',
        subtitle: 'กรุณาลองวิเคราะห์ภาพอีกครั้ง',
        action: 'Analysis unavailable',
        color: AppColors.textMuted,
        icon: Icons.question_mark_rounded,
      );
  }
}

  String _formatPx(int px) {
    if (px >= 1000000) return '${(px / 1000000).toStringAsFixed(2)}M';
    if (px >= 1000) return '${(px / 1000).toStringAsFixed(1)}K';
    return px.toString();
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _VerdictInfo {
  final String badge;
  final String headline;
  final String subtitle;
  final String action;
  final Color color;
  final IconData icon;

  const _VerdictInfo({
    required this.badge,
    required this.headline,
    required this.subtitle,
    required this.action,
    required this.color,
    required this.icon,
  });
}

class _VerdictIconRing extends StatelessWidget {
  final _VerdictInfo info;

  const _VerdictIconRing({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            info.color.withValues(alpha: 0.3),
            info.color.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: info.color.withValues(alpha: 0.5), width: 2),
        boxShadow: [AppDecorations.glow(info.color, blur: 20)],
      ),
      child: Icon(info.icon, color: info.color, size: 34),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.04, 1.04),
          duration: 1800.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _MetricGauge extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final String thresholdLabel;
  final Color color;
  final bool passed;

  const _MetricGauge({
    required this.label,
    required this.value,
    required this.max,
    required this.thresholdLabel,
    required this.color,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = passed ? AppColors.pass : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 38,
            lineWidth: 7,
            percent: (value / max).clamp(0.0, 1.0),
            center: Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            progressColor: color,
            backgroundColor: color.withValues(alpha: 0.12),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 1000,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                color: statusColor,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                thresholdLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultMetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultMetricRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool passed;

  const _CheckMetricRow({
    required this.label,
    required this.value,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.pass : AppColors.fail;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(width: 10),

          Icon(
            passed
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            color: color,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _MiniLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _MiniLegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(width: 6),

        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}