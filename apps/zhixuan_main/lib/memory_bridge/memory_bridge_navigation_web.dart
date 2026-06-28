import 'package:web/web.dart' as web;

String buildMemoryBridgeUrl() {
  final origin = web.window.location.origin;
  return '$origin/memory/';
}

bool openMemoryBridgeInSameTab(String url) {
  web.window.location.assign(url);
  return true;
}
