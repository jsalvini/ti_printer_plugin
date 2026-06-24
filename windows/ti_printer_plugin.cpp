#include "ti_printer_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <memory>
#include <sstream>
#include <string>
#include <map>
#include <vector>

// ver
#include <setupapi.h>
#include <initguid.h>
#include <devguid.h>
#include <iostream>
#include <usbiodef.h>
#include <cfgmgr32.h>

#pragma comment(lib, "setupapi.lib")
#define MAX_DEVICE_ID_LEN 200

namespace ti_printer_plugin {

void TiPrinterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "ti_printer_plugin",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<TiPrinterPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

// FIX #1: Inicializar AMBOS handles. Antes hUsb_ quedaba con basura y el
// destructor terminaba haciendo CloseHandle() sobre un valor indeterminado
// (UB), además de que cualquier sendCommandToUsb sin openUsbPort previo
// entraba al WriteFile en vez de devolver "puerto no abierto".
TiPrinterPlugin::TiPrinterPlugin()
    : hSerial_(INVALID_HANDLE_VALUE), hUsb_(INVALID_HANDLE_VALUE) {}

TiPrinterPlugin::~TiPrinterPlugin() {
  if (hSerial_ != INVALID_HANDLE_VALUE) {
    CloseSerialPort();
  }
  // FIX #21: Usar el método de cierre simétrico para que hUsb_ quede en
  // INVALID_HANDLE_VALUE (evita double-close si el destructor se invoca dos veces).
  if (hUsb_ != INVALID_HANDLE_VALUE) {
    CloseUsbPort();
  }
}

void TiPrinterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name().compare("openSerialPort") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    std::string port_name;
    int baud_rate = 9600; // Valor predeterminado

    if (arguments) {
      auto port_it = arguments->find(flutter::EncodableValue("portName"));
      if (port_it != arguments->end()) {
        port_name = std::get<std::string>(port_it->second);
      }
      auto baud_it = arguments->find(flutter::EncodableValue("baudRate"));
      if (baud_it != arguments->end()) {
        baud_rate = std::get<int>(baud_it->second);
      }
    }

