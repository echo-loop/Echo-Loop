# Echo Loop 任务清单

> 最后更新：2026-06-23（修复 Free Player 整篇循环次数不准 + 播放/暂停图标错乱）
> 当前焦点：Android 结束录音闪退（离线 ASR / Silero VAD）——**仍未解决**

## 已完成：修复 Free Player 整篇循环次数不准 + 播放/暂停图标错乱

整篇连续播放（gapless）此前依赖 just_audio 的 `ProcessingState.completed` 事件做反应式循环计数与重启，触发三个连带 bug：① 重复设 3 遍只播 2 遍就停（重复/滞后 completed 事件多计数）；② 播完后播放/暂停按钮仍显示「暂停」图标（按钮直接读 just_audio 的 `playing`，而它在自然播完后仍为 true）；③ 播完后点两下按钮却从最后一句开始（图标错误导致首击触发 pause，清掉了「从头重播」标志）。改为与单句循环一致的确定性 await-完成循环模型，并把图标改由 controller 的逻辑播放态驱动，从根上消除整类竞态。

- [x] `audio_engine_provider.dart`：新增 `playToEnd(sessionId)` 原语（await 自然播完，免疫重复 completed 事件）；新增 `processingState` getter（解耦续播判定、可测）。
- [x] `listening_practice_provider.dart`：新增 `_playWholeDriven` 确定性整篇循环协程 + `_startWholeDriven` 起播入口；删除反应式 `_onPlayerStateChanged`/`_advanceWholeCompletion`/`_handlingWholeCompletion` 及 playerState 订阅；暂停续播、模型交接、seek 续播均改走确定性循环。
- [x] `listening_practice_state.dart` + UI：新增 `isPlaying` 逻辑播放态作为图标唯一真相源；`playback_controls.dart`、`player_screen.dart` 热键改读逻辑态。
- [x] 测试：`free_player_playback_flow_test.dart` 扩展 fake engine（`playToEnd` + `emitCompleted` 贴近 just_audio）并新增 5 个用例（整篇 3 遍恰好停、重复 completed 不多计数、间隔停顿、播完图标恢复+单击从头、暂停续播保留遍数）；`playback_controls_test.dart`、共享 fake 同步更新。全量 `flutter test` 2951 通过。

  **完成时间**: 2026-06-23

## 已完成：Free Player 禁止 tab swipe，逐句精听支持左右滑动切句

此前 Free Player 的 `全文 / 收藏` 使用 `TabBarView` 默认横向切页，和产品想要的“横向手势优先用于学习态切句”语义冲突；逐句精听则只有底部上下句按钮，没有对应的左右滑动切句入口。现统一调整为：Free Player 只允许点击 tab 切换，逐句精听支持左右 swipe 切换句子。

- [x] `player_screen.dart`：`TabBarView` 显式禁用横向 swipe，仅保留点击 `TabBar` 切换。
- [x] `intensive_listen_player_screen.dart`：在主体内容区新增横向手势，左滑下一句、右滑上一句，并补边界防越界处理。
- [x] 测试：`player_screen_test.dart` 增加“横向滑动不会切 tab”回归；`intensive_listen_player_screen_test.dart` 增加左右滑动切句与首句防越界回归。

  **完成时间**: 2026-06-22 22:09:26 +0800

## 已完成：学习版通知提示收敛到逐句精听完成

此前“开启通知提醒”的学习版 pre-prompt 同时挂在逐句精听、跟读、盲听、难句补练、复述多个完成页上；任务顺序调整后，用户可能在错误的任务完成点看到提示。现收敛为只在逐句精听完成后直接弹出，其它任务完成页不再主动弹学习版通知提示。

- [x] `intensive_listen_player_screen.dart`：保留逐句精听完成后的学习版通知提示，并补充注释说明当前触发语义。
- [x] `blind_listen_player_screen.dart` / `listen_and_repeat_player_screen.dart` / `review_difficult_practice_screen.dart` / `retell_player_screen.dart`：移除完成页里的学习版通知提示调用与对应 import。
- [x] 测试：补充 5 个页面回归，覆盖“逐句精听完成后仍会检查并弹提示”“盲听/跟读/难句补练/复述完成后不再检查学习版通知提示”。

  **完成时间**: 2026-06-22 21:24:29 +0800

## 已完成：任务引导页与设置弹窗设置项横向对齐统一

逐句精听、跟读、复习、盲听、复述等任务引导页与设置弹窗此前各自手写 `Row + Text + Dropdown/Text`，导致标签列宽、右侧值区宽度和左右边距视觉上不一致。现统一抽出公共设置项横向布局骨架，只修对齐，不改业务逻辑和控件语义。

- [x] `setting_labeled_row.dart`：新增公共“左标签 + 右侧固定宽度值区”布局组件，统一设置项横向对齐约束。
- [x] `intensive_listen_briefing_sheet.dart` / `listen_and_repeat_briefing_sheet.dart` / `review_briefing_sheet.dart` / `paragraph_selection_sheet.dart`：入口引导弹窗里的下拉设置行统一切到公共骨架，并补测试 key。
- [x] `intensive_listen_settings_sheet.dart` / `listen_and_repeat_settings_sheet.dart` / `blind_listen_settings_sheet.dart` / `retell_settings_sheet.dart`：播放速度标题行统一切到公共骨架，收敛标签列和值区对齐。
- [x] 测试：新增 briefing/settings 相关 widget 回归，覆盖标签列左边界一致、右侧值区宽度一致，防止后续布局回退。

  **完成时间**: 2026-06-22 19:39:05 +0800

## 已完成：统一播放速度档位到 0.1 步进

此前 Free Player、各学习模式入口和设置面板仍混用 `0.75 / 0.85 / 0.95 / 1.25 / 1.75` 等旧档位，默认值映射与显示格式也不一致。现统一为 `0.4-1.5` 按 `0.1` 递增，另保留 `2.0`；所有速度文案统一显示一位小数，默认值映射中的旧档位同步上调到最近的 `0.1` 档。

- [x] `playback_speed.dart` + `playback_settings.dart`：新增统一速度档位、格式化和归一化工具；Free Player 速度档位与旧值兼容读取统一走同一套逻辑。
- [x] `intensive_listen_settings.dart` / `difficult_practice_settings.dart` / `blind_listen_settings.dart` / `retell_settings.dart` / `playback_speed_default.dart`：练习入口离散档位和默认速度映射统一到新规则，旧 `0.75 / 0.85 / 0.95` 默认值分别改为 `0.8 / 0.9 / 1.0`。
- [x] `playback_controls.dart`、各 briefing sheet、各 settings sheet、各练习页状态标签：速度显示统一为 `1.0x` / `2.0x`，并将设置面板滑块从 `0.05x` 连续步进改为统一离散档位。
- [x] 测试：更新模型、provider、briefing、settings、screen 相关回归，覆盖新档位列表、默认值映射、旧值归一化和 `1.0x / 2.0x` 文案。

  **完成时间**: 2026-06-22 18:19:35 +0800

## 已完成：所有练习页循环次数支持无限 ∞

此前只有 Free Player 的循环模型支持 `0 = ∞`，学习模式各页仍把重复次数写死为有限值，导致逐句精听、跟读、难句补练、收藏复习、盲听、复述都无法设置无限重复。现统一把所有重复次数语义扩展为 `0 = ∞`，并补齐设置 UI、流程引擎和遍数文案。

- [x] `intensive_listen_settings.dart` / `difficult_practice_settings.dart` / `blind_listen_settings.dart` / `retell_settings.dart`：重复次数统一支持 `0 = ∞`，并补齐对应防御性解析。
- [x] `intensive_listen_settings_sheet.dart` / `listen_and_repeat_settings_sheet.dart` / `difficult_practice_settings_sheet.dart` / `blind_listen_settings_sheet.dart` / `retell_settings_sheet.dart`：重复次数下拉统一补上 `∞` 选项。
- [x] `sentence_playback_engine.dart` / `blind_listen_player_provider.dart` / `retell_player_provider.dart` / `blind_practice_flow_state.dart` / `repeat_flow_state.dart`：流程状态与推进逻辑兼容无限重复，不再错误判定“最后一遍”。
- [x] `practice_play_count_label.dart` 及相关页面：自动模式遍数文案统一支持 `第 n/∞ 遍` / `Round n/∞`。
- [x] 测试：更新模型、设置面板、跟读 controller、盲听 provider、复述 provider 相关回归，覆盖 `0 = ∞` 解析、UI 展示和无限重复不自动完成。

  **完成时间**: 2026-06-22 15:33:09 +0800

## 已完成：Free Player 整数倍速文案精确显示

速度菜单和底部速度按钮此前会把整数倍速统一显示成 `1x` / `2x`，与产品预期不一致。现将整数倍速统一保留一位小数，确保默认档位和菜单选项显示为 `1.0x`、`2.0x`。

- [x] `playback_controls.dart`：速度文案格式化改为整数倍速统一保留一位小数，显示为 `1.0x`、`2.0x`。
- [x] `playback_controls_test.dart`：更新默认速度按钮和速度菜单断言，覆盖 `1.0x`、`2.0x` 文案。

  **完成时间**: 2026-06-22 11:15:24 +0800

## 已完成：弹出菜单样式收敛（更宽更轻 + 危险区分隔）

音频 item / 合集 / 排序类弹出菜单此前统一成了白底描边卡片，但内容比例仍偏重：菜单整体狭长、边框存在感过强、图标和文字都太黑太粗，末尾删除项也缺少独立危险区。现将统一菜单骨架收敛为更克制的悬浮卡片和更紧凑的条目节奏，并在删除/退订前加入分隔，减少“长白条清单感”。

