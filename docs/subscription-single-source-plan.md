# 订阅权益重构:单一来源(后端 `/api/entitlements` 为唯一权威)

> 本文件是**可直接实现的交付规格**。实现者无需重新规划,按"逐文件改动"与"测试"两节照做即可。
> 代码库:Flutter App `/Volumes/SamsungT7/workspace/fluency/fluency`;后端 `fluency-frontend`(仅读,本次不改)。

---

## 1. Context(为什么改)

App 有两套订阅来源:App Store/Google Play 走 RevenueCat(RC);Web/direct 走自建 Paddle。后端 `/api/entitlements` 已经**在服务端合并 RC + Paddle**(RC webhook 写 `user_entitlements`、Paddle webhook 写 `paddle_subscriptions`,合并后带 `source` 返回)。

但客户端目前是"两个权威源在端上打架":native 渠道**先信 RC 的 `currentEntitlement()`,RC 判非会员时才补查后端**。由此产生三个已复现的线上问题(均为客户端逻辑问题,非后端/Paddle 数据问题):

- **Bug1**:Paddle 会员在 App Store 包点"恢复购买" → 仍调用 RC `restorePurchases()` → `receiptAlreadyInUseError` → 误报"购买失败,请重试"。
- **Bug2**:RC restore 返回空权益 → `_applyEntitlement` 直接把 `status` 置 `free` 并写缓存,覆盖了本应有效的 Paddle premium。
- **Bug3**:native 下 RC 返回 `free`(非 null)、随后后端补查网络失败(`fetchRemote` 返回 null)→ `remote` 仍保留 RC 的 `free` → `reconcileEntitlement` 判 `remote!=null` 为权威 → 降级 `free`,忽略新鲜的 Paddle premium 缓存。

根因:**把只懂 Apple/Google 的 RC 结果当成了全局会员权威**,而 RC 对 Paddle 一无所知。

---

## 2. 方案抉择(已定稿)

**采用:单一来源。客户端所有渠道对账只读后端 `/api/entitlements`;reconcile 路径彻底不再调用 RC `currentEntitlement()`。**

### 为什么(与被否决的方案对比)
- **否决 A:混合模型**(RC 正向短路、负向查后端 —— 只改一行 `remote=backend`)。能修 bug,但保留了"两源在端上仲裁"的长期复杂度,bug 类仍有生存空间。
- **否决 B:Paddle→RevenueCat external purchase import**(POST /v1/receipts 把 Paddle 导入 RC,客户端只读 CustomerInfo)。最彻底,但涉及后端+RC 配置迁移、Apple 外部购买合规评估,周期长,不在本次。
- **选定 C:单一来源(后端权威)**。三个 bug **结构性消除**(reconcile 路径不读 RC,Bug2/Bug3 无处发生);web 与 native 对账合并为同一条路径,`_refreshOnline` 双分支消失,更简单。

### 已排除的伪约束(不要用它们反推设计)
- **后端成本**:不是问题。`/api/entitlements` → `getUserEntitlementSummaryWithReconcile`(`fluency-frontend/packages/payments/libs/entitlements.ts:329`)对唯一昂贵动作(回源 RC API)已做**每用户 24h 节流**(`ENTITLEMENT_RECONCILE_INTERVAL_MS`);绝大多数请求只走 2~3 条索引查表,开销与任意已鉴权业务接口同级,RC 不按 API 调用计费。成本与选型无关。
- **降级新鲜度**:与权威模型无关(见 §6)。退款/退订经 webhook **秒级**写入后端 DB(不经 24h 节流);客户端多快看到取决于刷新触发点。

### RC 的角色(**不删除**,只瘦身)
RC 继续负责:Apple/Google 购买执行、Offerings 价格、收据服务端校验 + webhook 进后端、商店 restore 认领、`identify(supabaseUserId)` 身份绑定。**仅移除"客户端用 RC 判断会员"这一职责。** 只有完全停售 Apple/Google IAP 才谈得上删 RC(=方案 B,非本次)。