    if (OpenSerialPort(port_name, baud_rate)) {
      //result->Success(flutter::EncodableValue("Puerto serial abierto con éxito."));
      result->Success(flutter::EncodableValue(true));
    } else {
      result->Error("ERROR", "No se pudo abrir el puerto serial.");
    }
  } else if (method_call.method_name().compare("closeSerialPort") == 0) {
    if (CloseSerialPort()) {
      result->Success(flutter::EncodableValue(true));
    } else {
      result->Error("ERROR", "No se pudo cerrar el puerto serial.");
    }
  } else if (method_call.method_name().compare("sendCommandToSerial") == 0) {
    const auto *args = std::get_if<std::vector<uint8_t>>(method_call.arguments());
    if (args) {
      // Llama a tu método SendCommand
      bool success = SendCommandToSerial(*args);
      if (success) {
          result->Success(flutter::EncodableValue(true));
      } else {
          result->Error("ERROR", "Failed to send data");
      }
    } else {
      result->Error("INVALID_ARGUMENT", "Expected a list of bytes.");
    }
  } else if (method_call.method_name().compare("readStatusSerial") == 0) {
    const auto* command = std::get_if<std::vector<uint8_t>>(method_call.arguments());
    if (command) {
        std::vector<uint8_t> status = ReadStatusSerial(*command);
        result->Success(
            flutter::EncodableValue(std::vector<uint8_t>(status)));
    } else {
        result->Error("INVALID_ARGUMENT", "Expected a list of bytes.");
    }
  } else if (method_call.method_name().compare("getUsbPrinters") == 0) {
        auto printerInstances = ListUsbInstance();

        flutter::EncodableList instanceList;
        for (const auto& printer : printerInstances) {
          flutter::EncodableMap map;
          map[flutter::EncodableValue("instanceId")] =
              flutter::EncodableValue(convertWStringToString(printer.instanceId));
          map[flutter::EncodableValue("displayName")] =
              flutter::EncodableValue(convertWStringToString(printer.displayName));
          map[flutter::EncodableValue("vid")] =
              flutter::EncodableValue(printer.vid);
          map[flutter::EncodableValue("pid")] =
              flutter::EncodableValue(printer.pid);
          instanceList.push_back(flutter::EncodableValue(map));
        }

        result->Success(flutter::EncodableValue(instanceList));
  } else  if (method_call.method_name().compare("openUsbPort") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    std::string device_instance_id;

    if (arguments) {
      auto instance_id_it = arguments->find(flutter::EncodableValue("deviceInstanceId"));
      if (instance_id_it != arguments->end()) {
        device_instance_id = std::get<std::string>(instance_id_it->second);
      }
    }

    if (OpenUsbPort(device_instance_id)) {
      //result->Success(flutter::EncodableValue("Puerto USB abierto con éxito."));
      result->Success(flutter::EncodableValue(true));
    } else {
      //std::cerr << "No se pudo abrir el puerto USB." << std::endl;
      result->Error("ERROR", "No se pudo abrir el puerto USB.");
    }
  } else if (method_call.method_name().compare("closeUsbPort") == 0) {
    if (CloseUsbPort()) {
      result->Success(flutter::EncodableValue(true));
    } else {
      result->Error("ERROR", "No se pudo cerrar el puerto USB.");
    }
  } else if (method_call.method_name().compare("sendCommandToUsb") == 0) {
     // Método para escribir en el puerto usb
    const auto *args = std::get_if<std::vector<uint8_t>>(method_call.arguments());
    if (args) {
      // Llama a tu método SendCommand
      bool success = SendCommandToUsb(*args);
      if (success) {
          result->Success(flutter::EncodableValue(true));
      } else {
          result->Error("ERROR", "Failed to send data");
      }
    } else {
      result->Error("INVALID_ARGUMENT", "Expected a list of bytes.");
    }
  } else if (method_call.method_name().compare("readFromUsb") == 0) {
    // Llama a la función leer datos de la impresora
  } else if (method_call.method_name().compare("readStatusUsb") == 0) {
    const auto* command = std::get_if<std::vector<uint8_t>>(method_call.arguments());
    if (command) {
        std::vector<uint8_t> status = ReadStatusUsb(*command);
        result->Success(
            flutter::EncodableValue(std::vector<uint8_t>(status)));
    } else {
        result->Error("INVALID_ARGUMENT", "Expected a list of bytes.");
    }
  } else {
    result->NotImplemented();
  }
}

bool TiPrinterPlugin::OpenSerialPort(const std::string& port_name, int baud_rate) {
  // Convierte el nombre del puerto en un formato que Windows pueda entender (e.g., "\\\\.\\COM3")
  std::string formatted_port_name = "\\\\.\\" + port_name;

  // Error al abrir el puerto serial
  hSerial_ = CreateFileA(
      formatted_port_name.c_str(),
      GENERIC_READ | GENERIC_WRITE,
      0,
      nullptr,
      OPEN_EXISTING,
      0,
      nullptr);

  if (hSerial_ == INVALID_HANDLE_VALUE) {
    return false;
  }

  // Configura los parámetros del puerto
  DCB dcbSerialParams = {0};
  dcbSerialParams.DCBlength = sizeof(dcbSerialParams);

  // Error al obtener los parámetros actuales
  if (!GetCommState(hSerial_, &dcbSerialParams)) {
    CloseHandle(hSerial_);
    return false;
  }

  dcbSerialParams.BaudRate = baud_rate;
  dcbSerialParams.ByteSize = 8;
  dcbSerialParams.StopBits = ONESTOPBIT;
  dcbSerialParams.Parity = NOPARITY;

  // Error al configurar el puerto
  if (!SetCommState(hSerial_, &dcbSerialParams)) {
    CloseHandle(hSerial_);
    return false;
  }

  // Configuración de tiempos
  COMMTIMEOUTS timeouts = {0};
  timeouts.ReadIntervalTimeout = 50;
  timeouts.ReadTotalTimeoutConstant = 50;
  timeouts.ReadTotalTimeoutMultiplier = 10;
  timeouts.WriteTotalTimeoutConstant = 50;
  timeouts.WriteTotalTimeoutMultiplier = 10;

  // Error al configurar los tiempos
  if (!SetCommTimeouts(hSerial_, &timeouts)) {
    CloseHandle(hSerial_);
    return false;
  }

  // El puerto serial se abrió correctamente
  return true;
}