- [x] `app_popup_menu.dart`：新增统一 `appPopupMenuItem()`，把菜单项高度收紧到 44；菜单行加最小宽度、固定图标列、较轻图标色和较低字重，稳定左右节奏。
- [x] `app_theme.dart`：`popupMenuTheme` 改为更大圆角、更弱描边、更轻阴影，减少外框抢眼感，主要靠阴影和圆角建立层级。
- [x] `audio_list_tile.dart` / `collection_screen.dart`：切到统一菜单项封装，并在删除 / 退订 / 移除前插入 `PopupMenuDivider`，把末尾危险操作单独分区。
- [x] `audio_list_view.dart` / `recycle_bin_sheet_base.dart` / `learned_word_forms_sheet.dart`：排序类菜单同步切到更紧凑的统一条目高度，保持菜单系统一致。
- [x] 测试：`audio_list_tile_test.dart` / `collection_screen_test.dart` 增加危险区分隔断言，验证菜单结构未回退。

  **完成时间**: 2026-06-22 10:54:15 +0800

## 已完成：Free Player 播放速度选项补齐

Free Player 原先只有 7 个离散倍速档位，和参考播放器不一致，细粒度慢速训练选择不够。现将速度菜单补齐为 12 档，并统一显示格式，整数档位不再显示多余的小数位。

- [x] `playback_controls.dart`：播放速度菜单从 `0.5 / 0.75 / 1 / 1.25 / 1.5 / 1.75 / 2` 调整为 `0.5 / 0.7 / 0.75 / 0.8 / 0.85 / 0.9 / 0.95 / 1 / 1.1 / 1.3 / 1.5 / 2`；新增统一速度文案格式化，显示为 `1x` / `2x` 而非 `1.0x` / `2.0x`。
- [x] `playback_controls_test.dart`：更新默认按钮文案断言，并补齐完整速度菜单选项覆盖。
- [x] 验证：`flutter analyze lib/widgets/playback_controls.dart test/widgets/playback_controls_test.dart` 通过；`flutter test test/widgets/playback_controls_test.dart` 16 passed。

  **完成时间**: 2026-06-22 10:49:16 +0800

## 已完成：Free Player 进度条 seek 抖动修复（收藏 tab / 全文 tab）

收藏 tab 在播放中点击进度条时，旧流程会先 `clearClip()` 再重启句子驱动播放，导致进度条短暂回到音频 0 点；全文 tab 在 seek 过程中也会偶发先跳到前后错误位置再归位。现改为：收藏 tab 播放中直接切到目标句并重新起播，同时在进度条 UI 增加短暂的 seek 预览，屏蔽底层引擎中间态带来的圆点抖动。

- [x] `listening_practice_provider.dart`：`seekAbsolute()` 增加播放中句子驱动分支，跳过 `clearClip()` / 中间 seek，直接 `_startCurrent()` 重起目标句。
- [x] `player_screen.dart`：进度条 `onSeek` 增加短暂的目标位置预览，seek 完成前优先显示用户点击位置，避免全文 tab 圆点偶发前后跳动。
- [x] `free_player_playback_flow_test.dart`：新增回归测试，覆盖收藏 tab 播放中点击进度条不再先清空 clip。
- [x] 验证：`flutter analyze lib/screens/player_screen.dart lib/providers/listening_practice/listening_practice_provider.dart test/providers/listening_practice/free_player_playback_flow_test.dart test/screens/player_screen_test.dart` 通过；`flutter test test/providers/listening_practice/free_player_playback_flow_test.dart test/screens/player_screen_test.dart` 32 passed。

  **完成时间**: 2026-06-22 08:55:41 +0800

## 已完成：学习计划页 Free Player 入口显眼度优化

学习计划页右上角的「自由练习」原本只是普通 `TextButton.icon`，在标题区视觉权重偏低，用户容易忽略。现改为更克制但更醒目的紧凑工具入口：提高底色对比、边框存在感和浮起感，在不明显挤压标题的前提下提高可发现性。

- [x] `learning_plan_screen.dart`：将 AppBar 右上角入口替换为自定义 `_FreePlayAppBarButton`；使用更强的主色容器底、轻描边、轻量耳机图标和加粗文案强化视觉层级，并保持移动端紧凑宽度。
- [x] `learning_plan_screen_test.dart`：新增回归测试，覆盖入口渲染与点击后进入 Player 路由。
- [x] 验证：`flutter analyze lib/screens/learning_plan_screen.dart test/screens/learning_plan_screen_test.dart` 通过；`flutter test test/screens/learning_plan_screen_test.dart` 42 passed。

  **完成时间**: 2026-06-22

## 已完成：Free Player 睡眠定时器入口改为低干扰倒计时

自由播放器右上角睡眠定时器此前激活后仍只显示图标，真正的剩余时间放在浮层里大字号展示，信息层级过重且抢占浮层注意力。现改为：激活后 AppBar 入口直接显示一个低存在感倒计时胶囊，浮层只保留标题、关闭操作和预设列表，当前档位稳定打勾，不再靠剩余时间近似推断。

- [x] `sleep_timer_state.dart`：新增 `presetMinutes` 运行态字段，显式保存当前预设档位，避免 UI 用剩余时间反推选中项。
- [x] `sleep_timer_provider.dart`：`start()` 写入预设分钟数，tick 期间仅刷新 `remaining` 并保留当前档位，到点/取消时统一清空。
- [x] `sleep_timer.dart`：未激活保持弱化 `timer_outlined`；激活改为小号 `mm:ss` 轻量胶囊（弱底色 + 细描边 + tabular figures）；浮层删除大号倒计时区块，仅保留“关闭定时”和预设项。
- [x] 测试：更新 provider / widget 回归，覆盖激活态胶囊显示、浮层去掉大号剩余时间、运行一段时间后当前档位仍正确打勾。

  **完成时间**: 2026-06-22

## 已完成：共享句子列表收藏图标视觉收敛

右侧收藏按钮已改成更接近原句子 item 的轻量标记：已收藏保持小号 amber 书签，未收藏态进一步弱化，减少对句子正文的注意力抢占。

- [x] `masked_sentence_tile.dart`：收藏图标缩到 14px，保持与原句子 item 一致的轻量标记风格；未收藏态使用更弱化的 `onSurfaceVariant` 半透明色。
- [x] 验证：`flutter analyze lib/widgets/common/masked_sentence_tile.dart lib/widgets/common/paragraph_sentence_list_card.dart test/widgets/masked_sentence_tile_test.dart test/screens/player_screen_test.dart test/screens/blind_listen_player_screen_test.dart test/screens/retell_player_screen_test.dart` 通过；`flutter test test/widgets/masked_sentence_tile_test.dart` 通过（12 passed）。

  **完成时间**: 2026-06-22

## 已完成：共享句子列表改为三段式收藏交互

共享句子列表组件 `ParagraphSentenceListCard` / `MaskedSentenceTile` 之前只有两段式交互：左侧编号区负责播放，右侧整块主体区进入讲解页，收藏/取消收藏只能进讲解页后再做。现改为三段式共享布局，供 Free Player、全文盲听、段落复述共用：左侧编号区继续从该句播放，中间文本区保留进入讲解页，右侧新增独立收藏按钮，支持直接收藏/取消收藏。

- [x] `masked_sentence_tile.dart`：布局改为左播 / 中间文本 / 右侧收藏三段式；新增右侧收藏点击区、测试 key、tooltip / semantics，正文区不再混入只读书签图标。
- [x] `paragraph_sentence_list_card.dart`：新增句子级 `onSentenceBookmarkToggle` 回调并透传给共享 tile，保持自动跟随、初次定位、guide step 逻辑不变。
- [x] `player_screen.dart`：全文 Tab 和收藏 Tab 接入列表右侧收藏切换；中间文本进讲解页行为保持不变。
- [x] `blind_listen_player_provider.dart` / `blind_listen_player_screen.dart`：补齐盲听 provider 的 `toggleBookmark` 能力，并把列表右侧按钮接到 provider。
- [x] `retell_player_screen.dart`：接入复述列表右侧收藏切换。
- [x] 测试：更新 `masked_sentence_tile_test.dart`，新增 Player / 盲听 / 复述页面对右侧收藏按钮的回归测试。
- [x] 验证：`flutter analyze` 相关文件通过；`flutter test test/widgets/masked_sentence_tile_test.dart test/screens/player_screen_test.dart test/screens/blind_listen_player_screen_test.dart test/screens/retell_player_screen_test.dart` 全部通过（58 passed）。

  **完成时间**: 2026-06-21

## 已完成：Free Player 收藏 Tab 默认单句循环

Free Player 的收藏句通常不是连续上下文，若按普通连续播放直接跳到下一条，听感会比较硬。现将收藏 tab 的默认循环语义统一为：默认开启单句循环，重复 1 次，间隔 1 秒；用“逐句停顿”替代“连续硬切”。全文 tab 保持原默认不变。