### 抽象原则的现状
"上层不区分 RC/API/谁优先" 这条原则,在单一来源下**退化为普通分层卫生**(UI 只依赖 `EntitlementState` + 语义意图,不直接碰传输层),不再是需要专门设计的受力构件——因为端上已无"多源仲裁"可隐藏。

---

## 3. 架构与数据模型(现状,基本不动)

分层:UI(`paywall_screen.dart`)→ `SubscriptionController`(唯一状态入口)→ `EntitlementRepository`(后端)/ `PurchaseService`(RC 购买执行)/ `EntitlementCache`(本地缓存)。UI 只读 `EntitlementState`。

数据模型(均无需改):
- `Entitlement`(`lib/features/subscription/models/entitlement.dart`):`isPremium/productId/expiresAt/willRenew/source` 等;`isActive(now)`;`Entitlement.free`。
- `EntitlementSource`(`.../models/entitlement_source.dart`):`apple/google/paddle/unknown`。
- `EntitlementState`(`.../state/entitlement_state.dart`):`status(premium/free/unknown)/entitlement/isStale/error`;`isActive` getter。
- `reconcileEntitlement`(`.../services/entitlement_reconciler.dart`)**契约不变**:`remote!=null`→采用并 `isStale=false`;`remote==null` 且缓存新鲜(≤24h)→用缓存 `isStale=true`;否则 `unknown/isStale=true`。**关键:`remote==null` 表示"未能获取",不是"确认无权益";"确认无权益"必须传 `Entitlement.free`。**

---

## 4. 接口设计与输入输出(核心改动)

### 4.1 `SubscriptionController._refreshOnline()` —— 改为单一来源
文件:`lib/features/subscription/providers/subscription_controller.dart`(当前第 129–236 行整段方法体替换)。

**新逻辑(输入→输出映射)**:
```dart
Future<void> _refreshOnline() async {
  final override = _debugOverride;
  if (override != null) { _setEntitlementState(_stateForOverride(override)); return; }

  final generation = ++_generation;
  final identity = _identity;
  final userId = identity.userId;
  final accessToken = identity.accessToken;
  AppLogger.log('Subscription',
      '权益刷新开始: generation=$generation channel=${_paymentChannel.name} '
      'userId=${userId ?? "匿名"} hasToken=${accessToken != null}');

  final cached = await _readValidCache(userId);
  Entitlement? remote;
  String? error;
  try {
    if (userId != null && accessToken != null) {
      // 唯一权威源：后端 /api/entitlements（服务端已合并 RC + Paddle）。
      remote = await _repository.fetchRemote(userId: userId, accessToken: accessToken);
      // fetchRemote 约定：成功且有权益→premium 实体；成功且无权益→Entitlement.free（权威降级）；
      // 网络/超时/非2xx/解析异常→null（不抛异常，见 entitlement_repository.dart:74-102），
      // remote=null 交由 reconciler 走新鲜缓存兜底。
    } else if (userId == null) {
      // 匿名：无账号可绑定的权益，明确 free（等价于原 web 匿名语义）。
      remote = Entitlement.free;
    }
    // userId!=null 但 token 未就绪：remote 保持 null → 走缓存兜底，不误判为 free。
  } catch (e) {
    error = e.toString();
    AppLogger.log('Subscription', '权益刷新在线源失败: generation=$generation error=$error');
  }

  if (generation != _generation) return; // 竞态：被更新的对账/登录切换作废

  final next = reconcileEntitlement(remote: remote, cached: cached, now: clock.now());
  _setEntitlementState(error == null ? next : next.copyWith(error: error, isStale: true));

  AppLogger.log('Subscription',
      '对账完成: remote=${remote != null ? "isPremium=${remote.isPremium}" : "无"} '
      'cached=${cached != null ? "isPremium=${cached.entitlement.isPremium}" : "无"} '
      '→ status=${state.status.name} isStale=${state.isStale} '
      'source=${state.entitlement?.source.name ?? "none"} channel=${_paymentChannel.name}'
      '${error != null ? " error=$error" : ""}');

  if (remote != null) await _writeCache(remote, userId);
}
```
**要点**:删除对 `_purchases.currentEntitlement()` 的调用、删除 `_paymentChannel == web` 分支与 native 回退补查块。web 与 native 走同一条"读后端"路径。`currentEntitlement()` 仍保留在 `PurchaseService` 接口(debug 面板等使用),只是 reconcile 不再调用它。

