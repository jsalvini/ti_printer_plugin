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

TiPrinterPlugin::TiPrinterPlugin() : hSerial_(INVALID_HANDLE_VALUE) {}

TiPrinterPlugin::~TiPrinterPlugin() {
  // Asegúrate de cerrar el puerto serial si está abierto al destruir el objeto
  if (hSerial_ != INVALID_HANDLE_VALUE) {
    CloseSerialPort();
  }
  if (hUsb_ != INVALID_HANDLE_VALUE) {
    CloseHandle(hUsb_);
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
      result->Success(flutter::EncodableValue("Puerto serial cerrado con éxito."));
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
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
        auto it = arguments->find(flutter::EncodableValue("command"));
        if (it != arguments->end()) {
            // Obtener el comando como un vector de bytes (Uint8List en Flutter)
            const auto* command = std::get_if<std::vector<uint8_t>>(&(it->second));

            if (command) {
                // Llamar a la función para ejecutar el comando y obtener el estado de la impresora
                std::vector<uint8_t> status = ReadStatusSerial(*command);

                if (!status.empty()) {
                    // Retornar el estado de la impresora como una lista de bytes a Flutter
                    result->Success(flutter::EncodableValue(std::vector<uint8_t>(status)));
                } else {
                    result->Error("ERROR", "No se pudo obtener el estado de la impresora.");
                }
            } else {
                result->Error("INVALID_ARGUMENT", "El comando no es válido ó no es un Uint8List.");
            }
        } else {
            result->Error("INVALID_ARGUMENT", "Comando no proporcionado.");
        }
    } else {
        result->Error("INVALID_ARGUMENT", "Argumentos inválidos.");
    }
  } else if (method_call.method_name().compare("getUsbPrinters") == 0) {
        // Llama a la función ListUsbInstance para obtener las instancias de impresoras USB
        std::vector<std::wstring> printerInstances = ListUsbInstance();

        // Prepara una lista para enviar de vuelta a Flutter
        flutter::EncodableList instanceList;
        for (const auto& instanceId : printerInstances) {
          // instanceList.push_back(flutter::EncodableValue(std::wstring_convert<std::codecvt_utf8<wchar_t>>().to_bytes(instanceId)));
          // Usar la función convertWStringToString en lugar de wstring_convert
          instanceList.push_back(flutter::EncodableValue(convertWStringToString(instanceId)));
        }

        // Envía la lista de impresoras de vuelta al resultado
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
    // Llama a la función que obtiene el estado de la impresora
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
        auto it = arguments->find(flutter::EncodableValue("command"));
        if (it != arguments->end()) {
            // Obtener el comando como un vector de bytes (Uint8List en Flutter)
            const auto* command = std::get_if<std::vector<uint8_t>>(&(it->second));

            if (command) {
                // Llamar a la función para ejecutar el comando y obtener el estado de la impresora
                std::vector<uint8_t> status = ReadStatusUsb(*command);

                if (!status.empty()) {
                    // Retornar el estado de la impresora como una lista de bytes a Flutter
                    result->Success(flutter::EncodableValue(std::vector<uint8_t>(status)));
                } else {
                    result->Error("ERROR", "No se pudo obtener el estado de la impresora.");
                }
            } else {
                result->Error("INVALID_ARGUMENT", "El comando no es válido ó no es un Uint8List.");
            }
        } else {
            result->Error("INVALID_ARGUMENT", "Comando no proporcionado.");
        }
    } else {
        result->Error("INVALID_ARGUMENT", "Argumentos inválidos.");
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
    BOOL success = TRUE;
    DWORD bytes_written = 0;
    OVERLAPPED overlapped = {0};  // Para operaciones I/O asincrónicas

    if (hSerial_ == INVALID_HANDLE_VALUE) {
        // Si el puerto serial no está abierto
        //std::cerr << "El puerto serial no está abierto." << std::endl;
        return FALSE;
    }

    // Configurar el timeout para las operaciones de escritura
    COMMTIMEOUTS timeouts;
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.ReadTotalTimeoutMultiplier = MAXDWORD;
    timeouts.ReadTotalTimeoutConstant = 500;  // 500 ms para operaciones de lectura
    timeouts.WriteTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 2000;  // 2000 ms para operaciones de escritura

    if (!SetCommTimeouts(hSerial_, &timeouts)) {
        //DWORD error_code = GetLastError();
        //std::cerr << "Error al configurar los tiempos de escritura: " << error_code << std::endl;
        return FALSE;
    }

    // Inicializa la estructura OVERLAPPED
    overlapped.Offset = 0;
    overlapped.OffsetHigh = 0;
    overlapped.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);

    if (overlapped.hEvent == NULL) {
        //std::cerr << "Error al crear el evento para la escritura asincrónica." << std::endl;
        return FALSE;
    }

    // Aquí hacemos la conversión explícita de `size_t` a `DWORD`
    DWORD data_size = static_cast<DWORD>(data.size());

    // Enviar los datos al puerto serial
    BOOL status = WriteFile(hSerial_, data.data(), data_size, &bytes_written, &overlapped);

    if (!status) {
        // Si la operación no es completada inmediatamente, comprobar si está en curso
        if (GetLastError() == ERROR_IO_PENDING) {
            // Esperar hasta que se complete la operación
            status = GetOverlappedResult(hSerial_, &overlapped, &bytes_written, TRUE);
        } else {
            //DWORD error_code = GetLastError();
            //std::cerr << "Error al enviar los datos al puerto serial: " << error_code << std::endl;
            success = FALSE;
        }
    }

    // Verificar si todos los bytes fueron enviados
    if (bytes_written != data_size) {
        //std::cerr << "No se enviaron todos los datos al puerto serial." << std::endl;
        success = FALSE;
    }

    // Liberar el handle de evento
    CloseHandle(overlapped.hEvent);

    return success;
}

