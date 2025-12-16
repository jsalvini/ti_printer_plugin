#include "include/ti_printer_plugin/ti_printer_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <string>
#include <vector>

// Linux system headers para acceso a dispositivos
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/select.h>
#include <errno.h>

#include "ti_printer_plugin_private.h"

#define TI_PRINTER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), ti_printer_plugin_get_type(), \
                              TiPrinterPlugin))

struct _TiPrinterPlugin
{
  GObject parent_instance;

  // File descriptor de la impresora USB (o -1 si no hay ninguno)
  int usb_fd;
};

struct _TiPrinterPluginClass
{
  GObjectClass parent_class;
};

G_DEFINE_TYPE(TiPrinterPlugin, ti_printer_plugin, g_object_get_type())

// ===================== Helpers internos de Linux =====================

// Agrega a 'out' todos los dispositivos en 'dir_path' cuyo nombre
// empieza por 'prefix' (ej: /dev/usb/lp0, ttyUSB0, etc.)
static void add_dev_entries_with_prefix(const char *dir_path,
                                        const char *prefix,
                                        std::vector<std::string> &out)
{
  DIR *d = opendir(dir_path);
  if (!d)
    return;

  struct dirent *entry;
  while ((entry = readdir(d)) != nullptr)
  {
    if (entry->d_name[0] == '.')
      continue;
    if (std::strncmp(entry->d_name, prefix, std::strlen(prefix)) == 0)
    {
      std::string full = std::string(dir_path) + "/" + entry->d_name;
      struct stat st{};
      if (stat(full.c_str(), &st) == 0 && S_ISCHR(st.st_mode))
      {
        out.push_back(full);
      }
    }
  }

  closedir(d);
}

// Devuelve posibles rutas de impresoras térmicas USB.
static std::vector<std::string> list_usb_printers()
{
  std::vector<std::string> paths;

  // Impresoras "raw" suelen aparecer como /dev/usb/lpX
  add_dev_entries_with_prefix("/dev/usb", "lp", paths);

  // Muchos modelos de impresora térmica aparecen como /dev/ttyUSBx o /dev/ttyACMx
  add_dev_entries_with_prefix("/dev", "ttyUSB", paths);
  add_dev_entries_with_prefix("/dev", "ttyACM", paths);

  return paths;
}

static bool open_usb_port(TiPrinterPlugin *self, const std::string &device_path)
{
  if (!self)
    return false;

  // Cerrar si ya había un descriptor abierto
  if (self->usb_fd >= 0)
  {
    close(self->usb_fd);
    self->usb_fd = -1;
  }

  int fd = open(device_path.c_str(), O_RDWR /*| O_NONBLOCK*/);
  if (fd < 0)
  {
    g_printerr("No se pudo abrir %s: %s\n", device_path.c_str(), g_strerror(errno));
    return false;
  }

  self->usb_fd = fd;
  return true;
}

static bool close_usb_port(TiPrinterPlugin *self)
{
  if (!self)
    return false;
  if (self->usb_fd >= 0)
  {
    if (close(self->usb_fd) == 0)
    {
      self->usb_fd = -1;
      return true;
    }
    return false;
  }
  return true; // ya estaba cerrado
}

static bool send_command_to_usb(TiPrinterPlugin *self,
                                const uint8_t *data,
                                size_t length)
{
  if (!self || self->usb_fd < 0 || !data || length == 0)
    return false;

  const uint8_t *ptr = data;
  size_t left = length;

  while (left > 0)
  {
    ssize_t written = write(self->usb_fd, ptr, left);
    if (written < 0)
    {
      if (errno == EINTR)
      {
        continue;
      }

      g_printerr("Error escribiendo en USB: %s\n", g_strerror(errno));

      // Si el dispositivo no esta disponible "desapareció", cerramos el descriptor
      if (errno == ENODEV || errno == EIO || errno == EBADF)
      {
        if (self->usb_fd >= 0)
        {
          close(self->usb_fd);
          self->usb_fd = -1;
        }
      }

      return false;
    }
    left -= written;
    ptr += written;
  }

  // Forzar a que los datos se envíen al dispositivo
  fsync(self->usb_fd);
  return true;
}

static bool send_command_to_usb(TiPrinterPlugin *self,
                                const std::vector<uint8_t> &command)
{
  if (command.empty()) return false;
  return send_command_to_usb(self, command.data(), command.size());
}

static std::vector<uint8_t> read_status_usb(TiPrinterPlugin *self,
                                            const std::vector<uint8_t> &command)
{
  std::vector<uint8_t> result;
  if (!self || self->usb_fd < 0)
    return result;

  // Enviar comando de estado si se proporcionó (por ej. DLE EOT n)
  if (!command.empty())
  {
    if (!send_command_to_usb(self, command))
    {
      // Si send_command_to_usb falló y cerró el fd, devolvemos vacío
      return result;
    }
  }

  uint8_t buffer[256];
  fd_set readfds;
  FD_ZERO(&readfds);
  FD_SET(self->usb_fd, &readfds);

  struct timeval tv{};
  tv.tv_sec = 0;
  tv.tv_usec = 500000; // 500 ms

  int ret = select(self->usb_fd + 1, &readfds, nullptr, nullptr, &tv);
  if (ret <= 0)
  {
    // timeout o error
    return result;
  }

  if (FD_ISSET(self->usb_fd, &readfds))
  {
    ssize_t n = read(self->usb_fd, buffer, sizeof(buffer));
    if (n > 0)
    {
      // Igual que en Windows: devolver solo el primer byte de estado.
      result.push_back(buffer[0]);
    }
  }

  return result;
}

