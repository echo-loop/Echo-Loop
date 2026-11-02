# General Development Guide

## Core Principles

* Prefer simple, explicit, and maintainable solutions.
* Follow existing architecture, patterns, and conventions before introducing new ones.
* Avoid unnecessary abstractions, indirection, and complexity.
* Make the smallest change necessary to achieve the requested behavior.
* Preserve existing behavior unless a change is explicitly required.

## Architecture & Design

* Keep clear boundaries between domain logic, infrastructure, persistence, and external integrations.
* Keep modules focused and responsibilities well separated.
* Prefer explicit data flow and dependencies over hidden state and global state.
* Keep I/O and side effects at system boundaries where practical.
* Introduce abstractions only when they solve an existing problem.
* Reuse existing abstractions and patterns instead of creating parallel implementations.
* Avoid circular dependencies and unnecessary coupling between modules.
* Model states and transitions explicitly. Avoid implicit state changes and inconsistent state.

## Code Quality & Maintainability

* Optimize for readability and maintainability over cleverness.
* Keep functions and classes focused on a single responsibility.
* Prefer straightforward control flow over deeply nested or overly generic logic.
* Reduce duplication when it represents shared knowledge, but do not abstract merely to remove repeated code.
* Use comments to explain intent, constraints, and non-obvious decisions rather than restating the code.
* Remove dead code instead of keeping unused implementations for hypothetical future use.

## Naming & Terminology

* Use clear, domain-specific names and avoid vague names such as `process`, `handle`, or `data`.
* Use the same term for the same domain concept throughout the codebase; avoid synonyms and naming drift.
* Prefer nouns for data and types, verbs for operations, plural names for collections, and `is`, `has`, `can`, `should`, or `needs` prefixes for booleans.

## Types & Data

* Add explicit parameter and return types to new or modified functions and public interfaces.
* Prefer explicit domain models and typed data structures over `Any` and loosely structured dictionaries.
* Validate external input at system boundaries and use well-defined types internally.
* Do not use `Any`, `cast`, `type: ignore`, or `noqa` to hide real problems; keep necessary exceptions narrowly scoped and documented.

## Error Handling & Reliability

* Fail fast on invalid states and handle expected failures explicitly.
* Catch only specific exceptions that can be handled meaningfully; otherwise preserve the exception chain and propagate the failure.
* Do not silently swallow errors or disguise failures as success by returning empty lists, `None`, or default values.
* Avoid broad `except Exception` blocks except at deliberate application boundaries.
* Diagnose bugs using logs and reproducible evidence, not assumptions. Verify fixes through runtime logs and relevant tests.

## Testing

* Prefer test-driven development (TDD) for critical business logic and bug fixes.
* Write only high-value tests that verify meaningful behavior, edge cases, and regressions. Prioritize quality over test count or coverage.
* Keep tests deterministic and independent. Mock external boundaries, not the logic under test.

## Dependencies & Configuration

* Prefer the standard library and existing dependencies before adding new ones.
* Add a dependency only when its value clearly justifies its maintenance cost.
* Keep configuration separate from business logic.
* Use environment variables or configuration files for environment-specific settings.
* Never hardcode secrets, credentials, tokens, or environment-specific values.

## Documentation & Comments

* Write comments and docstrings in Chinese.
* Explain business reasons, constraints, and non-obvious trade-offs rather than restating what the code does.

## Logging

* Follow existing logging conventions. Use structured logs with appropriate levels and diagnostic context at critical execution points, state transitions, and failures.
* Avoid noisy or redundant logs and never log sensitive information.
* Write logs and commit messages in Chinese.


---

# Flutter 开发原则

## 分层职责

- **Screen/Page**：负责页面组装、导航和连接 UI 与状态。
- **Widget**：负责展示和局部交互，不承载复杂业务逻辑。
- **Provider/Notifier**：负责状态管理和业务流程协调。
- **Repository**：负责数据访问和持久化，不负责业务流程编排。
- **Model**：表示业务数据，独立于 UI State。
- 保持单向数据流：UI 触发动作，Notifier 更新 State，UI 根据 State 渲染。
- 复杂业务流程按需提取为可独立测试的 Dart 类。

## 状态管理

- Provider 按功能域组织，不按组件或页面外观机械拆分。
- 局部 UI 状态优先使用 Widget State；跨页面、跨功能共享或需要独立管理生命周期的状态优先使用 Provider。
- 每份真实状态保持单一数据来源，通过明确入口修改；复杂状态转换应显式建模。

## Widget 设计

- `build()` 只负责构建 UI，不执行网络请求、状态修改或其他副作用。
- 保持 Widget 职责明确，避免过度参数化的万能组件。
- 优先保持布局和状态订阅简单，仅在存在明显重建开销或性能问题时优化。

## 异步与生命周期

- 防止异步竞态和过期结果覆盖新状态，必要时使用取消机制或操作标识。
- 异步操作完成后，使用 `BuildContext`、`WidgetRef` 或更新 State 前确认其生命周期仍有效。
- 资源与所有者生命周期绑定，及时释放 Controller、StreamSubscription 等资源。
- 显式处理加载、错误和空状态。
- 网络、文件和平台调用保持合理职责边界，仅在必要时引入依赖注入。

## 响应式布局

- 根据实际可用空间和布局约束适配 UI，避免依赖设备型号、屏幕方向或固定尺寸。
- 正确处理 Safe Area、键盘遮挡及窗口尺寸变化，兼容手机、平板和桌面窗口。


---


## 任务启动流程（必须执行）

开始任何编码工作前，按顺序执行：
1. 阅读 `PLAN.md`，确认当前里程碑和阶段
2. 阅读 `TASKS.md`，确认待办与优先级

---

## 任务收尾流程（必须执行）

Before completing a code change:

* Review the final diff against all applicable guidelines.
* Check architecture, naming, type safety, error handling, logging, testing, and maintainability for consistency with existing code.
* Check for unnecessary abstractions, duplicated implementations, naming drift, hidden failures, and unrelated changes.
* Run formatting, linting, type checking, and relevant tests.
* If any issue or validation failure is found, diagnose the cause, fix it, and re-run the relevant checks. Repeat until all required checks pass.
* In the final response, include a verification checklist showing the actual result of each required check, including guideline compliance, code quality, tests, formatting, linting, and type checking.
* 更新 `TASKS.md`（勾选任务并记录完成时间），如里程碑状态变化，更新 `PLAN.md`

---

## Troubleshooting（踩坑记录）
踩坑记录统一记录在 docs/troubleshooting.md，本文件不再收录具体条目。