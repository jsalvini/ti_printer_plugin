#ifndef FLUTTER_PLUGIN_TI_PRINTER_PLUGIN_H_
#define FLUTTER_PLUGIN_TI_PRINTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <vector>

namespace ti_printer_plugin {

class TiPrinterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  TiPrinterPlugin();

  virtual ~TiPrinterPlugin();

  // Disallow copy and assign.
  TiPrinterPlugin(const TiPrinterPlugin&) = delete;
  TiPrinterPlugin& operator=(const TiPrinterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  private:
    // SERIAL PORT
    bool OpenSerialPort(const std::string& port_name, int baud_rate);
    bool CloseSerialPort();
    bool SendCommandToSerial(std::vector<uint8_t> data);
    std::vector<uint8_t> ReadStatusSerial(const std::vector<uint8_t>& command);

    bool OpenUsbPort(const std::string& device_instance_id);
    void CloseUsbPort();
    std::vector<std::wstring> ListUsbInstance();
    std::string convertWStringToString(const std::wstring& wstr);

    std::vector<uint8_t> ReadStatusUsb(const std::vector<uint8_t>& command);
    bool SendCommandToUsb(std::vector<uint8_t> data);
    void GetUsbDevicesInstanceId();

    HANDLE hSerial_;  // Almacena el handle del puerto serial
    HANDLE hUsb_; // Almacena el handle del puerto usb
};

}  // namespace ti_printer_plugin

#endif  // FLUTTER_PLUGIN_TI_PRINTER_PLUGIN_H_