- [x] `playback_settings.dart`：新增收藏 tab 默认循环常量/辅助函数，统一表达“单句循环开 + 1 次 + 1 秒”。
- [x] `listening_practice_state.dart` / `storage_service.dart`：收藏 tab 默认设置、旧单份 schema 升级、双设置读取统一收敛到新的收藏默认循环语义。
- [x] `listening_practice_provider.dart`：加载新音频时，全文 tab 仍重置为“不循环”，收藏 tab 恢复默认单句循环，确保难句跳播不连续硬切。
- [x] 测试：更新 model / storage / provider / widget 回归，覆盖收藏默认设置、旧 schema 迁移、切到收藏 tab 生效、加载新音频后恢复默认循环。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test` 目标测试 86 passed。

  **完成时间**: 2026-06-21

## 已完成：Free Player 播放结束后重播语义统一

Free Player 在非循环模式下播到末尾后，之前会停在结尾，但用户再次点击主播放按钮时会从**最后一句**重新开始，全文 Tab 和收藏 Tab 都不符合播放器常见语义。现统一为：两个 Tab 都在播放结束后保留结尾态；用户再次点击主播放按钮时，从**当前 Tab 对应播放列表的开头**重新开始。整篇循环开启时保持自动回卷不变。

- [x] `listening_practice_provider.dart`：新增“当前播放列表已自然播完、等待从列表开头重播”的 provider 内部状态；全文 gapless 和收藏/单句 clip 两条自然结束路径统一置位；主播放按钮在该状态下改为从当前列表第 1 句启动，而不是从最后一句启动；手动 seek / 切句 / 切 Tab / 对齐当前位置等操作会清除结束态。
- [x] `free_player_playback_flow_test.dart`：新增“全文非循环播完后再播从第 1 句开始”“收藏非循环播完后再播从收藏列表第 1 句开始”两个回归场景。
- [x] 验证：`flutter analyze lib/providers/listening_practice/listening_practice_provider.dart test/providers/listening_practice/free_player_playback_flow_test.dart` 通过；`flutter test test/providers/listening_practice/free_player_playback_flow_test.dart` 12 passed。

  **完成时间**: 2026-06-21

## 已完成：Free Player 全文 / 收藏 Tab 设置解耦

Free Player 之前只有一份全局 `PlaybackSettings`，导致全文 Tab 和收藏 Tab 共用倍速、字幕显隐、单句模式和循环设置；这与两种模式的训练语义不一致：全文是连续播放，收藏是难句跳播，用户在一边调出的设置会污染另一边。现改为按 Tab 维护两套完全独立的设置，并兼容旧版单份持久化数据自动迁移。

- [x] `listening_practice_state.dart`：新增 `fullSettings` / `bookmarkSettings` 两份状态，保留 `settings` 作为“当前激活 Tab 生效设置”的派生入口，兼容既有调用方。
- [x] `storage_service.dart`：`playback_settings` 持久化升级为双配置结构；兼容旧 schema，首次读取旧单份设置时复制为全文 / 收藏两份初始值。
- [x] `listening_practice_provider.dart`：`loadSettings` / `updateSettings` / `setPlaylistMode` / `loadAudio` 改为读写两份设置；切 Tab 时立即应用目标 Tab 的倍速并停止上一个 Tab 播放，不自动续播；加载新音频时分别重置两边的循环开关。
- [x] `player_screen.dart`：全文列表/收藏列表/单句视图按各自 Tab 的设置渲染，不再错误读取当前激活 Tab 的显示状态。
- [x] 测试：新增 state / storage / provider / widget 回归，覆盖“双设置独立持久化”“旧 schema 迁移”“切 Tab 应用目标设置”“收藏设置不串改全文”。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test` 目标测试 56 passed。

  **完成时间**: 2026-06-21

## 已完成：修复 Free Player 单句循环开关误改播放状态

单句循环开关此前会在播放中直接触发 `gapless ↔ clip` 驱动模型切换，导致当前句突然回到开头；在暂停态切换时，也可能因为复用同一条重启路径而意外恢复播放。修复目标是把“切换设置”和“切换当前播放任务模型”解耦：开关切换本身不改变播放/暂停态，不立刻跳句首；若播放中打开单句循环，则当前句先自然播完，再从**当前句句首**进入循环。整篇循环行为保持不变。

- [x] `listening_practice_provider.dart`：拆分“当前实际播放模型”与“设置期望模型”，新增延迟交接标记；播放中开启单句循环时，当前句继续自然播放，播完后从当前句句首切到 clip；播放中关闭单句循环时，当前 clip 播完后切回 gapless；暂停态切换仅更新设置，不触发 `play/seek/newSession`。
- [x] `free_player_playback_flow_test.dart`：新增 3 个回归场景，覆盖“播放中开启不跳句首”“暂停开启不自动播”“播放中关闭后当前 clip 播完再回 gapless”。
- [x] 验证：`flutter analyze lib/providers/listening_practice/listening_practice_provider.dart test/providers/listening_practice/free_player_playback_flow_test.dart` 通过；`flutter test test/providers/listening_practice/free_player_playback_flow_test.dart` 10 passed；`flutter test test/providers/listening_practice/session_guard_test.dart` 6 passed（有既存测试日志告警，但不影响通过）。

  **完成时间**: 2026-06-21

## 已完成：Free Player 播放架构重构（分模式播放，修复单句/整篇循环）

Free Player 的单句循环和整篇循环在全 gapless + positionStream 边界监听模型下容易受采样 overshoot、末句完成事件、收藏非连续句和静音间隙影响，无法稳定复现 v1.0.17 的循环行为。本次改为按播放目标选择模型：普通全文播放继续 gapless，保留整段进度条任意 seek；单句循环和收藏跳播回到句级 clip 驱动，由 clip completed 明确推进，避免用 positionStream 猜句尾。

- [x] `listening_practice_provider.dart`：删除 `_watchBoundaries`/`_watchEndTime`/边界监听推进路径，新增播放任务 generation、句级 clip 播放协程和 gapless 整篇完成处理；单句循环/收藏模式忽略 positionStream 高亮推进，避免双推进。
- [x] `audio_engine_provider.dart`：恢复共享句级播放基元 `playClipWithLoops`，新增 `absoluteCurrentPosition`，确保 clip 模式保存断点时写入绝对时间而非 clip 相对位置。
- [x] `playback_state_storage.dart`：保存接口改为接收绝对 `Duration`，消除对 `AudioPlayer.position` 的 clip 相对时间依赖。
- [x] `free_player_playback_flow_test.dart`：新增复杂字幕场景（不等长句、句间静音、边界相邻、非连续收藏、尾句贴近音频尾部），覆盖普通 gapless、有限/无限单句循环、收藏跳播、seek 后重置计数、手动切句、双循环同开。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test test/providers/listening_practice` 全 66 passed；`player_screen_test` / `playback_controls_test` / `settings_dialog_test` / `loop_reset_on_load_test` 相关组合全 passed。

  **完成时间**: 2026-06-18

## 已完成：修复 CI widget test 失败（句子列表点击与字幕弹窗语言选择）

GitHub Actions `test` job 失败于 3 个 widget test：Free Player 句子列表两个点击测试点到了不可命中的文本/Tile 中心区域；管理字幕弹窗测试假设默认语言为 auto，但当前默认语言是 en，导致找不到可点击的 `Start Transcription` 按钮。

- [x] `masked_sentence_tile.dart`：给句子编号点击区和主体点击区增加 `@visibleForTesting` key 前缀，测试可精准点击真实交互热区，不依赖内部文本布局。
- [x] `player_screen_test.dart`：等待初次定位淡入完成后，改用点击区 key 分别测试“编号区播放”和“主体区进讲解页”。
- [x] `manage_subtitles_sheet_test.dart`：测试中显式从 English 切换到 Auto Detect，再断言 AI(en) 已转录场景下可重新发起 auto 转录。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`player_screen_test.dart` 15 passed；`manage_subtitles_sheet_test.dart` 12 passed。

  **完成时间**: 2026-06-18

## 已完成：Free Player 句子列表初次定位「直接显示在中间」（去除多余滚动）

Free Player 句子列表在「首次进入」和「收藏 Tab 切回全文 Tab」时，当前句会从顶部滚到中部——不符合业界标准（初次定位应直接显示在中间，不发生滚动）。根因：`ParagraphSentenceListCard` 的初次定位与播放跟随共用「jumpTo 顶部 → scrollTo 居中」路径，无论动画快慢，用户都会看到目标句从顶部移动到中部。

业界标准做法（避免踩坑）：在「列表不可见」时完成滚动定位，居中后再淡入，用户全程看不到滚动。关键约束：必须保持底层 `anchor=0`——`ScrollablePositionedList` 的 `initialAlignment=0.5` 会把 anchor 永久设为 0.5、破坏既有「anchor=0 + ClampingScrollPhysics 硬停」的到头/尾防回弹设计（实测 `不越界` 回归测试失败）。

- [x] `widgets/common/paragraph_sentence_list_card.dart`：`initState` 用 `initialScrollIndex` 首帧把当前句渲染在顶部（anchor 仍为 0）；新增 `_centerInitialFocus`（jumpTo→scrollTo 两阶段瞬时居中，保持 anchor 0）；`build` 外层包 `AnimatedOpacity`（`_initialFocusDone` 前 opacity=0 隐藏、完成后 120ms 淡入）；`_focusPlayingSentence` 恢复原状仅负责播放中逐句跟随；新增 `@visibleForTesting kParagraphListInitialFocusKey`。
- [x] `paragraph_sentence_list_card_test.dart`：新增「居中完成前隐藏、完成后淡入且已居中」回归测试；现有「末句贴底/首句贴顶/中部居中/不越界防回弹」4 测试不变。
- [x] 验证：`flutter analyze` 改动文件 No issues；`flutter test paragraph_sentence_list_card_test.dart`：10 passed；`test/screens test/widgets` 仅 2 个 pre-existing 失败（`player_screen_test` 交互用例，baseline 同样失败，与本改动无关）。

  **完成时间**: 2026-06-18

## 已完成：更换内置 Examples 为 6 条 CEFR 示例音频

内置 Examples 从单条 `English in a Minute - On the Ball` 替换为 A1/A2/B1/B2/C1/C2 六条 CEFR 示例音频。安装器改为版本化幂等安装：全新空库安装 6 条新示例；已安装旧 bundled example 的用户启动后自动删除旧记录、旧音频文件和旧音频关联数据并迁移到 6 条新示例；已有用户库但没有旧 example 的环境不自动插入示例，避免污染既有库。示例继续保持无字幕策略，引导用户通过 AI 转录生成字幕；重复安装不会覆盖新示例已生成的字幕。

- [x] `bundled_example_installer.dart`：新增 v2 manifest（6 条固定 ID）和 `bundled_example_installed_version`；支持旧 `bundled-example-audio-0001` 迁移清理；显式清理旧音频的 collection/bookmark/progress/stage/playback/tag 关联与 saved word/sense group 冗余上下文；复制新 assets 并写入 `Examples` 合集。
- [x] `bundled_example_installer_test.dart`：覆盖空库安装、最新版跳过、版本标记丢失幂等（保留已生成字幕）、旧示例迁移（含关联表/上下文清理）、非空用户库不自动插入五个分支。
- [x] `native_audio_decoder_integration_test.dart`：demo asset 改为新的 `CEFR A1 - Book a table.m4a`，更新时长断言。
- [x] 验证：`flutter analyze lib/services/bundled_example_installer.dart test/services/bundled_example_installer_test.dart integration_test/native_audio_decoder_integration_test.dart`：No issues found；`flutter test test/services/bundled_example_installer_test.dart`：5 passed。

  **完成时间**: 2026-06-18

## 已完成：Free Player 睡眠定时器（定时停止）

自由播放器缺少听力/播客播放器的标准「定时停止」功能。在 AppBar 右上角新增 timer 图标按钮，点击在按钮下方弹出气泡浮层（复用「循环设置」浮层的视觉与交互骨架，箭头朝上）选择预设时长（5/10/15/30/45/60 分钟），到点自动**暂停**（可续播）。定时为**一次性**：不持久化、独立 provider、autoDispose 绑定页面生命周期，离开页面即取消、到点后清空、重进无激活态。墙钟倒计时（`clock.now()` + `Timer.periodic`，便于 fake_async 测试），防竞态用 generation token 作废旧计时。范围裁剪：不做「听完本条/当前句」自然结束选项、不做音量淡出、不做自定义分钟输入。

- [x] `models/sleep_timer_state.dart`：不可变运行态 `SleepTimerState{remaining}` + 预设档常量 `sleepTimerPresets`。
- [x] `providers/listening_practice/sleep_timer_provider.dart`：`@riverpod`(autoDispose) `SleepTimer`，`start/cancel/_tick`，到点 `ref.read(listeningPracticeProvider.notifier).pause()`；`ref.onDispose` 取消 ticker。
- [x] `widgets/sleep_timer.dart`：`SleepTimerButton`（AppBar，OverlayPortal 定位按钮下方）+ `_SleepTimerPopup`（未激活列 6 档；激活显剩余时间 + 关闭定时 + 当前档打勾）+ `_CaretUpPainter`（朝上箭头）。
- [x] `screens/player_screen.dart`：AppBar `actions: [SleepTimerButton()]`。
- [x] l10n：`app_en.arb`/`app_zh.arb` 新增 sleepTimer/sleepTimerMinutes/sleepTimerRemaining/sleepTimerOff/sleepTimerA11yActive。
- [x] 依赖：`pubspec.yaml` 直接引入 `clock`（墙钟可测）。
- [x] 测试：`sleep_timer_provider_test`（fake_async：剩余递减、到点暂停一次、重设替换、取消不触发、dispose 取消）5 例；`sleep_timer_test`（widget：6 档渲染、点选启动收起转激活、激活态剩余/关闭/打勾、点关闭恢复）3 例。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test` 全套 2874 例通过。
- [x] UI 打磨：图标加右边距；浮层收窄（240→144）；新增居中标题头 + 浅色分割线；选项字体收小（bodyLarge→bodyMedium）、行高/图标收紧；行内容统一居中、hover 高亮铺满整行。

  **完成时间**: 2026-06-18