// ===================== Helpers ya existentes =====================

// Implementado acá para que pueda usarse desde private/test.
FlMethodResponse *get_platform_version()
{
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// ===================== Manejo de MethodChannel =====================

// Called when a method call is received from Flutter.
static void ti_printer_plugin_handle_method_call(
    TiPrinterPlugin *self,
    FlMethodCall *method_call)
{
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar *method = fl_method_call_get_name(method_call);

  if (std::strcmp(method, "getPlatformVersion") == 0)
  {
    response = get_platform_version();
  }
  else if (std::strcmp(method, "getUsbPrinters") == 0)
  {
    // Devuelve una lista de rutas /dev/... como List<String>
    auto printers = list_usb_printers();
    g_autoptr(FlValue) result = fl_value_new_list();
    for (const auto &path : printers)
    {
      fl_value_append_take(result, fl_value_new_string(path.c_str()));
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  else if (std::strcmp(method, "openUsbPort") == 0)
  {
    FlValue *args = fl_method_call_get_args(method_call);
    const gchar *device = nullptr;

    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP)
    {
      FlValue *v = fl_value_lookup_string(args, "deviceInstanceId");
      if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_STRING)
      {
        device = fl_value_get_string(v);
      }
    }

    if (device != nullptr && open_usb_port(self, device))
    {
      g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    }
    else
    {
      response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("ERROR",
                                       "No se pudo abrir el puerto USB.",
                                       nullptr));
    }
  }
  else if (std::strcmp(method, "closeUsbPort") == 0)
  {
    bool ok = close_usb_port(self);
    if (ok)
    {
      g_autoptr(FlValue) result =
          fl_value_new_string("Puerto USB cerrado con éxito.");
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    }
    else
    {
      response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("ERROR",
                                       "No se pudo cerrar el puerto USB.",
                                       nullptr));
    }
  }
  else if (std::strcmp(method, "sendCommandToUsb") == 0)
  {
    // Argumento: Uint8List directamente
    FlValue *args = fl_method_call_get_args(method_call);
    if (args != nullptr &&
        fl_value_get_type(args) == FL_VALUE_TYPE_UINT8_LIST)
    {
      const uint8_t *data = fl_value_get_uint8_list(args);
      size_t length = fl_value_get_length(args);

      bool ok = send_command_to_usb(self, data, length);
      if (ok)
      {
        g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
      }
      else
      {
        response = FL_METHOD_RESPONSE(
            fl_method_error_response_new("ERROR",
                                         "Failed to send data to USB.",
                                         nullptr));
      }
    }
    else
    {
      response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("INVALID_ARGUMENT",
                                       "Expected Uint8List as argument.",
                                       nullptr));
    }
  }
  else if (std::strcmp(method, "readStatusUsb") == 0)
  {
    // Argumento: Map {"command": Uint8List} como en Windows
    FlValue *args = fl_method_call_get_args(method_call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP)
    {
      FlValue *cmd_val = fl_value_lookup_string(args, "command");
      if (cmd_val != nullptr &&
          fl_value_get_type(cmd_val) == FL_VALUE_TYPE_UINT8_LIST)
      {
        const uint8_t *cmd_bytes = fl_value_get_uint8_list(cmd_val);
        size_t cmd_len = fl_value_get_length(cmd_val);
        std::vector<uint8_t> command(cmd_bytes, cmd_bytes + cmd_len);

        std::vector<uint8_t> status = read_status_usb(self, command);

        g_autoptr(FlValue) result = nullptr;
        if (!status.empty())
        {
          result = fl_value_new_uint8_list(status.data(), status.size());
        }
        else
        {
          // Devolver lista vacía si no hubo respuesta
          result = fl_value_new_uint8_list(nullptr, 0);
        }
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
      }
      else
      {
        response = FL_METHOD_RESPONSE(
            fl_method_error_response_new("INVALID_ARGUMENT",
                                         "Campo 'command' inválido o no es "
                                         "Uint8List.",
                                         nullptr));
      }
    }
    else
    {
      response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("INVALID_ARGUMENT",
                                       "Se esperaba un mapa de argumentos.",
                                       nullptr));
    }
  }
  else
  {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// ===================== Ciclo de vida del plugin =====================

static void ti_printer_plugin_dispose(GObject *object)
{
  TiPrinterPlugin *self = TI_PRINTER_PLUGIN(object);
  // Asegurar que se cierre el descriptor USB
  if (self->usb_fd >= 0)
  {
    close(self->usb_fd);
    self->usb_fd = -1;
  }

  G_OBJECT_CLASS(ti_printer_plugin_parent_class)->dispose(object);
}

static void ti_printer_plugin_class_init(TiPrinterPluginClass *klass)
{
  G_OBJECT_CLASS(klass)->dispose = ti_printer_plugin_dispose;
}

static void ti_printer_plugin_init(TiPrinterPlugin *self)
{
  self->usb_fd = -1;
}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data)
{
  TiPrinterPlugin *plugin = TI_PRINTER_PLUGIN(user_data);
  ti_printer_plugin_handle_method_call(plugin, method_call);
}

void ti_printer_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
  TiPrinterPlugin *plugin = TI_PRINTER_PLUGIN(
      g_object_new(ti_printer_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "ti_printer_plugin",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
