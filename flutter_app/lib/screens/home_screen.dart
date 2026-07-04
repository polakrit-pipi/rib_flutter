import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  XFile? _selectedImage;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();
  final ApiService _api = ApiService();
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 95,
    );
    if (picked != null) {
      setState(() => _selectedImage = picked);
    }
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surfaceElevated,
              AppColors.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('เลือกแหล่งภาพ', style: AppTextStyles.title),
                const SizedBox(height: 8),
                Text(
                  'อัปโหลดภาพ X-ray ทรวงอกเพื่อวิเคราะห์',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.photo_library_rounded,
                        label: 'แกลเลอรี',
                        gradient: AppGradients.accent,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'กล้อง',
                        gradient: const LinearGradient(
                          colors: [AppColors.accentPurple, AppColors.accentBlue],
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runAnalysis() async {
    if (_selectedImage == null) return;
    setState(() => _isAnalyzing = true);

    try {
      final result = await _api.analyze(_selectedImage!);
      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ResultScreen(result: result),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 550),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.fail),
            SizedBox(width: 12),
            Text('วิเคราะห์ไม่สำเร็จ', style: AppTextStyles.title),
          ],
        ),
        content: Text(
          msg.length > 200 ? '${msg.substring(0, 200)}...' : msg,
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ตกลง',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppGradients.accent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [AppDecorations.glow(AppColors.accent, blur: 16)],
              ),
              child: const Icon(Icons.biotech_rounded, color: Colors.black, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rib 9 Scanner', style: AppTextStyles.title),
                Text('Lung Overlap Analysis',
                    style: TextStyle(color: AppColors.accent, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: AppDecorations.glass(radius: 12),
              child: const Icon(Icons.tune_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroCard(),
                const SizedBox(height: 24),
                _buildUploadArea(),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 24),
                  _buildImagePreview(),
                ],
                const SizedBox(height: 24),
                _buildAnalyzeButton(),
                const SizedBox(height: 28),
                _buildCriteriaCard(),
                const SizedBox(height: 20),
                _buildLegend(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.15),
            AppColors.surfaceElevated.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        boxShadow: [
          AppDecorations.glow(AppColors.accent, blur: 24),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Segmentation',
                  style: AppTextStyles.sectionLabel.copyWith(color: AppColors.accent),
                ),
                const SizedBox(height: 8),
                const Text(
                  'วิเคราะห์การทับซ้อน\nซี่โครงที่ 9 กับปอด',
                  style: AppTextStyles.display,
                ),
                const SizedBox(height: 10),
                Text(
                  'อัปโหลดภาพ X-ray แล้วระบบจะประเมินว่าภาพผ่านเกณฑ์ใช้งานต่อหรือไม่',
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.monitor_heart_outlined,
                color: AppColors.accent, size: 36),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.15, end: 0);
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _showPickerSheet,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) {
          return DottedBorder(
            color: AppColors.accent.withValues(
                alpha: 0.35 + _shimmerController.value * 0.25),
            strokeWidth: 2,
            dashPattern: const [12, 7],
            borderType: BorderType.RRect,
            radius: const Radius.circular(26),
            child: Container(
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.06),
                    AppColors.surface.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.accent,
                      boxShadow: [AppDecorations.glow(AppColors.accent, blur: 20)],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.black, size: 34),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'แตะเพื่ออัปโหลดภาพ X-ray',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'รองรับ JPG · JPEG · PNG',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 600.ms).slideY(begin: 0.12, end: 0);
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        Container(
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            boxShadow: [
              AppDecorations.glow(AppColors.accent, blur: 24),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FutureBuilder<Uint8List>(
              future: _selectedImage!.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(snapshot.data!, fit: BoxFit.cover),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Container(
                  color: AppColors.surface,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _FloatingBadge(
            icon: Icons.check_circle_rounded,
            label: 'พร้อมวิเคราะห์',
            color: AppColors.pass,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: _showPickerSheet,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: AppDecorations.glass(radius: 12),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: AppColors.textPrimary, size: 20),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildAnalyzeButton() {
    final bool canAnalyze = _selectedImage != null && !_isAnalyzing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: canAnalyze ? AppGradients.accentVertical : null,
        color: canAnalyze ? null : AppColors.surfaceElevated,
        boxShadow: canAnalyze
            ? [
                AppDecorations.glow(AppColors.accent, blur: 28),
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: canAnalyze ? _runAnalysis : null,
          child: Center(
            child: _isAnalyzing
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      ),
                      SizedBox(width: 14),
                      Text(
                        'กำลังวิเคราะห์...',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: canAnalyze ? Colors.black : AppColors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _selectedImage != null
                            ? 'เริ่มวิเคราะห์'
                            : 'เลือกภาพก่อน',
                        style: TextStyle(
                          color: canAnalyze ? Colors.black : AppColors.textMuted,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms);
  }

  Widget _buildCriteriaCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.glass(borderColor: AppColors.accentBlue, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rule_rounded,
                    color: AppColors.accentBlue, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('เกณฑ์การผ่าน', style: AppTextStyles.title),
            ],
          ),
          const SizedBox(height: 16),
          _CriteriaRow(
            icon: Icons.verified_rounded,
            color: AppColors.pass,
            text: 'Conf ≥ 0.95 และ IoU > 0.85 → ผ่าน ใช้ภาพต่อได้',
          ),
          const SizedBox(height: 10),
          _CriteriaRow(
            icon: Icons.block_rounded,
            color: AppColors.fail,
            text: 'Conf ≥ 0.95 แต่ IoU ≤ 0.85 → ไม่ผ่าน',
          ),
          const SizedBox(height: 10),
          _CriteriaRow(
            icon: Icons.rate_review_rounded,
            color: AppColors.review,
            text: 'Conf < 0.95 → ต้องตรวจสอบด้วยตา (มี box/tag)',
          ),
        ],
      ),
    ).animate().fadeIn(delay: 450.ms, duration: 500.ms);
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.glass(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สีบนภาพผลลัพธ์', style: AppTextStyles.title),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LegendItem(color: AppColors.lungBlue, label: 'ปอด'),
              _LegendItem(color: AppColors.ribRed, label: 'Rib 9'),
              _LegendItem(color: AppColors.overlapMagenta, label: 'ทับซ้อน'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 550.ms, duration: 500.ms);
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (ctx) => _SettingsDialog(api: _api),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.black, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FloatingBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [AppDecorations.glow(color, blur: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CriteriaRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _CriteriaRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppTextStyles.body.copyWith(fontSize: 13)),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            boxShadow: [AppDecorations.glow(color, blur: 8)],
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  final ApiService api;
  const _SettingsDialog({required this.api});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.api.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('ตั้งค่า Server', style: AppTextStyles.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FastAPI Server URL', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'http://localhost:8000',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Android emulator: http://10.0.2.2:8000\n'
            'Physical device: http://<your-lan-ip>:8000\n'
            'Desktop/iOS: http://localhost:8000',
            style: AppTextStyles.caption.copyWith(height: 1.6),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            widget.api.baseUrl = _controller.text.trim();
            Navigator.pop(context);
          },
          child: const Text('บันทึก', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
