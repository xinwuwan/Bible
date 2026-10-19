// external_link_web.dart — Web 平台：新标签打开外部链接，避免离开 App。
import 'dart:html' as html;

void openExternalLink(String url) {
  html.window.open(url, '_blank');
}