std::vector<uint8_t> TiPrinterPlugin::ReadStatusSerial(const std::vector<uint8_t>& command) {
    DWORD bytes_written = 0;
    DWORD bytes_read = 0;
    DWORD errors;
    COMSTAT status;
    char response[256];  // Puede ser ajustado según el tamaño de respuesta esperado.

    // Limpiar errores de comunicación y obtener el estado del puerto
    if (!ClearCommError(hSerial_, &errors, &status)) {
        //std::cerr << "Error al limpiar los errores del puerto: " << GetLastError() << std::endl;
        return {};
    }

    // Configurar el timeout para la operación de escritura y lectura
    COMMTIMEOUTS timeouts;
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.ReadTotalTimeoutMultiplier = 0;
    timeouts.ReadTotalTimeoutConstant = 500;  // 500 ms para la lectura
    timeouts.WriteTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 500;  // 500 ms para la escritura

    if (!SetCommTimeouts(hSerial_, &timeouts)) {
        //std::cerr << "Error al configurar los tiempos de lectura: " << GetLastError() << std::endl;
        return {};
    }

    // Aquí hacemos la conversión explícita de `size_t` a `DWORD`
    DWORD data_size = static_cast<DWORD>(command.size());

    // Enviar el comando DLE EOT (solicitud de estado) recibido como parámetro
    if (!WriteFile(hSerial_, command.data(), data_size, &bytes_written, NULL)) {
        //std::cerr << "Error al enviar el comando DLE EOT: " << GetLastError() << std::endl;
        return {};
    }

    //std::cout << "Comando DLE EOT enviado, bytes escritos: " << bytes_written << std::endl;

    // Leer la respuesta del estado de la impresora (1 byte)
    if (!ReadFile(hSerial_, response, sizeof(response), &bytes_read, NULL)) {
        //std::cerr << "Error al leer la respuesta del puerto: " << GetLastError() << std::endl;
        return {};
    }

    if (bytes_read > 0) {
        //std::cout << "Estado de la impresora leído: " << static_cast<int>(response[0]) << std::endl;
        return { static_cast<uint8_t>(response[0]) };
    } else {
        //std::cerr << "No se recibió respuesta de la impresora." << std::endl;
        return {};
    }
}

