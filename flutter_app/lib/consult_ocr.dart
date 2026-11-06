// consult_ocr.dart
// v58：诊断材料图片 OCR 客户端（医药布道模块「上传即识别」链路的一环）。
//
// 背景：v46 起附件解析对图片一律返回「需手动誊写」占位，上传诊断证明图片后
// 表单四个字段全部要人工填写。v57 的本地识别器（MaterialRecognizer）只能
// 处理已提取的文本，缺的是「图片 → 文字」这一环。
//
// 本文件补上该环节：图片字节经 base64 送后端 /api/ocr（视觉模型纯转录），
// 拿回全文后交本地识别器提取字段。**OCR 只转录文字、不做任何医疗判断**，
// 转录文本与本地识别结果最终都由用户核实后提交。
//
// v59：后端原默认付费视觉模型 glm-4v-plus 在账号余额耗尽后返回 1113
// 「余额不足或无可用资源包」→ /api/ocr 502 → 本客户端收不到文本 → 自动填编
// 失效。后端已切换为免费视觉模型链并做 fallback，本文件同步放宽超时以匹配。
//
// 失败策略（任一环节失败都返回 null，由调用方退回「手动誊写」提示，
// 绝不阻塞上传流程）：
//   - kRagBaseUrl 为空（灰度关闭）
//   - 网络错误 / 超时（60s；后端 v59 起会依次尝试多个免费视觉模型，需留足时间）
//   - 非 200 / ok != true / 文本为空
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'rag_config.dart';

/// 图片 OCR：返回转录文本；失败返回 null（调用方应退回手动誊写提示）。
class ConsultOcr {
  ConsultOcr._();

  /// 超时：托管网关对挂死的上游有过期窗口，必须按时放弃（服务本身 4xx/5xx
  /// 属正常响应，别误判挂了）。后端 v59 的免费模型 fallback 链总预算 50s，
  /// 客户端需略大于该值，否则模型刚切到第二个就被前端提前放弃。
  static const Duration timeout = Duration(seconds: 60);

  /// 可注入的取数器（测试 seam；生产默认走 [_defaultFetch]）。
  static Future<String?> Function(Uint8List bytes, String mime)?
      fetcherForTest;

  /// 识别图片文字。[bytes] 图片字节；[mime] 如 'image/jpeg'。
  /// 失败（网络/超时/上游错误/空文本）一律返回 null。
  /// [client] 可注入 http 客户端（测试用）。
  static Future<String?> recognizeImage(
    Uint8List bytes,
    String mime, {
    http.Client? client,
  }) async {
    if (kRagBaseUrl.isEmpty) return null;
    if (bytes.isEmpty) return null;
    if (fetcherForTest != null) return fetcherForTest!(bytes, mime);
    return _defaultFetch(bytes, mime, client);
  }

  static Future<String?> _defaultFetch(
    Uint8List bytes,
    String mime,
    http.Client? client,
  ) async {
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(
            Uri.parse(consultOcrApiUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': base64Encode(bytes),
              'mime': mime,
            }),
          )
          .timeout(timeout);
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (j['ok'] != true) return null;
      final text = (j['text'] ?? '').toString().trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }
}
