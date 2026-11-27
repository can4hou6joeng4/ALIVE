<div align="center">
  <img src="Alive/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="96" height="96" alt="ALIVE 应用图标" style="border-radius: 22px;" />
  <h1>ALIVE</h1>
  <p><strong>围绕「今天还可花」设计的极简 iOS 个人每日预算应用</strong></p>
  <p>
    <img src="https://img.shields.io/badge/Platform-iOS%2026.0%2B-0A84FF?style=flat-square" alt="Platform iOS 26.0+" />
    <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square" alt="Swift 6.0" />
    <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20Bento%20Grid-111111?style=flat-square" alt="SwiftUI Bento Grid" />
    <img src="https://img.shields.io/badge/Storage-SwiftData%20仅本地-30D158?style=flat-square" alt="Local Only" />
  </p>
  <p>
    <a href="README.md">English</a> | <strong>简体中文</strong>
  </p>
</div>

---

## 简介

**ALIVE**（寓意「活着」）不追求传统记账工具的繁杂分类、图表与报表，而是聚焦一个核心问题：**「今天还能花多少」**。应用将当前余额按日历天数自动分配到发薪日前的每一天，结合 **Bento 便当盒主屏** 与 **灵动岛 / 锁屏实时活动**，大幅降低日常查看与记账摩擦。

---

## 应用截图

| 今日主屏（浅色） | 今日主屏（深色） | 快速记账卡片 | 本周期记录 | 设置抽屉 |
| :---: | :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/today-light.png" width="170" alt="今日主屏浅色" /> | <img src="docs/screenshots/today-dark.png" width="170" alt="今日主屏深色" /> | <img src="docs/screenshots/quick-entry.png" width="170" alt="快速记账卡片" /> | <img src="docs/screenshots/history.png" width="170" alt="本周期记录" /> | <img src="docs/screenshots/settings.png" width="170" alt="设置抽屉" /> |

---

## 核心特性

- **每日可用额度引擎**：基于左闭右开周期 `[起始日, 发薪日)` 与固定北京时间（`Asia/Shanghai`）日历日，实时计算「今天还可花」或未来起始日的「预计每日额度」（`pending` 待开始状态）。
- **Bento 便当盒主屏**：
  - **主格**：展示今日可用（或超支）金额、已用百分比徽章与进度条。
  - **双列指标格**：左右并排呈现 **距发薪日天数** 与 **当前余额**（轻点余额方格即可直接调整）。
  - **最近记录格**：清晰展示近期支出流水，点击即可进入本周期完整记录页。
- **轻量快速记账**：从屏幕顶部展开悬浮记账卡片，自动聚焦数字键盘，支持最多 80 字可选备注与实时校验；历史流水页支持支出编辑与确认删除。
- **余额修正与周期自动结转**：支持随时修正当前剩余金额并实时重算今日预算；到达发薪日 00:00 自动归档旧周期并结转余额。
- **灵动岛与锁屏实时活动**：
  - **紧凑态与最小态**：展示 ALIVE 连笔流体符号与紧凑金额，短按直达今日主屏（`alive://today`）。
  - **展开态 Micro-Bento**：长按进入两步整数记账（`0–9` 防裁切数字键、退格、下一步 → 三标签点选直存），由 `LiveActivityIntent` 在 App 进程幂等写入。
  - **锁屏连续记账层**：轻点锁屏活动整卡通过 `alive://live-entry` 进入 App 顶部连续记账层输入自由备注。

---

## 核心计算口径

进行中周期（及起始日不晚于今天的首次设置）：

```text
今日预算   = max(0, 当前余额) ÷ max(1, 今天到发薪日的日历日数)
今天还可花 = 今日预算 − 今日已支出
```

- 内部金额全程使用最小货币单位整数（分）与 `Decimal` 精确计算，禁止二进制浮点数累加。
- 今日预算在当天内固定；超支仅进入 `overspent` 状态而不阻断记账，次日按最新余额重新分摊。

---

## 技术架构与目录结构

- **系统基线**：iOS 26.0+、iPhone only、Swift 6 严格并发
- **核心框架**：SwiftUI、SwiftData、ActivityKit、WidgetKit、Swift Testing
- **工程生成**：XcodeGen（[project.yml](project.yml)）

```text
ALIVE/
├── Alive/                 # 主 App（页面、AppModel、设计系统、应用图标资源）
├── AliveCore/             # 共享静态框架（领域模型、BudgetCalendar、BudgetResolver、SwiftData 仓库、格式化与深链）
├── AliveWidgets/          # WidgetKit 扩展（Live Activity 与灵动岛两步记账视图）
├── AliveTests/            # Swift Testing 测试集（3 个 suite，共 42 个单元测试）
├── Shared/                # 跨进程共享意图定义（LiveActivityIntent）
├── docs/screenshots/      # README 展示用应用内截图
├── project.yml            # XcodeGen 工程配置源
├── PRD.md                 # 产品需求文档（唯一产品事实源）
├── DESIGN.md              # 交互、视觉与技术架构设计基线
└── AGENTS.md              # 仓库协作与工程验证规范
```

---

## 本地构建与测试

### 环境要求

- Xcode 26+（iOS 26.0+ SDK）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（修改 `project.yml` 或 target 配置时使用）

### 生成工程与构建

```bash
xcodegen generate

xcodebuild -project ALIVE.xcodeproj -scheme Alive \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -configuration Debug \
  -derivedDataPath artifacts/local-verification/DerivedData \
  build
```

### 运行单元测试（`AliveTests`）

```bash
xcodebuild -project ALIVE.xcodeproj -scheme Alive \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -configuration Debug \
  -derivedDataPath artifacts/local-verification/DerivedData \
  test
```

---

## 隐私与本地存储

- **纯本地沙盒**：金额、发薪日与支出记录仅保存在本机 SwiftData 数据库（`Library/Application Support/ALIVE/Database/Alive.store`）。
- **零遥测与零联网**：无账号体系、无云同步、无网络请求、无分析埋点或任何第三方 SDK。
- **无 App Group**：Live Activity 仅消费 App 通过 `ActivityContent` 下发的只读状态，岛内动作直接由系统在 App 进程执行。

---

## 相关文档

- [产品需求文档（PRD.md）](PRD.md)
- [设计与架构文档（DESIGN.md）](DESIGN.md)
- [工程约束与验证清单（AGENTS.md）](AGENTS.md)
