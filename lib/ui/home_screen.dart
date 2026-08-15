import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bthome/bthome_models.dart';
import '../scanner/ble_discovery_source.dart';
import '../scanner/scanner_controller.dart';
import 'app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _SeaBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 900;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        desktop ? 28 : 14,
                        14,
                        desktop ? 28 : 14,
                        14,
                      ),
                      child: Column(
                        children: [
                          _TopBar(controller: controller),
                          const SizedBox(height: 14),
                          _HeroPanel(controller: controller, compact: !desktop),
                          if (controller.error != null) ...[
                            const SizedBox(height: 10),
                            _ErrorBanner(controller: controller),
                          ],
                          const SizedBox(height: 14),
                          Expanded(
                            child: desktop
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        width: 430,
                                        child: _DeviceBrowser(
                                          controller: controller,
                                          onOpen: controller.selectDevice,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _DeviceDetail(
                                          device: controller.selectedDevice,
                                        ),
                                      ),
                                    ],
                                  )
                                : _DeviceBrowser(
                                    controller: controller,
                                    onOpen: (id) =>
                                        _openMobileDetail(context, id),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  void _openMobileDetail(BuildContext context, String id) {
    controller.selectDevice(id);
    final device = controller.selectedDevice;
    if (device == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, scrollController) => DecoratedBox(
          decoration: const BoxDecoration(
            color: SeaColors.sky,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: SeaColors.ocean.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: _DeviceDetail(
                  device: device,
                  scrollController: scrollController,
                  embedded: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [SeaColors.cyan, SeaColors.ocean],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: SeaColors.ocean.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.waves_rounded, color: Colors.white),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BTHome Coast',
              style: TextStyle(
                color: SeaColors.deep,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'BLE 广播调试台 · BTHome v2',
              style: TextStyle(color: SeaColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      _AdapterBadge(status: controller.status),
    ],
  );
}

class _AdapterBadge extends StatelessWidget {
  const _AdapterBadge({required this.status});
  final BleAdapterStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BleAdapterStatus.poweredOn => ('蓝牙就绪', const Color(0xff138a75)),
      BleAdapterStatus.poweredOff => ('蓝牙关闭', SeaColors.coral),
      BleAdapterStatus.unauthorized => ('等待授权', const Color(0xffb47718)),
      BleAdapterStatus.unsupported => ('不支持 BLE', SeaColors.coral),
      BleAdapterStatus.unknown => ('正在检查', SeaColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.controller, required this.compact});
  final ScannerController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    height: compact ? 142 : 168,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff087fa8), Color(0xff16a9cf), Color(0xff83d9e9)],
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: SeaColors.ocean.withValues(alpha: 0.2),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _WavePainter())),
        Positioned(
          left: compact ? 20 : 28,
          top: compact ? 19 : 25,
          right: compact ? 16 : 28,
          bottom: compact ? 16 : 22,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.isScanning ? '正在聆听附近广播' : '准备发现 BTHome 设备',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 21 : 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.isScanning
                          ? '持续接收 0xFCD2 Service Data，实时更新告警与测量值'
                          : '点击开始扫描；Android 首次运行会请求附近设备权限',
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: compact ? 12 : 13,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _HeroStat(
                          value: '${controller.totalCount}',
                          label: '设备',
                        ),
                        const SizedBox(width: 22),
                        _HeroStat(
                          value: '${controller.alarmCount}',
                          label: '警报',
                        ),
                        const SizedBox(width: 22),
                        _HeroStat(
                          value: '${controller.encryptedCount}',
                          label: '加密',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const Key('scan-button'),
                onPressed: controller.isBusy ? null : controller.toggleScanning,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: SeaColors.ocean,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.75),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 14 : 20,
                    vertical: compact ? 13 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                icon: controller.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.3),
                      )
                    : Icon(
                        controller.isScanning
                            ? Icons.stop_rounded
                            : Icons.radar_rounded,
                      ),
                label: Text(controller.isScanning ? '停止' : '扫描'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 5),
      Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 11,
          ),
        ),
      ),
    ],
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.controller});
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    decoration: BoxDecoration(
      color: const Color(0xfffff3f1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SeaColors.coral.withValues(alpha: 0.22)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: SeaColors.coral,
          size: 19,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            controller.error!,
            style: const TextStyle(color: Color(0xff8f3f38), fontSize: 13),
          ),
        ),
        IconButton(
          onPressed: controller.dismissError,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ],
    ),
  );
}