bool TiPrinterPlugin::CloseSerialPort() {
  if (hSerial_ != INVALID_HANDLE_VALUE) {
    // Cierra el puerto serial
    if (CloseHandle(hSerial_)) {
      hSerial_ = INVALID_HANDLE_VALUE;
      return true;  // El puerto serial se cerró correctamente
    } else {
      // Obtener el error
      DWORD error_code = GetLastError();
      std::ostringstream error_message;
      error_message << "Error cerrando el puerto serial: " << error_code;
      OutputDebugStringA(error_message.str().c_str());  // Imprime el error en el debugger
    }
  }else{
    // Obtener el error
      DWORD error_code = GetLastError();
      std::ostringstream error_message;
      error_message << "Error estado invalido puerto serial: " << error_code;
      OutputDebugStringA(error_message.str().c_str());  // Imprime el error en el debugger
  }
  return false;  // No se pudo cerrar el puerto serial o ya estaba cerrado
}

bool TiPrinterPlugin::SendCommandToSerial(std::vector<uint8_t> data) {
    if (hSerial_ == INVALID_HANDLE_VALUE) {
        return false;
    }
    if (data.empty()) {
        return true;
    }

    // FIX #22: El handle se abrió SIN FILE_FLAG_OVERLAPPED, así que toda la
    // ceremonia OVERLAPPED / CreateEvent / GetOverlappedResult era código muerto
    // (ERROR_IO_PENDING no sucede en handles síncronos). Para serial, los
    // timeouts via SetCommTimeouts son el camino canónico de Win32.
    COMMTIMEOUTS timeouts = {};
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.ReadTotalTimeoutMultiplier = MAXDWORD;
    timeouts.ReadTotalTimeoutConstant = 500;
    timeouts.WriteTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 2000;

    if (!SetCommTimeouts(hSerial_, &timeouts)) {
        return false;
    }

    DWORD data_size = static_cast<DWORD>(data.size());
    DWORD bytes_written = 0;

    if (!WriteFile(hSerial_, data.data(), data_size, &bytes_written, NULL)) {
        return false;
    }

    return bytes_written == data_size;
}

std::vector<uint8_t> TiPrinterPlugin::ReadStatusSerial(const std::vector<uint8_t>& command) {
    std::vector<uint8_t> result;
    if (hSerial_ == INVALID_HANDLE_VALUE) {
        return result;
    }

    DWORD errors;
    COMSTAT status;
    if (!ClearCommError(hSerial_, &errors, &status)) {
        return result;
    }

    // Timeout para lectura/escritura (500 ms total)
    COMMTIMEOUTS timeouts = {};
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.ReadTotalTimeoutMultiplier = 0;
    timeouts.ReadTotalTimeoutConstant = 500;
    timeouts.WriteTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 500;

    if (!SetCommTimeouts(hSerial_, &timeouts)) {
        return result;
    }

    DWORD bytes_written = 0;
    DWORD data_size = static_cast<DWORD>(command.size());
    if (!WriteFile(hSerial_, command.data(), data_size, &bytes_written, NULL)) {
        return result;
    }

    // FIX #6: Devolver TODOS los bytes leídos, no sólo el primero. La versión
    // anterior truncaba a 1 byte, lo cual rompe respuestas multi-byte (ESC u,
    // auto status back, etc.).
    uint8_t response[256];
    DWORD bytes_read = 0;
    if (!ReadFile(hSerial_, response, sizeof(response), &bytes_read, NULL)) {
        return result;
    }

    if (bytes_read > 0) {
        result.assign(response, response + bytes_read);
    }
    return result;
}