## 已完成：Free Player 进度条重构（gapless + 边界监听，业界标准任意 seek）

Free Player 进度条两个 bug——①位置与句子有时不匹配、②只能按句子寻址不能任意位置——根因都在 **clip 播放形态**：单句循环/收藏 tab 下用 `just_audio.setClip` 把播放限制在当前句区间，导致整段进度条只在小区间内移动、拖动吸附句首重起播。彻底重构为**永不 setClip 的 gapless 播放 + positionStream 边界监听**：进度条始终是整段连续时间轴、可任意位置 seek；单句循环/收藏跳播/整篇循环改由「越过当前监听句尾」检测驱动（接受 ~200ms 标准 overshoot）。

- [x] `audio_engine_provider.dart`：新增 `pauseKeepSession()`（暂停但不递增 sessionId），供边界处理/任意 seek 续播同一 session。`setClip`/`playClipOnce`/`playRangeOnce` 保持不动（学习模式仍用）。
- [x] `sentence_tracker.dart`：`findSentenceIndexByPosition` 间隙归属由「下一句」改为「上一句」（尾部静音），修高亮在静音段提前跳。
- [x] `playback_reducer.dart`：`decideNext` 删除 `isClipMode`，语义改为「越过当前句尾后该做什么」；新增 public `shouldLoopWhole`（供 gapless 整段自然播完判定）。
- [x] `listening_practice_provider.dart`：删 `_isClipMode`/`_playPosition`/`_advanceAfterCompletion`/`_advancing`；`_isClipMode`→`_watchBoundaries`；新增 `_watchPos`/`_watchEndTime`/`_boundaryGen`/`_handlingBoundary` 与 `_maybeCrossBoundary`/`_advance`/`_resumeAt`/`_setWatch`/`_alignEngineToCurrent`；`_onPositionChanged` 拆「越界检测 + 高亮」；`seekAbsolute` 重写为任意 seek 从落点续播（收藏模式吸附最近收藏句）。
- [x] 测试：`playback_reducer_test` 删 isClipMode 用例、补 `shouldLoopWhole`；`sentence_tracker_test` 间隙归属改上一句 + 补 endTime 边界；`session_guard_test` 单句循环改 gapless 断言、新增「越过句尾位置流重播」「任意拖动从落点续播」；`fake_notifiers` 补 `pauseKeepSession`。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`flutter test` 全套 2866 例通过。

  **完成时间**: 2026-06-18

## 已完成：修复学习首页「待解锁」任务卡片误显"学习中"

待解锁任务（`reviewUpcoming`）本轮尚未解锁，按设计只应显示解锁倒计时，但 v2 计划的音频会误显"学习中"。根因：`study_screen.dart` 的 `_statusText` 用 `task.subStage != task.stage.allSubStages.first` 判定"学习中"，而 `allSubStages`（v1∪v2 展示并集）复习阶段首元素是盲听，v2 计划首步却是难句补练，导致刚进入新复习轮的待解锁任务被误判。改为基于真实完成历史（`stage_completions`），与 `learning_plan_screen` 的判定口径统一，且不依赖计划版本。

- [x] `study_task_provider.dart`：`StudyTask` 新增 `hasRoundProgress` 字段，`_buildTaskForAudio` 由 `completionsByAudio` 计算当前 stage 是否有 ≥1 完成记录（key 前缀带冒号，避免 `review1` 误匹配 `review14`）。
- [x] `study_screen.dart`：`_statusText` 改用 `task.hasRoundProgress` 判定"学习中"，弃用 `allSubStages.first` 比较。
- [x] 测试：`study_task_provider_test` 新增 `hasRoundProgress` group（待解锁无记录=false、有记录=true、跨阶段不误命中）；`study_screen_test` 新增待解锁卡片显示倒计时而非"学习中"用例。
- [x] 验证：`flutter analyze` 改动文件 0 issue；目标测试全绿。

  **完成时间**: 2026-06-18

## 已完成：Free Player 单句模式改为精听模式（复用 AnnotationContentView）

自由播放器的「单句模式」原本只是一张简单卡片（句子大字 + 序号 + 时间 + 收藏图标，隐藏字幕仅模糊句子文本），语义上其实就是「精听模式」。改为与「逐句精听」复用同一套解析 UI（`AnnotationContentView`：解析/翻译/意群工具栏 + 句子 + 翻译 + 解析 + 难句标记行）。与逐句精听唯一不同：自由播放器有「隐藏字幕」开关，隐藏时遮蔽**整个解析内容区**（含工具栏、句子、翻译、解析）且禁用点击。

- [x] `player_screen.dart`：重写 `_buildSingleSentenceView`，弃用旧卡片，改为「序号+时间 + `BookmarkToggleRow` 难句标记行 + `AnnotationContentView`（被遮罩 Stack 包裹）」，接入方式参照 `sentence_detail_screen.dart`；`onStopMainPlayer` 接 `controller.pause()` 让意群试听前停主播放；隐藏字幕遮罩复用原模糊视觉（`ImageFilter.blur(5,5)` + `onSurface` 0.05）外加 `IgnorePointer` 实现禁用。删除随之失效的整卡右键/长按上下文菜单（`_showContextMenu` + `text_context_menu` import）。
- [x] 测试：`player_screen_test` 新增「单句模式（精听）」group——验证渲染 `AnnotationContentView` + `BookmarkToggleRow`、隐藏字幕叠加遮罩/显示字幕无遮罩、点击标记行切换收藏。复用 `intensive_listen_player_screen_test` 的 AI/DAO/学习设置 override 套路避免真实网络/DB。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`player_screen_test` 全 15 例绿；`flutter test` 全套 2860 例通过。

  **完成时间**: 2026-06-18

## 已完成：Free Player Tab 激活态视觉优化

自由播放器顶部「全文 / 收藏」两个 tab 原激活态只靠蓝色文字 + 底部下划线，对比弱、用户不易察觉哪个 tab 激活。改为业界通用、与 Material 3 一致的 SegmentedButton 风格浅色药丸激活态。

- [x] `app_theme.dart`（`tabBarTheme`）：激活态改用 `indicator` 浅色药丸（`secondaryContainer` + 圆角 10）+ `indicatorSize: tab` 铺满；`dividerColor: transparent` 去掉底部下划线；`labelColor: onSecondaryContainer`、`unselectedLabelColor: onSurfaceVariant`；`splashBorderRadius` 与药丸圆角对齐。
- [x] `player_screen.dart`（`TabBar`）：新增 `indicatorPadding`（垂直 8 / 水平 4）让药丸四周留白、不顶满。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`player_screen_test` 全绿（纯样式属性调整，无需改测试）。

  **完成时间**: 2026-06-18

## 已完成：播放控制栏视觉优化

自由播放器底部控制栏的 UI 打磨，按用户多轮反馈逐项调整：

- [x] `player_screen.dart`：移动端底部状态栏也显示（原仅桌面端），居中于播放按钮下方且保留播放按钮原有下边距；状态栏顺序调整为「模式 · 倍速 · 整篇循环 · 单句循环」；整体弱化为低对比灰（`onSurface` 0.45），避免与控制按钮抢注意力。
- [x] `playback_controls.dart`：切换按钮激活态改用 MD3 tonal 风格（`primaryContainer` 浅色调底 + 主色图标），替代原蓝/灰图标（对比太弱、又不与主播放按钮抢焦点）；移动端切换按钮间距 4 → 12；倍速文字弱化（灰、w600）。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`playback_controls_test` / `player_screen_test` 全绿。

  **完成时间**: 2026-06-18

## 已完成：循环开关改为不全局持久化（随加载新音频重置）

