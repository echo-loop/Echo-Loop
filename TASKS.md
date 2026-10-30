# Echo Loop 当前任务清单

> 当前待办与本次完成记录；此前完成任务已归档，详见 [2026-10-29 归档](./docs/tasks-archive/tasks-2026-10-29-completed.md)、[2026-09-29 归档](./docs/tasks-archive/tasks-2026-09-29-completed.md)。

## 本次完成
- [x] 播客 RSS 已有字幕时直接下载，跳过转录（ECH-29，2026-10-30）：解析 `<podcast:transcript>`，只支持 SRT / VTT（按 MIME type 识别，type 不认识时按 URL 扩展名兜底，JSON / HTML / 纯文本忽略；多个字幕取第一个受支持的）。字幕地址与格式随单集入库（`audio_items` 新增 `podcast_transcript_url` / `podcast_transcript_format`，schema v61），订阅/刷新时不下载字幕；点击下载音频后，若条目尚无字幕则一并下载，解码后走 `importLocalSubtitleWithRef`，与本地字幕上传同一入库主干（来源 `local`，词级时间戳为合成值），不触发转录任务。字幕下载或解析失败、空字幕均静默降级，音频下载结果不受影响，用户仍可手动转录。老的未下载单集在刷新时补写字幕地址，不触发下载。新增测试：解析器 9 项（格式识别、多字幕、不支持格式、空 url）、下载器 7 项（成功、非 2xx、空体、超体积、网络错误、连接/接收超时、CancelToken 透传）、控制器 8 项（入库来源与句数、下载失败降级、空字幕不入库、已有字幕不覆盖、无字幕地址回归、下载期间用户已加字幕不覆盖、取消时字幕请求被取消且不入库）、订阅补写 1 项、v60→v61 迁移 1 项。代码审查后修复：字幕请求增加 20s 连接/接收超时（此前挂起会让下载界面永久停在 Downloading）；字幕请求接入下载取消；判断与入库基于资源库最新条目，避免覆盖下载期间用户加入的字幕。全量 `flutter test` 通过（+5751 ~11，0 失败），改动文件 `flutter analyze` 无问题。**完成时间**: 2026-10-30
- [x] 新手引导增加「跳过」按钮，移除引导开关（2026-10-30）：引导 tooltip 每一步都显示「跳过」，点击后结束当前 tour 并关闭之后所有页面的引导（复用 `guide_enabled`，仅本机，不参与云同步）。学习设置「新手引导」卡片只保留「重置」，重置会重新开启引导并清空已看状态。`guideEnabled` 从偏好同步白名单中移除，后端 README 同步更新（该仓库单独提交）。新增测试：跳过按钮每一步都显示；点跳过后结束 tour、关闭开关、后续 flow 不启动；`skipAll`/`resetAll`；设置页无开关、重置始终可见；快照不含 `guideEnabled`。引导相关测试通过，改动文件 `flutter analyze` 无问题。**完成时间**: 2026-10-30
- [x] 一次性提示与引导开关加入跨设备偏好同步（2026-10-29）：`learning` 域新增 `retellAutoPlaybackPromptShown`、`pdfExportReminderShown`、`unclearAutoSaveReminderShown` 与 `guideEnabled`。已展示标记在写回时只做「未展示 → 已展示」，云端 false 或缺失不清除本地 true；`guideEnabled` 按云端值写回。引导已看状态（`guide_v1_*_seen`）不同步，「重置引导」只影响本机，避免重置被其它设备撤销。`setEnabled` 写入后补发同步事件。后端 `features/user-preferences/README.md` 同步更新白名单约定（该仓库单独提交）。新增测试：采集不含引导已看状态、云端写回、缺失与 false 均保留本地 true、setEnabled 触发同步事件、markSeen/reset 不触发同步事件。偏好同步、引导 provider 相关测试通过，改动文件 `flutter analyze` 无问题。**完成时间**: 2026-10-29
- [x] 首次点「听不太懂」弹出自动收藏说明（一次性）：精听中第一次点击「听不太懂」，进入讲解页前弹窗说明该操作会自动收藏句子，弹窗内可直接切换「听不懂时自动收藏」开关（即时生效），并提示可在「学习设置」随时修改。已提示标记 `learning_unclear_auto_save_reminder_shown` 存 SP（参与跨设备同步，老用户升级后也会提示一次）。弹窗不可点外部关闭，保证标记必定落库。同时修正上一条英文文案为 Unclear / saved 用语。新增测试：provider 标记与幂等、弹窗开关写回与关闭路径、精听页首次弹窗后进入讲解、弹窗内关开关后进入讲解。精听页、学习设置 provider 与弹窗相关测试通过，改动文件 `flutter analyze` 无问题。**完成时间**: 2026-10-29
- [x] 修复精听切换收藏时抛出 `Failed to interpolate TextStyles with different inherit values`：未收藏句子点「听不太懂」旁收藏后，`PracticeNormalModeView` 的 Row 子项按位置复用 `FilledButton` element，「听不太懂」的文字样式被插值到「取消标记」按钮。修复：两个按钮加稳定 `ValueKey`。新增回归测试（修复前复现插值异常，修复后通过）；相关 practice / 精听 / 复习页测试 205 项通过，改动文件 `flutter analyze` 无问题。**完成时间**: 2026-10-29
- [x] 学习设置新增「听不懂时自动收藏」开关（偏好 `learning_auto_favorite_on_cant_understand`，默认开启，保持原行为）：关闭后精听点击「听不太懂」只进入讲解，不再把当前句加入收藏（不改动已收藏句）；走 `LearningSettings` 与云同步白名单。新增测试：provider setter 与启动读取、精听进入讲解页开启/关闭两条路径；`learning_settings_screen_test` 的两个引导用例因新增卡片把引导区挤出默认视口，改为加高测试视口后再点击（基线 14 项通过，改后仍 14 项通过）。相关测试 provider/精听/同步/设置页合计通过，改动文件 `flutter analyze` 无问题。**完成时间**: 2026-10-29
- [x] 学习页「为你推荐」卡片可关闭，并新增设置入口「显示设置」：推荐卡标题行右侧加关闭按钮，点击弹确认框，确认后隐藏（偏好 `learning_show_study_recommendation`，默认开启，走 `LearningSettings` 与云同步白名单）；设置页「学习」分组新增「显示设置」页，可重新开启推荐卡片。新增测试：provider setter 与启动读取、同步白名单、学习页取消/确认/设置关闭三条路径、显示设置页开关。相关测试 119 项通过，改动文件 `flutter analyze` 无问题。**完成时间**: 2026-10-29
- [x] 修复复述「重听本段」时录音把原音录进去（2026-10-29）：按用户日志（Android 1.0.40，64 次录音与原文播放重叠）与 macOS 实机复现定位：复述阶段点主播放重听本段走 `_handleReplay`，`clearRecording` 先把录音置为 idle 再等待原生清理，期间若跑过一帧（评估中点击时主线程被评估计算占用，间隔可达 200ms+），idle 触发的自动录音在播放器仍为 retelling 时抢先启动，随后才切到 listening 播放原文，原音整段录进去并被评估。修复：`_handleReplay` 清理期间置 `_manualStoppedThisParagraph = true` 挡住自动录音，清理完、同步切到 listening 前再放开（与「录音中点主播放」已有保护一致；1.0.43 起该分支已修，评估中/等开口超时/手动停止后点击仍有此漏洞）。新增页面回归测试（评估中点击 + 原生清理跨帧；修复前 startCalls=1，修复后为 0，且原文播完回到复述阶段自动录音恢复）。复述页面测试 26 项通过，定向 `flutter analyze` 无问题。**完成时间**: 2026-10-29

