// mailto_web.dart — Web 平台实现：打开外部 URL，mailto: 会唤起默认邮件客户端。
import 'dart:html' as html;

void openExternalUrl(String url) {
  html.window.location.href = url;
}