自由播放器底部四个按钮原本全部全局持久化（SharedPreferences）。按业界惯例区分「偏好」与「意图」：播放速度 / 字幕显隐 / 单句视图属偏好，保持全局持久化；**循环开关是「现在想刷这条」的临时意图，不应被全局记忆**。改为：循环开关纯内存、不落任何盘，加载新音频时一律重置为关；循环参数（次数/间隔）仍作为全局偏好保留。已与用户确认采用「不持久化 / 永远忘记」方案，不改数据库 schema。

- [x] `playback_settings.dart`：`toJson` 移除 `loopWhole`/`loopSentence` 两个开关键（参数键照常写）；`fromJson` 新 schema 判据改按循环参数键识别（避免误入 legacy 迁移），开关一律还原为 `false`，仅恢复参数/速度/视图/字幕；旧字段（`repeatMode`/`loopEnabled`/`loopAudioEnabled`）的开关迁移逻辑去除，只保留旧 `loopCount`/`pauseInterval`→单句参数的迁移。
- [x] `listening_practice_provider.dart`：`loadAudio` 真正加载新音频路径上 `state.copyWith(settings: settings.copyWith(loopWhole:false, loopSentence:false))`，仅改内存、不持久化；同音频早返回则保持不变。
- [x] 测试：重写 `playback_settings_test` 往返/旧字段/范围校验三组断言（开关不往返、参数保留）；新增 `loop_reset_on_load_test`（内存 DB + 测试引擎，验证加载新音频重置开关、同音频早返回不重置）。
- [x] 验证：`flutter analyze` 改动文件 0 issue；`playback_settings_test` / `listening_practice/` / `settings_dialog_test` / `playback_controls_test` 全绿。

  **完成时间**: 2026-06-18

## 已完成：循环设置浮层定位修复 + 布局优化

原浮层用 `CompositedTransformFollower` 右对齐到循环按钮（宽 300），向左溢出甚至超出屏幕左边缘。按用户参考样式改为**按钮正上方居中弹出、底部带向下箭头指向按钮**的气泡，并经 ui-ux agent 优化布局。

- [x] `playback_controls.dart`（`_LoopButton`）：弃用 `LayerLink`/`CompositedTransform*`，改为按钮加 `GlobalKey`，在 `overlayChildBuilder` 内读按钮相对 Overlay 的位置，用 `Positioned`（left/bottom/width）将浮层居中于按钮并**水平夹紧到屏幕内**（左右各留 16px），`caretX` = 按钮中心相对浮层左缘的偏移；`bottom` 锚定使浮层展开时向上生长、箭头始终贴按钮。
- [x] `settings_dialog.dart`（`LoopSettingsPopup`）：删除「循环设置」标题；宽度 300→280，新增 `width`/`caretX` 参数；卡片底部用 `_CaretPainter`（CustomPaint 等腰三角，宽 16 高 8）画向下箭头；区块间分隔改 1px `outlineVariant` Divider；主开关行图标/标题随开关变色（开 primary / 关 onSurfaceVariant）且整行 `InkWell` 可点；`_LabeledSliderRow` label 宽 84→64、单行省略、值列宽 40→44；间隔值用紧凑单位 `Ns`（label 去「（秒）」），无障碍朗读保留完整「N 秒」。
- [x] l10n：`intervalTime` 由「间隔时间（秒）」→「间隔」、「Interval (seconds)」→「Interval」。
- [x] 测试：更新 `settings_dialog_test`/`playback_controls_test`/`player_screen_test` 改用「Whole-text loop」判定浮层开启（标题已删），断言间隔 label「Interval」与值「3s」。`flutter analyze` 改动文件 0 issue；三套测试全绿。

  **完成时间**: 2026-06-18

## 已完成：循环设置弹窗（整篇 / 单句双循环独立可同时开启）

自由播放器原循环交互繁琐：循环图标是三态切换（关闭→整段→单句，**互斥**），重复次数/间隔藏在右上角 `Icons.tune` 弹窗且仅作用于单句循环。改为：点击循环图标直接弹出循环设置面板，「整篇循环」「单句循环」两个**独立、可同时开启**的开关，各带「重复次数」「间隔时长」滑块。右上角 tune 按钮删除。已与用户确认语义：整篇循环「重复次数 N」= 整篇**总共播放 N 遍**（∞=无限）。

- [x] `playback_settings.dart`：用六个新字段（`loopWhole`/`wholeLoopCount`/`wholeInterval` + `loopSentence`/`sentenceLoopCount`/`sentenceInterval`）**替换**单一 `repeatMode`/`loopCount`/`pauseInterval`；范围校验（次数 0=∞ 或 1-10，间隔 0-10s）；`fromJson` 兼容旧 schema 迁移（`one`→单句、`all`→整篇∞、`off`→双关，旧 `loopEnabled`/`loopAudioEnabled` 亦兼容）；删除已无消费方的 `PlaybackRepeatMode` 枚举与其 export。
- [x] `playback_reducer.dart`：`decideNext` 重写为接收 `isClipMode` + 双循环参数，覆盖 gapless（整篇完成）/clip（单句完成）两种事件语义；`ReplayCurrent`/`GoToPosition` 增加 `pauseBefore` 字段，让 reducer 直接给出该用单句还是整篇间隔（单一真相源）。
- [x] `listening_practice_provider.dart`：`_repeatsDone`→`_sentenceRepeatsDone` 并新增 `_wholeLoopsDone`（clip 模式仅在真正整篇回卷时 +1，避免 off-by-one）；`_isClipMode` 改为 `bookmarks || loopSentence`；`_advanceAfterCompletion` 走新 reducer；`_delayInterval(Duration)` 接收 reducer 决策的间隔；所有起播/seek 重置点同步归零两个计数。
- [x] UI：`playback_controls.dart` 循环图标改为点击弹出**悬浮浮层**（`_LoopButton` 用 `OverlayPortal` + `CompositedTransformFollower` 锚定到按钮上方、右对齐，透明遮罩点击外部关闭；任一循环开则高亮，仅单句开用 repeat_one）；`settings_dialog.dart` 重写为浮层 `LoopSettingsPopup`（两组自定义紧凑开关行 + `AnimatedSize` 展开「标签 + 滑条 + 值」**单行**滑块：重复次数 1-10/∞、间隔 0-10s，即时生效）；`player_screen.dart` 删除 tune 按钮与 `_showSettingsDialog`，状态徽标改为按 `loopWhole`/`loopSentence` 各自展示；l10n 新增 `wholeTextLoop`/`singleSentenceLoop`（复用 `loopSettings`/`repeatCount`/`intervalTime`/`times`/`seconds`）。
- [x] 测试：重写 `playback_reducer_test`（gapless/clip/两者同开全程 trace/边界，断言 `pauseBefore`）、`playback_settings_test`（六字段往返、范围截断、旧 schema 迁移）、`settings_dialog_test`（双开关展开滑块、∞ 文案、切换触发 updateSettings）、`playback_controls_test`（图标随循环态、点击开弹窗）、`player_screen_test`（移除 tune、循环按钮开弹窗）、`session_guard_test`（迁移到新字段）。

  **完成时间**: 2026-06-17

## 已完成：自由播放器（free player）播放架构重构

free player 的循环/跳句 bug（单句循环莫名跳第一句、讲解页试听返回后跳句）根源是架构问题：`ListeningPractice` 用**两套执行模型**（响应式 `_playContinuous` + 命令式 `while/for` 长协程 `_playSubtitleDriven`）驱动同一个共享 `AudioEngine`，由 `loopEnabled×loopCount×autoPlayNext×loopAudio` 四开关矩阵 + 被多处递增的 `sessionId` 协调，事件竞态导致索引乱跳。本次彻底重写为**单一事件驱动模型**，不打补丁。

- [x] 新增纯函数 `playback_reducer.dart`（`PlaybackRepeatMode{off,all,one}` + `decideNext`），把「一句播完后做什么」从协程剥离为可单测的无副作用决策；枚举名避开 Flutter material 的 `RepeatMode` 冲突。
- [x] `playback_settings.dart`：用单一 `repeatMode` **替换** `loopEnabled`/`loopAudioEnabled`/`loopAudio`；`fromJson` 一次性迁移旧字段；删除废弃字段及其 toJson/copyWith/校验。
- [x] 重写 `listening_practice_provider.dart`：删除 `_playContinuous`/`_playSubtitleDriven`/`_shouldUseContinuousMode`/`_audioLoopCount` 与 `play()` 的 `isResume` 启发式；改为「位置流推进高亮（gapless）+ 完成事件归约器 `_advanceAfterCompletion` 调 `decideNext`」；新增 `restorePosition()` 供讲解页返回显式对齐当前句；保留共享引擎必需的 `isActiveSession` 守卫并加注释。删除引擎中仅 LP 使用的死代码 `playClipWithLoops`。
- [x] UI：`playback_controls.dart` 单句开关改为三态循环按钮（关闭→整段循环→单句循环）；`settings_dialog.dart` 删除「音频循环」整块与「句子重复」开关，合并为单句循环参数（重复次数/间隔）；`player_screen.dart` 讲解页返回调用 `restorePosition()`，InfoBar 按 `repeatMode` 展示；清理孤立 l10n 键。
- [x] 交互简化（用户反馈）：删除费解的「自动播放下一句」开关，把「单句循环是无限重复还是重复 N 次后前进」折叠进**重复次数**——`loopCount=0` 即「∞」无限重复当前句，有限次数则重复够后自动进下一句。`autoPlayNextSentenceEnabled` 字段一并删除。
- [x] 测试：新增 `playback_reducer_test.dart`（13 用例覆盖 decideNext 全分支）；重写 `session_guard_test.dart`（单句循环不跳第一句、讲解页返回 `restorePosition` 对齐当前句、gapless 位置推进、外来 session 隔离）；更新 `playback_settings_test`/`settings_dialog_test`/`playback_controls_test`/`player_screen_test`。`flutter analyze` lib 0 issue；全量 2841 单元/组件测试通过。（macOS integration_test 因环境「Unable to start the app on the device」启动失败，与本改动无关。）

  **完成时间**: 2026-06-17