// FUNCIONES PARA PUERTO USB
bool TiPrinterPlugin::OpenUsbPort(const std::string& device_instance_id) {
    // Convertimos el instanceId de std::string a std::wstring (necesario para la comparación)
    std::wstring targetDeviceInstanceId(device_instance_id.begin(), device_instance_id.end());

    // GUID para dispositivos USB
    GUID guid = GUID_DEVINTERFACE_USB_DEVICE;

    // Obtén el conjunto de dispositivos conectados
    HDEVINFO deviceInfoSet = SetupDiGetClassDevs(&guid, NULL, NULL, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);

    if (deviceInfoSet == INVALID_HANDLE_VALUE) {
        //std::cerr << "Error al obtener el conjunto de dispositivos." << std::endl;
        return false;
    }

    SP_DEVICE_INTERFACE_DATA deviceInterfaceData;
    deviceInterfaceData.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);

    // Itera sobre los dispositivos
    for (DWORD i = 0; SetupDiEnumDeviceInterfaces(deviceInfoSet, NULL, &guid, i, &deviceInterfaceData); ++i) {
        DWORD requiredSize = 0;

        // Obtén el tamaño del buffer
        SetupDiGetDeviceInterfaceDetail(deviceInfoSet, &deviceInterfaceData, NULL, 0, &requiredSize, NULL);
        std::vector<BYTE> buffer(requiredSize);
        PSP_DEVICE_INTERFACE_DETAIL_DATA deviceInterfaceDetailData = (PSP_DEVICE_INTERFACE_DETAIL_DATA)buffer.data();
        deviceInterfaceDetailData->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA);

        // Obtén los detalles de la interfaz del dispositivo
        if (!SetupDiGetDeviceInterfaceDetail(deviceInfoSet, &deviceInterfaceData, deviceInterfaceDetailData, requiredSize, NULL, NULL)) {
            //std::cerr << "Error al obtener detalles del dispositivo." << std::endl;
            continue;
        }

        // Ahora obtenemos el SP_DEVINFO_DATA asociado para obtener el DeviceInstanceId
        SP_DEVINFO_DATA devInfoData;
        devInfoData.cbSize = sizeof(SP_DEVINFO_DATA);

        if (!SetupDiEnumDeviceInfo(deviceInfoSet, i, &devInfoData)) {
            //std::cerr << "Error al obtener el SP_DEVINFO_DATA." << std::endl;
            continue;
        }

        // Aquí obtenemos el DeviceInstanceId real
        WCHAR deviceInstanceIdBuffer[MAX_DEVICE_ID_LEN];
        if (CM_Get_Device_ID(devInfoData.DevInst, deviceInstanceIdBuffer, MAX_DEVICE_ID_LEN, 0) != CR_SUCCESS) {
            //std::cerr << "Error al obtener el DeviceInstanceId." << std::endl;
            continue;
        }

        // Comparamos el DeviceInstanceId con el pasado como parámetro
        if (wcscmp(deviceInstanceIdBuffer, targetDeviceInstanceId.c_str()) == 0) {
            //std::wcout << L"Dispositivo encontrado: " << deviceInstanceIdBuffer << std::endl;

            // Abrir el dispositivo para escritura usando el DevicePath
            hUsb_ = CreateFile(
                deviceInterfaceDetailData->DevicePath,  // Ruta del dispositivo
                GENERIC_READ | GENERIC_WRITE,           // Permisos de lectura y escritura
                0,                                      // Sin compartir
                NULL,                                   // Seguridad por defecto
                OPEN_EXISTING,                          // Abrir solo si existe
                FILE_ATTRIBUTE_NORMAL,                  // Atributos normales
                NULL                                    // Sin plantilla
            );

            if (hUsb_ == INVALID_HANDLE_VALUE) {
                //std::cerr << "Error al abrir el dispositivo: " << GetLastError() << std::endl;
                SetupDiDestroyDeviceInfoList(deviceInfoSet);
                return false;
            }

            //std::cout << "Dispositivo abierto correctamente." << std::endl;
            // Cerrar el handle del dispositivo
            // CloseHandle(hUsb_);
            // Limpiar los recursos
            SetupDiDestroyDeviceInfoList(deviceInfoSet);
            return true;
        }
    }

    // Limpia los recursos si no se encontró el dispositivo
    SetupDiDestroyDeviceInfoList(deviceInfoSet);
    //std::cerr << "Dispositivo no encontrado." << std::endl;
    return false;
}

