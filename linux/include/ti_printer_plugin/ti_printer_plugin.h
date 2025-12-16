#ifndef FLUTTER_PLUGIN_TI_PRINTER_PLUGIN_H_
#define FLUTTER_PLUGIN_TI_PRINTER_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

// Forward declarations de las structs generadas por G_DEFINE_TYPE
typedef struct _TiPrinterPlugin TiPrinterPlugin;
typedef struct _TiPrinterPluginClass TiPrinterPluginClass;

// G_DEFINE_TYPE genera la implementación de esta función en el .cc
FLUTTER_PLUGIN_EXPORT GType ti_printer_plugin_get_type(void);

// Función de registro del plugin en Linux
FLUTTER_PLUGIN_EXPORT void ti_printer_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_TI_PRINTER_PLUGIN_H_