### 4.2 `SubscriptionController.restore()` —— 统一编排,商店 restore 仅作认领
文件同上(当前第 363–401 行方法替换)。

**语义**:单一"找回/刷新会员"意图。先回源后端(唯一权威,含 Paddle + 已同步的 Apple/Google);仍非会员且是原生商店渠道时,才用 RC restore 认领"尚未关联到本账号的历史商店收据"(认领成功触发 RC webhook 更新后端,本地先乐观解锁)。
```dart
Future<void> restore() async {
  AppLogger.log('Subscription',
      '恢复/刷新会员发起: channel=${_paymentChannel.name} '
      'source=${state.entitlement?.source.name ?? "none"} userId=${_identity.userId ?? "匿名"}');

  final isStoreChannel = _paymentChannel == ClientPaymentChannel.appleStore ||
      _paymentChannel == ClientPaymentChannel.googlePlay;

  // 非商店渠道（web/direct）：恢复=回源后端刷新（无平台恢复接口）。
  if (!isStoreChannel) { await refresh(); return; }

  await _ensurePurchaseIdentity(); // fail-closed：未绑定 Supabase user_id 直接中止
  await refresh();                 // 后端权威回源；命中（含 Paddle）即结束
  if (state.isActive) return;

  // 仍非会员：RC restore 认领游离商店收据
  try {
    final result = await _purchases.restore();
    final entitlement = result.entitlement;
    final currentUserId = _identity.userId;
    final ownerUserId = result.originalAppUserId;
    if (entitlement.isActive(clock.now()) &&
        currentUserId != null && ownerUserId != null && ownerUserId != currentUserId) {
      AppLogger.log('Subscription',
          '恢复购买归属冲突: currentUserId=$currentUserId originalAppUserId=$ownerUserId');
      throw PurchaseException('此订阅已绑定到另一个 Echo Loop 账号。请登录原账号后重试。',
          ownershipConflict: true);
    }
    if (entitlement.isActive(clock.now())) {
      await _applyEntitlement(entitlement, currentUserId); // 乐观解锁刚认领的商店订阅
      AppLogger.log('Subscription', '恢复完成(商店认领): productId=${entitlement.productId}');
    } else {
      AppLogger.log('Subscription', 'RC 无可恢复收据，保持后端对账结果'); // 不硬降级为 free（修 Bug2）
    }
  } on PurchaseException catch (e) {
    if (e.receiptInUse) {
      // 收据属其他 RC 订阅者，但本账号可能已由后端判定为会员：回源确认，不当"购买失败"（修 Bug1 兜底）
      AppLogger.log('Subscription', 'RC 收据被占用，回源确认真实会员态');
      await refresh();
      return;
    }
    AppLogger.log('Subscription', '恢复购买失败: error=$e');
    rethrow;
  }
}
```
**输入→输出**:
- Paddle 会员(后端 premium)+ appleStore → `refresh()` 命中 premium → return,**不调 `_purchases.restore()`**(修 Bug1)。
- 商店会员重装、后端已知 → `refresh()` 命中 → return。
- 商店会员重装、后端未知 → `refresh()` free → RC restore active(归属己方)→ `_applyEntitlement` premium。
- RC restore 无收据 → 保持 `refresh()` 的后端结果,**不降级**(修 Bug2)。
- RC restore `receiptAlreadyInUse` → 转 `refresh()`,不报"购买失败"。