void TiPrinterPlugin::CloseUsbPort() {
    if (hUsb_ != INVALID_HANDLE_VALUE) {
        CloseHandle(hUsb_);
    }
}

bool TiPrinterPlugin::SendCommandToUsb(std::vector<uint8_t> data) {
  BOOL success = TRUE;
  DWORD bytes_written = 0;
  OVERLAPPED overlapped = {0};  // Para operaciones I/O asincrónicas

  if (hUsb_ == INVALID_HANDLE_VALUE) {
      // Si el puerto USB no está abierto
      //std::cerr << "El puerto USB no está abierto." << std::endl;
      return FALSE;
  }

  // Inicializa la estructura OVERLAPPED
  overlapped.Offset = 0;
  overlapped.OffsetHigh = 0;
  overlapped.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);

  if (overlapped.hEvent == NULL) {
      //std::cerr << "Error al crear el evento para la escritura asincrónica." << std::endl;
      return FALSE;
  }

  // Aquí hacemos la conversión explícita de `size_t` a `DWORD`
  DWORD data_size = static_cast<DWORD>(data.size());

  // Enviar los datos al dispositivo USB
  BOOL status = WriteFile(hUsb_, data.data(), data_size, &bytes_written, &overlapped);

  if (!status) {
      // Si la operación no es completada inmediatamente, comprobar si está en curso
      if (GetLastError() == ERROR_IO_PENDING) {
          // Esperar hasta que se complete la operación
          status = GetOverlappedResult(hUsb_, &overlapped, &bytes_written, TRUE);
      } else {
          //DWORD error_code = GetLastError();
          //std::cerr << "Error al enviar los datos al puerto USB: " << error_code << std::endl;
          success = FALSE;
      }
  }

  // Verificar si todos los bytes fueron enviados
  if (bytes_written != data_size) {
      //std::cerr << "No se enviaron todos los datos al puerto USB." << std::endl;
      success = FALSE;
  }

  // Liberar el handle de evento
  CloseHandle(overlapped.hEvent);
  return success;
}