## 已完成：修复自由播放器看完句子讲解返回后主播放按钮跳回第一句

free player 点句子进讲解页 → 试听单句 → 返回 → 点主播放按钮，结果从第一句重播。根因：讲解页与 free player 共享同一个 `AudioEngine`，讲解页旁路驱动它（`playRangeOnce`，`newSession()` 顶掉 LP 的 session、改写 clip/position），污染了「外部播放器」状态。两处泄漏：①LP 的位置/状态监听器不校验 session，`_updateCurrentSentence` 把 `currentFullIndex` 改成被试听的句子；②`play()` 的 `isResume` 仅看引擎当前 position，会从讲解页留下的（被污染）位置续播。盲听播放器本就有 `isActiveSession` 守卫且 resume 永远按断点句重新 seek（`blind_listen_player_provider.dart`），free player 缺失——本次按同款思路补齐。

- [x] `audio_engine_provider.dart`：新增 `currentSessionId` getter。
- [x] `listening_practice_provider.dart`：新增 `_playbackSessionId` 字段，`_playContinuous`/`_playSubtitleDriven` 的 `newSession()` 后记录、`pause()` 后记录引擎当前 session（使「普通暂停→续播」仍归 LP 所有）；`_updateCurrentSentence`/`_handlePlaybackCompleted` 加 `isActiveSession(_playbackSessionId)` 守卫；`play()` 的 `isResume` 增加 `isActiveSession(_playbackSessionId)` 前置——被外来 session 驱动过就不续播引擎位置，改按 `currentFullIndex` 重新定位。
- [x] 测试：新增 `test/providers/listening_practice/session_guard_test.dart`（外来 session 位置事件不改 `currentFullIndex`、外来 session 后 `play()` 按 `currentFullIndex` 重新 seek、LP 自身 session 正常推进高亮）。`flutter analyze` 改动文件 0 issue；provider + player_screen 共 609 测试全绿。

  **完成时间**: 2026-06-17

## 已完成：自由练习全能播放器复用盲听句子列表组件

自由练习「全能播放器」(`PlayerScreen`) 原用自有 `SentenceListView`（整条点击=播放、右侧书签切换按钮、显示时间范围）。改为复用全文盲听的共享组件 `ParagraphSentenceListCard`/`MaskedSentenceTile`，统一交互：点击左侧编号区从该句继续播放、点击句子主体进讲解页、内置「尊重用户手动滚动」的自动跟随。约束：仅共享句子列表组件，不共享 provider/controller，不给共享组件加新职责。

- [x] `player_screen.dart`：`_buildFullTextTab`/`_buildBookmarkedTab` 用 `ParagraphSentenceListCard` 替换 `SentenceListView`。全文 tab `playingSentenceIndex=currentFullIndex`（列表位置==index）；收藏 tab 把 `currentBookmarkIndex` 换算成收藏子集本地位置。`displayMode` 由 `settings.showTranscript` 映射 showAll/hideAll。`autoFocusEnabled=autoScrollEnabled`。
- [x] `player_screen.dart`：新增 `_handleSentenceDetail`（仿盲听、本页持有不共享）——`_isNavigatingToDetail` 防重入 → `pause()` → `context.push(AppRoutes.sentenceDetail, extra: SentenceDetailArgs(...))` → 返回后 `syncBookmarks()` 刷新收藏标记与「收藏(n)」计数。移除原 `onUserScroll→setAutoScroll(false)` 桥接（共享组件自管理）。删除 `_buildSingleSentenceView` 中遗留未用的 `l10n`。
- [x] 删除死代码 `lib/widgets/sentence_list_view.dart` 及 `test/widgets/sentence_list_view_test.dart`（仅 PlayerScreen 引用）。
- [x] 行为变化：列表内不再有内联书签切换（收藏改到讲解页完成）、不再显示时间范围、不再支持长按文本选择菜单（单句模式视图仍保留自带菜单）。
- [x] 测试：`test/helpers/test_app.dart` 加 `/sentence-detail` stub 路由；重写 `player_screen_test.dart` 列表渲染断言（改查共享组件类型）、`play_arrow` 断言限定在 `PlaybackControls` 内（当前播放句编号区也渲染 ▶）；新增「点击编号区从该句播放」「点击主体进讲解页」两个交互用例。`flutter analyze` 改动文件 0 issue。

  **完成时间**: 2026-06-17

## 已完成：修复未开始音频仍显示旧版首次学习流程（盲听优先）

v33→v34 迁移把所有存量 audio 的 firstLearn 一律锁 v1。v2（盲听后置）上线后，一个**在旧版打开过学习计划页、被建了进度行但从未真正开始学习**的音频被永久锁在 v1 顺序（全文盲听排第一）。新增一次性迁移直接清空这类进度行——删除后无进度行 → plan 回退 `kLatestPlanVersions`（firstLearn=2）→ 显示新版流程；重新打开时 `ensureProgress` 建全新 v2 进度。

- [x] `app_database.dart`：`currentSchemaVersion` 41→42；新增 `_clearUnstartedV1FirstLearnProgress()`——删除 `current_stage='firstLearn' AND current_sub_stage='blindListen' AND plan firstLearn==1` 的进度行。**安全点**：v2 第 3 步同样是 firstLearn:blindListen，必须校验 json `firstLearn==1` 只删 v1，绝不误删进行中的 v2。迁移块置于 `onUpgrade` 末尾（依赖 v34 块创建的 plan_versions_json 列，迁移块按源码顺序执行）。
- [x] 测试：新增 `test/database/v42_migration_test.dart`（5 类 fixture：v1 盲听首步删 / 盲听过几遍仍删 / v1 已前进到精听保留 / v1 已进入 review 保留 / v2 第 3 步保留）；更新 `v33_to_v34_migration_test`（链式迁移到 head 后 audio-fresh 被 v42 清理，review 版本判定改用 audio-only-firstlearn）。全量 2836 测试通过，`flutter analyze` 改动文件 0 issue。

  **完成时间**: 2026-06-17

## 已完成：难度实时化 —— 按当前难句书签数重算，驱动各入口默认速度

原难度在精听完成时一次性按难句比例判定并冻结落库，后续步骤/复习只读这个冻结值。导致用户练熟后取消难句收藏（如 9 句只剩 1 句难句）时，难句跟读等入口仍按历史 veryHard 显示 0.75x。改为「每次进入练习入口时按当前难句书签数实时重算难度并静默回写」：难句比例下降 → 难度降低 → 默认播放速度随之回升，不再被历史难度绑定。

- [x] `learning_progress_provider.dart`：新增 `refreshDifficultyFromBookmarks(audioItemId, totalSentences)`——查 bookmarkDao 当前难句数 → `difficultyFromDifficultRatio` 重算 → 静默落库（不发埋点，区别于用户显式 `setDifficulty`）；难度无变化跳过写库；`totalSentences<=0`（字幕未加载）不重算，避免误清成 veryEasy；无 progress 返回 medium。
- [x] `learning_plan_screen.dart`：各练习入口在弹引导前调用 `refreshDifficultyFromBookmarks`，用返回的实时难度算 `defaultPlaybackSpeedFor` / `KeywordRatio` / 跟读 `playCount`。覆盖：难句跟读、段落复述、复习盲听、复习难句补练、复习段落复述，及对应自由练习路径。
- [x] `learning_plan_screen.dart`：首学全文盲听（第三步）`_startBlindListen` 原本未传 `defaultPlaybackSpeed`（恒 1x），补为按 firstLearn 阶段的实时难度速度，与难句跟读/复述一致。
- [x] `fake_notifiers.dart`：`FakeLearningProgressNotifier` 覆盖 `refreshDifficultyFromBookmarks` 为纯内存返回现有难度（测试不接 bookmarkDao）。
- [x] 测试：`learning_progress_provider_test` 新增 `refreshDifficultyFromBookmarks` group（1/9→medium、0→veryEasy、4/9→veryHard、无变化跳过写库、totalSentences=0 不重算、无 progress 返回 medium）；修正 `blind_listen_briefing_sheet_test` 过期文案断言。全量测试通过，`flutter analyze` 0 error。

  **完成时间**: 2026-06-17

---

## 已完成：学习流程调整 —— 盲听后置 + 取消手动选难度 + 难度自动判定

依据 DAU 下降分析报告：盲听作为首次学习第一步让新用户困惑、延后 aha 时刻。首次学习流程由
`盲听→精听→跟读→复述` 调整为 `逐句精听→难句跟读→盲听(可跳过)→段落复述`，并取消手动难度选择、
难句跟读统一默认 3 遍、精听完成弹窗增加间隔复习引导。仅对新建音频生效（计划版本 firstLearn v2）。

- [x] `learning_plan.dart`：`kLatestPlanVersions[firstLearn]=2`；`LearningPlan.standard` firstLearn 按版本分支，v2=`[intensive, listenAndRepeat, blind, retell]`，v1 保留旧顺序。
- [x] `enums.dart`：`LearningStage.allSubStages` firstLearn 改为 v2 规范顺序。
- [x] `learning_progress.dart`：新增 `firstLearnEntrySubStage`（按 plan 版本派生）；`isStarted` / `canSkipCurrentSubStage` 改为按入口子步骤判定（v1 盲听不可跳过、v2 精听不可跳过盲听可跳过）。
- [x] `learning_progress_provider.dart`：`ensureProgress` 新建进度入口子步骤改为 v2 的逐句精听。
- [x] `step_complete_dialog.dart`：删除 5 档难度选择器（含 `StepCompleteResult.difficulty`、`showDifficultySelector`）。
- [x] `blind_listen_player_screen.dart`：盲听完成不再弹难度选择 / 写难度。
- [x] 新增 `utils/difficulty_from_ratio.dart`：精听后按「难句比例=收藏难句/总句数」自动判定难度（0/≤5%/≤15%/≤30%/>30% → veryEasy/easy/medium/hard/veryHard）。
- [x] `intensive_listen_player_screen.dart`：精听完成时自动 `setDifficulty`。难度仍驱动 `defaultPlaybackSpeedFor(难度×阶段)` 默认速度（整表不变）。
- [x] `sentence_playback_engine.dart`：`targetPlayCountForDifficulty` 各档统一返回 3（保留接口便于以后差异化）。
- [x] l10n：`intensiveListenCompleteMessage` 改为「你已精听全部 X 个句子，收藏了 Y 个难句。坚持间隔复习，就能彻底掌握这些难句。」（中英）。
- [x] 测试：新增 `difficulty_from_ratio_test`；更新 plan/progress/enums/dialog/provider/screen/engine/fake_notifiers 及 integration 测试（v2 顺序、入口跳过规则、难度自动判定、新文案）。全量 2818 单元/widget 测试通过，`flutter analyze` 0 error。

  **完成时间**: 2026-06-17

