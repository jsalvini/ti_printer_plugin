import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ti_printer_plugin/esc_pos_utils_platform/esc_pos_utils_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assetChannel = 'flutter/assets';
  const capabilitiesAssetKey =
      'packages/ti_printer_plugin/assets/resources/capabilities.json';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(assetChannel, (ByteData? message) async {
      final key = const StringCodec().decodeMessage(message);
      if (key != capabilitiesAssetKey) {
        return null;
      }

      final payload = utf8.encode(
        json.encode({
          'profiles': {
            'default': {
              'codePages': {'0': 'CP437', '16': 'CP1252'},
              'vendor': 'Generic',
              'model': 'Default',
              'description': 'Default ESC/POS profile',
            },
            'custom': {
              'codePages': {'2': 'CP850'},
              'vendor': 'Vendor',
              'model': 'Model',
              'description': 'Custom profile',
            },
          },
        }),
      );

      return ByteData.sublistView(Uint8List.fromList(payload));
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(assetChannel, null);
  });

  test('CapabilityProfile.load reads the default profile from package assets',
      () async {
    final profile = await CapabilityProfile.load();

    expect(profile.name, 'default');
    expect(profile.codePages, isNotEmpty);
    expect(profile.getCodePageId('CP437'), 0);
  });

  test('CapabilityProfile.getAvailableProfiles returns profile metadata',
      () async {
    final profiles = await CapabilityProfile.getAvailableProfiles();

    expect(profiles, isNotEmpty);
    expect(
      profiles,
      contains(
        allOf(
          containsPair('key', 'default'),
          containsPair('vendor', 'Generic'),
          containsPair('model', 'Default'),
          containsPair('description', 'Default ESC/POS profile'),
        ),
      ),
    );
  });
}