std::vector<uint8_t> TiPrinterPlugin::ReadStatusUsb(const std::vector<uint8_t>& command) {
  DWORD bytes_written = 0;
  DWORD bytes_read = 0;
  char response[256];  // Ajustar según el tamaño de la respuesta esperada.

  // Enviar el comando a través del puerto USB usando el HANDLE (hUsb_)
  DWORD command_size = static_cast<DWORD>(command.size());

  // Agregar salida por consola para el comando recibido
  // std::cout << "Comando recibido para enviar: ";
  for (const auto& byte : command) {
      std::cout << std::hex << static_cast<int>(byte) << " ";  // Muestra en formato hexadecimal
  }
  std::cout << std::dec << std::endl;  // Vuelve al formato decimal

  if (!WriteFile(hUsb_, command.data(), command_size, &bytes_written, NULL)) {
    //DWORD error = GetLastError();
    //std::cerr << "Error al enviar el comando USB: " << error << std::endl;
    return {};
  }

  //std::cout << "Comando USB enviado, bytes escritos: " << bytes_written << std::endl;

  // Leer la respuesta del dispositivo USB
  if (!ReadFile(hUsb_, response, sizeof(response), &bytes_read, NULL)) {
      //std::cerr << "Error al leer la respuesta del dispositivo USB: " << GetLastError() << std::endl;
      return {};
  }

  if (bytes_read > 0) {
      //std::cout << "Respuesta del dispositivo USB leída: " << static_cast<int>(response[0]) << std::endl;
      // Retornar los datos leídos, aquí se asume que la respuesta es 1 byte, pero puedes ajustarlo según tu caso.
      //return { response, response + bytes_read };  // Devuelve un vector con los bytes leídos.
      return { static_cast<uint8_t>(response[0]) };
  } else {
      //std::cerr << "No se recibió respuesta del dispositivo USB." << std::endl;
      return {};
  }
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

std::vector<std::wstring> TiPrinterPlugin::ListUsbInstance() {
    std::vector<std::wstring> usbPrinterInstances;

    // Obtén una lista de dispositivos que coincidan con la clase de impresoras USB
    HDEVINFO deviceInfoSet = SetupDiGetClassDevs(
        &GUID_DEVINTERFACE_USB_DEVICE, // Interfaz para dispositivos USB
        NULL,                          // Sin enumerador
        NULL,                          // Sin ventana
        DIGCF_PRESENT | DIGCF_DEVICEINTERFACE
    );

    if (deviceInfoSet == INVALID_HANDLE_VALUE) {
        return usbPrinterInstances;  // No se pudo obtener el conjunto de dispositivos
    }

    SP_DEVICE_INTERFACE_DATA deviceInterfaceData;
    deviceInterfaceData.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);

    DWORD deviceIndex = 0;

    while (SetupDiEnumDeviceInterfaces(
        deviceInfoSet,
        NULL,
        &GUID_DEVINTERFACE_USB_DEVICE,
        deviceIndex,
        &deviceInterfaceData)) {

        // Obtener detalles de la interfaz del dispositivo
        DWORD requiredSize = 0;
        SetupDiGetDeviceInterfaceDetail(
            deviceInfoSet,
            &deviceInterfaceData,
            NULL,
            0,
            &requiredSize,
            NULL
        );

        std::vector<BYTE> deviceInterfaceDetailDataBuffer(requiredSize);
        SP_DEVICE_INTERFACE_DETAIL_DATA* deviceInterfaceDetailData = reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA*>(deviceInterfaceDetailDataBuffer.data());
        deviceInterfaceDetailData->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA);

        SP_DEVINFO_DATA deviceInfoData;
        deviceInfoData.cbSize = sizeof(SP_DEVINFO_DATA);

        if (SetupDiGetDeviceInterfaceDetail(
            deviceInfoSet,
            &deviceInterfaceData,
            deviceInterfaceDetailData,
            requiredSize,
            &requiredSize,
            &deviceInfoData)) {

            WCHAR deviceInstanceId[MAX_DEVICE_ID_LEN];
            if (CM_Get_Device_ID(deviceInfoData.DevInst, deviceInstanceId, MAX_DEVICE_ID_LEN, 0) == CR_SUCCESS) {
                // Ahora obtenemos la propiedad "Service" para verificar si es una impresora
                WCHAR service[256];
                if (SetupDiGetDeviceRegistryProperty(
                    deviceInfoSet,
                    &deviceInfoData,
                    SPDRP_SERVICE,
                    NULL,
                    (PBYTE)service,
                    sizeof(service),
                    NULL)) {

                    // Verifica si el servicio es "usbprint"
                    if (wcscmp(service, L"usbprint") == 0) {
                        // Añadir el DeviceInstanceId a la lista
                        usbPrinterInstances.push_back(deviceInstanceId);
                    }
                }
            }
        }

        deviceIndex++;
    }

    SetupDiDestroyDeviceInfoList(deviceInfoSet);
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