---

## 已完成：修复「清除缓存」误删系统 URLCache 致 disk I/O error

清缓存把整个 `Library/Caches` 一级条目全删，连带删掉 `URLSession.shared`(NSURLCache) 正在打开的 `<bundleId>/Cache.db`，导致后续网络请求反复报 `disk I/O error`（与磁盘空间无关）。改为只清 app 自己的产物。

- [x] `temp_cleanup_service.cleanupAllTempFiles`：`Library/Caches` 不再全量删；新增前缀白名单 `audio_export_`/`echoloop_export_`/`echoloop_import_` + `_cleanupDirectory` 的 `nameFilter` 参数，只删 app 自建导出/导入临时目录，系统/框架缓存（`Cache.db*`、`<bundleId>/`、`app_network_images`）一律跳过；日志补 `skipped=`。tmp/ 仍全量清。
- [x] `settings_screen._clearNetworkImageCache`：网络图片缓存改走 `AppNetworkImageCache.instance.emptyCache()`（flutter_cache_manager API），释放字节累加进提示。
- [x] 测试：`temp_cleanup_service_test` 重写 `cleanupAllTempFiles` group（tmp/ 全清、Library/Caches 只删导出导入目录、保护 URLCache/框架缓存）。services 全量 445 测试通过，`flutter analyze` 改动文件 0 issue。
- [x] CLAUDE.md §7.5 记录踩坑与规则。

  **完成时间**: 2026-06-17

---

## 已完成：清空缓存补齐孤儿音频/字幕/waveform 文件清理

设置页「清除缓存」此前只清 AI 缓存表 + 内存 + 系统临时目录 + 词典，从不触碰 app 数据目录下按内容/ID 落盘的产物，导致孤儿音频、孤儿字幕、waveform 文件永久堆积。

- [x] **源头泄漏修复**：删除音频时 `_deleteAudioFilesIfUnreferenced`（`audio_library_provider.dart`）此前只删 audioPath/transcriptPath，从不删 `waveforms/{id}.wave` → 每删一个音频漏一个波形文件。现按 id 一并删除（波形按 id 独占无共享，无需引用检查）。
- [x] 新增 `AudioItemDao.getAllReferencedRelPaths()`：取**所有行（含软删）**的 audioPath/transcriptPath 相对路径集合，作为孤儿清扫白名单（软删行硬删前仍持有文件，不能误删）。
- [x] 新增 `lib/services/orphan_file_cleanup_service.dart`：`cleanupOrphanMediaFiles()` 递归扫 `audios/`（覆盖 imported/official 子目录 + 旧版直接存于根、可读文件名的遗留音频）和 `transcripts/`，删除 DB 无引用的孤儿文件；`cleanupAllWaveforms()` 全量清 `waveforms/`（纯缓存，可重建）。
- [x] `settings_screen._clearAiCache` 接入两个清理函数，freedBytes 累加进释放提示，沿用现有文案与埋点。
- [x] 测试：`orphan_file_cleanup_service_test.dart`（孤儿删除/引用保留/空集全删/不碰 waveforms/全量清波形）；`dao_test` 补 `getAllReferencedRelPaths`（含软删行、忽略空路径）；`audio_library_provider_test` 补「删音频一并删 waveform」。

  **完成时间**: 2026-06-17

---

## 已完成：练习播放页进度条改为可拖动（按句吸附跳转）

学习计划五个播放页（盲听 / 精听 / 跟读 / 复述 / 难句补练）的顶部进度条由只读 `LinearProgressIndicator` 改为按句分档的可拖动滑块，松手吸附到目标句并从该句开始播放。**收藏复习不做**。

- [x] 共享组件 `PracticeProgressSection` 新增可选 `onSeek(int targetIndex)`（0-based）；非 null 且 `total>1` 时渲染私有 `_SeekableProgressBar`（拖动跟手、`onChangeEnd` 才提交、`SliderTheme` 收紧尺寸），否则保持只读进度条。向后兼容。
- [x] `ParagraphPracticeScaffold` 新增 `onSeekToIndex` 透传（盲听 / 复述经它渲染）。
- [x] 跳转能力：盲听 / 复述复用现成 `seekToSentence`；精听、`RepeatFlowEngine`（跟读）、难句补练新增公开 `goToSentence(int)`（防御式 clamp + 同句 no-op，next/prev 复用）；`ListenAndRepeatController` 转发。
- [x] 五个播放页接线 `onSeek`。
- [x] 测试：新建 `practice_progress_section_test.dart`（只读/滑块切换、拖动回调取值）；精听 / 跟读 / 难句补练 provider 各补 `goToSentence`（合法跳转 / 越界 clamp / 同句 no-op）单测。`flutter analyze` 0 error，相关 117 测试全过。

  **完成时间**: 2026-06-16

---

## 已完成：延后转码 —— 导入保留原始音频，AI 转录后再转码

提升 AI 转录质量：旧流程导入即转码为 64k 单声道 m4a，转录上传低质 m4a。改为导入**不转码**（保留原始、导入更快）、转录上传**原始文件**（质量更高）、转录成功后在流程内**顺带**把原始转码为 m4a 并替换 `audioPath`、删除原始。

- [x] `AudioTranscodeService`：抽出底层 `transcodeToFile(source, output)→bool`（不删源、失败删半成品），删除旧 `transcodeToM4a`/`_uniqueOutputPath`/`_replaceSourceWithOutput` 死代码。
- [x] `AudioFinalizationService.finalize()`：导入不再转码，按原始指纹保留原格式落盘（`sha==originalSha`）；新增 `transcodeExisting()`（转录后转码，`try/finally` 清理临时 m4a，不删源由调用方删）。
- [x] `transcription_task_provider`：`_saveTranscriptAndFinish` 内 best-effort 转码——仅对未转码用户导入（`remoteAudioId==null && audioSha256==originalAudioSha256`）触发；成功更新 `audioPath`/`audioSha256` 并删原始，**失败静默**（仍保存字幕、保留原始，不阻塞学习）。新增 `transcriptionFinalizationServiceProvider`。
- [x] 边界：① 转码失败/异常清理临时文件；② "是否已转码"复用现有两 sha 相等判据，删字幕不动 sha → 重转录天然跳过/重试，无需新字段或迁移。
- [x] 测试：finalization 单测（导入不转码 / transcodeExisting 成功·失败·去重·无残留）；import_service 单测改为断言保留原始；provider 单测新增「成功触发转码并删原始」「失败静默仍完成」；transcode 集成测试改用 `transcodeToFile`。

  **完成时间**: 2026-06-16

---

## 已修复：字幕丢失 + 冷重启音频显示未下载（同一根因）

- [x] **根因**：`AudioItemDao.batchInsert` 用 `InsertMode.insertOrReplace`，在 SQLite 是整行 **DELETE+INSERT**。由 commit `3768a131` 把 `_upsertItem` 改走批量 `insertOrReplace` 引入。两个后果：
  1. `_audioItemToCompanion` 不携带 `transcript_srt` / `word_timestamps_json`，整行替换把这两列抹成 NULL → 「句数词数还在但字幕没了」（编辑字幕/自由练习/盲听都拿不到字幕）。
  2. DELETE 行触发所有子表 `ON DELETE CASCADE`（`collection_audio_items` / `bookmarks` / `playback_states` / `learning_progresses`）→ 音频被静默移出合集、丢书签与学习进度。冷启动若有旧绝对路径音频触发 `hasMigratedItems`，会对全部音频回写一遍，整片合集 junction 被删空 → 官方/podcast 音频在详情页"消失"并回落到下载态 → 显示「下载按钮」。
  - 任何走 `_upsertItem` 的回写都会触发：`updateAudioItem` / `togglePin` / `checkAudioContent`（下载完成后立即调用）/ `backfill*` / 路径迁移。
  - **修复**：`batchInsert` 改为逐条 `insert(..., onConflict: DoUpdate((_) => entry))`（INSERT … ON CONFLICT DO UPDATE），已存在行只更新 companion 携带的列、不删行 → 大字段保留、不触发级联。
  - **测试**：`test/database/dao_test.dart` 新增 2 个回归用例（保留 transcript_srt/word_timestamps 大字段；不级联删除合集 junction/书签），旧实现下精确 fail、修复后通过。
  - **注意**：已被旧版本抹掉 `transcript_srt` 的存量数据无法从统计反推；有遗留 `transcriptPath` 文件的可由启动 `backfillTranscriptSrt` 恢复，否则需重新下载/转录。被级联删空的合集 junction 由下次官方 sync 重建。

  **完成时间**: 2026-06-15

---

## 待办：Android 离线 ASR 结束录音仍闪退

- [ ] 崩在 sherpa-onnx 的 Silero VAD native 推理（`_extractSpeechWithVad`）；cpu provider、AudioRecord 串行、自适应跳过 VAD 三种尝试均未解决（skip-VAD 真机连续崩多次已撤销）。诊断设施已保留，待真机 **logcat + `/data/tombstones`** 确诊信号/栈后再定方案。详见 CLAUDE.md §7.4。

---

## 进行中：启动埋点附带 4 类授权状态

PostHog 自动事件 `Application Opened` 不带任何系统授权属性，无法做"授权状态 vs 留存"分析。本期把麦克风 / 语音识别 / 通知 / 网络 4 类授权状态作为 PostHog **super properties + person properties + 自定义事件 `app_permission_snapshot`** 上报；不修改任何现有权限弹窗时机。