// FUNCIONES PARA PUERTO USB
bool TiPrinterPlugin::OpenUsbPort(const std::string& device_instance_id) {
    // FIX #19: Conversión UTF-8 → UTF-16 correcta. La versión anterior hacía
    // un cast byte-a-byte que sólo era válido para ASCII puro. Los InstanceIds
    // de Windows son ASCII en la práctica, pero si alguna vez aparece un
    // carácter non-ASCII se rompía silenciosamente.
    std::wstring targetDeviceInstanceId;
    if (!device_instance_id.empty()) {
        int sizeNeeded = MultiByteToWideChar(
            CP_UTF8, 0,
            device_instance_id.c_str(), -1,
            NULL, 0);
        if (sizeNeeded > 0) {
            std::vector<wchar_t> buf(sizeNeeded);
            MultiByteToWideChar(
                CP_UTF8, 0,
                device_instance_id.c_str(), -1,
                buf.data(), sizeNeeded);
            targetDeviceInstanceId.assign(buf.data());
        }
    }

    // GUID para dispositivos USB
    GUID guid = GUID_DEVINTERFACE_USB_DEVICE;

    // Obtén el conjunto de dispositivos conectados
    HDEVINFO deviceInfoSet = SetupDiGetClassDevs(&guid, NULL, NULL, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);

    if (deviceInfoSet == INVALID_HANDLE_VALUE) {
        return false;
    }

    SP_DEVICE_INTERFACE_DATA deviceInterfaceData;
    deviceInterfaceData.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);

    // Itera sobre los dispositivos
    for (DWORD i = 0; SetupDiEnumDeviceInterfaces(deviceInfoSet, NULL, &guid, i, &deviceInterfaceData); ++i) {
        DWORD requiredSize = 0;

        SetupDiGetDeviceInterfaceDetail(deviceInfoSet, &deviceInterfaceData, NULL, 0, &requiredSize, NULL);
        std::vector<BYTE> buffer(requiredSize);
        PSP_DEVICE_INTERFACE_DETAIL_DATA deviceInterfaceDetailData = (PSP_DEVICE_INTERFACE_DETAIL_DATA)buffer.data();
        deviceInterfaceDetailData->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA);

        if (!SetupDiGetDeviceInterfaceDetail(deviceInfoSet, &deviceInterfaceData, deviceInterfaceDetailData, requiredSize, NULL, NULL)) {
            continue;
        }

        SP_DEVINFO_DATA devInfoData;
        devInfoData.cbSize = sizeof(SP_DEVINFO_DATA);

        if (!SetupDiEnumDeviceInfo(deviceInfoSet, i, &devInfoData)) {
            continue;
        }

        WCHAR deviceInstanceIdBuffer[MAX_DEVICE_ID_LEN];
        if (CM_Get_Device_ID(devInfoData.DevInst, deviceInstanceIdBuffer, MAX_DEVICE_ID_LEN, 0) != CR_SUCCESS) {
            continue;
        }

        if (wcscmp(deviceInstanceIdBuffer, targetDeviceInstanceId.c_str()) == 0) {
            // FIX #7: Abrimos con FILE_FLAG_OVERLAPPED para poder hacer I/O
            // asincrónica con timeout en SendCommandToUsb y ReadStatusUsb.
            // Sin esto, ReadFile bloquea indefinidamente si la impresora no
            // responde (apagada, error, etc.) — fatal para un Timer de status.
            hUsb_ = CreateFile(
                deviceInterfaceDetailData->DevicePath,
                GENERIC_READ | GENERIC_WRITE,
                0,
                NULL,
                OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED,
                NULL
            );

            if (hUsb_ == INVALID_HANDLE_VALUE) {
                SetupDiDestroyDeviceInfoList(deviceInfoSet);
                return false;
            }

            SetupDiDestroyDeviceInfoList(deviceInfoSet);
            return true;
        }
    }

    SetupDiDestroyDeviceInfoList(deviceInfoSet);
    return false;
}

bool TiPrinterPlugin::CloseUsbPort() {
    if (hUsb_ == INVALID_HANDLE_VALUE) {
        return true;
    }

    if (CloseHandle(hUsb_)) {
        hUsb_ = INVALID_HANDLE_VALUE;
        return true;
    }

    return false;
}

