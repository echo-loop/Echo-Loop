// API_BASE_URL 配置全球 API 候选地址；实际区域由 RuntimeEndpointRouter 在运行时选择。

import 'package:flutter/foundation.dart' show kReleaseMode;

/// 全球生产 API 地址，可通过 `API_BASE_URL` 编译期变量覆盖。
const globalApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://www.echo-loop.top',
);

/// 发布使用全球 API 候选地址；开发和测试默认使用本地地址，也允许覆盖。
const apiBaseUrl = kReleaseMode
    ? globalApiBaseUrl
    : String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000',
      );
