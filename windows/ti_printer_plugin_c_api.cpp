#include "include/ti_printer_plugin/ti_printer_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ti_printer_plugin.h"

void TiPrinterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ti_printer_plugin::TiPrinterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