### 任务拆分（一次一项）
- [x] **任务 1：埋点常量 + PermissionSnapshot helper + 单测**
  - `event_names.dart`：新增 `Events.appPermissionSnapshot` + 4 个 EventParams（mic/speech/notification/network）
  - `lib/analytics/permission_snapshot.dart`：不可变值对象 + `toEventParams()` + 静态 `capture(prefs, {probe})`
  - `PermissionProbe` 抽象 + `DefaultPermissionProbe` 实现（mic/speech 走 `SpeechPracticePlatform`，notification 走 `flutter_local_notifications`；网络读 SP `network_data_task_succeeded`，仅 iOS 有意义，其他平台 `not_applicable`）
  - 网络状态映射：iOS 上 SP 缺失 → `notDetermined`，true → `granted`，**不引入假 denied 推断**
  - `test/analytics/permission_snapshot_test.dart`：11 个测试覆盖 toEventParams 映射 / 网络状态平台分支 / probe 容错 / 状态常量
  
  **完成时间**: 2026-04-26
- [x] **任务 2：iOS 网络 channel 改造 + main.dart 写 SP**
  - `ios/Runner/AppDelegate.swift:1144-1170` channel handler 返回 `{ok, reason}` + `hasResponded` Once 守护 + 5s 超时（避免 method channel 多次 result 踩坑，参考 CLAUDE.md §7.2）
  - 把原 `_triggerNetworkPermission` 抽到 `lib/services/network_permission_trigger.dart` 的 `NetworkPermissionTrigger.trigger(prefs, url)`，便于单测；成功时写 SP `network_data_task_succeeded = true`，**失败/超时/异常不写 SP**（防止飞行模式 / 弱网 / 服务端故障被误判为 denied）
  - `lib/main.dart` 删除内联 `_triggerNetworkPermission`，启动调用改为 `NetworkPermissionTrigger.trigger(prefs, apiBaseUrl)`，并清理掉不再用的 `package:flutter/services.dart` import
  - `test/services/network_permission_trigger_test.dart`：7 个测试覆盖 ok=true/false/null/缺字段/抛错/幂等/失败不回退
  
  **完成时间**: 2026-04-26
- [x] **任务 3：AnalyticsChannel.registerSuperProperties + PostHog 实现 + 其他 channel no-op + AnalyticsService 转发**
  - `analytics_channel.dart` 接口新增 `registerSuperProperties(Map<String, Object>)` + 中文文档注释（解释与 setUserProperty 的区别）
  - `posthog_channel.dart` 实现：循环调用 `Posthog().register(key, value)`（5.x SDK 一次接受一个 key/value）
  - `firebase_channel.dart` / `umeng_channel.dart` no-op 实现 + 注释说明为何
  - `log_only_channel.dart` 实现：把 `key=value` 列表打到 `AppLogger`
  - `analytics_service.dart` 加 `registerSuperProperties` 方法：consent gate + try/catch 兜底（埋点不影响主业务）
  - 更新所有现有 mock channel 实现新方法（`MockChannel` / `_RecordingChannel`）
  - 新增 4 个测试：转发 / consent 拦截 / 异常静默吞 / LogOnly 日志格式
  
  **完成时间**: 2026-04-26
- [x] **任务 4：main.dart 启动序列接入 + Onboarding 末页权限预告 label**
  - `lib/analytics/permission_snapshot.dart` 新增 `PermissionSnapshotReporting` extension on `AnalyticsService`，把"super properties + 4 个 person property + `app_permission_snapshot` 事件"三路写入封装在一个方法里
  - `lib/main.dart` 在 `initAnalytics` 之后 `await PermissionSnapshot.capture(prefs)` → `await analyticsService.reportPermissionSnapshot(snapshot)`，用 try/catch 包裹避免影响启动
  - Onboarding 方法论页（summary）"开始学习"按钮上方加权限预告：小号提示 + 两个 `Wrap` chip（`notifications_outlined` / `wifi_outlined` + 短 label "系统通知" / "网络权限"），独立 Padding 区不滚动总能见，仅展示无交互
  - 网络权限保持启动即触发（保留原行为）：埋点上报依赖网络通畅，推迟到 Onboarding 完成会丢事件；系统弹窗具体呈现时机由 OS 决定
  - ARB 新增 3 个 key（zh + en）
  - 测试：`permission_snapshot_test.dart` 加 2 个测试覆盖 extension（三路写入 / consent 拦截）；`onboarding_survey_screen_test.dart` 加权限 label 渲染断言
  
  **完成时间**: 2026-04-26
- [ ] 任务 5：手动验证（PostHog Live Events / Persons / Insights）

### 范围内不做
- 自定义教育弹窗 / 调整任何现有权限弹窗时机 / 跳系统设置引导 / AppLifecycleState.resumed 监听 / Android 13+ 通知权限 UI 验证

---

## 录音+识别功能（进行中）

- [x] **修复 iOS `prod` flavor release 构建配置**

  **完成时间**: 2026-06-15 18:38 +0800

  补齐 `prod` flavor 的 iOS 构建链路，避免 `flutter run --release --flavor prod` 在 Flutter 26 / Xcode 26 下丢失 `TARGET_BUILD_DIR`：
  - `ios/Podfile` 增加 `Debug-prod` / `Release-prod` 到 CocoaPods 配置映射
  - 新增 `ios/Flutter/Debug-prod.xcconfig` 与 `ios/Flutter/Release-prod.xcconfig`
  - `ios/Runner.xcodeproj/project.pbxproj` 将 `Debug-prod` / `Release-prod` 绑定到对应 flavor xcconfig
  - 重新执行 `pod install` 同步 Pods flavor 配置
  - 验证 `xcodebuild -workspace Runner.xcworkspace -scheme prod -configuration Release-prod -showBuildSettings` 可正常输出 `TARGET_BUILD_DIR`

- [x] **段落复述评级开关**
  
  **完成时间**: 2026-06-15 16:04 +0800
  
  学习设置页新增「计算并显示复述评级」开关，默认开启。关闭后段落复述只保留录音和自动回听，不再启用识别、转录、匹配或评分，胶囊降级为「录音」胶囊（不显示评级）；段间停顿按无评分策略计算。
  - [x] `LearningSettings` 新增 `retellRatingEnabled`，使用 `learning_retell_rating_enabled` 持久化，默认 true
  - [x] 段落复述录音关闭评级时跳过 ASR/transcript/matcher/embedding，只保存录音 attempt
  - [x] 关闭评级时胶囊降级为「录音」胶囊（`unavailable + filePath`），仍挂载并复用 badge controller
  - [x] 补充学习设置、复述录音 controller、复述页面回归测试
  - [x] 2026-06-15 16:08 +0800：调整学习设置页复述评级开关文案为「复述时关闭评级」，描述改为关闭后只保留录音回听且不再显示评分
  - [x] 2026-06-15：修复关闭评级时自动回听不显示停止图标的 bug——删除绕过 badge 的 `_playAttemptRecordingDirectly` 直连路径，开启/关闭统一走 `_ratingBadgeController.play()`，使「录音」胶囊在自动回听时正确显示停止图标且可点停止；修正被该 bug 固化的测试断言；补全 `_TestLearningSettingsNotifier.setRetellRatingEnabled` 缺失实现
  - [x] `flutter analyze lib/providers/learning_settings_provider.dart lib/providers/retell_recording_controller_provider.dart lib/screens/learning_settings_screen.dart lib/screens/retell_player_screen.dart lib/widgets/common/repeat_practice_panel.dart lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart test/providers/learning_settings_provider_test.dart test/providers/retell_recording_controller_test.dart test/screens/learning_settings_screen_test.dart test/screens/retell_player_screen_test.dart`：No issues found
  - [x] `flutter test test/providers/learning_settings_provider_test.dart test/screens/learning_settings_screen_test.dart test/providers/retell_recording_controller_test.dart test/screens/retell_player_screen_test.dart`：39 passed
  - [ ] `scripts/check.sh`：未跑；本次为学习设置与段落复述局部行为改动，按规范仅运行直接相关检查

- [ ] 段落复述页面复用同一模块接入录音识别能力。

---

## 优化UI（进行中）

- [x] **全能播放器句子列表交互优化**

  **完成时间**: 2026-06-17

  删除 AppBar 手动 focus 按钮，改为播放句自动跟随、用户滚动后短暂停留再自动恢复；缩小播放器标题字号并单行省略；句子 item 改为左侧单句播放、中间进入句子讲解、右侧整高收藏区域，字幕文字与时间样式参考字幕编辑器。补充单句播放 provider 入口，确保点击左侧只播放当前句，播完暂停。

- [ ] 支持自定义背景、背景音

---

## 用户体验优化（待办）

- [ ] 计算每个任务的估计学习时长，显示在音频学习计划页以及学习tab页的任务item上。没有学习的显示估计时长，已经学习的显示真实的耗时。
- [ ] 学习 tab 页面点击学习或复习要直接打开学习页面，跳过学习计划页面
- [ ] 在学习tab，增加显示今日完成任务（如果有），默认折叠起来，避免用户不知道今天都学了哪些
- [ ] 给句子增加复制功能，在移动端长按，在PC端右键，弹出一个菜单，现在只有一个选项就是复制。

---

## 加入特效

- [ ] 一个句子/单词播放完成，一遍播放完成，播放音效
- [ ] 任务完成，播放动画+音效

---

## 埋点

- [ ] 支持中国大陆区
- [ ] 支持全球

---

## 历史归档
- [Milestone 2 - 学习流程引擎](./docs/tasks-archive/milestone-2-learning-engine.md)
- [Milestone 3 - 收藏与标注体系 + 体验优化](./docs/tasks-archive/milestone-3-completed.md)
- [Milestone 4 - 功能完善与体验打磨](./docs/tasks-archive/milestone-4-features-and-polish.md)
- [Milestone 5 - 登录认证 / Podcast / 离线 ASR / 字幕编辑器](./docs/tasks-archive/milestone-5-completed.md)

---

## 任务完成记录模板

<!--
完成任务后，按以下格式在任务下方添加记录：

  **完成时间**: 2026-XX-XX
-->
