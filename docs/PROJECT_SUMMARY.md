# 项目总结：MatePad MacBridge

## 项目目标

把华为 MatePad 通过 USB Debug 变成 MacBook 的长期免费副屏，并进一步支持：

- 在 MatePad 上触控操作 Mac 副屏。
- 在 MatePad 上一键触发 Mac 上的豆包语音输入。
- 断线后可以快速恢复。

## 最终方案

采用 SideScreen 作为免费副屏底座，再补一个本地控制桥：

```text
MatePad SideScreen
  -> 视频流：ADB reverse tcp:54321 -> SideScreen Mac Host
  -> 触控/语音：ADB reverse tcp:18765 -> MatePadControl.app
```

## 做过的关键工作

1. 安装并验证 SideScreen Mac Host 和 Android Client。
2. 通过 ADB reverse 建立 USB 本地端口映射。
3. 确认 SideScreen 视频副屏可用，分辨率为 1920x1200。
4. 发现原生触控在当前 MatePad/HarmonyOS 环境下不稳定。
5. 编写 `MatePadControl` Mac 本地 HTTP 控制桥：
   - `/touch`：归一化触点映射到 SideScreen 副屏坐标。
   - `/voice`：双击右 Option，触发豆包输入法语音。
   - `/move`、`/click`、`/rightclick`、`/scroll`：触控板兜底控制。
6. 把控制桥包装成 `/Applications/MatePadControl.app`，解决 macOS 辅助功能授权绑定问题。
7. 配置 LaunchAgent 开机自启。
8. 修改 SideScreen Android 客户端：
   - 左下角增加“豆包语音”按钮。
   - 连接成功后显示按钮，断开时隐藏。
   - SurfaceView 触摸事件同步调用 Mac 控制桥 `/touch`。
9. 构建并安装定制 SideScreen APK 到 MatePad。

## 验证记录

最终验证结果：

- MatePad 在线：`FRU6R20105000511 device usb:1-1 product:MRX-W09`
- SideScreen 端口映射：`tcp:54321 -> tcp:54321`
- 控制桥端口映射：`tcp:18765 -> tcp:18765`
- 控制桥健康检查：

```json
{"ok":true,"axTrusted":true,"port":18765}
```

- SideScreen 画面实测：
  - 分辨率：1920x1200
  - FPS：约 37-39
  - RTT：约 3ms
- 触控验证：
  - 点击 MatePad 前，Mac 光标约为 `1138.7,444.6`
  - 点击 MatePad 画面后，Mac 光标变为 `3390.0,272.9`
  - 结论：MatePad 触摸已经成功映射到 Mac 副屏坐标。
- 语音验证：
  - MatePad 左下角“豆包语音”按钮存在。
  - `/voice` 接口返回 `ok`。
  - 豆包输入法语音快捷键通过 Mac 端双击右 Option 触发。

## 当前限制

- 需要 USB Debug 保持授权。
- ADB reverse 断线后需要重新执行恢复脚本。
- 豆包语音依赖 Mac 上豆包输入法的语音快捷键配置。
- SideScreen Android 补丁基于 `v0.9.1`，后续版本升级需要重新套 patch。

## 推荐名字

`MatePad MacBridge`

这个名字直接表达项目定位：MatePad 和 Mac 之间的副屏、触控、语音桥。
