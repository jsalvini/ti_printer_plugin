import 'database_printer.dart' show lookupPrinterInfo;

class PrinterDeviceInfo {
  final String instanceId;
  final String displayName;
  final int vid;
  final int pid;

  String get resolvedDisplayName {
    if (vid <= 0 && pid <= 0) return displayName;

    final known = lookupPrinterInfo(vid, pid);
    if (known != null) return known.displayName;

    final hexVid = '0x${vid.toRadixString(16).padLeft(4, '0')}';
    final hexPid = '0x${pid.toRadixString(16).padLeft(4, '0')}';
    return 'USB Printer ($hexVid:$hexPid)';
  }

  const PrinterDeviceInfo({
    required this.instanceId,
    required this.displayName,
    required this.vid,
    required this.pid,
  });

  factory PrinterDeviceInfo.fromMap(Map<String, dynamic> map) {
    return PrinterDeviceInfo(
      instanceId: map['instanceId'] as String,
      displayName: map['displayName'] as String,
      vid: map['vid'] as int,
      pid: map['pid'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'instanceId': instanceId,
        'displayName': displayName,
        'vid': vid,
        'pid': pid,
      };

  @override
  String toString() {
    final hexVid = vid > 0 ? '0x${vid.toRadixString(16).padLeft(4, '0')}' : 'N/A';
    final hexPid = pid > 0 ? '0x${pid.toRadixString(16).padLeft(4, '0')}' : 'N/A';
    return '$resolvedDisplayName ($hexVid:$hexPid)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterDeviceInfo &&
          runtimeType == other.runtimeType &&
          instanceId == other.instanceId;

  @override
  int get hashCode => instanceId.hashCode;
}
