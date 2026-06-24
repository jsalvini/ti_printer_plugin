class KnownUsbPrinter {
  final int vid;
  final int pid;
  final String displayName;
  final String protocol;
  final bool exactModel;

  const KnownUsbPrinter({
    required this.vid,
    required this.pid,
    required this.displayName,
    this.protocol = 'escpos',
    this.exactModel = true,
  });

  bool matches(int queryVid, int queryPid) => vid == queryVid && pid == queryPid;
}

const knownThermalUsbPrinters = <KnownUsbPrinter>[
  KnownUsbPrinter(vid: 0x04B8, pid: 0x0202, displayName: 'EPSON TM Series / TM-T88 / TM-T70', exactModel: false),
  KnownUsbPrinter(vid: 0x04B8, pid: 0x0201, displayName: 'EPSON TM/BA/EU USB Controller', exactModel: false),
  KnownUsbPrinter(vid: 0x04B8, pid: 0x0205, displayName: 'EPSON TM/BA/EU USB Controller', exactModel: false),
  KnownUsbPrinter(vid: 0x04B8, pid: 0x0E03, displayName: 'EPSON TM-T20'),
  KnownUsbPrinter(vid: 0x04B8, pid: 0x0E20, displayName: 'EPSON TM-m30'),

  KnownUsbPrinter(vid: 0x0519, pid: 0x0003, displayName: 'Star TSP100ECO / TSP100II', protocol: 'escpos/starprnt'),

  KnownUsbPrinter(vid: 0x1504, pid: 0x001F, displayName: 'Bixolon SRP-350II'),

  KnownUsbPrinter(vid: 0x1D90, pid: 0x20F0, displayName: 'Citizen CT-E351'),
  KnownUsbPrinter(vid: 0x1D90, pid: 0x201E, displayName: 'Citizen PPU-700'),

  KnownUsbPrinter(vid: 0x04B8, pid: 0x0203, displayName: 'Rongta RP Series / USB Controller', exactModel: false),

  KnownUsbPrinter(vid: 0x0416, pid: 0x5011, displayName: 'POS58 / Zjiang / GD32 USB Printer', exactModel: false),
  KnownUsbPrinter(vid: 0x09C5, pid: 0x588E, displayName: 'HaoYin CX588 / POS58 Portable', exactModel: false),
  KnownUsbPrinter(vid: 0x6868, pid: 0x0200, displayName: 'Generic Chinese POS58/POS80', exactModel: false),
  KnownUsbPrinter(vid: 0x28E9, pid: 0x0289, displayName: 'Generic Chinese POS58/POS80', exactModel: false),

  KnownUsbPrinter(vid: 0x0471, pid: 0x0055, displayName: 'Gprinter USB Printer', protocol: 'escpos/tspl', exactModel: false),
  KnownUsbPrinter(vid: 0x1CBE, pid: 0x0002, displayName: 'Gprinter Virtual Serial Port', exactModel: false),

  KnownUsbPrinter(vid: 0x0A5F, pid: 0x0009, displayName: 'Zebra LP2844', protocol: 'zpl/epl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x0027, displayName: 'Zebra LP2844-Z', protocol: 'zpl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x0062, displayName: 'Zebra GK420d', protocol: 'zpl/epl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x0080, displayName: 'Zebra GK420d', protocol: 'zpl/epl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x0081, displayName: 'Zebra GK420t', protocol: 'zpl/epl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x0084, displayName: 'Zebra GX420d', protocol: 'zpl/epl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x008C, displayName: 'Zebra ZP 450', protocol: 'zpl/epl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x00D1, displayName: 'Zebra GC420d', protocol: 'zpl/epl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x0110, displayName: 'Zebra ZD500', protocol: 'zpl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x011C, displayName: 'Zebra ZD410', protocol: 'zpl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x0141, displayName: 'Zebra ZD620', protocol: 'zpl'),
  KnownUsbPrinter(vid: 0x0A5F, pid: 0x0172, displayName: 'Zebra ZT411', protocol: 'zpl'),

  KnownUsbPrinter(vid: 0x1203, pid: 0x0140, displayName: 'TSC TTP-245C', protocol: 'tspl'),

  KnownUsbPrinter(vid: 0x0922, pid: 0x0020, displayName: 'DYMO LabelWriter 450', protocol: 'dymo'),
  KnownUsbPrinter(vid: 0x0922, pid: 0x0028, displayName: 'DYMO LabelWriter 550', protocol: 'dymo'),
];

KnownUsbPrinter? lookupPrinterInfo(int vid, int pid) {
  for (final p in knownThermalUsbPrinters) {
    if (p.matches(vid, pid)) return p;
  }
  return null;
}