## 优先处理

- [ ] 实测 WebView 移动内容模式与 User-Agent：macOS 完整重启 App 后确认有道等词典是否显示移动布局；如仍为桌面版，再收集页面实际 User-Agent 与 viewport 宽度。
- [ ] 修复 macOS 网页词典首帧黑闪：继续隔离原生 WebView 创建与 Flutter 合成时序，保持内容尽早显示且不修改插件源码。
- [ ] Android 离线 ASR 结束录音闪退：获取真机 `logcat` 与 `/data/tombstones`，定位并修复 Silero VAD native 崩溃。
- [ ] 段落复述页面复用统一录音识别模块。
- [ ] 意群操作栏切换收藏时其他按钮闪烁，继续定位根因。
- [ ] 在发布包手动验证数据采集：核对 onboarding、页面访问、权限快照、生命周期事件及应用版本信息。

## 后续产品体验

- [ ] 学习内容字号（方案 A：只调正文，不缩放整个 UI；字体选择已移除；颜色设置待产品决定）。
  - [x] 试点：字幕列表（`MaskedSentenceTile`）支持字号档位，设置页「文字大小」实时预览。

    偏好单一来源 `readingTextPrefsNotifierProvider`（SP key `reading_font_scale`），字号 85%–175%、每档 5% 离散吸附；两端 A−/A+ 按钮逐档调整。设置页：上方字号卡，下方纯文本预览（放下方避免调字号时控件移位）。

    **完成时间**: 2026-10-28
  - [x] 推广：句子正文 `SelectableSentenceText`（精听/难句/收藏复习共用）、意群 `SenseGroupText`、句子解析与翻译、复述转写、词典结果面板（整块主题同比缩放，词头 17 基准随倍率）、AI 助教（气泡文字与 markdown 标题）。

    统一规则：在样式进入渲染/选区组件之前缩放，选区几何随样式一致。标签、chip、输入框等 UI 文字不缩放。`PracticeNormalModeView` 的无查词来源静态分支目前无生产调用方，未接入。

    **完成时间**: 2026-10-29
  - [ ] 云端偏好同步接入 `reading_font_scale`（需后端文档字段确认）。
- [ ] 查词归一化 Unicode 化，并迁移已有收藏 key（需产品与数据决策）。
- [ ] 计算并展示每个学习任务的预计/实际耗时。
- [ ] 学习 Tab 点击学习/复习后直接进入学习页面，跳过学习计划页。
- [ ] 学习 Tab 展示“今日完成任务”折叠区。
- [ ] 句子增加复制能力：移动端长按、桌面端右键。
- [ ] 支持自定义背景和背景音。
- [ ] 增加播放完成音效、任务完成动画与音效。
- [ ] 埋点能力按中国大陆 / 全球环境拆分落地。

## 后端与发布

- [ ] 后端账号登录会话能力。
- [ ] 完成跨平台验证与发布准备。
