# 墨岛 · InkNotch 本地维护说明

项目目录：`/Users/bluemoe/code/public/InkNotch`。

本地分支为 `local/zh-hans`，基于上游正式版 2.7.3。`origin` 指向原项目；不向远端推送任何内容。

## 汉化维护

`localization/zh-Hans.json` 是本地译文词典，键保留原来的英文，值为简体中文。它覆盖设置、菜单、引导、权限提示、媒体控件、电池状态和文件操作。品牌名、文件格式、用户自己的文件名、媒体标题及歌词保留原文。

译文同步到上游原有的 `boringNotch/Localizable.xcstrings`，其他语言保持不变。系统权限弹窗使用 `boringNotch/InfoPlist.xcstrings`。不修改持久化设置的键、枚举原始值、URL、系统符号名或操作标识。

```bash
cd /Users/bluemoe/code/public/InkNotch
python3 tools/localize.py sync
python3 tools/localize.py check
```

检查包含中文覆盖、空译文、格式占位符、常见界面调用的静态扫描，以及 Xcode 可用时的 Apple 文案提取。编译后还会核对编译器生成的 `.stringsdata`，检查带插值的精确键，避免 `%@`、`%lld` 等类型错配。检查失败时会列出缺失项，不会静默跳过。

新增普通文本：在词典中加入 `"English text": "中文译文"`，然后运行同步与检查。新增插值文本：根据编译器输出的完整键补充词典，原样保留占位符。动态生成的控件标签、枚举值或 AppKit 菜单需要在显示位置明确接入本地化；检查工具不能替代实际界面验收。

原始英文保留作默认回退。文案未翻译不会影响业务标识。文件右键菜单使用原始英文操作标识执行动作，再把显示标题翻译为中文，避免翻译后失效。

## 编译、安装和运行

需要完整 Xcode 26 或更新版本，并完成首次启动。脚本优先使用 `/Applications/Xcode.app`，不修改全局开发工具设置；也可通过 `DEVELOPER_DIR` 指定其他 Xcode。

```bash
tools/build-local.sh
tools/install-local.sh
```

脚本使用上游锁定的依赖版本，以 Release 配置构建。产物在 `build/DerivedData/Build/Products/Release/InkNotch.app`。安装到 `/Applications/InkNotch.app`，仅将此应用的语言设为简体中文，然后启动。已有安装会备份到 `build/backups/`。重新安装前请退出正在运行的墨岛 · InkNotch。

本机构建使用无需开发者账号的临时签名，保留应用沙盒权限。由于没有 Apple Developer 签名证书，本地开发构建不启用 Hardened Runtime；这不会关闭 macOS 的 SIP 或 Gatekeeper。脚本还会重新签署随项目提供的 MediaRemoteAdapter，并再次验证整个 App。面向其他用户分发时应使用 Apple Developer 正式签名和公证。

## 同步新版

先确保本地工作已提交，再执行：

```bash
tools/update-local.sh
```

脚本获取上游标签，合并最新正式版（排除 alpha、beta、rc 和 nightly），重新应用本地词典，并检查新增文案。也可以显式指定上游引用，例如 `tools/update-local.sh origin/main`。

若上游改动与本地修改冲突，Git 会保留冲突供人工处理，不会强制覆盖。解决冲突或补齐新增译文后：

```bash
python3 tools/localize.py sync
python3 tools/localize.py check
git add .
git commit -m "Update local Chinese translations for upstream release"
tools/build-local.sh
tools/install-local.sh
```

本地汉化版不启动 Sparkle 自动更新，菜单提供“查看上游新版本”入口。这样官方二进制不会覆盖本地汉化。翻译词典、显示层修补和构建脚本均保存在本地 Git 历史中，便于合并、比较和回滚。

## 回滚

退出应用后，可以用 `build/backups/` 中的旧版本恢复 `/Applications/InkNotch.app`；用户原有偏好设置保留。源码修改由 Git 管理，可切换分支检查上游代码。不要在存在未提交修改时执行强制重置。

原项目仍遵循仓库中的 GPL-3.0 许可证；本地修改沿用该许可。

## 快捷应用栏

在“设置 → 快捷应用”中启用或关闭底栏，并通过“添加应用…”多选常用应用。箭头调整顺序，减号仅移除快捷方式。灵动岛底部的加号可直接打开管理页；应用较多时横向滚动，点击图标启动后会收起灵动岛。