### 4.3 `PurchaseException` 增 `receiptInUse` 标记
文件:`lib/features/subscription/services/purchase_service.dart`(第 13–33 行)。
```dart
PurchaseException(this.message, {this.cancelled = false,
    this.ownershipConflict = false, this.receiptInUse = false});
...
final bool receiptInUse; // 收据已被其他 RC 订阅者占用（receiptAlreadyInUseError）
@override
String toString() => 'PurchaseException($message, cancelled: $cancelled, '
    'ownershipConflict: $ownershipConflict, receiptInUse: $receiptInUse)';
```

### 4.4 RC 实现映射 `receiptAlreadyInUseError`
文件:`lib/features/subscription/services/revenuecat_purchase_service.dart`(`restore()` catch,第 164–171 行)。在 `purchaseCancelledError` 特判之外增加:
```dart
if (code == PurchasesErrorCode.receiptAlreadyInUseError) {
  throw PurchaseException(e.message ?? '收据已被占用', receiptInUse: true);
}
```

### 4.5 UI:去分流 + 来源感知文案
文件:`lib/features/subscription/screens/paywall_screen.dart`。
- 恢复按钮(第 135–142 行):**行为统一为单一 `_restore()` 调用**,删除 `webMode ? _refreshEntitlement : _restore` 分流;按 `state` 决定文案:
  ```dart
  final isPaddleMember = subState.entitlement?.source == EntitlementSource.paddle && isPremium;
  actions: [
    TextButton(
      onPressed: _busy ? null : _restore,
      child: Text(isPaddleMember ? l10n.premiumRefreshStatus : l10n.premiumRestore),
    ),
  ],
  ```
- `_restore()`(第 636–661 行)catch:`receiptInUse` 已在 controller 消化(转 refresh,不再抛),故 UI 侧仅保留 `ownershipConflict → premiumRestoreAccountMismatch`,其余 `premiumPurchaseFailed`;成功后按 `isActive` 提示 `premiumRestored`/`premiumRestoreNone`(现有逻辑不变)。
- `_refreshEntitlement`(第 524 行附近)若无其它调用方则删除(死代码);其"后端刷新"语义已并入 `restore()` 的非商店分支。

### 4.6 l10n 新键
`lib/l10n/app_en.arb`:`"premiumRefreshStatus": "Refresh membership"`;`lib/l10n/app_zh.arb`:`"premiumRefreshStatus": "刷新会员状态"`(均加在 `premiumRefresh` 之后)。随后运行 `flutter gen-l10n`。

---

## 5. 刷新事件模型(P1,可在 P0 后单独做)

原则:不主动轮询,只在**明确状态已变**或**检测到前后端分歧**时刷新。

A 组 · 状态已变信号(多数已存在,P0 沿用):
- E1 冷启动 seed→reconcile;E2 身份变化(登录/切换/登出,`subscriptionIdentityProvider` 监听);E3 RC `entitlementStream → refresh()`(`subscription_controller.dart:94`,商店渠道近实时降级信号;单一来源下它仅是"触发器",refresh 仍读后端);E4 购买/恢复成功乐观解锁;E5 到期 one-shot(`_rescheduleExpiryRefresh`)。

B 组 · 分歧检测(搭既有流量,零额外轮询):
- **E6** 在 `createBackendDio` 加 `EntitlementSignalInterceptor`(仿 `lib/analytics/geo_interceptor.dart` 的 `onResponse` 读响应头范式):读 `X-Entitlement-Epoch`(或 `isPremium`),与当前 state 不一致 → 触发一次 refresh(需 in-flight 去重 + 现有 generation 防竞态)。后端在**已经会算权益的端点**(AI 额度类)附 epoch 头(webhook 时 bump,零额外查询)。
- **E7** 客户端已有 `AiFeatureQuotaExceededException`/`TranscriptionQuotaExceeded`(服务端判非会员/额度耗尽):抛出时若前端仍 premium → 立即 refresh。**纯客户端,无需后端改动**,覆盖"白嫖窗口"。