bool TiPrinterPlugin::SendCommandToUsb(std::vector<uint8_t> data) {
  if (hUsb_ == INVALID_HANDLE_VALUE) {
    return false;
  }
  if (data.empty()) {
    return true;
  }

  // FIX #7 + #15: Escritura overlapped REAL con timeout + loop para
  // re-enviar el remanente en caso de escritura parcial. La versión anterior
  // marcaba como error la escritura parcial pero NO reintentaba el resto,
  // dejando a la impresora con medio ticket.
  //
  // El handle se abrió con FILE_FLAG_OVERLAPPED, así que WriteFile retorna
  // ERROR_IO_PENDING si no completa inmediatamente y podemos esperar con
  // timeout y cancelar con CancelIoEx si vence.
  const DWORD WRITE_TIMEOUT_MS = 10000; // 10s — los tickets con logos pueden ser KB

  const uint8_t* ptr = data.data();
  DWORD remaining = static_cast<DWORD>(data.size());

  while (remaining > 0) {
    OVERLAPPED overlapped = {};
    overlapped.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
    if (overlapped.hEvent == NULL) {
      return false;
    }

    DWORD bytes_written = 0;
    BOOL ok = WriteFile(hUsb_, ptr, remaining, &bytes_written, &overlapped);

    if (!ok) {
      DWORD err = GetLastError();
      if (err == ERROR_IO_PENDING) {
        DWORD wait = WaitForSingleObject(overlapped.hEvent, WRITE_TIMEOUT_MS);
        if (wait != WAIT_OBJECT_0) {
          // Timeout o error → cancelamos la operación pendiente
          CancelIoEx(hUsb_, &overlapped);
          GetOverlappedResult(hUsb_, &overlapped, &bytes_written, TRUE);
          CloseHandle(overlapped.hEvent);
          return false;
        }
        if (!GetOverlappedResult(hUsb_, &overlapped, &bytes_written, TRUE)) {
          CloseHandle(overlapped.hEvent);
          return false;
        }
      } else {
        CloseHandle(overlapped.hEvent);
        return false;
      }
    }

    CloseHandle(overlapped.hEvent);

    if (bytes_written == 0) {
      // El driver no aceptó ningún byte; cortamos para no quedarnos en loop.
      return false;
    }

    ptr += bytes_written;
    remaining -= bytes_written;
  }

  return true;
}

std::vector<uint8_t> TiPrinterPlugin::ReadStatusUsb(const std::vector<uint8_t>& command) {
  std::vector<uint8_t> result;
  if (hUsb_ == INVALID_HANDLE_VALUE) {
    return result;
  }

  // Primero enviamos el comando (DLE EOT n o el que sea)
  if (!command.empty()) {
    if (!SendCommandToUsb(command)) {
      return result;
    }
  }

  // FIX #7: Lectura overlapped con timeout de 500 ms. La versión anterior
  // hacía un ReadFile() bloqueante sobre un handle síncrono — si la impresora
  // estaba apagada o desconectada, la app quedaba colgada hasta que alguien
  // re-enchufara el USB. Con el Timer.periodic(3s) del controller, una
  // impresora apagada literalmente freezaba el plugin.
  const DWORD READ_TIMEOUT_MS = 500;

  OVERLAPPED overlapped = {};
  overlapped.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
  if (overlapped.hEvent == NULL) {
    return result;
  }

  uint8_t response[256];
  DWORD bytes_read = 0;
  BOOL ok = ReadFile(hUsb_, response, sizeof(response), &bytes_read, &overlapped);

  if (!ok) {
    DWORD err = GetLastError();
    if (err == ERROR_IO_PENDING) {
      DWORD wait = WaitForSingleObject(overlapped.hEvent, READ_TIMEOUT_MS);
      if (wait != WAIT_OBJECT_0) {
        // Timeout → cancelamos la lectura pendiente
        CancelIoEx(hUsb_, &overlapped);
        GetOverlappedResult(hUsb_, &overlapped, &bytes_read, TRUE);
        CloseHandle(overlapped.hEvent);
        return result;
      }
      if (!GetOverlappedResult(hUsb_, &overlapped, &bytes_read, TRUE)) {
        CloseHandle(overlapped.hEvent);
        return result;
      }
    } else {
      CloseHandle(overlapped.hEvent);
      return result;
    }
  }

  CloseHandle(overlapped.hEvent);

  // FIX #6: Devolver TODOS los bytes leídos. La versión anterior truncaba a 1.
  if (bytes_read > 0) {
    result.assign(response, response + bytes_read);
  }
  return result;
}