class _DeviceBrowser extends StatelessWidget {
  const _DeviceBrowser({required this.controller, required this.onOpen});
  final ScannerController controller;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '附近设备',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: SeaColors.deep,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: controller.totalCount == 0
                    ? null
                    : controller.clearDevices,
                icon: const Icon(Icons.cleaning_services_outlined, size: 17),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: controller.setQuery,
            decoration: const InputDecoration(
              hintText: '搜索名称或地址',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: '全部 ${controller.totalCount}',
                  value: DeviceFilter.all,
                  controller: controller,
                ),
                const SizedBox(width: 7),
                _FilterChip(
                  label: '警报 ${controller.alarmCount}',
                  value: DeviceFilter.alarms,
                  controller: controller,
                ),
                const SizedBox(width: 7),
                _FilterChip(
                  label: '加密 ${controller.encryptedCount}',
                  value: DeviceFilter.encrypted,
                  controller: controller,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: controller.devices.isEmpty
                ? _EmptyDevices(scanning: controller.isScanning)
                : ListView.separated(
                    itemCount: controller.devices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final device = controller.devices[index];
                      return _DeviceTile(
                        device: device,
                        selected:
                            device.deviceId == controller.selectedDeviceId,
                        onTap: () => onOpen(device.deviceId),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.controller,
  });
  final String label;
  final DeviceFilter value;
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: controller.filter == value,
    onSelected: (_) => controller.setFilter(value),
    showCheckmark: false,
    labelStyle: TextStyle(
      color: controller.filter == value ? Colors.white : SeaColors.muted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    selectedColor: SeaColors.ocean,
    backgroundColor: SeaColors.foam,
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
  );
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({required this.scanning});
  final bool scanning;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.88, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: SeaColors.foam,
                shape: BoxShape.circle,
              ),
              child: Icon(
                scanning
                    ? Icons.radar_rounded
                    : Icons.bluetooth_searching_rounded,
                color: SeaColors.ocean,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            scanning ? '正在等待第一帧浪花' : '还没有发现设备',
            style: const TextStyle(
              color: SeaColors.deep,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scanning ? '确保设备正在广播 BTHome v2 数据' : '开始扫描后，这里只显示含 0xFCD2 的广播',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SeaColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.selected,
    required this.onTap,
  });
  final BthomeDeviceSnapshot device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final alarm = device.packet.hasActiveAlarm;
    final encrypted = device.packet.deviceInfo.encrypted;
    return Material(
      color: selected ? const Color(0xffe5f6fb) : const Color(0xfff7fbfd),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? SeaColors.cyan.withValues(alpha: 0.5)
                  : SeaColors.ocean.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: alarm
                      ? const Color(0xffffebe8)
                      : const Color(0xffddf5fa),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  alarm
                      ? Icons.warning_amber_rounded
                      : encrypted
                      ? Icons.lock_outline_rounded
                      : Icons.sensors_rounded,
                  color: alarm ? SeaColors.coral : SeaColors.ocean,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SeaColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      device.deviceId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SeaColors.muted,
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (alarm)
                          const _TinyTag(label: '警报', color: SeaColors.coral),
                        if (encrypted)
                          const _TinyTag(label: '加密', color: Color(0xff8b67c8)),
                        if (!alarm && !encrypted)
                          const _TinyTag(label: '正常', color: Color(0xff148976)),
                        const Spacer(),
                        _SignalBars(rssi: device.rssi),
                        const SizedBox(width: 5),
                        Text(
                          '${device.rssi} dBm',
                          style: const TextStyle(
                            color: SeaColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 5),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.rssi});
  final int rssi;