C 组 · 替换盲查:
- **E8** `main.dart:503` 现在是 resume 就无条件 `refresh()`;改为**仅当 缓存超过短新鲜窗口 或 后台期间越过 `expiresAt` 才刷新**,其余靠 E6/E7。

D 组 · 可选(本次不做):
- **E9** 后端 webhook → Supabase Realtime 推 → 客户端 refresh,给 Paddle 也做秒级降级/升级。

边界:E6/E7 依赖用户在发请求;**空闲用户的升级反映**只能靠 E8 过期兜底或 E9 推送——被动模型固有代价,因服务端已即时放行/拦截,通常可接受。

---

## 6. 降级(取消/退款)新鲜度说明(设计依据,非改动项)
- 后端 DB 秒级新鲜:RC webhook(`processRevenueCatWebhookEvent` 立即 reconcile 写 `userEntitlements.isActive`)、Paddle webhook(`parseAndProcessPaddleWebhook` 立即写 `paddle_subscriptions.status`),**均不经 24h 节流**。
- 客户端多快看到 = 刷新触发点(§5)。Apple/Google 退款近实时(E3 RC stream);Paddle 退款等下次 resume(E8)或 E9 推送;取消续费不紧急(到期自然降级)。
- 正确性兜底:付费能力由服务端 `hasActiveEntitlement`(`fluency-frontend/.../entitlements.ts:129`)在 AI 额度校验时实时判定;客户端 UI 滞后仅观感,不产生白嫖。

---

## 7. 分期交付
- **P0 — 单一来源 + 三 bug 根除**:§4 全部(`_refreshOnline` 改单一来源 + `restore()` 重排 + `PurchaseException.receiptInUse` + RC 映射 + UI 去分流 + l10n)。可独立上线,用现有 E1–E5 触发。
- **P1 — 智能刷新**:E7(纯客户端,先做)→ E8(去盲查)→ E6(需后端加 epoch 头 + 客户端拦截器)。
- **P2 — 可选**:E9 Supabase Realtime 推送。

---

## 8. 逐文件改动清单(P0)
1. `lib/features/subscription/providers/subscription_controller.dart`:替换 `_refreshOnline()`(§4.1)、`restore()`(§4.2)。
2. `lib/features/subscription/services/purchase_service.dart`:`PurchaseException` 增 `receiptInUse`(§4.3)。
3. `lib/features/subscription/services/revenuecat_purchase_service.dart`:`restore()` catch 映射 `receiptAlreadyInUseError`(§4.4)。
4. `lib/features/subscription/screens/paywall_screen.dart`:恢复按钮去分流 + 文案、`_restore` catch、删 `_refreshEntitlement`(§4.5)。
5. `lib/l10n/app_en.arb` / `app_zh.arb` + `flutter gen-l10n`(§4.6)。

`entitlement_reconciler.dart` 不改(契约已契合单一来源)。

---

## 9. 测试(test-first;`test/features/subscription/`)

### 9.1 需更新的现有用例(`subscription_controller_test.dart`)——因语义从"native 信 RC"改为"单一来源"
- `native 登录冷启动 → 跳过后端,直接采用 RevenueCat active`:改为断言**读后端权威**——`repo` 返回 `proEntitlement`,`expect(repo.calls, contains('u1'))`、`status=premium`、`purchases.currentCalls == 0`。
- `native 登录冷启动 → identify 完成前不读取权益`:把 `currentCalls` 断言改为 `repo.calls`(identify 完成前 `repo.calls` 空、status=unknown;完成后被调、premium)。
- `native 快速切换身份 → refresh 必须等待最新用户 identify 完成`:同上,`currentCalls` → `repo.calls`;`repo` 返回 `proEntitlement`,最终 premium。
- `restore active → 直接应用平台返回权益,不调用后端`:语义变更为"后端无会员 → RC 认领 active → premium"。`repo` 返回 free、`restoreResult=proEntitlement`;断言 `status=premium`、`purchases.restoreCalls>=1`(不再断言 `repo.calls` 为空——`restore()` 会先 `refresh()`)。
- `restore free 且存在其他 originalAppUserId → 不触发归属冲突`:把 `repo` 改为返回 free(否则后端 premium 会短路,不进入 RC restore),保持最终 `status=free`。
- 保持不变(应仍通过):`restore active 且归属为当前用户 → premium+缓存`、`restore active 但归属不是当前用户 → 抛 ownershipConflict`、`Web 渠道 restore → 转后端刷新且不调底层恢复`、`fail-closed 身份未绑定 → restore 报错`、`native identify 失败 → 不读权益且不覆盖缓存(currentCalls==0)`、离线/退款/登出/切换/generation 竞态等 reconcile 用例。

