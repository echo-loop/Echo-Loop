import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/audio_item.dart';
import '../../../providers/audio_library_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/app_logger.dart';
import '../../../widgets/audio_list_view.dart';
import '../data/official_catalog_service.dart';
import '../data/trigger_official_sync.dart';
import '../models/catalog.dart';
import '../providers/official_collection_detail_provider.dart';
import '../providers/official_enrollment_provider.dart';

const _logTag = 'OfficialDetail';

/// 官方合集详情页（发现页点合集后的浏览页）。
///
/// 数据来源：本地 catalog 缓存（同 Discover 页）；零网络。
/// detail / 卡片用同一份数据，根除"卡片显示 1 条 / 详情显示 2 条"不一致。
///
/// 三态：
/// - catalog 未初始化（首次安装等待）→ loading
/// - catalog 已初始化但找不到该 remoteId（运营下架/从未发布）→ "已下架" 提示
/// - 找到 → 渲染详情；未加入显示远端 audios 预览，已加入复用 [AudioListView]
///
/// 触发同步：
/// - initState 时若 `!hasInitialized` → 主动 fire-and-forget syncAll
/// - 下拉刷新 → await syncAll(force: true)
/// - **不再**用 `_maybeSyncToLocal` 单独触发同步（plan §核心原则 §3：唯一入口）
class OfficialCollectionDetailScreen extends ConsumerStatefulWidget {
  final String remoteId;
  const OfficialCollectionDetailScreen({super.key, required this.remoteId});

  @override
  ConsumerState<OfficialCollectionDetailScreen> createState() =>
      _OfficialCollectionDetailScreenState();
}

class _OfficialCollectionDetailScreenState
    extends ConsumerState<OfficialCollectionDetailScreen> {
  bool _enrolling = false;
  bool _trackedView = false;

  @override
  void initState() {
    super.initState();
    final svc = ref.read(officialCatalogServiceProvider);
    if (!svc.hasInitialized) {
      AppLogger.log(_logTag, 'initState: catalog not initialized → syncAll');
      unawaited(_syncCatalog());
    }
    // 延迟埋点，确保 detail 数据可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackDetailView();
    });
  }

  /// 页面浏览埋点（仅触发一次）
  void _trackDetailView() {
    if (_trackedView) return;
    final detail = ref.read(officialCollectionDetailProvider(widget.remoteId));
    if (detail == null) return;

    final localId = _findLocalIdStatic(detail.id);
    final enrolled = localId != null;
    ref
        .read(analyticsServiceProvider)
        .track(Events.officialCollectionDetailViewed, {
          EventParams.remoteId: detail.id,
          EventParams.collectionName: detail.name,
          EventParams.audioCount: detail.audios.length,
          EventParams.enrolled: enrolled ? 1 : 0,
        });
    _trackedView = true;
  }

  /// initState 中使用的静态版本（不依赖 context）
  String? _findLocalIdStatic(String remoteId) {
    final state = ref.read(collectionListProvider);
    for (final c in state.collections) {
      if (c.isOfficial && c.remoteId == remoteId) return c.id;
    }
    return null;
  }

  /// 触发全局唯一同步；helper 内部处理 outcome=updated 后的
  /// loadLibrary + loadCollections + invalidate catalog。
  Future<CatalogRefreshOutcome?> _syncCatalog({bool force = false}) =>
      triggerOfficialSync(ref, force: force);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(officialCollectionDetailProvider(widget.remoteId));
    final svc = ref.read(officialCatalogServiceProvider);

    return Scaffold(
      appBar: AppBar(),
      body: _buildBody(detail, svc.hasInitialized, l10n),
    );
  }

  Widget _buildBody(
    CatalogCollection? detail,
    bool hasInitialized,
    AppLocalizations l10n,
  ) {
    // catalog 未初始化 → loading
    if (!hasInitialized && detail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // catalog 已初始化但查不到 → 已下架/从未发布
    if (detail == null) {
      return _NotFoundOrDeprecated(
        message: l10n.officialCollectionDeprecated,
        onRefresh: () async {
          final outcome = await _syncCatalog(force: true);
          if (!mounted || outcome is! CatalogFailed) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.discoverLoadFailed)));
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final outcome = await _syncCatalog(force: true);
        if (!mounted) return;
        if (outcome is CatalogFailed) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.discoverLoadFailed)));
        }
      },
      child: _buildContent(detail, l10n),
    );
  }

  Widget _buildContent(CatalogCollection detail, AppLocalizations l10n) {
    final localId = _findLocalId(detail.id);
    final enrolled = localId != null;
    return Column(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(detail, l10n),
              if ((detail.description ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    detail.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const Divider(height: 1),
              // 列名表头只在「未加入」态显示 —— 未加入态的 tile 简化（只有
              // 名称 + 时长两列），表头帮助理解结构。已加入态走 AudioListView，
              // tile 有更丰富的 meta 行和操作菜单，表头反而会误导。
              if (!enrolled) _buildListSectionHeader(l10n),
              Expanded(
                child: enrolled
                    ? _EnrolledAudioList(localCollectionId: localId)
                    : _UnenrolledAudioList(
                        audios: detail.audios,
                        onTapAudio: (_) => _showEnrollDialog(detail),
                      ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: _buildCta(detail, enrolled, l10n),
            ),
          ),
        ),
      ],
    );
  }

  /// 音频列表上方的两列表头（名称 / 时长）。
  ///
  /// 水平位置对齐下方 ListTile 的 title / trailing —— ListTile 内部：
  /// 左 padding 16 + leading(40) + leading-title 间距 16 = 72px 到 title；
  /// 右 padding 16 到 trailing。
  Widget _buildListSectionHeader(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 12, 16, 8),
      child: Row(
        children: [
          Expanded(child: Text(l10n.audioListColumnName, style: style)),
          Text(l10n.audioListColumnDuration, style: style),
        ],
      ),
    );
  }

  Widget _buildHeader(CatalogCollection detail, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            l10n.audioCount(detail.audios.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta(
    CatalogCollection detail,
    bool enrolled,
    AppLocalizations l10n,
  ) {
    if (_enrolling) {
      return const FilledButton(
        onPressed: null,
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      );
    }
    if (enrolled) {
      return FilledButton(
        onPressed: () {
          final localId = _findLocalId(detail.id);
          if (localId != null) {
            context.go(AppRoutes.collectionDetail(localId));
          }
        },
        child: Text(l10n.goLearn),
      );
    }
    return FilledButton(
      onPressed: () => _doEnroll(detail),
      child: Text(l10n.addToMyCollections),
    );
  }

  String? _findLocalId(String remoteId) {
    final state = ref.watch(collectionListProvider);
    for (final c in state.collections) {
      if (c.isOfficial && c.remoteId == remoteId) return c.id;
    }
    return null;
  }

  Future<void> _showEnrollDialog(CatalogCollection detail) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.enrollNeededTitle),
        content: Text(l10n.enrollNeededMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'enroll'),
            child: Text(l10n.addToMyCollections),
          ),
        ],
      ),
    );
    if (result == 'enroll' && mounted) {
      await _doEnroll(detail);
    }
  }

  Future<void> _doEnroll(CatalogCollection detail) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    AppLogger.log(_logTag, 'tap add-to-my-collections remoteId=${detail.id}');
    setState(() => _enrolling = true);
    try {
      final result = await ref
          .read(officialEnrollmentProvider.notifier)
          .enroll(detail.id);
      AppLogger.log(
        _logTag,
        'enrolled localId=${result.localCollectionId} createdNew=${result.createdNew}',
      );
      if (!mounted) return;
      if (result.createdNew) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.enrollSucceeded)));
      }
    } catch (e) {
      AppLogger.log(_logTag, 'enroll failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.enrollFailed)));
    } finally {
      if (mounted) {
        setState(() => _enrolling = false);
      }
    }
  }
}

