# 音频操作二级菜单实施计划

**目标：** 音频列表使用 MenuAnchor 与 SubmenuButton，缩短主菜单。
**架构：** 保留现有操作回调与可见性条件，仅调整菜单容器和分组。
**技术栈：** Flutter Material、现有本地化工具。

- [x] 将 audio_list_tile.dart 菜单迁移到 MenuAnchor，导出和更多操作使用子菜单，删除在底部分组。
- [x] 补充中英文本地化并更新组件测试的子菜单交互。
- [x] 格式化、静态检查、运行相关测试并复查差异，更新 TASKS.md。