应用列表、顺序和显示开关保存在用户偏好设置中，升级或重启后保留。代码不写死用户的应用列表。重新选择同一个应用会刷新路径和访问书签，不会重复添加；已移动的应用优先通过保存的书签或应用标识定位。文件选择器仅授予选中应用的只读访问，不要求访问整个磁盘。

此功能位于 `boringNotch/QuickApps/`，模型、应用管理、底栏、设置页各自独立。该目录使用 Xcode 同步分组，新增源文件会自动参与编译。接入现有工程的改动仅涉及设置导航、内容底栏和展开尺寸；关闭后恢复原高度。新文案仍统一放在 `localization/zh-Hans.json`。

`tools/test-quick-apps.sh` 验证重复添加、应用移动后刷新、排序边界和持久化，已接入常规构建流程。修改快捷应用功能后，还需实际检查选择应用、开关、图标启动及重启后的列表。

## 实时充电功率与整机功耗

电池旁默认显示功率，可以在“设置 → 电池 → 在电池旁显示功率”中关闭。正在充电时显示实际进入电池的瓦数；未充电、充电暂停或仅使用电池时，显示整机功耗。点击电池，或打开电池设置，可同时查看电池充电功率、整机功耗和适配器输入。适配器标称的 100W 等额定值不会用于实时读数。

界面显示时约每 2 秒读取一次；关闭相关界面后停止轮询。优先读取 SMC 的 `PSTR`（整机）、`PDTR`（适配器）、`B0AC`/`B0AV`（电池电流、电压）。这些传感器随机型和系统版本有所不同，不保证所有 Mac 都具备。不可用时依次使用电池电流/电压、系统遥测或输入输出差值；电池放电及差值推算的整机功耗显示 `≈`，系统遥测会注明更新较慢。无有效数据时显示 `—`，不伪造数值。

采样和换算位于 `Shared/PowerTelemetry/`，界面和偏好设置位于 `boringNotch/PowerTelemetry/`。读取通过现有的普通 XPC 服务完成，不需要管理员权限，不控制充电或电源设置。SMC 读取代码改编自 [PowerFlow](https://github.com/dylansantwani/powerflow)，沿用 MIT 许可；完整许可保存在源码及 App 资源中的 `PowerFlow-MIT.txt`。上游升级后，保留共享采样目录、两个 XPC 协议中的读取方法及界面接入点，新增文案仍放入统一译文词典。

`tools/test-power.sh` 验证三种电源状态、符号电流、单位换算、降级标识、无效数据及 XPC 数据；已接入常规构建。`tools/test-power.sh --probe` 额外读取本机三次数据，可验证传感器是否可用。充电切换和休眠唤醒还应在对应硬件状态下实际检查。

## 本地移除的交互

已移除整套手势控制：双指上下滑动展开/收起、灵敏度与开关、滚动事件监听，以及跟随手势的缩放/透明度动画。通用设置中不再显示该功能。仍可悬停或点击展开灵动岛，鼠标移出后收起；进度条拖动、文件拖放和日历滚动照常使用。

同步上游新版时，若重新引入 `PanGesture.swift`、`enableGestures`、`closeGestureEnabled`、`gestureSensitivity` 或手势设置，应在合并时继续移除。相关功能、编译引用和六条专用本地化文案已从源码中清理。

## 名称与图标

应用显示名称为“墨岛 · InkNotch”，安装文件为 `/Applications/InkNotch.app`，项目目录为 `/Users/bluemoe/code/public/InkNotch`。主 README 说明本地分支的来源与改动，原版 README 保存在 `docs/README.upstream.md`。

应用图标由 `tools/render-app-icon.swift` 中的矢量绘制生成，运行 `tools/regenerate-icon.sh` 可同时更新所有 macOS 图标尺寸、引导页图标和 `branding/` 中的预览。不要逐张修改导出的 PNG。

为继承原有偏好设置、应用访问书签和数据，本地版暂沿用原 bundle identifier、XPC 服务标识及内部源文件/工程名称。安装脚本将旧的本地 Boring Notch.app 备份并替换为 InkNotch.app；此版本不支持与官方版同时运行。将来若需要独立分发，应另行规划新标识和数据迁移，并按所选身份重新申请系统权限。
