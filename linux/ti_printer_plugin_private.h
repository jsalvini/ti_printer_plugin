#ifndef FLUTTER_PLUGIN_TI_PRINTER_PLUGIN_PRIVATE_H_
#define FLUTTER_PLUGIN_TI_PRINTER_PLUGIN_PRIVATE_H_

#include <flutter_linux/flutter_linux.h>

#include "include/ti_printer_plugin/ti_printer_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Handles the getPlatformVersion method call.
FlMethodResponse *get_platform_version();

#endif // FLUTTER_PLUGIN_TI_PRINTER_PLUGIN_PRIVATE_H_
