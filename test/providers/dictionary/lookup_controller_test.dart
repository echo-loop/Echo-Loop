import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/providers/dictionary/dictionary_registry.dart';
import 'package:echo_loop/providers/dictionary/lookup_controller.dart';
import 'package:echo_loop/providers/dictionary/visible_sources_provider.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可控源：每次 lookup 返回一个手动完成的 Future，用于编排竞态时序
class ControllableSource implements DictionarySource {
  @override
  final String id;
  @override
  final bool requiresNetwork;
  ControllableSource(this.id, {this.requiresNetwork = true});

  final List<Completer<DictionaryLookupResult?>> calls = [];

  /// 记录每次 lookup 收到的请求，供断言归一化结果
  final List<DictionaryLookupRequest> requests = [];

  @override
  IconData get icon => Icons.abc;
  @override
  bool get canBeDisabled => true;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) {
    requests.add(request);
    final c = Completer<DictionaryLookupResult?>();
    calls.add(c);
    return c.future;
  }
}

DictionaryLookupResult _result(String word) => WebDictResult(
  sourceId: 'cambridge',
  url: Uri.parse('https://x/$word'),
  word: word,
);

void main() {
  // 让 build() 里的 Future.microtask 跑完
  Future<void> pump() => Future<void>.delayed(Duration.zero);

  ProviderContainer makeContainer(
    Map<String, DictionarySource> sources, {
    String defaultId = 'a',
  }) {
    final c = ProviderContainer(
      overrides: [
        dictionarySourcesByIdProvider.overrideWithValue(sources),
        resolvedDefaultSourceIdProvider.overrideWithValue(defaultId),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// 启动 controller 并保持订阅（autoDispose 在测试中无监听会被立即销毁）
  DictionaryLookupController start(ProviderContainer c, String word) {
    final p = dictionaryLookupControllerProvider(word);
    final sub = c.listen(p, (_, _) {});
    addTearDown(sub.close);
    return c.read(p.notifier);
  }

  test('进入即查默认源 → Loading 然后 Loaded', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    final ctrl = start(c, 'run');

    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoading>(),
    );

    a.calls.single.complete(_result('run'));
    await pump();
    final state = c.read(dictionaryLookupControllerProvider('run'));
    expect(state.current, isA<LookupLoaded>());
    expect((state.current! as LookupLoaded).result.headword, 'run');
    expect(ctrl, isNotNull);
  });

  test('切到另一个源加载；切回不重复查询', () async {
    final a = ControllableSource('a');
    final b = ControllableSource('b');
    final c = makeContainer({'a': a, 'b': b});
    final ctrl = start(c, 'run');
    await pump();
    a.calls.single.complete(_result('a-run'));
    await pump();

    ctrl.selectSource('b');
    await pump();
    b.calls.single.complete(_result('b-run'));
    await pump();
    expect(
      (c.read(dictionaryLookupControllerProvider('run')).current!
              as LookupLoaded)
          .result
          .headword,
      'b-run',
    );

    // 切回 a：复用缓存，不再调用 a.lookup
    ctrl.selectSource('a');
    await pump();
    expect(a.calls, hasLength(1)); // 仍只调用过一次
    expect(
      (c.read(dictionaryLookupControllerProvider('run')).current!
              as LookupLoaded)
          .result
          .headword,
      'a-run',
    );
  });

  test('未收录 → LookupNotFound', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    start(c, 'run');
    await pump();
    a.calls.single.complete(null);
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupNotFound>(),
    );
  });

  test('需登录 → LookupAuthRequired', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    start(c, 'run');
    await pump();
    a.calls.single.completeError(const DictionaryAuthRequiredException());
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupAuthRequired>(),
    );
  });

  test('失败 → LookupError；retry 重新查询', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    final ctrl = start(c, 'run');
    await pump();
    a.calls.single.completeError(Exception('boom'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupError>(),
    );

    ctrl.retry();
    await pump();
    expect(a.calls, hasLength(2));
    a.calls.last.complete(_result('run'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoaded>(),
    );
  });

  test('同源竞态：旧查询晚到被丢弃，只保留新结果', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    final ctrl = start(c, 'run');
    await pump(); // 第 1 次查询发起

    ctrl.retry(); // 第 2 次查询发起（同源）
    await pump();
    expect(a.calls, hasLength(2));

    // 旧查询(call#0)晚到 → 应被丢弃
    a.calls[0].complete(_result('OLD'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoading>(),
    );

    // 新查询(call#1)到达 → 生效
    a.calls[1].complete(_result('NEW'));
    await pump();
    expect(
      (c.read(dictionaryLookupControllerProvider('run')).current!
              as LookupLoaded)
          .result
          .headword,
      'NEW',
    );
  });

  test('controller 销毁后在途请求完成不写已销毁状态（不抛错）', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    final p = dictionaryLookupControllerProvider('run');
    final sub = c.listen(p, (_, _) {});
    await pump();
    expect(a.calls, hasLength(1));

    // 关闭订阅 → autoDispose 销毁 controller（模拟关闭词典弹窗）
    sub.close();
    await pump();

    // 在途请求此刻才完成（AI 后台跑完的回调晚于 dispose 到达）：
    // disposed 守卫应丢弃回调，不对已销毁 Notifier 写 state，否则会抛错。
    a.calls.single.complete(_result('run'));
    await pump();
    // 跑到这里无未捕获异常即通过
  });

  test('word（已由调用方归一化）原样透传给各源，controller 不再归一', () async {
    final a = ControllableSource('a');
    final c = makeContainer({'a': a});
    // family key 已是归一化结果（由 widget 层 normalizeWord 产出）
    start(c, "dogs'");
    await pump();
    expect(a.requests.single.word, "dogs'");
  });

  test('词组（含空格）：AI 源可见时初始源为 AI，忽略全局默认源', () async {
    final a = ControllableSource('a');
    final ai = ControllableSource('ai');
    final c = ProviderContainer(
      overrides: [
        dictionarySourcesByIdProvider.overrideWithValue({'a': a, 'ai': ai}),
        resolvedDefaultSourceIdProvider.overrideWithValue('a'),
        visibleDictionarySourcesProvider.overrideWithValue([a, ai]),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    start(c, 'give up');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('give up')).selectedSourceId,
      'ai',
    );
    expect(ai.calls, hasLength(1)); // 进入即查 AI 源
    expect(a.calls, isEmpty);
    expect(ai.requests.single.word, 'give up');
  });

  test('词组：AI 源不可见时回退全局默认源', () async {
    final a = ControllableSource('a');
    final c = ProviderContainer(
      overrides: [
        dictionarySourcesByIdProvider.overrideWithValue({'a': a}),
        resolvedDefaultSourceIdProvider.overrideWithValue('a'),
        visibleDictionarySourcesProvider.overrideWithValue([a]),
        dictionaryLookupContextProvider.overrideWithValue(
          const DictionaryLookupContext(
            accessToken: 'tok',
            targetLanguage: 'zh-CN',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    start(c, 'give up');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('give up')).selectedSourceId,
      'a',
    );
    expect(a.calls, hasLength(1));
  });

  test('单词（无空格）初始源沿用全局默认源，不读可见源列表', () async {
    final a = ControllableSource('a');
    // 不 override visibleDictionarySourcesProvider：单词路径不应读它
    final c = makeContainer({'a': a});
    start(c, 'run2');
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run2')).selectedSourceId,
      'a',
    );
  });

  test('不需联网的源不读取上下文也能查', () async {
    final a = ControllableSource('a', requiresNetwork: false);
    // 不 override context：若 controller 误读会抛错
    final c = ProviderContainer(
      overrides: [
        dictionarySourcesByIdProvider.overrideWithValue({'a': a}),
        resolvedDefaultSourceIdProvider.overrideWithValue('a'),
      ],
    );
    addTearDown(c.dispose);
    start(c, 'run');
    await pump();
    a.calls.single.complete(_result('run'));
    await pump();
    expect(
      c.read(dictionaryLookupControllerProvider('run')).current,
      isA<LookupLoaded>(),
    );
  });
}
