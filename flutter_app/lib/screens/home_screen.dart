import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
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
  Uint8List? _selectedImageBytes;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 95,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();

      setState(() {
        _selectedImage = picked;
        _selectedImageBytes = bytes;
      });
    }
  }

  void _showPickerSheet() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(12),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Select image source',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Choose where to load the chest X-ray image from.',
                  style: AppTextStyles.caption,
                ),

                const SizedBox(height: 18),

                _SourceButton(
                  icon: Icons.photo_outlined,
                  label: 'Choose from gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),

                const SizedBox(height: 10),

                _SourceButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take a photo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
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
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: AppColors.border,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),

      title: const Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.fail,
            size: 20,
          ),
          SizedBox(width: 10),
          Text(
            'Analysis failed',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),

      content: Text(
        msg.length > 200 ? '${msg.substring(0, 200)}...' : msg,
        style: AppTextStyles.body,
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
          ),
          child: const Text(
            'Close',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border,
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.biotech_outlined,
                color: AppColors.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chest X-ray Analysis', style: AppTextStyles.title),
                Text(
                  'Rib 9 Scanner',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
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
      body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1440,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedImage == null)
                      _buildUploadArea()
                    else
                      _buildImagePreview(),

                    const SizedBox(height: 16),
                    _buildAnalyzeButton(),
                    const SizedBox(height: 20),
                    _buildCriteriaCard(),
                    const SizedBox(height: 16),
                    _buildLegend(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

Widget _buildUploadArea() {
  return GestureDetector(
    onTap: _showPickerSheet,
    child: Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.borderStrong,
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: const Icon(
                Icons.upload_rounded,
                color: AppColors.textSecondary,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Select a chest X-ray image',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Supported formats: DICOM, PNG, JPG',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: _showPickerSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Browse Files',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildImagePreview() {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.border,
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected image',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ready for analysis',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showPickerSheet,
                icon: const Icon(
                  Icons.swap_horiz_rounded,
                  size: 17,
                ),
                label: const Text('Change'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border,
        ),

        Container(
          color: const Color(0xFFF3F5F7),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 560,
                maxHeight: 520,
              ),
              child: _selectedImageBytes != null
                  ? Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                    )
                  : const SizedBox(
                      height: 420,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
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

Widget _buildAnalyzeButton() {
  final bool canAnalyze = _selectedImage != null && !_isAnalyzing;

  return Align(
    alignment: Alignment.centerRight,
    child: SizedBox(
      width: 180,
      height: 42,
      child: ElevatedButton(
        onPressed: canAnalyze ? _runAnalysis : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceElevated,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: _isAnalyzing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Analyzing...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 17,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Analyze',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

  Widget _buildCriteriaCard() {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.border,
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Text(
            'Analysis criteria',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border,
        ),

        _CriteriaRow(
          status: 'PASS',
          color: AppColors.pass,
          criteria: 'Confidence ≥ 0.89',
          result: 'IoU > 0.85',
          description: 'Image can be used for further assessment',
        ),

        const Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: AppColors.border,
        ),

        _CriteriaRow(
          status: 'FAIL',
          color: AppColors.fail,
          criteria: 'Confidence ≥ 0.89',
          result: 'IoU ≤ 0.85',
          description: 'Image does not meet the acceptance criteria',
        ),

        const Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: AppColors.border,
        ),

        _CriteriaRow(
          status: 'REVIEW',
          color: AppColors.review,
          criteria: 'Confidence < 0.89',
          result: 'Manual review',
          description: 'Visual verification is required',
        ),
      ],
    ),
  );
}

  Widget _buildLegend() {
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

        const _LegendItem(
          color: AppColors.lungBlue,
          label: 'Lung',
        ),

        const SizedBox(width: 20),

        const _LegendItem(
          color: AppColors.ribRed,
          label: 'Rib 9',
        ),

        const SizedBox(width: 20),

        const _LegendItem(
          color: AppColors.overlapMagenta,
          label: 'Overlap',
        ),
      ],
    ),
  );
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
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          side: const BorderSide(
            color: AppColors.border,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.textSecondary,
              size: 19,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _CriteriaRow extends StatelessWidget {
  final String status;
  final Color color;
  final String criteria;
  final String result;
  final String description;

  const _CriteriaRow({
    required this.status,
    required this.color,
    required this.criteria,
    required this.result,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            flex: 2,
            child: Text(
              criteria,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            flex: 2,
            child: Text(
              result,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            flex: 3,
            child: Text(
              description,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
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
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(
        color: AppColors.border,
      ),
    ),

    titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),

    title: const Text(
      'Server settings',
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),

    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FastAPI Server URL',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 6),

          TextField(
            controller: _controller,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'http://localhost:8000',
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),

              filled: true,
              fillColor: AppColors.bgBase,

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.border,
                ),
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.border,
                ),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: const Text(
              'Android emulator: http://10.0.2.2:8000\n'
              'Physical device: http://<your-lan-ip>:8000\n'
              'Desktop / iOS: http://localhost:8000',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    ),

    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      SizedBox(
        height: 38,
        child: ElevatedButton(
          onPressed: () {
            widget.api.baseUrl = _controller.text.trim();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text(
            'Save',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );
}
}