  @override
  Widget build(BuildContext context) {
    final level = rssi >= -55
        ? 4
        : rssi >= -67
        ? 3
        : rssi >= -80
        ? 2
        : 1;
    return SizedBox(
      width: 18,
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          4,
          (index) => Container(
            width: 3,
            height: 4.0 + index * 3,
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(
              color: index < level
                  ? SeaColors.ocean
                  : SeaColors.ocean.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceDetail extends StatelessWidget {
  const _DeviceDetail({
    required this.device,
    this.scrollController,
    this.embedded = false,
  });
  final BthomeDeviceSnapshot? device;
  final ScrollController? scrollController;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final current = device;
    if (current == null) {
      return Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.water_drop_outlined,
                size: 42,
                color: SeaColors.ocean.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              const Text(
                '选择一台设备查看广播详情',
                style: TextStyle(color: SeaColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final packet = current.packet;
    return Card(
      color: embedded ? Colors.transparent : null,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: packet.hasActiveAlarm
                      ? const LinearGradient(
                          colors: [SeaColors.coral, Color(0xffff9a76)],
                        )
                      : const LinearGradient(
                          colors: [SeaColors.cyan, SeaColors.ocean],
                        ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  packet.hasActiveAlarm
                      ? Icons.warning_amber_rounded
                      : Icons.bluetooth_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      current.deviceId,
                      style: const TextStyle(
                        color: SeaColors.muted,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _RssiPill(rssi: current.rssi),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.memory_rounded,
                label: 'BTHome v${packet.deviceInfo.version}',
              ),
              _InfoPill(
                icon: packet.deviceInfo.encrypted
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                label: packet.deviceInfo.encrypted ? '已加密' : '明文',
              ),
              _InfoPill(
                icon: Icons.bolt_rounded,
                label: packet.deviceInfo.triggerBased ? '触发式广播' : '周期广播',
              ),
              _InfoPill(
                icon: Icons.repeat_rounded,
                label: '接收 ${current.seenCount} 帧',
              ),
              _InfoPill(
                icon: Icons.schedule_rounded,
                label: _formatAge(current.lastSeen),
              ),
            ],
          ),
          if (packet.issue != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xfffff7e6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xffb47718),
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      packet.issue!,
                      style: const TextStyle(
                        color: Color(0xff76531f),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const _SectionTitle(
            title: '测量与事件',
            subtitle: '按 BTHome Object ID 顺序解析',
          ),
          const SizedBox(height: 11),
          if (packet.measurements.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: SeaColors.foam.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                packet.deviceInfo.encrypted
                    ? '加密帧未配置密钥，测量值不会显示。'
                    : '该帧没有可解析的测量对象。',
                style: const TextStyle(color: SeaColors.muted),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 680
                    ? 3
                    : constraints.maxWidth > 420
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 9) / columns;
                return Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: packet.measurements
                      .map(
                        (measurement) => SizedBox(
                          width: width,
                          child: _MeasurementCard(measurement: measurement),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  title: '原始 Service Data',
                  subtitle: 'UUID 0xFCD2 · 十六进制',
                ),
              ),
              IconButton(
                tooltip: '复制十六进制',
                onPressed: () => _copyRaw(context, packet.raw),
                icon: const Icon(Icons.copy_rounded, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: SeaColors.deep,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: SeaColors.deep.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: SelectableText(
              bytesToHex(packet.raw),
              style: const TextStyle(
                color: Color(0xffbdeeff),
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.6,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (packet.remaining.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              '未解析尾部：${bytesToHex(packet.remaining)}',
              style: const TextStyle(
                color: SeaColors.coral,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAge(DateTime lastSeen) {
    final seconds = math.max(0, DateTime.now().difference(lastSeen).inSeconds);
    if (seconds < 2) return '刚刚收到';
    if (seconds < 60) return '$seconds 秒前';
    return '${seconds ~/ 60} 分钟前';
  }

  Future<void> _copyRaw(BuildContext context, Uint8List data) async {
    await Clipboard.setData(ClipboardData(text: bytesToHex(data)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('原始 Service Data 已复制')));
  }
}

class _RssiPill extends StatelessWidget {
  const _RssiPill({required this.rssi});
  final int rssi;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: SeaColors.foam,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$rssi dBm',
      style: const TextStyle(
        color: SeaColors.ocean,
        fontWeight: FontWeight.w800,
        fontSize: 11,
      ),
    ),
  );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xfff2f9fc),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: SeaColors.ocean),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: SeaColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: SeaColors.deep,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(color: SeaColors.muted, fontSize: 10.5),
      ),
    ],
  );
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({required this.measurement});
  final BthomeMeasurement measurement;

  @override
  Widget build(BuildContext context) {
    final activeAlarm =
        measurement.isAlarm && measurement.value == measurement.alarmWhenValue;
    final color = activeAlarm ? SeaColors.coral : _colorFor(measurement.key);
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: activeAlarm ? const Color(0xfffff0ed) : const Color(0xfff5fbfd),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: color.withValues(alpha: activeAlarm ? 0.25 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(measurement.key), color: color, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  measurement.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SeaColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                measurement.objectIdHex,
                style: TextStyle(
                  color: SeaColors.muted.withValues(alpha: 0.75),
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: measurement.displayValue,
                  style: TextStyle(
                    color: activeAlarm ? SeaColors.coral : SeaColors.deep,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (measurement.unit.isNotEmpty)
                  TextSpan(
                    text: '  ${measurement.unit}',
                    style: const TextStyle(
                      color: SeaColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String key) {
    if (key.contains('temperature') || key == 'heat' || key == 'cold') {
      return Icons.thermostat_rounded;
    }
    if (key.contains('humidity') ||
        key.contains('moisture') ||
        key == 'water') {
      return Icons.water_drop_rounded;
    }
    if (key.contains('battery')) return Icons.battery_5_bar_rounded;
    if (key.contains('power') ||
        key.contains('energy') ||
        key.contains('voltage') ||
        key.contains('current')) {
      return Icons.bolt_rounded;
    }
    if (key.contains('light') || key == 'illuminance') {
      return Icons.light_mode_rounded;
    }
    if (key.contains('event') || key == 'command') {
      return Icons.touch_app_rounded;
    }
    if (key.contains('time')) return Icons.schedule_rounded;
    if (key.contains('pressure')) return Icons.speed_rounded;
    if (key.contains('motion') ||
        key.contains('speed') ||
        key.contains('acceleration')) {
      return Icons.directions_run_rounded;
    }
    if (measurement.kind == BthomeValueKind.binary) {
      return Icons.toggle_on_rounded;
    }
    return Icons.data_object_rounded;
  }

  Color _colorFor(String key) {
    if (key == 'heat') return const Color(0xffee704f);
    if (key == 'cold') return const Color(0xff328fca);
    if (key.contains('battery')) return const Color(0xff34a176);
    if (key.contains('light')) return const Color(0xffd99b26);
    return SeaColors.ocean;
  }
}

class _SeaBackground extends StatelessWidget {
  const _SeaBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xfff7fcfe), Color(0xffeaf8fc), Color(0xfff8fcfd)],
      ),
    ),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.52,
        size.width * 0.36,
        size.height * 0.92,
        size.width * 0.58,
        size.height * 0.7,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.5,
        size.width * 0.88,
        size.height * 0.78,
        size.width,
        size.height * 0.61,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.08),
      size.height * 0.7,
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