/// "找不到 / 已下架"占位 — 仍允许下拉刷新（catalog 可能本地为空被新拉到）。
class _NotFoundOrDeprecated extends StatelessWidget {
  final String message;
  final Future<void> Function() onRefresh;

  const _NotFoundOrDeprecated({required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(message, textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 已加入态：复用现有 [AudioListView]，tile 自带学习进度 + 点击触发下载/学习。
class _EnrolledAudioList extends ConsumerWidget {
  final String localCollectionId;
  const _EnrolledAudioList({required this.localCollectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(audioLibraryProvider);
    final collectionState = ref.watch(collectionListProvider);
    final audioIds = collectionState.getAudioIds(localCollectionId);
    final audioItems = audioIds
        .map((id) => ref.read(audioLibraryProvider.notifier).getItemById(id))
        .whereType<AudioItem>()
        .toList();

    final l10n = AppLocalizations.of(context)!;
    return AudioListView(
      items: audioItems,
      collectionId: localCollectionId,
      // 官方空合集不应展示通用的「+ 添加音频」按钮（用户不能手动添加官方内容）；
      // 显示中性的「该合集暂无音频」文字即可。
      emptyState: _OfficialEmptyAudioList(
        message: l10n.officialCollectionEmpty,
      ),
    );
  }
}

/// 未加入态：展示 catalog 中的音频预览，点击 tile 弹引导添加 dialog。
class _UnenrolledAudioList extends StatelessWidget {
  final List<CatalogAudio> audios;
  final void Function(CatalogAudio) onTapAudio;

  const _UnenrolledAudioList({required this.audios, required this.onTapAudio});

  @override
  Widget build(BuildContext context) {
    if (audios.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return _OfficialEmptyAudioList(message: l10n.officialCollectionEmpty);
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: audios.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final audio = audios[index];
        return _UnenrolledAudioTile(
          audio: audio,
          onTap: () => onTapAudio(audio),
        );
      },
    );
  }
}

class _OfficialEmptyAudioList extends StatelessWidget {
  final String message;

  const _OfficialEmptyAudioList({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: Center(child: Text(message)),
        ),
      ],
    );
  }
}

class _UnenrolledAudioTile extends StatelessWidget {
  final CatalogAudio audio;
  final VoidCallback onTap;

  const _UnenrolledAudioTile({required this.audio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.graphic_eq, color: theme.colorScheme.outline),
      title: Text(
        audio.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      // 时长放 trailing，弱化颜色；单行布局
      trailing: audio.durationSec > 0
          ? Text(
              _formatDuration(audio.durationSec),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    if (min >= 60) {
      final h = min ~/ 60;
      final m = min % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}min';
    }
    if (min == 0) return '${sec}s';
    return sec == 0 ? '${min}min' : '$min:${sec.toString().padLeft(2, '0')}';
  }
}
