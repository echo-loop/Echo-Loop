/// 在线词典数据源
///
/// 包装 [DictionaryService]：先读本地缓存，未命中再请求在线词典 API。
/// 不可禁用；缓存命中时离线可用，未命中且无网络时抛出异常，由 controller 转为错误态。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/dictionary/dictionary_lookup_result.dart';
import '../dictionary_service.dart';
import 'dictionary_source.dart';

/// 在线词典源（源 id 沿用 `local`，它是持久化与缓存的稳定标识）
class LocalDictionarySource implements DictionarySource {
  final DictionaryService _service;

  LocalDictionarySource(this._service);

  @override
  String get id => 'local';

  @override
  IconData get icon => Icons.menu_book_rounded;

  @override
  bool get canBeDisabled => false;

  @override
  bool get requiresNetwork => true;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async {
    final entry = await _service.lookup(request.word);
    return entry == null ? null : LocalDictResult(entry);
  }
}