### 9.2 新增用例(锁死三个 bug)
- **Bug3(结构性)**:`native + repo 返回 null(后端不可达) + 新鲜 Paddle premium 缓存` → `status=premium`、`isStale=true`(不降 free)。channel=appleStore。
- **Bug3b**:`native + repo 返回 Entitlement.free(后端明确无会员) + Paddle premium 缓存` → `status=free`(权威降级仍生效)。
- **Bug1**:`当前 state=active source=paddle(repo 返回 paddle premium) + appleStore` → 调 `restore()` → `status=premium`、`purchases.restoreCalls==0`(不走 RC restore)。
- **receiptInUse**:`FakePurchaseService.restore()` 抛 `PurchaseException(receiptInUse:true)`(需给 Fake 增可注入错误)、`repo` free → `restore()` 不 rethrow、最终走 `refresh()`(free)。
- **RC 映射单测**(`revenuecat_purchase_service_test.dart`):模拟 `PlatformException(receiptAlreadyInUseError)` → `restore()` 抛 `PurchaseException.receiptInUse == true`。

### 9.3 Widget 测试(`paywall_screen_test.dart`)
- `source=paddle` premium 态:恢复按钮文案 = "刷新会员状态"(`premiumRefreshStatus`);点击调用统一 `restore()`(mock controller 验证单次调用,无 `webMode` 分支)。

### 9.4 `FakePurchaseService` 调整(测试替身)
`restore()` 增加可注入异常字段(如 `Object? restoreError`),用于 receiptInUse 用例;其余沿用现有替身。

---

## 10. 验证命令
```bash
cd /Volumes/SamsungT7/workspace/fluency/fluency
flutter gen-l10n          # 改了 arb 后
flutter analyze
flutter test test/features/subscription/
```
手动回归(用 Paddle 生产账号 `bc4c31e5-...` 登录 App Store 包):
1. 点"刷新会员状态" → 日志无 `RC restorePurchases 发起` / `receiptAlreadyInUseError` / "购买失败"。
2. 断网点刷新 → 日志 `remote=无 cached=isPremium=true → status=premium isStale=true`(不再 `→ status=free`)。
3. 正常联网 → `对账完成: remote=isPremium=true ... source=paddle → status=premium`。

---

## 11. 风险与注意
- **§7 防竞态结构保留**:`_generation` 计数器、`_waitForIdentitySync`、`_applyEntitlement` 的 generation 校验一律不动;单一来源只改数据来源,不改竞态骨架。
- **购买后 webhook 延迟窗口**:native 新购买由 `purchase()`/`restore()` 的 `_applyEntitlement` 乐观解锁覆盖(RC 结果即时可信,只用于"刚成交"这一刻,不进 reconcile 权威路径),不受单一来源影响。
- **`_applyEntitlement` 后不要立即 `refresh()`**:乐观解锁后若马上回源,后端可能尚未收到 webhook 而返回 free → 误降级。与现有 `purchase()` 保持一致:只 `_applyEntitlement`,由 §5 既有触发点自然收敛。
- **token 未就绪**(userId 有、accessToken 无):`remote` 置 null 走缓存,不误判 free。
