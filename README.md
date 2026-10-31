<p align="center">
  <img src="branding/InkNotch.png" alt="墨岛 · InkNotch 图标" width="144">
</p>

<h1 align="center">墨岛 · InkNotch</h1>

<p align="center">为个人使用定制的 macOS 灵动岛本地修改版</p>

## 项目来源与关系说明

**墨岛 · InkNotch 是基于 [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch) 的本地修改版，当前以 Boring Notch 正式版 v2.7.3 为基础。**

原项目及原有功能由 TheBoredTeam 和上游贡献者开发。本地版本使用独立的显示名称和重新绘制的图标，便于识别；它与原项目团队没有官方关联，也不是上游官方发行版。更名不改变原代码的作者、版权或许可证归属。

原版 README 保存在 [docs/README.upstream.md](docs/README.upstream.md)，其中的下载链接、构建徽章、更新计划及社群信息属于上游项目。本地版本的编译、安装和维护以本文件及 [本地维护说明](localization/README.zh-CN.md) 为准。

## 本地修改

本地修改日期：2026 年 10 月 28 日。

- **简体中文界面**：设置、菜单、引导页及权限说明统一汉化；译文词典与上游英文键分开维护，便于升级时补齐新文案。
- **快捷应用栏**：可添加常用应用、调整顺序或移除快捷方式；重启后保留列表。
- **实时功率显示**：充电时显示进入电池的功率；未充电或暂停充电时显示整机功耗。详情同时列出适配器输入。可见时约每 2 秒刷新，估算读数标记 `≈`，缺失数据显示 `—`。传感器支持随机型及系统版本而变化。
- **移除手势控制**：已删除上下滑动展开/收起、灵敏度、事件监听和相关动画；仍可悬停或点击展开、移出鼠标收起，媒体滑块和文件拖放照常使用。
- **名称与图标**：更名为“墨岛 · InkNotch”，使用独立的黑色灵动岛与蓝色光点图标。图标由仓库内的矢量绘制程序生成。
- **本地更新方式**：关闭上游二进制自动更新，避免覆盖汉化和本地功能；通过合并上游源码更新。

## 编译、安装与运行

本地项目目录：`/Users/bluemoe/code/public/InkNotch`。需要完整 Xcode 26 或更新版本，并完成首次启动设置。当前本机已在 Apple silicon Mac 上验证；传感器在其他机型上的可用性需要实际检查。

```bash
cd /Users/bluemoe/code/public/InkNotch
tools/build-local.sh
tools/install-local.sh
```

编译产物为 `build/DerivedData/Build/Products/Release/InkNotch.app`，安装到 `/Applications/InkNotch.app`。安装前请退出正在运行的旧版本。安装脚本会将此前的本地 Boring Notch.app 或 InkNotch.app 备份至 `build/backups/`，再安装并启动新版本。

此本地版本沿用原应用的 bundle identifier、XPC 服务标识、偏好设置与数据位置，以保留已有设置、应用书签和使用数据；内部源码目录、工程名及英文翻译键也继续沿用上游命名，以减少升级冲突。**请勿同时运行墨岛与官方 Boring Notch。** 独立分发所需的标识迁移、正式签名和公证尚未配置。

本机构建使用临时签名并保留应用沙盒权限，不启用 Hardened Runtime。它面向本机开发使用；这不会修改 macOS 的 SIP 或 Gatekeeper 设置。

## 更新与图标维护

在本地工作全部提交后，通过以下命令合并上游正式版，并检查新增译文：

```bash
tools/update-local.sh
```

解决可能的合并冲突、补齐译文后，重新编译和安装。维护细节见 [localization/README.zh-CN.md](localization/README.zh-CN.md)。

图标的绘制源为 `tools/render-app-icon.swift`，修改后执行：

```bash
tools/regenerate-icon.sh
```

脚本会生成全部 macOS 图标尺寸、引导页图标及 `branding/` 下的预览，无需逐张维护 PNG。

## 验证

常规构建包含简体中文覆盖与占位符校验、快捷应用模型测试、功率换算与状态切换测试。实时硬件数据、系统权限及界面交互仍需在对应 Mac 上检查。

## 许可证与致谢

本项目继续遵循原项目的 [GPL-3.0 许可证](LICENSE)，保留上游版权与署名；本地修改沿用该许可。本地更名和新图标不表示原项目的开发成果归本地维护者所有。

SMC 读取部分改编自 [PowerFlow](https://github.com/dylansantwani/powerflow)，沿用 MIT 许可。完整声明见 [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES) 及 [PowerFlow-MIT.txt](boringNotch/PowerTelemetry/PowerFlow-MIT.txt)。

感谢 Boring Notch、PowerFlow 及原项目所使用依赖的作者与贡献者。
