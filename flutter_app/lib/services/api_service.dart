import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Verdict from backend scoring: Conf ≥ 0.95 + IoU > 0.85 → PASS, etc.
enum AnalysisVerdict { pass, fail, needsReview, unknown }

AnalysisVerdict _parseVerdict(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'PASS':
      return AnalysisVerdict.pass;
    case 'FAIL':
      return AnalysisVerdict.fail;
    case 'NEEDS_REVIEW':
      return AnalysisVerdict.needsReview;
    default:
      return AnalysisVerdict.unknown;
  }
}

/// Data model for analysis results returned by the FastAPI backend.
class AnalysisResult {
  final int lungArea;
  final int ribArea;
  final int overlapArea;
  final double overlapPercent;
  final double iou;
  final double ribConf;
  final AnalysisVerdict verdict;
  final String verdictReason;
  final bool ribDetected;
  final Uint8List? resultImageBytes;

  const AnalysisResult({
    required this.lungArea,
    required this.ribArea,
    required this.overlapArea,
    required this.overlapPercent,
    required this.iou,
    required this.ribConf,
    required this.verdict,
    required this.verdictReason,
    required this.ribDetected,
    this.resultImageBytes,
  });

  bool get isUsable => verdict == AnalysisVerdict.pass;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    Uint8List? resultBytes;

    final String? resultB64 = json['result_image'] as String?;
    if (resultB64 != null && resultB64.isNotEmpty) {
      resultBytes = base64Decode(resultB64);
    }

    return AnalysisResult(
      lungArea: json['lung_area'] as int? ?? 0,
      ribArea: json['rib_area'] as int? ?? 0,
      overlapArea: json['overlap_area'] as int? ?? 0,
      overlapPercent: (json['overlap_percent'] as num?)?.toDouble() ?? 0.0,
      iou: (json['iou'] as num?)?.toDouble() ?? 0.0,
      ribConf: (json['rib_conf'] as num?)?.toDouble() ?? 0.0,
      verdict: _parseVerdict(json['verdict'] as String?),
      verdictReason: json['verdict_reason'] as String? ?? '',
      ribDetected: json['rib_detected'] as bool? ?? false,
      resultImageBytes: resultBytes,
    );
  }
}

/// HTTP client that communicates with the FastAPI backend.
/// Uses XFile so it works on both web and mobile/desktop.
class ApiService {
  String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8000'});

  /// Check if the backend is up and models are loaded.
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send an XFile image to the backend and return the analysis result.
  /// Works on web (bytes) and mobile/desktop (path).
  Future<AnalysisResult> analyze(XFile imageFile) async {
    final uri = Uri.parse('$baseUrl/analyze');
    final request = http.MultipartRequest('POST', uri);

    // Read as bytes — works on ALL platforms including web
    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.name.isNotEmpty ? imageFile.name : 'xray.jpg';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    try {
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw Exception(
          'หมดเวลารอการตอบกลับ กรุณาตรวจสอบว่า backend ทำงานที่ $baseUrl',
        ),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return AnalysisResult.fromJson(json);
      } else if (response.statusCode == 422) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = json['detail'] ?? 'ไม่พบปอดในภาพนี้';
        throw Exception(detail);
      } else if (response.statusCode == 503) {
        throw Exception(
          'Server ยังไม่พร้อม (โมเดลกำลังโหลด) กรุณารอสักครู่แล้วลองใหม่',
        );
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
        final detail = json['detail'] ?? 'เกิดข้อผิดพลาด (${response.statusCode})';
        throw Exception(detail);
      }
    } on http.ClientException catch (e) {
      throw Exception(formatConnectionError(baseUrl, e.message));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Connection refused') ||
          msg.contains('Failed host lookup')) {
        throw Exception(formatConnectionError(baseUrl));
      }
      rethrow;
    }
  }

  /// Human-readable Thai message when backend is unreachable.
  static String formatConnectionError(String baseUrl, [String? detail]) {
    return 'เชื่อมต่อ backend ไม่ได้ที่ $baseUrl\n\n'
        'กรุณาเปิด FastAPI server ก่อน:\n'
        '1. ดับเบิลคลิก start_server.bat\n'
        '   หรือรัน: uvicorn api:app --host 0.0.0.0 --port 8000\n'
        '2. รอจนเห็น "Models loaded successfully"\n'
        '3. ลองวิเคราะห์ใหม่อีกครั้ง'
        '${detail != null && detail.isNotEmpty ? '\n\n($detail)' : ''}';
  }
}