void TiPrinterPlugin::GetUsbDevicesInstanceId() {
    HDEVINFO deviceInfoSet = SetupDiGetClassDevs(NULL, L"USB", NULL, DIGCF_PRESENT | DIGCF_ALLCLASSES);
    //HDEVINFO deviceInfoSet = SetupDiGetClassDevsA(NULL, "USB", NULL, DIGCF_PRESENT | DIGCF_ALLCLASSES);

    if (deviceInfoSet == INVALID_HANDLE_VALUE) {
        //std::cerr << "Error obteniendo el conjunto de dispositivos USB." << std::endl;
        return;
    }

    SP_DEVINFO_DATA deviceInfoData;
    deviceInfoData.cbSize = sizeof(SP_DEVINFO_DATA);
    DWORD deviceIndex = 0;

    while (SetupDiEnumDeviceInfo(deviceInfoSet, deviceIndex, &deviceInfoData)) {
        deviceIndex++;
        // Obtener el InstanceId
        char instanceId[1024];
        if (SetupDiGetDeviceInstanceIdA(deviceInfoSet, &deviceInfoData, instanceId, sizeof(instanceId), NULL)) {
           // std::cout << "InstanceId: " << instanceId << std::endl;
        }
    }

    SetupDiDestroyDeviceInfoList(deviceInfoSet);
}

