import 'package:flutter_test/flutter_test.dart';
import 'package:core_network/core_network.dart';

import 'package:zhixuan_main/main.dart';

void main() {
  test('ZhixuanSuperApp accepts ApiClient dependency', () {
    final apiClient = ApiClient(baseUrl: 'https://test.api.zhixuan.global');
    final app = ZhixuanSuperApp(apiClient: apiClient);

    expect(app.apiClient, same(apiClient));
  });
}
