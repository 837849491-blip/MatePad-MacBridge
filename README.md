# MatePad MacBridge

把华为 MatePad 通过 USB Debug 变成 Mac 的免费副屏，并补上触控控制和豆包语音入口。

这个项目是在免费开源的 [SideScreen](https://github.com/tranvuongquocdat/SideScreen) 基础上做的桥接方案：

- SideScreen 负责把 Mac 桌面串流到 MatePad。
- `MatePadControl` 负责把 MatePad 上的触摸映射成 Mac 鼠标事件。
- MatePad 端 SideScreen 增加一个“豆包语音”按钮，用 USB reverse 调用 Mac 上的豆包输入法语音快捷键。

## 功能

- USB 有线副屏，实测 1920x1200、约 37-39 FPS、RTT 约 3ms。
- MatePad 屏幕触摸可直接控制 Mac 副屏坐标。
- MatePad 左下角“豆包语音”按钮可触发 Mac 上豆包输入法的语音输入。
- Mac 控制桥以 `/Applications/MatePadControl.app` 运行，并通过 LaunchAgent 开机自启。
- 所有通信只走本机和 ADB reverse：`127.0.0.1:18765`、`tcp:54321`。

## 仓库结构

```text
src/matepad_control.c                         Mac 控制桥服务
macos/Info.plist                              MatePadControl.app 信息模板
launchd/com.ai-book.matepad-control.plist     LaunchAgent 示例
scripts/start-matepad-workspace.sh            一键恢复 USB reverse 和 SideScreen
scripts/install-mac-bridge.sh                 构建并安装 Mac 控制桥
patches/*.patch                               SideScreen Android 客户端补丁
docs/PROJECT_SUMMARY.md                       项目总结和验证记录
```

## 安装思路

1. 在 Mac 上安装 SideScreen。
2. 在 MatePad 上安装打过补丁的 SideScreen Android 客户端。
3. 在 Mac 上构建并安装 `MatePadControl.app`。
4. 在 macOS 设置里给 `MatePadControl` 和 `SideScreen` 开启“辅助功能”权限。
5. 通过 ADB 建立端口映射：

```bash
adb reverse tcp:54321 tcp:54321
adb reverse tcp:18765 tcp:18765
```

## Mac 控制桥

构建并安装：

```bash
./scripts/install-mac-bridge.sh
```

检查服务：

```bash
curl http://127.0.0.1:18765/health
```

期望看到：

```json
{"ok":true,"axTrusted":true,"port":18765}
```

常用接口：

- `GET /health`：状态检查
- `GET /touch?x=0.5&y=0.5&type=1`：把触摸映射到副屏坐标
- `GET /voice`：双击右 Option，触发豆包输入法语音
- `GET /move?dx=80&dy=30`：触控板式相对移动
- `GET /click`：左键点击
- `GET /rightclick`：右键点击

## SideScreen Android 补丁

补丁位于 `patches/`：

- `activity_main.xml.patch`：增加“豆包语音”按钮。
- `MainActivity.kt.patch`：连接后显示按钮；触摸 SurfaceView 时同步调用 Mac 控制桥 `/touch`；点击按钮时调用 `/voice`。

基于 SideScreen `v0.9.1`：

```bash
curl -L -o SideScreen-src.zip https://github.com/tranvuongquocdat/SideScreen/archive/refs/tags/0.9.1.zip
unzip SideScreen-src.zip
cd SideScreen-0.9.1
patch -p1 < /path/to/patches/activity_main.xml.patch
patch -p1 < /path/to/patches/MainActivity.kt.patch
cd AndroidClient
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

如果遇到签名不一致：

```bash
adb uninstall com.sidescreen.app
adb install app/build/outputs/apk/debug/app-debug.apk
```

## 一键恢复

日常断线后运行：

```bash
./scripts/start-matepad-workspace.sh
```

然后在 MatePad 的 SideScreen 里点 `CONNECT`。

## 依赖

- macOS
- Huawei MatePad，开启 USB Debug
- `adb`
- `clang`
- SideScreen Mac Host
- 豆包输入法，且语音快捷键配置为双击右 Option

## 授权与归属

本仓库代码使用 MIT License。

SideScreen 是第三方 MIT License 项目，本仓库只提供桥接代码和补丁；SideScreen 原项目版权归其作者所有。