std::vector<PrinterDeviceInfo> TiPrinterPlugin::ListUsbInstance() {
    std::vector<PrinterDeviceInfo> usbPrinterInstances;

    // Lambdas inline (antes eran static helpers fuera de la clase)
    auto parseHexFromInstanceId = [](const std::wstring& instanceId, const std::wstring& prefix) -> int {
        auto pos = instanceId.find(prefix);
        if (pos == std::wstring::npos) return 0;
        pos += prefix.length();
        if (pos + 4 > instanceId.length()) return 0;
        std::wstring hexStr = instanceId.substr(pos, 4);
        return std::wcstol(hexStr.c_str(), nullptr, 16);
    };

    auto getDisplayName = [](HDEVINFO devSet, PSP_DEVINFO_DATA devInfoData) -> std::wstring {
        WCHAR friendlyName[256];
        if (SetupDiGetDeviceRegistryProperty(
                devSet, devInfoData, SPDRP_FRIENDLYNAME,
                NULL, (PBYTE)friendlyName, sizeof(friendlyName), NULL)) {
            return friendlyName;
        }
        WCHAR devDesc[256];
        if (SetupDiGetDeviceRegistryProperty(
                devSet, devInfoData, SPDRP_DEVICEDESC,
                NULL, (PBYTE)devDesc, sizeof(devDesc), NULL)) {
            return devDesc;
        }
        return L"Unknown Printer";
    };

    // 1ra pasada: dispositivos USB con servicio "usbprint"
    HDEVINFO deviceInfoSet = SetupDiGetClassDevs(
        &GUID_DEVINTERFACE_USB_DEVICE,
        NULL,
        NULL,
        DIGCF_PRESENT | DIGCF_DEVICEINTERFACE
    );

    if (deviceInfoSet == INVALID_HANDLE_VALUE) {
        DWORD err = GetLastError();
        OutputDebugStringA(("ListUsbInstance: SetupDiGetClassDevs(USB_DEVICE) failed, error=" + std::to_string(err) + "\n").c_str());
    } else {
        SP_DEVICE_INTERFACE_DATA deviceInterfaceData;
        deviceInterfaceData.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);
        DWORD deviceIndex = 0;

        while (SetupDiEnumDeviceInterfaces(
            deviceInfoSet, NULL, &GUID_DEVINTERFACE_USB_DEVICE,
            deviceIndex, &deviceInterfaceData)) {

            DWORD requiredSize = 0;
            SetupDiGetDeviceInterfaceDetail(deviceInfoSet, &deviceInterfaceData, NULL, 0, &requiredSize, NULL);

            std::vector<BYTE> buffer(requiredSize);
            auto* detailData = reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA*>(buffer.data());
            detailData->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA);

            SP_DEVINFO_DATA devInfoData;
            devInfoData.cbSize = sizeof(SP_DEVINFO_DATA);

            if (SetupDiGetDeviceInterfaceDetail(deviceInfoSet, &deviceInterfaceData,
                    detailData, requiredSize, &requiredSize, &devInfoData)) {

                WCHAR service[256];
                if (SetupDiGetDeviceRegistryProperty(deviceInfoSet, &devInfoData,
                        SPDRP_SERVICE, NULL, (PBYTE)service, sizeof(service), NULL)) {
                    if (wcscmp(service, L"usbprint") == 0) {
                        PrinterDeviceInfo info = {};
                        info.vid = 0;
                        info.pid = 0;

                        WCHAR instanceId[MAX_DEVICE_ID_LEN];
                        if (CM_Get_Device_ID(devInfoData.DevInst, instanceId, MAX_DEVICE_ID_LEN, 0) == CR_SUCCESS) {
                            info.instanceId = instanceId;
                            info.displayName = getDisplayName(deviceInfoSet, &devInfoData);
                            info.vid = parseHexFromInstanceId(instanceId, L"VID_");
                            info.pid = parseHexFromInstanceId(instanceId, L"PID_");
                            if (!info.instanceId.empty()) {
                                usbPrinterInstances.push_back(info);
                            }
                        }
                    }
                }
            }
            deviceIndex++;
        }
        SetupDiDestroyDeviceInfoList(deviceInfoSet);
    }

    // 2da pasada: dispositivos de clase "Printer" (drivers propietarios)
    HDEVINFO printerClassSet = SetupDiGetClassDevs(
        &GUID_DEVCLASS_PRINTER, NULL, NULL, DIGCF_PRESENT);

    if (printerClassSet == INVALID_HANDLE_VALUE) {
        DWORD err = GetLastError();
        OutputDebugStringA(("ListUsbInstance: SetupDiGetClassDevs(Printer) failed, error=" + std::to_string(err) + "\n").c_str());
    } else {
        SP_DEVINFO_DATA devInfo;
        devInfo.cbSize = sizeof(SP_DEVINFO_DATA);
        DWORD idx = 0;

        while (SetupDiEnumDeviceInfo(printerClassSet, idx, &devInfo)) {
            PrinterDeviceInfo info = {};
            info.vid = 0;
            info.pid = 0;

            WCHAR instanceId[MAX_DEVICE_ID_LEN];
            if (CM_Get_Device_ID(devInfo.DevInst, instanceId, MAX_DEVICE_ID_LEN, 0) == CR_SUCCESS) {
                info.instanceId = instanceId;
                info.displayName = getDisplayName(printerClassSet, &devInfo);
                info.vid = parseHexFromInstanceId(instanceId, L"VID_");
                info.pid = parseHexFromInstanceId(instanceId, L"PID_");

                if (!info.instanceId.empty()) {
                    bool alreadyFound = false;
                    for (const auto& existing : usbPrinterInstances) {
                        if (existing.instanceId == info.instanceId) {
                            alreadyFound = true;
                            break;
                        }
                    }
                    if (!alreadyFound) {
                        usbPrinterInstances.push_back(info);
                    }
                }
            }
            idx++;
        }
        SetupDiDestroyDeviceInfoList(printerClassSet);
    }

    OutputDebugStringA(("ListUsbInstance: found " + std::to_string(usbPrinterInstances.size()) + " printers\n").c_str());
    for (size_t i = 0; i < usbPrinterInstances.size(); i++) {
        const auto& p = usbPrinterInstances[i];
        std::string displayName = convertWStringToString(p.displayName);
        std::string instanceId = convertWStringToString(p.instanceId);
        OutputDebugStringA(("  [" + std::to_string(i) + "] " + displayName + " | " + instanceId + " VID=0x" + std::to_string(p.vid) + " PID=0x" + std::to_string(p.pid) + "\n").c_str());
    }

    return usbPrinterInstances;
}

std::string TiPrinterPlugin::convertWStringToString(const std::wstring& wstr) {
    if (wstr.empty()) {
        return std::string();
    }
    int sizeNeeded = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string result(sizeNeeded, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &result[0], sizeNeeded, NULL, NULL);
    return result;
}

}  // namespace ti_printer_plugin
