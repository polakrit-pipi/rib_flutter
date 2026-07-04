import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_header.dart';
import '../services/api_service.dart';

class ResultScreen extends StatelessWidget {
  final AnalysisResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final info = _verdictInfo(result.verdict);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: AppDecorations.glass(radius: 14),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 16),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text('ผลการวิเคราะห์', style: AppTextStyles.title),
        centerTitle: true,
      ),
      body: AmbientBackground(
        accentColor: info.color,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildVerdictHero(info),
                const SizedBox(height: 24),
                _buildSegmentationImage(info),
                const SizedBox(height: 24),
                _buildMetricsGrid(),
                const SizedBox(height: 24),
                _buildColorLegend(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerdictHero(_VerdictInfo info) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            info.color.withValues(alpha: 0.22),
            AppColors.surfaceElevated.withValues(alpha: 0.95),
            AppColors.surface.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: info.color.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          AppDecorations.glow(info.color, blur: 40),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Decorative corner glow
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      info.color.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _VerdictIconRing(info: info),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: info.color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: info.color.withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                info.badge,
                                style: TextStyle(
                                  color: info.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              info.headline,
                              style: AppTextStyles.display.copyWith(
                                color: info.color,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(info.subtitle, style: AppTextStyles.body),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (result.verdictReason.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: info.color.withValues(alpha: 0.8), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              result.verdictReason,
                              style: AppTextStyles.body.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricGauge(
                          label: 'Confidence',
                          value: result.ribConf,
                          max: 1.0,
                          thresholdLabel: '≥ 0.95',
                          color: AppColors.accentBlue,
                          passed: result.ribConf >= 0.95,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MetricGauge(
                          label: 'IoU Score',
                          value: result.iou,
                          max: 1.0,
                          thresholdLabel: '> 0.85',
                          color: AppColors.accentPurple,
                          passed: result.iou > 0.85,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 550.ms)
        .slideY(begin: -0.08, end: 0, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.97, 0.97), end: const Offset(1, 1));
  }

  Widget _buildSegmentationImage(_VerdictInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'ภาพ Segmentation',
          subtitle: 'ปอด · ซี่โครงที่ 9 · พื้นที่ทับซ้อน',
          icon: Icons.image_search_rounded,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: info.color.withValues(alpha: 0.35)),
            boxShadow: [
              AppDecorations.glow(info.color, blur: 28),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                if (result.resultImageBytes != null)
                  Image.memory(
                    result.resultImageBytes!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  )
                else
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.textMuted, size: 40),
                      ),
                    ),
                  ),
                // Scan line overlay aesthetic
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            info.color.withValues(alpha: 0.04),
                            Colors.transparent,
                            info.color.withValues(alpha: 0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom label bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        _MiniLegendDot(color: AppColors.lungBlue, label: 'ปอด'),
                        const SizedBox(width: 14),
                        _MiniLegendDot(color: AppColors.ribRed, label: 'Rib 9'),
                        const SizedBox(width: 14),
                        _MiniLegendDot(
                            color: AppColors.overlapMagenta, label: 'ทับซ้อน'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 120.ms, duration: 600.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _buildMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'ข้อมูล Segmentation',
          subtitle: 'พื้นที่ที่ตรวจพบ (pixels)',
          icon: Icons.analytics_outlined,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                icon: Icons.air_rounded,
                iconColor: AppColors.lungBlue,
                label: 'Lung Area',
                value: _formatPx(result.lungArea),
                unit: 'px',
                delay: 280,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                icon: Icons.view_in_ar_rounded,
                iconColor: AppColors.ribRed,
                label: 'Rib 9 Area',
                value: _formatPx(result.ribArea),
                unit: 'px',
                delay: 360,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MetricCard(
          icon: Icons.blur_on_rounded,
          iconColor: AppColors.overlapMagenta,
          label: 'Overlap Area',
          value: _formatPx(result.overlapArea),
          unit: 'px',
          delay: 440,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildColorLegend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.glass(borderColor: AppColors.accent, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'คำอธิบายสี',
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: 18),
          const _LegendRow(
            color: AppColors.lungBlue,
            label: 'Lung Region',
            description: 'เขตปอดที่ AI ตรวจพบ',
          ),
          const SizedBox(height: 12),
          const _LegendRow(
            color: AppColors.ribRed,
            label: 'Rib 9',
            description: 'ซี่โครงที่ 9 ที่ segment ได้',
          ),
          const SizedBox(height: 12),
          const _LegendRow(
            color: AppColors.overlapMagenta,
            label: 'Overlap',
            description: 'พื้นที่ซี่โครงทับกับปอด',
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms, duration: 500.ms);
  }

  _VerdictInfo _verdictInfo(AnalysisVerdict verdict) {
    switch (verdict) {
      case AnalysisVerdict.pass:
        return const _VerdictInfo(
          badge: 'PASS',
          headline: 'ผ่านเกณฑ์ — ใช้ภาพต่อได้',
          subtitle: 'Confidence ≥ 0.95 และ IoU > 0.85',
          color: AppColors.pass,
          icon: Icons.verified_rounded,
        );
      case AnalysisVerdict.fail:
        return const _VerdictInfo(
          badge: 'FAIL',
          headline: 'ไม่ผ่านเกณฑ์ — ไม่ควรใช้ภาพต่อ',
          subtitle: 'Confidence สูงแต่ IoU ไม่ถึง หรือไม่พบ Rib 9',
          color: AppColors.fail,
          icon: Icons.block_rounded,
        );
      case AnalysisVerdict.needsReview:
        return const _VerdictInfo(
          badge: 'REVIEW',
          headline: 'ต้องตรวจสอบด้วยตา',
          subtitle: 'Confidence < 0.95 — ดู box/tag บนภาพอีกครั้ง',
          color: AppColors.review,
          icon: Icons.rate_review_rounded,
        );
      case AnalysisVerdict.unknown:
        return const _VerdictInfo(
          badge: 'UNKNOWN',
          headline: 'ไม่ทราบผลการประเมิน',
          subtitle: 'กรุณาลองวิเคราะห์ใหม่',
          color: AppColors.textMuted,
          icon: Icons.help_outline_rounded,
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
  final Color color;
  final IconData icon;

  const _VerdictInfo({
    required this.badge,
    required this.headline,
    required this.subtitle,
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

class _MiniLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _MiniLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [AppDecorations.glow(color, blur: 8)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String description;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.35),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            boxShadow: [AppDecorations.glow(color, blur: 12)],
          ),
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(description, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}
