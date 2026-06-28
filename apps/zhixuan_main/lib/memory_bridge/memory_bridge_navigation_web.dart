import 'dart:html' as html;

String buildMemoryBridgeUrl() {
  final origin = html.window.location.origin ?? '';
  return '$origin/memory/';
}

bool openMemoryBridgeInSameTab(String url) {
  html.window.location.assign(url);
  return true;
}
