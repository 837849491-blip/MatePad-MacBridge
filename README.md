# MatePad MacBridge

一条命令，把华为 MatePad + MacBook 配成免费的 USB 副屏，并补上触控和豆包语音入口。

## 一键安装

在 Mac 的终端里执行：

```bash
curl -fsSL https://raw.githubusercontent.com/837849491-blip/MatePad-MacBridge/main/install.sh | bash
```

安装器会自动完成：

- 下载并保存本项目到 `~/.matepad-macbridge/MatePad-MacBridge`
- 构建并安装 Mac 端触控桥 `MatePadControl.app`
- 安装或检查 `adb`
- 创建日常启动命令 `~/.matepad-macbridge/bin/matepad-macbridge-start`
- 打开 macOS 辅助功能权限设置页
- 在 MatePad 已连接并授权时，自动建立 USB 端口映射并启动 SideScreen

日常断线、重启或重新插线后，执行：

```bash
~/.matepad-macbridge/bin/matepad-macbridge-start
```

## 必须手动确认的两件事

这些权限 macOS / Android 不允许脚本替你点，必须本人确认：

- macOS 辅助功能权限：在 `系统设置 > 隐私与安全性 > 辅助功能` 中启用 `MatePadControl` 和 `SideScreen`
- MatePad USB 调试：MatePad 插上 Mac 后，解锁平板并允许 USB 调试授权

## MatePad 端 APK

默认安装命令不会强行编译 Android APK，因为这依赖 Android SDK、JDK、Gradle 和当前机器环境，普通用户第一次跑很容易卡住。

如果你已经准备好 Android 构建环境，可以尝试自动编译并安装打补丁的 SideScreen MatePad 客户端：

```bash
curl -fsSL https://raw.githubusercontent.com/837849491-blip/MatePad-MacBridge/main/install.sh | bash -s -- --with-android-build
```

如果遇到签名不一致，先卸载旧的 SideScreen Android 客户端，再重新安装生成的 APK：

```bash
adb uninstall com.sidescreen.app
adb install ~/.matepad-macbridge/build/SideScreen-0.9.1/AndroidClient/app/build/outputs/apk/debug/app-debug.apk
```

## 你需要准备什么

- 一台 MacBook
- 一台支持 USB 调试的华为 MatePad
- 一根稳定的数据线
- SideScreen Mac Host，放在 `/Applications/SideScreen.app`
- 豆包输入法，并把语音快捷键配置为双击右 Option

如果你的 Mac 没有 `adb`，安装器会在检测到 Homebrew 时自动执行：

```bash
brew install android-platform-tools
```

如果没有 Homebrew，请先安装 Homebrew 或自行安装 Android platform tools。

## 怎么验证成功

安装完成后检查 Mac 端触控桥：

```bash
curl http://127.0.0.1:18765/health
```

理想输出类似：

```json
{"ok":true,"axTrusted":true,"port":18765}
```

如果 `axTrusted` 是 `false`，说明还没有给 `MatePadControl` 开启 macOS 辅助功能权限。

## 这个项目做了什么

本项目基于开源项目 [SideScreen](https://github.com/tranvuongquocdat/SideScreen) 做桥接增强：

- SideScreen 负责把 Mac 桌面通过 USB 串流到 MatePad
- `MatePadControl` 把 MatePad 上的触摸事件映射为 Mac 鼠标事件
- MatePad 端补丁增加“豆包语音”按钮，通过 USB reverse 调用 Mac 上的豆包语音快捷键
- 所有通信只走本机和 ADB reverse：`127.0.0.1:18765`、`tcp:54321`

## 仓库结构

```text
install.sh                                   面向普通用户的一键安装入口
src/matepad_control.c                        Mac 控制桥服务
macos/Info.plist                             MatePadControl.app 信息模板
launchd/com.ai-book.matepad-control.plist    LaunchAgent 配置
scripts/install-mac-bridge.sh                构建并安装 Mac 控制桥
scripts/start-matepad-workspace.sh           恢复 ADB reverse 并启动工作区
patches/*.patch                              SideScreen Android 客户端补丁
docs/PROJECT_SUMMARY.md                      项目总结和验证记录
tests/smoke.sh                               安装入口冒烟测试
```

## 常用命令

```bash
# 查看安装器会做什么，不改系统
./install.sh --dry-run

# 只安装，不自动启动
./install.sh --no-start

# 日常启动
~/.matepad-macbridge/bin/matepad-macbridge-start

# 检查触控桥状态
curl http://127.0.0.1:18765/health
```

## 已知限制

- macOS 辅助功能权限必须手动开启，这是系统安全限制
- MatePad USB 调试授权必须手动确认，这是 Android 安全限制
- SideScreen Mac Host 仍需要你安装到 `/Applications/SideScreen.app`
- Android APK 自动构建依赖本机 Android 构建环境，失败时可以按 README 的手动命令排查

## 授权与归属

本仓库代码使用 MIT License。

SideScreen 是第三方 MIT License 项目，本仓库只提供桥接代码和补丁；SideScreen 原项目版权归其作者所有。
