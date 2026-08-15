# BTHome Coast

一个面向 Android 和 Windows 的 BTHome v2 BLE 广播调试器。应用只做被动扫描，不连接设备；界面会实时合并同一设备的广播并展示 RSSI、接收次数、Device Information、测量对象、告警状态和原始 Service Data。

## 功能

- 扫描 UUID `0xFCD2` 的 BTHome v2 Service Data
- Android 与 Windows 共用同一套扫描和解析逻辑
- 支持标准数值、二进制传感器、按键/命令/旋钮事件、文本、Raw、时间戳和设备信息对象
- 正确处理小端、有符号数、缩放因子以及同类对象重复出现
- 高温、低温及其他告警对象醒目标记
- 搜索设备，并按全部、警报和加密广播筛选
- 展示并一键复制原始十六进制 Service Data
- 自适应手机单栏和 Windows 列表/详情双栏布局
- 扫描时的多层海浪动画、平滑状态过渡与数值动效
- 扫描时自动播放极低音量的原创海浪环境声，可随时静音
- Android 自适应/单色图标和 Windows 多尺寸应用图标

## 加密广播

应用能识别 BTHome v2 加密标记并展示原始密文。当前版本不保存设备密钥，也不会在没有密钥时猜测或错误显示测量值。用于调试本项目 CH572 广播器时，请使用未加密 BTHome 广播。

## 运行环境

- Flutter 3.41.9 或兼容的稳定版本
- Dart 3.11 或更高版本
- Android 7.0（API 24）或更高版本，必须使用带 BLE 的真机
- Windows 10/11，电脑需要支持 Bluetooth Low Energy
- Visual Studio 的“使用 C++ 的桌面开发”工作负载（Windows 构建）

## 开发与构建

```powershell
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
flutter build windows --debug
```

海浪环境声只会在扫描期间播放，默认音量为 5.5%；点击扫描按钮旁的音量图标可立即静音或恢复。

Android 12 及更高版本首次扫描会请求“附近设备”权限；Android 11 及以下版本使用定位权限完成 BLE 扫描。应用声明 `neverForLocation`，不会请求或读取位置信息。

## 目录

- `lib/bthome/`：不依赖平台的 BTHome v2 数据模型和解析器
- `lib/audio/`：跨平台海浪环境声状态与播放控制
- `lib/scanner/`：BLE 平台适配与扫描状态管理
- `lib/ui/`：蓝白海岸主题和自适应界面
- `assets/`：原创图标母版、应用内图标和无缝环境声
- `tool/generate_assets.py`：重新生成平台图标与原创海浪声的资产脚本
- `test/`：协议、控制器和界面测试

协议实现依据 [BTHome v2 Format](https://bthome.io/format/)。BLE 扫描使用 MIT 许可的 [`bluetooth_low_energy`](https://pub.dev/packages/bluetooth_low_energy)，环境声播放使用 MIT 许可的 [`audioplayers`](https://pub.dev/packages/audioplayers)。
