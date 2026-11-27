# ALIVE

ALIVE 是一款围绕 **「今天还可花」** 设计的 iOS 个人每日预算应用。它不追求传统记账工具的复杂报表与分类，而是把当前余额按日历天数清晰分配到发薪日前的每一天，并通过 **Bento 便当盒主屏** 与 **灵动岛 / 锁屏 Live Activity** 降低日常查看与记账成本。

---

## 核心特性

- **每日可用额度计算**：基于左闭右开周期 `[起始日, 发薪日)` 与固定北京时间（`Asia/Shanghai`）日历日，实时计算「今天还可花」与待开始状态的「预计每日额度」。
- **Bento 便当盒主屏**：顶部核心额度与今日消耗进度、双列「距发薪日 / 当前余额」快捷方格，以及近期支出流水。
- **轻量快速记账**：主屏顶部悬浮展开卡片，自动聚焦数字键盘，支持 80 字可选备注与实时校验；支持当前周期流水编辑与确认删除。
- **余额修正与周期结转**：支持随时修正当前剩余余额并实时重算今日预算；跨越发薪日自动归档旧周期并结转余额。
- **灵动岛与锁屏实时活动**：
  - 紧凑态与最小态展示连笔流体品牌符号与紧凑金额，短按直达今日主屏（`alive://today`）。
  - 展开态采用 Micro-Bento 布局与防裁切 0–9 整数键盘，支持岛内两步快捷记账（`LiveActivityIntent` 在 App 进程幂等写入）。
  - 锁屏活动整卡通过 `alive://live-entry` 进入 App 顶部连续记账层。
- **隐私与本地优先**：所有数据仅保存在本机 App 沙盒（SwiftData），不联网、不接入账号、云同步、分析或第三方 SDK，不使用 App Group。

---

## 技术栈与工程结构

- **平台基线**：iOS 26.0+、iPhone only、Swift 6 严格并发
- **核心框架**：SwiftUI、SwiftData、ActivityKit、WidgetKit、Swift Testing
- **工程生成**：XcodeGen（[project.yml](project.yml)）

```text
ALIVE/
├── Alive/                 # 主 App（页面、状态管理、设计系统、图标资源）
├── AliveCore/             # 共享静态框架（领域模型、BudgetCalendar、BudgetResolver、SwiftData 仓库、格式化与深链）
├── AliveWidgets/          # WidgetKit 扩展（Live Activity UI 与岛内两步记账视图）
├── AliveTests/            # Swift Testing 单元测试（3 个 suite，共 42 个测试）
├── Shared/                # 跨进程共享意图定义（LiveActivityIntent）
├── project.yml            # XcodeGen 工程配置源
├── PRD.md                 # 产品需求文档（唯一产品事实源）
├── DESIGN.md              # 交互、视觉与技术架构设计基线
└── AGENTS.md              # 仓库协作与工程验证规范
```

---

## 本地构建与测试

修改 `project.yml`、Info.plist、entitlements 或资源结构后，先重新生成工程文件：

```bash
xcodegen generate
```

### Debug 构建（iPhone 模拟器）

```bash
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

## 相关文档

- 产品需求规格：[PRD.md](PRD.md)
- 设计与架构文档：[DESIGN.md](DESIGN.md)
- 工程约束与验证清单：[AGENTS.md](AGENTS.md)
