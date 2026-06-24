Análisis integral · subsistema de impresión

# Subsistema de ImpresiónAuto-Compra POS + ti\_printer\_plugin · dossier completo

Documento único que cubre los dos componentes que forman el subsistema: el plugin nativo `ti_printer_plugin v1.0.9` (capa C/C++ y librería Dart) y la integración Flutter en la app de auto-servicio. Incluye el análisis completo de ambos, los diagramas de arquitectura y cascada causal, los 22 hallazgos del plugin con sus parches, los 12 fixes de la app con código antes / después, el orden de ejecución end-to-end y los protocolos de verificación.

Fecha23 · 06 · 2026

AudienciaDev a cargo de fixes

Hallazgos totales34 · 22 plugin · 12 app

Plugin nativoPatches ya aplicados

Índice

[01Resumen ejecutivo](https://autoservicio-impresion-20260622.pages.dev/#resumen)[02Cadena causal del incidente](https://autoservicio-impresion-20260622.pages.dev/#cascada)[03Arquitectura integral](https://autoservicio-impresion-20260622.pages.dev/#arq-integral)[04Plugin · stack y zonas](https://autoservicio-impresion-20260622.pages.dev/#plg-pipeline)[05Plugin · severidad](https://autoservicio-impresion-20260622.pages.dev/#plg-severity)[06Plugin · hallazgos](https://autoservicio-impresion-20260622.pages.dev/#plg-findings)[07Plugin · archivos patchados](https://autoservicio-impresion-20260622.pages.dev/#plg-patched)[08App · mapa por capa](https://autoservicio-impresion-20260622.pages.dev/#app-arch)[09App · plan](https://autoservicio-impresion-20260622.pages.dev/#app-plan)[10App · fixes detallados](https://autoservicio-impresion-20260622.pages.dev/#app-fixes)[11Orden end-to-end](https://autoservicio-impresion-20260622.pages.dev/#orden)[12Verificación](https://autoservicio-impresion-20260622.pages.dev/#verify)

## 01Resumen ejecutivo

El problema en una oración

El subsistema de impresión falla en ****dos capas simultáneamente****: el plugin nativo tiene bugs de bajo nivel (handle USB sin inicializar, timeouts ausentes, lectura de status truncada a un byte, QR limitado a 252 bytes, etc.) y la app encima lo usa mal (no cierra el puerto, trata "bytes aceptados" como "ticket impreso", el interpreter por defecto es ciego al papel, no hay idempotencia por voucher). Los síntomas operativos —impresora "fuera de servicio", reinicios para recuperar, bucle de reimpresión— son la suma de ambas capas.

El plugin ya tiene ****9 patches aplicados**** en una entrega previa (sección 07). La app necesita ****12 fixes**** agrupados en P0/P1/P2 (secciones 09 y 10). El orden end-to-end importa: hay fixes de app que __dependen__ de que el plugin esté patcheado para tener efecto.

-   ****Plugin**** 22 hallazgos · 10 críticos · 9 ya patcheados
-   ****App**** 12 fixes · 6 P0 · 3 P1 · 3 P2
-   ****Incidente**** 22 / 06 / 2026 · bucle de reimpresión + "fuera de servicio"
-   ****Camino crítico**** Plugin patcheado → App FIX 01 → 04 → 05 → 06

### Por qué necesita fixes en las dos capas

Un fix sólo en el plugin no es suficiente: aunque el plugin ahora tenga timeout real en `ReadStatusUsb` y devuelva todos los bytes leídos, la app sigue tratando "bytes aceptados por el endpoint USB" como "ticket impreso" (Causa D). Un fix sólo en la app tampoco alcanza: aunque la app haga confirmación post-envío, si el plugin no tiene timeout, una lectura USB colgada deja la confirmación esperando indefinidamente.

Los fixes son complementarios — los del plugin dan las herramientas, los de la app las usan correctamente. Esta es la motivación de tenerlos juntos en un solo documento.

## 02Cadena causal del incidente

Reconstrucción de la secuencia entre la falla física (cable USB) y los síntomas en la app y en el hardware de la impresora, anclando cada paso a la causa raíz que lo origina. El timing es aproximado pero el orden de eventos refleja el código actual.

Fig. 02-A — Cascada del incidente22 jun 2026 · 00:00T0T1T2T3T4T5FÍSICOCable USBdefectuosoRed de serviciode cobro caídaCAUSA A3 reiniciosde la appCada reinicio dejahandle huérfanoCAUSA AReconnectfalla loopopenUsbPort retornafalse (sharing)CAUSA DApp reporta"impreso OK"Bytes en bufferdel firmwareCAUSA BBucle dereimpresiónRecovery vacía elbuffer de golpe (×3)WORKAROUNDCambio deimpresoraReset físico delbuffer firmwareSÍNTOMA OBSERVADOCobro caído"Impresorafuera de servicio"No recuperasin reiniciarUI: comprobanteimpreso (sin papel)3 ticketsduplicadosOperaciónrestauradaFIX QUE CORTA LA CADENA EN CADA PUNTOFIX AcloseUsbPort()en el \_safeCloseFIX C + DLeer DLE EOT 4 +confirmar post-envíoFIX BIdempotenciapor voucher

### Causas raíz

Cada causa es independiente y produce su propio síntoma observable; combinadas amplifican el daño. Las cuatro son ****P0****.

Causa A · P0

#### Handle USB nunca se libera

`_safeCloseUsbPort()` tiene el `closeUsbPort()` comentado. Tras cualquier corte (cable, energía, kill), el handle del SO queda huérfano.

App muestra "fuera de servicio"; sólo recupera reiniciando el proceso.

Causa B · P0

#### Sin idempotencia por voucher

Cuando la impresora no procesa, los bytes se quedan en el buffer del firmware. La app + las reimpresiones manuales + el reconnect re-envían todo el set sin tracking de "cuál salió de verdad".

Bucle de reimpresión al recuperar — el buffer se vacía de golpe.

Causa C · P0

#### Control de "listo" ciego al papel

El interpreter TM-T20IIIL no lee `paperResponse` y devuelve `hasPaper:true` forzado. Encima, es el fallback silencioso cuando la detección de modelo falla — que es __siempre__ en Windows USB.

Impresora sin papel pasa el gate `isReadyToPrint` e intenta imprimir.

Causa D · P0

#### "Enviar" no confirma impresión

`sendCommandToUsb` devuelve `true` cuando el endpoint USB acepta el buffer. El BLoC emite `PrintStatus.success` con eso. No se relee el estado.

UI dice "impreso" aunque la impresora esté offline o sin papel.

## 03Arquitectura integral · ambos componentes

Diagrama de las 8 capas que atraviesa un byte desde el evento de UI en la app de self-checkout hasta el cabezal térmico de la impresora. Las primeras 4 viven en el código de la app (`auto-compra/lib/`), las siguientes 4 en el plugin (`ti_printer_plugin/`). La línea horizontal marca el límite entre ambos repos.

Fig. 03 — Stack completoApp + PluginREPO · AUTO-COMPRAUI · views/management\_printer · management\_ticket · result\_payment · sharedVIEWMODEL · viewmodels/printer/PrinterBloc (printer\_bloc.dart · 2070 líneas)SERVICE · services/printer/UsbPrinterService · SerialPrinterService · interpretersPLUGIN DART · lib/TiPrinterPlugin · esc\_pos\_utils\_platform (generator · qrcode · ...)REPO · TI\_PRINTER\_PLUGINMETHOD CHANNELPlataforma Flutter ↔ Nativo (serializado por canal)NATIVO · C/C++windows/ti\_printer\_plugin.cpp · linux/ti\_printer\_plugin.ccSISTEMA OPERATIVOCreateFile · WriteFile · ReadFile / open · write · read · selectHARDWAREImpresora térmica ESC/POS · cable USB · cabezalFIXES POR CAPAAPP-11 · build\_vale\_listener leakAPP-05 · confirmar post-envíoAPP-06 · idempotencia por voucherAPP-01 · closeUsbPort · APP-02 · serial closeAPP-03 · serial sendCommand · APP-04 · interpreterAPP-07 · timeouts · APP-08 · testConnectionPLG-04 · QR length · PLG-05 · QR utf8PLG-06 · beep · PLG-09/10 · PLG-11/12/13PLG-14 · args inconsistentesPLG-01 · hUsb\_ uninit · PLG-02 · read truncadoPLG-03 · timeout USB · PLG-15/19/21/22PASANTE — sin fixes propios(usado por capa 6, no se modifica)FUERA DE ALCANCE

Los símbolos PLG-XX referencian hallazgos del plugin (sección 06). Los APP-XX referencian fixes de la app (sección 10). El color indica severidad: rojo P0, ámbar P1, verde P2.

## 04Plugin · stack y zonas afectadas

Mapa del recorrido de un byte desde que se construye el ticket en Dart hasta que llega al cabezal térmico, con los IDs de hallazgo de esta auditoría posicionados donde efectivamente viven en el código.

Fig. 01 — Pipeline ESC/POSv1.0.9DART · LIBesc\_pos\_utilsgenerator · qrcodepos\_styles · barcodeDART · PLUGINMethodChannelti\_printer\_plugin.dart+ platform\_interfaceNATIVO · C/C++Plugin nativowindows/ti\_printer\_plugin.cpplinux/ti\_printer\_plugin.ccI/O · SOUSB / SerialCreateFile · WriteFile/dev/usb/lp · ttyUSBHARDWAREImpresoratérmica ESC/POSEpson · Bixolon · …HALLAZGOS04 · 05 · 06 · 0708 · 09 · 1011 · 12 · 13HALLAZGOS14HALLAZGOS01 · 02 · 0315 · 1921 · 22HALLAZGOS16 · 17 · 1820

## 05Plugin · conteo por severidad

Criterio: ****crítico**** = afecta correctitud, puede colgar la app o corromper el ticket en escenarios reales; ****latente**** = falla sólo en casos borde (texto vacío, payloads grandes, datos no-ASCII); ****smell**** = funciona pero confunde a quien lo lea o derrocha bytes / recursos.

Crítico****10****Correctitud comprometida o riesgo de freeze en producción.

Latente****07****Casos borde y comportamientos rotos en configuraciones puntuales.

Smell****05****Funciona pero suma deuda técnica o desperdicia ciclos.

## 06Plugin · hallazgos detallados

22 hallazgos en total. Cada uno con archivo, línea y un fragmento __antes / después__. Los fragmentos están reducidos a lo mínimo necesario para mostrar la diferencia; la versión completa de cada archivo parcheado va en la sección siguiente.

****PLG-01Crítico****handle USB · construcción

### hUsb\_ no se inicializa en el constructor

windows/ti\_printer\_plugin.cpp · línea 48

El constructor sólo inicializa `hSerial_`. `hUsb_` queda con basura de memoria, por lo que el check `if (hUsb_ != INVALID_HANDLE_VALUE)` del destructor casi nunca da falso y termina ejecutando `CloseHandle()` sobre un valor indeterminado. Además, si alguien llama a `sendCommandToUsb` antes de `openUsbPort`, el check de "puerto no abierto" puede fallar y entrar al `WriteFile` sobre el handle basura.

Antes

TiPrinterPlugin()  
  : hSerial\_(INVALID\_HANDLE\_VALUE) {}

Después

TiPrinterPlugin()  
  : hSerial\_(INVALID\_HANDLE\_VALUE),  
    hUsb\_(INVALID\_HANDLE\_VALUE) {}

****PLG-02Crítico****I/O · lectura de estado

### ReadStatusUsb y ReadStatusSerial truncan a 1 byte

windows/ti\_printer\_plugin.cpp · líneas 412 y 602 · linux/ti\_printer\_plugin.cc · línea 218

El código devuelve sólo el primer byte del buffer leído, descartando el resto. Los comandos `DLE EOT 1/2/4` retornan un byte, pero `ESC u` y los __auto status back__ de varias Epson devuelven streams de 2+ bytes. La versión correcta estaba comentada justo arriba.

Antes

if (bytes\_read > 0) {  
  return { static\_cast<uint8\_t>(response\[0\]) };  
}

Después

std::vector<uint8\_t> result;  
if (bytes\_read > 0) {  
  result.assign(response, response + bytes\_read);  
}  
return result;

****PLG-03Crítico****I/O · timeout USB Windows

### ReadFile USB sin timeout — bloquea indefinidamente

windows/ti\_printer\_plugin.cpp · ReadStatusUsb (línea ~593)

El handle USB se abría sin `FILE_FLAG_OVERLAPPED` y la lectura era síncrona y bloqueante. Si la impresora está apagada o desconectada, `ReadFile` espera para siempre. Combinado con un `Timer.periodic(3s)` de monitor de estado, una impresora apagada freeza toda la app o apila llamadas en cola.

En Linux esto está bien resuelto con `select()` + `timeout 500 ms`. En Windows hay que abrir overlapped y usar `WaitForSingleObject` + `CancelIoEx`.

Después · OpenUsbPort + ReadStatusUsb

__// 1) Abrir overlapped__  
hUsb\_ = CreateFile(..., FILE\_ATTRIBUTE\_NORMAL | FILE\_FLAG\_OVERLAPPED, NULL);  
  
__// 2) ReadStatusUsb con timeout real__  
OVERLAPPED overlapped = {};  
overlapped.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);  
  
BOOL ok = ReadFile(hUsb\_, response, sizeof(response), &bytes\_read, &overlapped);  
if (!ok && GetLastError() == ERROR\_IO\_PENDING) {  
  DWORD wait = WaitForSingleObject(overlapped.hEvent, 500);  
  if (wait != WAIT\_OBJECT\_0) {  
    CancelIoEx(hUsb\_, &overlapped);  __// timeout → cancelo la pending I/O__  
    ...  
  }  
}

****PLG-04Crítico****QR · longitud

### QR Code limitado silenciosamente a 252 bytes de payload

lib/esc\_pos\_utils\_platform/src/qrcode.dart · línea 60

El comando `GS ( k pL pH cn fn ...` codifica el tamaño del payload en dos bytes (pL + pH×256). El código hardcodea `pH = 0x00` y mete `textBytes.length + 3` en pL. Cualquier QR con más de 252 bytes hace overflow silencioso y la impresora interpreta basura. URLs largas de ARCA con muchos parámetros caen acá.

Antes

bytes += cQrHeader.codeUnits +  
  \[textBytes.length + 3, 0x00, 0x31, 0x50, 0x30\];

Después

final int storeLen = textBytes.length + 3;  
final int pL = storeLen & 0xFF;  
final int pH = (storeLen >> 8) & 0xFF;  
bytes += cQrHeader.codeUnits +  
  \[pL, pH, 0x31, 0x50, 0x30\];

****PLG-05Crítico****QR · encoding

### latin1.encode para datos de QR — rompe con cualquier carácter fuera de 0x00–0xFF

lib/esc\_pos\_utils\_platform/src/qrcode.dart · línea 57

Un QR carga binario y los lectores móviles decodifican UTF-8 por estándar. Con `latin1.encode`, cualquier emoji, kanji o símbolo fuera de Latin-1 (un `€` en ciertos casos, ideogramas) tira `ArgumentError`. Y si el dato sí pasa, el celular puede interpretarlo distinto al servidor.

Antes

List<int> textBytes = latin1.encode(text);

Después

final List<int> textBytes = utf8.encode(text);

****PLG-06Crítico****generator · beep

### beep() recursivo descarta el retorno

lib/esc\_pos\_utils\_platform/src/generator.dart · línea 481

El comando ESC/POS `ESC B n t` tiene `n` tope en 9, por eso se hace recursión para n > 9. Pero el resultado del llamado recursivo no se concatena a `bytes`, así que `beep(n: 20)` emite sólo UNA tanda de 9 beeps.

Antes

bytes += Uint8List.fromList(...);  
  
beep(n: n - 9, duration: duration);  __// retorno descartado__  
return bytes;

Después

bytes += Uint8List.fromList(...);  
  
if (n > 9) {  
  bytes += beep(n: n - 9, duration: duration);  
}  
return bytes;

****PLG-07Crítico****generator · oldRrow

### oldRrow() pierde el wrap de columnas que se desborda

lib/esc\_pos\_utils\_platform/src/generator.dart · línea 600

Si una columna excede su ancho, la fila siguiente se calcula y se acumula en `nextRow`, pero el llamado a `row(nextRow)` descarta el retorno. Resultado: el texto wrapeado no se imprime nunca. El método nuevo `row()` (línea 736) ya lo hace bien, pero `oldRrow` sigue en el API público.

Antes

if (isNextRow) {  
  row(nextRow);  __// se calcula y se tira__  
}

Después

if (isNextRow) {  
  bytes += row(nextRow);  
}

****Sugerencia adicional:**** deprecar `oldRrow` y dejar sólo `row()`. El sufijo `old` ya da la pista.

****PLG-08Crítico****encoding · codeTable

### \_encode() ignora el codeTable del PosStyles

lib/esc\_pos\_utils\_platform/src/generator.dart · línea 99

`setStyles` manda `ESC t n` a la impresora para que ésta interprete los bytes según un code page (CP437, CP858, CP1252, etc.), pero los bytes se generan SIEMPRE con `latin1.encode` independientemente del codeTable elegido. Por suerte Latin-1 es compatible byte-a-byte con CP1252, CP850, CP858 e ISO\_8859-15 para los acentos comunes del español. Pero con CP437 (default histórico):

-   ****ñ**** en CP437 va en 0xA4 — acá se manda 0xF1 que en CP437 es ****±****
-   ****°**** en CP437 va en 0xF8 — acá se manda 0xB0 que en CP437 es ****░****

Footgun real: el dev tiene que acordarse de poner `codeTable: 'CP1252'` en CADA `PosStyles` con tildes. Si una se olvida, sale quilombo. El default de `PosStyles.defaults` es CP437, lo que es engañoso porque no concuerda con el encoding.

****Fix bajo:**** documentar la limitación + cambiar el default a `CP1252`.  
****Fix correcto:**** reemplazar `latin1.encode` por una conversión basada en el codeTable activo (paquete `charset_converter` o equivalente). Refactor de medio día.

****PLG-09Crítico****generator · lexemes

### \_getLexemes("") tira RangeError

lib/esc\_pos\_utils\_platform/src/generator.dart · línea 120

Accede a `text[0]` sin chequear si el string está vacío. Si llega un `PosColumn(text: '', ...)` o un wrap que deja restos vacíos, explota.

Antes

List \_getLexemes(String text) {  
  ...  
  bool curLexemeChinese = \_isChinese(text\[0\]);  
  ...  
}

Después

List \_getLexemes(String text) {  
  ...  
  if (text.isEmpty) {  
    return <dynamic>\[lexemes, isLexemeChinese\];  
  }  
  bool curLexemeChinese = \_isChinese(text\[0\]);  
  ...  
}

****PLG-10Crítico****generator · precedencia

### \_intLowHigh con paréntesis mal en la cota máxima

lib/esc\_pos\_utils\_platform/src/generator.dart · línea 148

Por precedencia de operadores, la expresión se evalúa como `256 << ((bytesNb * 8) - 1)`, dando para `bytesNb = 2` un máximo de `8.388.608` en lugar de `65.535`. La validación es 128× más permisiva y el bucle posterior trunca silenciosamente los bytes excedentes. Imágenes muy grandes pueden generar headers con tamaño truncado.

Antes

final dynamic maxInput = 256 << (bytesNb \* 8) - 1;

Después

final dynamic maxInput = (256 << (bytesNb \* 8)) - 1;

****PLG-11Latente****generator · dead code

### Condiciones imposibles dentro de row()

lib/esc\_pos\_utils\_platform/src/generator.dart · líneas 661–687

Dentro de `if (realCharactersNb > maxCharactersNb)` aparecen ternarios del estilo `realCharactersNb < maxCharactersNb ? ... : ...` cuya rama "verdadero" es inalcanzable. Después una asignación `isNextRow = true` redundante. Funciona pero confunde y hace pensar que falta un caso.

Después · simplificado

if (realCharactersNb > maxCharactersNb) {  
  final Uint8List encodedToPrintNextRow =  
      encodedToPrint.sublist(maxCharactersNb);  
  encodedToPrint = encodedToPrint.sublist(0, maxCharactersNb);  
  isNextRow = true;  
  
  nextRow.add(PosColumn(  
    textEncoded: encodedToPrintNextRow,  
    width: cols\[i\].width,  
    styles: cols\[i\].styles));  
  
  bytes += \_text(encodedToPrint, ...);  
}

****PLG-12Latente****generator · round-trip

### String.fromCharCodes(bytes).trim() para pasar el wrap a la fila siguiente

lib/esc\_pos\_utils\_platform/src/generator.dart · línea 671

Toma los bytes ya encodeados, los pasa a String con `fromCharCodes` (que interpreta cada byte como codepoint Unicode), y la siguiente iteración los vuelve a encodear. Funciona porque Latin-1 ≡ codepoints 0–255, pero:

-   Si `_encode` deja de ser Latin-1 (ver #08), rompe en silencio.
-   El `.trim()` al final se come espacios intencionales en columnas con alineación a la derecha.

Mejor pasar el `textEncoded` directo y evitar el round-trip — el `PosColumn` ya soporta `textEncoded` como parámetro.

****PLG-13Latente****generator · drawImage

### Asignación dentro del ternario en drawImage

lib/esc\_pos\_utils\_platform/src/generator.dart · línea 1061

Funciona por casualidad pero es código ofuscado. La línea siguiente (`dstH`) ya es la versión limpia — esta no debería disonar.

Antes

dstW ??= (dst.width < src.width)  
    ? dstW = dst.width  
    : src.width;

Después

dstW ??= (dst.width < src.width)  
    ? dst.width  
    : src.width;

****PLG-14Latente****method channel · args

### Inconsistencia en el shape de argumentos del MethodChannel

lib/ti\_printer\_plugin\_method\_channel.dart

Algunas llamadas pasan el comando como argumento posicional (`Uint8List` directo) y otras lo envuelven en un `Map`:

-   `sendCommandToSerial` · `sendCommandToUsb` → mandan `command` directo
-   `readStatusSerial` · `readStatusUsb` → mandan `{ 'command': command }`

El nativo refleja esa inconsistencia. Cualquiera que extienda el API se va a equivocar. Unificar a `Map` con nombres explícitos da espacio para crecer sin breaking changes.

****PLG-15Latente****WriteFile · partial write

### SendCommandToUsb no reintenta escritura parcial

windows/ti\_printer\_plugin.cpp · SendCommandToUsb

Detecta `bytes_written != data_size` pero sólo marca como error, sin re-enviar el remanente. Para drivers `usbprint` es raro, pero si sucede dejás media factura en el stream y la impresora queda en un estado feo. En Linux esto está bien hecho con un `while (left > 0)` (línea 139).

Después · Windows con loop

while (remaining > 0) {  
  ...  
  BOOL ok = WriteFile(hUsb\_, ptr, remaining, &bytes\_written, &overlapped);  
  ...  
  if (bytes\_written == 0) return false;  
  ptr += bytes\_written;  
  remaining -= bytes\_written;  
}

****PLG-16Latente****enumeración · Windows

### ListUsbInstance filtra sólo service == "usbprint"

windows/ti\_printer\_plugin.cpp · ListUsbInstance

Excluye impresoras con driver propietario: Epson Advanced Printer Driver, EpsonNet, OPOS, POS for .NET. En entornos POS Argentina muchas TM-T20III usan el driver de Epson y no aparecen en la lista.

****Camino sugerido:**** agregar fallback enumerando por `Class GUID = {4d36e979-e325-11ce-bfc1-08002be10318}` (printers) o devolver todos los USB y exponer VID/PID para que el caller filtre.

****PLG-17Latente****linux · serial stub

### Linux serial devuelve false silencioso en lugar de NotImplemented

linux/ti\_printer\_plugin.cc · líneas 252–271

El caller no puede distinguir "no hay soporte en esta plataforma" de "falló". Devolver `fl_method_not_implemented_response_new()` o un `PlatformException` con código `"UNSUPPORTED"` es más honesto.

****PLG-18Latente****linux · enumeración

### getUsbPrinters trae cualquier ttyUSB / ttyACM

linux/ti\_printer\_plugin.cc · list\_usb\_printers

Aparecen Arduinos, módems 4G, GPS, lectores RFID, conversores FT232/CH340. Para una UI termina siendo confuso. Filtrar por VID/PID conocidos (Epson `0x04B8`, Star Micronics `0x0519`, Bixolon `0x1504`) o leer `/sys/class/usbmisc/lp*/device/idVendor` levanta la señal.

****PLG-19Latente****encoding · win32

### OpenUsbPort hace string→wstring byte-a-byte

windows/ti\_printer\_plugin.cpp · OpenUsbPort

Sólo es correcto para ASCII puro. Los InstanceIDs de Windows son ASCII en la práctica, pero la función `convertWStringToString` hace UTF-8 correcto en el camino de vuelta — la inversa debería ser simétrica con `MultiByteToWideChar(CP_UTF8, ...)`.

Antes

std::wstring target(  
  device\_instance\_id.begin(),  
  device\_instance\_id.end());

Después

int sizeNeeded = MultiByteToWideChar(  
  CP\_UTF8, 0,  
  device\_instance\_id.c\_str(), -1,  
  NULL, 0);  
std::vector<wchar\_t> buf(sizeNeeded);  
MultiByteToWideChar(CP\_UTF8, 0,  
  device\_instance\_id.c\_str(), -1,  
  buf.data(), sizeNeeded);  
std::wstring target(buf.data());

****PLG-20Smell****pubspec

### capabilities.json declarado dos veces en assets

pubspec.yaml + lib/resources/ + assets/resources/

Hay dos copias idénticas (5.110 bytes c/u) y `pubspec.yaml` declara ambas paths en `assets:`. El código carga `packages/ti_printer_plugin/resources/capabilities.json` únicamente — la otra es muerta. Sobra el archivo o sobra la entrada del pubspec.

****PLG-21Smell****destructor

### Destructor usa CloseHandle directo en USB pero el método CloseSerialPort en serial

windows/ti\_printer\_plugin.cpp · ~TiPrinterPlugin

Inconsistencia menor. Si el destructor se invoca dos veces (no debería pasar pero…), USB hace double-close porque `CloseHandle` directo no setea `hUsb_` a `INVALID_HANDLE_VALUE`. Llamar a `CloseUsbPort()` simétrico al serial elimina ese filo.

****PLG-22Smell****código muerto

### OVERLAPPED + CreateEvent + GetOverlappedResult en handles síncronos

windows/ti\_printer\_plugin.cpp · SendCommandToSerial, SendCommandToUsb (versión original)

Los handles se abrían sin `FILE_FLAG_OVERLAPPED`, así que toda la ceremonia `OVERLAPPED` + `CreateEvent` + check de `ERROR_IO_PENDING` + `GetOverlappedResult` es código muerto: nunca se entra a la rama PENDING porque la I/O es síncrona. Genera trabajo desperdiciado en cada write y oculta la intención del código (parece async cuando no lo es).

Después del fix de #03, el handle USB sí queda overlapped y el código de async cobra sentido. En serial se simplificó a write síncrono limpio con `SetCommTimeouts`.

## 07Plugin · archivos parcheados

Cada archivo lleva los IDs de hallazgo aplicados como comentario `// FIX #N` in-line. Reemplazo directo del archivo original — no son diffs incrementales.

windows/ti\_printer\_plugin.cpp→ reemplaza el archivo en windows/

-   ****#01**** · `hUsb_` inicializado en INVALID\_HANDLE\_VALUE
-   ****#02**** · `ReadStatusUsb` y `ReadStatusSerial` devuelven todos los bytes
-   ****#03**** · USB abierto con `FILE_FLAG_OVERLAPPED`, I/O async con timeout y `CancelIoEx`
-   ****#15**** · `SendCommandToUsb` con loop por escritura parcial
-   ****#19**** · Conversión UTF-8 → UTF-16 con `MultiByteToWideChar`
-   ****#21**** · Destructor usa `CloseUsbPort()` simétrico
-   ****#22**** · OVERLAPPED muerto removido de `SendCommandToSerial`

linux/ti\_printer\_plugin.cc→ reemplaza el archivo en linux/

-   ****#02**** · `read_status_usb` devuelve todos los bytes leídos en lugar de `buffer[0]`

lib/esc\_pos\_utils\_platform/src/generator.dart→ reemplaza el archivo de la librería ESC/POS

-   ****#06**** · `beep()` recursivo concatena retornos
-   ****#07**** · `oldRrow` concatena el wrap
-   ****#08**** · Comentario detallado documentando la limitación de codeTable
-   ****#09**** · `_getLexemes("")` protegido contra string vacío
-   ****#10**** · `_intLowHigh` con paréntesis correctos
-   ****#11 · #12**** · Limpieza de código muerto en `row()` y eliminación del round-trip bytes→String→trim
-   ****#13**** · `drawImage` sin asignación dentro del ternario

lib/esc\_pos\_utils\_platform/src/qrcode.dart→ reemplaza el archivo de QR

-   ****#04**** · pL / pH con split de 16 bits — soporta payloads > 252 bytes
-   ****#05**** · `utf8.encode` en lugar de `latin1.encode`

## 08App · mapa de bugs por capa

Las 6 capas que atraviesa un byte desde el evento de UI hasta el cabezal térmico, con los IDs de fix ubicados donde efectivamente viven en el código de la app. Los fixes del plugin nativo (sección 07) son externos a este árbol.

UI · viewsmanagement\_printer / management\_ticket / shared / result\_paymentVIEWMODEL · BLoCPrinterBloc (printer\_bloc.dart, 2070 líneas)SERVICEUsbPrinterService / SerialPrinterService\_safeCloseUsbPort · \_safeCloseSerialPort · connect · sendRawData · checkStatus+ StatusInterpreterFactory + Tm/Rpt interpretersPLUGIN DARTti\_printer\_plugin · MethodChannelNATIVO C/C++windows/ti\_printer\_plugin.cpp · linux/ti\_printer\_plugin.ccHARDWAREUSB driver SO · impresora ESC/POSFIX IDS POR CAPAP2 · build\_vale\_listenerB · loop vouchers · D · success post-envíoP1 · timeouts · P1 · retry idempotenteP2 · spin-wait · P2 · clearPrintMessageA · closeUsbPort · A2 · closeSerialPortA3 · serial→sendCommandToUsbA4 · connect mismo device · C · interpreterA5 · testConnection · A8 · cache devicesA11 · logs mienten · A12 · disposeA9 · instancias compartidas(sin fixes propios — pasante)PATCHADO · ver §079 fixes aplicados en entrega previaFUERA DE ALCANCE

## 09App · plan de remediación

Orden recomendado de ejecución. El orden combina: ****impacto**** en el síntoma observable, ****independencia**** (puede mergearse solo) y ****esfuerzo****. Cada fix es atómico y se valida contra los pasos de la sección 06.

1.  Habilitar `closeUsbPort()` y `closeSerialPort()`Causa A · descomentar la llamada al plugin en `_safeClose*Port`, garantizar cierre antes de cada `open`, alinear logs con la realidad. Pequeño y desbloquea recuperación sin reiniciar.
    
    ****P0**** #A1 + #A2
    
2.  Short-circuit en `connect()` cuando es el mismo deviceMi #A4 · si `_currentConfig?.devicePath == config.devicePath`, retornar `true` sin re-abrir. Hacerlo en el mismo PR de #1 porque viven en la misma función.
    
    ****P0**** #A4
    
3.  `SerialPrinterService.sendRawBytes` debe usar `sendCommandToSerial`Mi #A3 · hoy llama a `sendCommandToUsb` por error. Si tu flota tiene aunque sea una térmica por RS-232, es bloqueante. Si todas son USB, podés bajar a P1.
    
    ****P0**** #A3
    
4.  Detección de modelo + lectura de papel en T20IIILCausa C · matchear por VID/PID en `detectModel` (o pedirlo a la UI). Replicar la lectura de `paperResponse` del RPT008 al TM-T20IIIL. Eliminar el `hasPaper:true` forzado.
    
    ****P0**** Causa C
    
5.  Confirmar estado tras enviarCausa D · al final del envío, releer DLE EOT y emitir `PrintStatus.success` sólo con `isOnline && hasPaper && !hasError`. Si no, `PrintStatus.error`.
    
    ****P0**** Causa D
    
6.  Idempotencia por voucherCausa B · tag único por voucher, registro de "intentos enviados / confirmados". El reconnect no debe reenviar vouchers ya aceptados-y-confirmados. Sin esto, el bucle de duplicados sigue siendo posible.
    
    ****P0**** Causa B
    
7.  Timeouts en lecturas y envíosP1 ayer · envolver `readStatusUsb` y `sendCommandToUsb` con `.timeout()`. Tratar timeout como no-listo / error, no como éxito.
    
    ****P1**** Timeouts
    
8.  `testConnection` respeta conexión activaMi #A5 · si hay conexión activa, no tocar handles — sólo verificar en la lista de devices. Sin esto, un "test" rompe la conexión real.
    
    ****P1**** #A5
    
9.  Invalidación del cache de devices en erroresMi #A8 · cuando la comunicación falla, marcar el cache de `getUsbPrinters` como vencido para que la próxima detección de presencia consulte fresco.
    
    ****P1**** #A8
    
10.  Logs que no mientanP2 · "Puerto USB cerrado correctamente" se loguea hoy aunque el close esté comentado. Después del fix #1 el log se vuelve verdadero; mientras tanto, ajustar texto.
     
     ****P2**** #A11
     
11.  Limpiar dead code y leaks menoresP2 · spin-wait que no espera nada, `clearPrintMessage` inconsistente, `PrinterStatusHandler` sin `listenWhen` (no se usa), suscripción colgada en `build_vale_listener`.
     
     ****P2**** Higiene
     
12.  Instancia única del pluginP2 · pasar el mismo `TiPrinterPlugin` a USB y Serial services para que sea claro que comparten estado nativo. Cosmético.
     
     ****P2**** #A9
     

## 10App · fixes detallados

Cada fix tiene contexto, ubicación exacta, código antes / después e impacto operativo. Los snippets están reducidos al diff mínimo; el archivo entero queda inalterado en lo demás.

****FIX 01P0 · Causa A****service · usb

### Habilitar el cierre real del puerto USB

lib/services/printer/usb\_printer\_service.dart · líneas 343–352

Síntoma

Cliente reporta "impresora apagada y fuera de servicio". Sólo se recupera reiniciando el proceso de la app. Tras un corte de cable USB o energía, los reconnect del BLoC fallan con `openUsbPort → false`.

Causa raíz

El `_plugin.closeUsbPort()` está comentado dentro de `_safeCloseUsbPort()`. El handle queda abierto a nivel del SO. El próximo `openUsbPort` sobre el mismo dispositivo falla con `ERROR_SHARING_VIOLATION` (porque el plugin nativo abre con `dwShareMode = 0`).

Fix

Antes

Future<void> \_safeCloseUsbPort() async {  
  if (\_currentConfig == null) return;  
  
  try {  
    __// await \_plugin.closeUsbPort();__  
    \_log('Puerto USB cerrado correctamente');  
  } on Exception catch (e) {  
    \_log('Error al cerrar puerto USB (ignorado): $e');  
  }  
}

Después

Future<void> \_safeCloseUsbPort() async {  
  if (\_currentConfig == null) return;  
  
  try {  
    final ok = await \_plugin.closeUsbPort();  
    \_log('closeUsbPort -> $ok');  
  } catch (e) {  
    \_log('Error al cerrar puerto USB (ignorado): $e');  
  }  
}

Verificación

Conectar USB, esperar status connected, sacar y reinsertar el cable USB durante una sesión. La app debe recuperar automáticamente sin reiniciar el proceso. Ver §06-V1.

****Impacto:**** corta el bucle de "reiniciar para recuperar". Es la única causa P0 que se arregla en menos de 10 líneas de código y desbloquea el resto del trabajo.

****FIX 02P0 · #A4****service · usb

### Short-circuit en `connect()` cuando es el mismo dispositivo

lib/services/printer/usb\_printer\_service.dart · líneas 132–144

Síntoma

Apretar "reconectar" sobre una impresora ya conectada falla con error. Especialmente molesto después del fix #1: ahora que el close sí cierra, reconectar a la misma impresora va a la rama "mismo dispositivo" que NO cierra pero igual intenta `openUsbPort`, que falla porque el handle sigue abierto.

Causa raíz

La rama dice `'Ya conectado a este dispositivo, omitiendo close...'` pero acto seguido resetea `_currentConfig` y llama `openUsbPort` igual. La intención parece haber sido un short-circuit, pero el código nunca corta. En Windows, `CreateFile` con `dwShareMode=0` sobre un handle ya abierto retorna `ERROR_SHARING_VIOLATION`.

Fix

Después

try {  
  \_log('Conectando a: ${config.devicePath}');  
  
  __// Short-circuit: si ya estamos conectados a este mismo device, OK.__  
  if (\_currentConfig?.devicePath == config.devicePath) {  
    \_log('Ya conectado a este dispositivo, OK sin re-abrir');  
    return true;  
  }  
  
  __// Cerrar conexión previa si es distinto device__  
  await \_safeCloseUsbPort();  
  \_currentConfig = null;  
  \_interpreter = null;  
  
  final success = await \_plugin.openUsbPort(config.devicePath!);  
  \_log('openUsbPort -> $success');  
  __// ... resto idéntico__  
}

****Impacto:**** elimina el path roto en reconexiones idempotentes. Bug latente que sólo se observa cuando un usuario presiona reconectar dos veces o cuando el BLoC reintenta en situaciones intermedias.

****FIX 03P0 · #A3****service · serial

### Serial service debe usar `sendCommandToSerial`

lib/services/printer/serial\_printer\_service.dart · líneas 230–235

Síntoma

Una terminal conectada por RS-232 (COM port) imprime el status check correctamente pero NUNCA imprime tickets. La app reporta éxito.

Causa raíz

Un comentario antiguo dice __"ti\_printer\_plugin puede no tener método específico para serial"__. Es falso. El plugin tiene `sendCommandToSerial`. Pero `sendRawBytes` llama a `sendCommandToUsb` por error. El status sí funciona porque sí usa `readStatusSerial` bien.

Fix

Antes

try {  
  __// Nota: ti\_printer\_plugin puede no tener método__  
  __// específico para serial__  
  final payload = data is Uint8List  
      ? data  
      : Uint8List.fromList(data);  
  final success = await \_plugin.sendCommandToUsb(payload);  
  return success ?? false;  
}

Después

try {  
  final payload = data is Uint8List  
      ? data  
      : Uint8List.fromList(data);  
  final success = await \_plugin.sendCommandToSerial(payload);  
  return success ?? false;  
}

Aprovechá y descomentá también `closeSerialPort()` dentro de `_safeCloseSerialPort()` (mismo bug que el USB pero en serial).

****Impacto:**** binario. Si tu flota tiene una sola terminal con impresora por RS-232, hoy no imprime nada por serial. Si todas son USB, el fix es defensivo.

****FIX 04P0 · Causa C****models · interpreter + factory

### Detección de modelo + lectura de papel en T20IIIL

lib/models/printer/status\_interpreter\_factory.dart · líneas 27–54  
lib/models/printer/tmt20iiil\_status\_interpreter.dart · líneas 38–132

Síntoma

Una impresora sin papel pero online pasa el gate `isReadyToPrint`. La app intenta imprimir, `sendCommandToUsb` retorna `true` al aceptar el buffer, UI dice "comprobante impreso", no sale papel.

Causa raíz · dos problemas componiéndose

-   ****4a — Detección que nunca matchea.**** `detectModel` busca substrings tipo `"rpt008"`, `"t88v"`, `"t20iiil"` en el devicePath y displayName. En Windows USB el devicePath es el InstanceID (`USB\VID_04B8&PID_0202\...`) y el displayName es generado por `_extractDeviceName` (`"Impresora USB LP0"`). Ningún caso contiene el modelo.
-   ****4b — Fallback ciego al papel.**** Al fallar la detección, `connect()` cae a `PrinterModel.tmT20IIIL` por defecto. El `TmT20IIILStatusInterpreter` no lee `paperResponse` — devuelve `PrinterStatus.withLimitedSensors(...)` que fuerza `hasPaper:true`. El RPT008 sí lo lee.

Fix 4a · matchear por VID/PID

status\_interpreter\_factory.dart

static PrinterModel? detectModel(String? devicePath, String? displayName) {  
  if (devicePath == null && displayName == null) return null;  
  
  final searchStr = '${devicePath ?? ''} ${displayName ?? ''}'.toLowerCase();  
  
  __// Match por VID/PID (Windows USB InstanceID o /sys/.../idVendor)__  
  __// Epson TM-T20III\* → VID\_04B8 PID\_0E28 (familia)__  
  if (searchStr.contains('vid\_04b8')) {  
    if (searchStr.contains('pid\_0202')) return PrinterModel.tmT88V;  
    if (searchStr.contains('pid\_0e28')) return PrinterModel.tmT20IIIL;  
    __// Otros TM Epson — extender según hardware real__  
  }  
  __// 3nstar RPT008 — VID\_0FE6 PID\_811E (verificar con tu hardware)__  
  if (searchStr.contains('vid\_0fe6') && searchStr.contains('pid\_811e')) {  
    return PrinterModel.rpt008;  
  }  
  
  __// Matchers por nombre (mantener compat)__  
  if (searchStr.contains('rpt008') || searchStr.contains('3nstar')) {  
    return PrinterModel.rpt008;  
  }  
  __// ... resto idéntico__  
  
  return null;  
}

****Importante:**** verificar los VID/PID reales en cada equipo de la flota — abrir Device Manager → la impresora → Detalles → Hardware Ids. Los valores arriba son ejemplos, no garantías.

Fix 4b · T20IIIL aprende a leer DLE EOT 4

Replicar la lectura de papel del `Rpt008StatusInterpreter.interpretPaperStatus` (líneas 55–98 del rpt008) en el T20IIIL. Los bits relevantes en DLE EOT 4 son:

-   ****Bit 5 (0x20):**** papel cerca del fin (near-end / paper roll low)
-   ****Bit 6 (0x40):**** sin papel (paper-end)

tmt20iiil\_status\_interpreter.dart · método interpret()

PrinterStatus interpret(  
  Uint8List onlineResponse,  
  Uint8List paperResponse,  
  Uint8List offlineResponse,  
) {  
  __// ... interpret online + offline como hoy ...__  
  
  __// FIX 4b: leer DLE EOT 4 en lugar de devolver withLimitedSensors()__  
  bool hasPaper = true;  
  bool paperNearEnd = false;  
  
  if (paperResponse.isNotEmpty) {  
    final b = paperResponse\[0\];  
    paperNearEnd = (b & 0x20) != 0;  
    final paperEnd = (b & 0x40) != 0;  
    hasPaper = !paperEnd;  
  } else {  
    __// Sin respuesta: marcar como no-listo, NO como hasPaper=true__  
    hasPaper = false;  
  }  
  
  return PrinterStatus(  
    isOnline: isOnline,  
    hasPaper: hasPaper,  
    paperNearEnd: paperNearEnd,  
    isCoverOpen: isCoverOpen,  
    hasError: hasError,  
    rawOnline: onlineResponse,  
    rawPaper: paperResponse,  
    rawOffline: offlineResponse,  
    model: PrinterModel.tmT20IIIL,  
  );  
}

Y de paso, eliminar el constructor `PrinterStatus.withLimitedSensors` o al menos marcarlo `@Deprecated` — ningún modelo "limitado" debería reportar `hasPaper:true` forzado.

****Impacto:**** restaura el contrato "sin papel = error" para todas las impresoras. Combinado con el FIX 05 (confirmar post-envío), es lo que evita el síntoma "UI dice impreso pero no salió papel".

****FIX 05P0 · Causa D****viewmodel · printer\_bloc

### Confirmar estado tras enviar — "éxito" significa impreso

lib/viewmodels/printer/printer\_bloc.dart · líneas 1407–1430, 1690–1720

Síntoma

Cliente pasa el producto, la app emite `PrintStatus.success` y muestra "Comprobante impreso", pero la impresora estaba offline o sin papel. Bytes acumulan en el buffer del firmware.

Causa raíz

El BLoC trata el retorno de `sendRawData` como definitivo. `sendRawData` a su vez devuelve el retorno de `sendCommandToUsb`, que es `true` en cuanto el endpoint USB del SO acepta el buffer — sin confirmación de que la impresora procesó o emitió papel.

Fix

printer\_bloc.dart · \_onPrintReceiptEvent (extracto)

__// 4.4. Enviar datos a impresora__  
\_log('🖨️ Print: enviando ${data.length} bytes...');  
final sentOk = await \_printerService.sendRawData(data);  
  
if (!sentOk) {  
  emit(state.copyWith(  
    printStatus: PrintStatus.error,  
    printMessage: 'No se pudo enviar el recibo a la impresora',  
  ));  
  return;  
}  
  
__// 4.5. NUEVO: confirmar que efectivamente imprimió__  
__// Pequeño delay para que la impresora procese antes de re-leer__  
await Future.delayed(const Duration(milliseconds: 300));  
  
final postStatus = await \_printerService.checkStatus();  
  
if (postStatus.isReadyToPrint) {  
  \_log('✅ Print: confirmado');  
  emit(state.copyWith(  
    printStatus: PrintStatus.success,  
    printMessage: '${event.type.name} impreso',  
  ));  
} else {  
  \_log('⚠️ Print: bytes enviados pero estado no-listo tras envío');  
  emit(state.copyWith(  
    printStatus: PrintStatus.error,  
    printMessage: 'Posible falla: ${postStatus.errorMessage ?? "verificar impresora"}',  
  ));  
}

Aplicar el mismo patrón en `_onStartPrintingVouchers` (líneas 1690–1720) para que cada voucher del lote tenga su propia confirmación. Sin esto, el FIX 06 (idempotencia) no tiene cómo decidir qué reenviar y qué no.

****Impacto:**** rompe la regla "bytes aceptados = ticket impreso" que es el bug madre. Después de este fix, un equipo sin papel reporta `error` de verdad y la UI deja de mentir.

****FIX 06P0 · Causa B****viewmodel · printer\_bloc

### Idempotencia por voucher

lib/viewmodels/printer/printer\_bloc.dart · \_onStartPrintingVouchers (líneas 1646–1730)

Síntoma

Recovery tras corte → ráfaga de tickets duplicados (los "3 tickets" del incidente). El cliente recibe múltiples copias del mismo voucher.

Causa raíz

El loop de vouchers no tiene tracking de "cuál voucher fue confirmado". Combinado con la causa D (la app cree que "enviado = impreso"), las reimpresiones manuales más los reintentos del reconnect generan múltiples envíos del mismo voucher. Cuando la impresora se recupera, su buffer firmware se vacía de golpe — los 3 (o más) sets salen seguidos.

Fix · esquema

El cambio tiene varias piezas; el esqueleto:

Esquema de idempotencia

__// Nuevo modelo: VoucherJob__  
class VoucherJob {  
  final String id;          __// ID único, server-side__  
  final VoucherType type;  
  final Uint8List bytes;  
  final DateTime createdAt;  
  VoucherStatus status;    __// pending, sent, confirmed, failed__  
  int attempts;  
}  
  
__// En PrinterBloc:__  
final Map<String, VoucherJob> \_voucherJobs = {};  
  
Future<void> \_onStartPrintingVouchers(...) async {  
  for (final voucher in event.vouchers) {  
    __// Skip vouchers ya confirmados__  
    final existing = \_voucherJobs\[voucher.id\];  
    if (existing?.status == VoucherStatus.confirmed) {  
      \_log('Voucher ${voucher.id} ya confirmado, skip');  
      continue;  
    }  
  
    final job = existing ?? VoucherJob(...);  
    job.status = VoucherStatus.sent;  
    job.attempts++;  
    \_voucherJobs\[voucher.id\] = job;  
  
    final sentOk = await \_printerService.sendRawData(job.bytes);  
    if (!sentOk) { job.status = VoucherStatus.failed; continue; }  
  
    __// Aplicar FIX 05 acá: confirmar antes de marcar__  
    await Future.delayed(const Duration(milliseconds: 300));  
    final postStatus = await \_printerService.checkStatus();  
  
    job.status = postStatus.isReadyToPrint  
        ? VoucherStatus.confirmed  
        : VoucherStatus.failed;  
  }  
}

Consideraciones para el desarrollador:

-   El ID único del voucher tiene que venir del backend (no generado en cliente) para que la idempotencia sobreviva a reinicios del proceso.
-   Persistir `_voucherJobs` en Isar (ya hay infraestructura en `services/database/`) si el caso de uso lo requiere — para que un reinicio no pierda el tracking.
-   Definir política para vouchers `failed`: ¿se reintentan automáticamente? ¿requieren intervención del supervisor? Esto es decisión de producto.
-   El "lote de 3" del incidente apunta a que un set típico tiene 3 vouchers (¿comprobante + plan de pago + control?). Asegurarse que cada uno tiene ID separado del backend.

****Impacto:**** mata la posibilidad del bucle de duplicados al recuperar la impresora. Requiere el FIX 05 antes (sin confirmación post-envío, "confirmed" no significa nada).

****FIX 07P1 · Timeouts****service · usb / serial

### Timeouts en lecturas y envíos

lib/services/printer/usb\_printer\_service.dart · checkStatus + sendRawData

Síntoma

Una lectura USB colgada congela la app en `printing`; el listener de la pantalla de resultado nunca dispara y el timer de redirección no arranca → el usuario queda en pantalla negra.

Causa raíz

El plugin nativo ya tiene timeouts internos (500ms en read, 10s en write, ver §07). Pero del lado Dart no hay `.timeout()`, así que si por algún motivo el plugin no devuelve, el await se cuelga indefinido.

Fix

usb\_printer\_service.dart · checkStatus

static const \_statusReadTimeout = Duration(seconds: 1);  
static const \_sendTimeout = Duration(seconds: 15);  
  
__// En checkStatus():__  
final onlineResponse = await \_plugin  
  .readStatusUsb(onlineCmd)  
  .timeout(\_statusReadTimeout, onTimeout: () => Uint8List(0));  
  
__// En sendRawData():__  
final success = await \_plugin  
  .sendCommandToUsb(payload)  
  .timeout(\_sendTimeout, onTimeout: () => false);

****Impacto:**** garantiza que la app nunca quede congelada esperando a un plugin colgado. Defensa en profundidad sobre los timeouts del plugin nativo.

****FIX 08P1 · #A5****service · usb / serial

### `testConnection` respeta la conexión activa

lib/services/printer/usb\_printer\_service.dart · líneas 301–318

Síntoma

Apretar "test" sobre otra impresora mientras hay una conexión activa rompe la conexión real: leakea el handle de la impresora activa y deja el servicio creyendo que sigue conectado a la primera, cuando el plugin ya no la tiene.

Fix

Después

@override  
Future<bool> testConnection(PrinterConnectionConfig config) async {  
  if (config.type != PrinterConnectionType.usb) return false;  
  
  __// Si hay conexión activa, no tocar handles — sólo verificar en la lista__  
  if (\_currentConfig != null) {  
    try {  
      final devices = await \_plugin.getUsbPrinters();  
      return devices.contains(config.devicePath);  
    } catch (e) {  
      return false;  
    }  
  }  
  
  __// Sin conexión activa: abrir+cerrar es seguro__  
  try {  
    final success = await \_plugin.openUsbPort(config.devicePath!);  
    if (success == true) {  
      await \_plugin.closeUsbPort();  
      return true;  
    }  
    return false;  
  } catch (e) {  
    \_log('testConnection falló: $e');  
    return false;  
  }  
}

Aplicar el mismo patrón en `SerialPrinterService.testConnection`.

****FIX 09P1 · #A8****service · usb

### Invalidar cache de devices cuando hay falla de comunicación

lib/services/printer/usb\_printer\_service.dart · checkStatus + \_isDevicePresent

Síntoma

Detección de "impresora desconectada" puede tardar hasta ~5 segundos (2s de cache stale + 3s del polling interval).

Fix

Cuando `checkStatus` recibe respuesta vacía del DLE EOT 1, invalidar el cache antes de llamar a `_isDevicePresent`:

Después

if (onlineResponse == null || onlineResponse.isEmpty) {  
  __// FIX 09: invalidar cache para forzar consulta fresca__  
  \_lastDeviceCheck = null;  
  
  final present = await \_isDevicePresent(config.devicePath!);  
  if (!present) {  
    __// ... resto idéntico__  
  }  
}

****FIX 10P2 · #A11****service · logs

### Logs que no mientan

\_safeCloseUsbPort + \_safeCloseSerialPort

Después del FIX 01 + FIX 03, los logs "Puerto USB/serial cerrado correctamente" pasan a ser verdaderos. Si por alguna razón el FIX 01 / 03 no se mergea (¿conflictos?), cambiar el texto a algo no-engañoso:

Texto provisional si el close sigue comentado

\_log('\_safeCloseUsbPort llamado (NO-OP — close real comentado)');

****FIX 11P2 · Higiene****viewmodel · varios

### Limpiar dead code y leaks menores

Items menores, juntables en un único PR de "limpieza":

-   ****Spin-wait que no espera nada**** — `printer_bloc.dart:1283–1296`. El `while (state.isMonitoring && attempts < 10)` sale en la primera iteración porque `emit` es síncrono. Si la intención era esperar a in-flight `checkStatus`, usar un `bool _statusInFlight` y aguardar eso. Si no era nada, borrar el código.
-   **`**clearPrintMessage**`** ****inconsistente**** — comentado en recibo único, activo en vouchers múltiples. Unificar criterio.
-   **`**PrinterStatusHandler**`** ****sin**** **`**listenWhen**`** — re-dispara en cada cambio de estado. Pero el archivo parece no estar siendo usado. Si está zombi, borrar; si se usa, agregar `listenWhen: (prev, curr) => prev.printerStatus != curr.printerStatus`.
-   **`**build_vale_listener._listenForPrintCompletion**`** — abre `stream.listen` que sólo se cancela a los 10s. Si se entra dos veces antes de los 10s, apila suscripciones. Cancelar la previa al entrar nuevamente.
-   **`**PrinterStatus.withLimitedSensors**`** con `hasPaper:true` forzado — eliminar el constructor o marcarlo `@Deprecated` tras el FIX 04.

****FIX 12P2 · #A9****service · cosmetic

### Instancia única del plugin

usb\_printer\_service.dart + serial\_printer\_service.dart + PrinterServiceFactory

Hoy cada servicio hace `_plugin = TiPrinterPlugin()`. Crear instancias no aísla nada (el plugin tiene estado nativo singleton). Hacerlo explícito inyectando una sola instancia desde la factory:

printer\_service\_factory.dart

class PrinterServiceFactory {  
  static final \_plugin = TiPrinterPlugin();  
  
  static PrinterService create(  
    PrinterConnectionType type, {  
    PrinterModel? model,  
  }) {  
    switch (type) {  
      case PrinterConnectionType.usb:  
        return UsbPrinterService(plugin: \_plugin, printerModel: model);  
      case PrinterConnectionType.serial:  
        return SerialPrinterService(plugin: \_plugin, printerModel: model);  
      __// ...__  
    }  
  }  
}

Es cosmético, no fixea bugs — sólo deja claro en el código que comparten estado nativo.

## 11Orden de ejecución end-to-end

Secuencia operativa para llevar el subsistema desde el estado actual hasta el estado patcheado. El plugin ya tiene sus parches aplicados (etapas 1–4). La app necesita ejecutar las etapas 5–14 en este orden, validando cada una con la sección 12 antes de avanzar.

1.  ****Etapa 01 · DonePlugin · capa nativa Windows patcheada****handle `hUsb_` inicializado · USB con `FILE_FLAG_OVERLAPPED` · timeouts reales en read/write · loop de escritura parcial · UTF-8 ↔ UTF-16 con MultiByteToWideChar · destructor simétrico · OVERLAPPED muerto removido del serialti\_printer\_plugin/windows/ti\_printer\_plugin.cppPLG-01 · 02 · 03  
    PLG-15 · 19 · 21 · 22
2.  ****Etapa 02 · DonePlugin · capa nativa Linux patcheada****`read_status_usb` devuelve todos los bytes leídos en lugar del primeroti\_printer\_plugin/linux/ti\_printer\_plugin.ccPLG-02
3.  ****Etapa 03 · DonePlugin · generator.dart patcheado****beep recursivo · oldRrow wrap · \_getLexemes guard · \_intLowHigh paréntesis · dead code en row · round-trip eliminado · drawImage limpioti\_printer\_plugin/lib/esc\_pos\_utils\_platform/src/generator.dartPLG-06 · 07 · 09  
    PLG-10 · 11 · 12 · 13
4.  ****Etapa 04 · DonePlugin · qrcode.dart patcheado****pL/pH calculados con split de 16 bits — soporta payloads > 252 bytes · utf8.encode en lugar de latin1.encodeti\_printer\_plugin/lib/esc\_pos\_utils\_platform/src/qrcode.dartPLG-04 · 05
5.  ****Etapa 05 · P0App · habilitar cierre real del puerto USB****Descomentar `_plugin.closeUsbPort()` en `_safeCloseUsbPort`. Esto desbloquea el resto del trabajo: sin esto, los fixes posteriores no pueden recuperarse de errores transitorios.lib/services/printer/usb\_printer\_service.dart:343–352APP-01 · Causa A
6.  ****Etapa 06 · P0App · short-circuit en connect() para mismo device****En el mismo PR que la etapa 05. Evita el `ERROR_SHARING_VIOLATION` al reconectar a una impresora ya conectada.lib/services/printer/usb\_printer\_service.dart:132–144APP-02 · #A4
7.  ****Etapa 07 · P0App · serial usa sendCommandToSerial****Si tu flota tiene aunque sea una terminal RS-232, hoy no imprime. Descomentar también el closeSerialPort.lib/services/printer/serial\_printer\_service.dart:230–235 + 292–303APP-03 · #A3
8.  ****Etapa 08 · P0App · interpreter T20IIIL aprende a leer el papel****Replicar la lectura de DLE EOT 4 del RPT008 al T20IIIL. Eliminar `hasPaper:true` forzado. Matchear modelo por VID/PID en el factory.lib/models/printer/tmt20iiil\_status\_interpreter.dart + status\_interpreter\_factory.dartAPP-04 · Causa C
9.  ****Etapa 09 · P0App · confirmar estado tras enviar****Releer DLE EOT después del send. Emitir `PrintStatus.success` sólo con confirmación. Aplicar en print único y en el loop de vouchers.lib/viewmodels/printer/printer\_bloc.dart:1407–1430 + 1690–1720APP-05 · Causa D
10.  ****Etapa 10 · P0App · idempotencia por voucher****Tag único por voucher · registro de attempts y status · skip de vouchers ya confirmed en reintentos. Requiere coordinar IDs con el backend.lib/viewmodels/printer/printer\_bloc.dart:1646–1730APP-06 · Causa B
11.  ****Etapa 11 · P1App · timeouts en lecturas y envíos****Envolver `readStatusUsb` y `sendCommandToUsb` con `.timeout()` del lado Dart. Defensa en profundidad sobre los timeouts del plugin (etapa 01).lib/services/printer/usb\_printer\_service.dartAPP-07
12.  ****Etapa 12 · P1App · testConnection respeta conexión activa****Si hay `_currentConfig`, no tocar handles — sólo verificar en la lista.lib/services/printer/usb\_printer\_service.dart:301–318 + serial:246–268APP-08 · #A5
13.  ****Etapa 13 · P1App · invalidación de cache de devices en fallas****Cuando comm falla, marcar el cache de `getUsbPrinters` como vencido para que la próxima detección de presencia consulte fresco.lib/services/printer/usb\_printer\_service.dart:354–376APP-09 · #A8
14.  ****Etapa 14 · P2App · higiene****Logs que no mienten · spin-wait fake · clearPrintMessage inconsistente · listener leak · withLimitedSensors deprecation · instancia única del plugin.Varios archivos en lib/services/printer/ y lib/viewmodels/printer/APP-10 · 11 · 12

Estimado: etapa 05 = 30 minutos · etapas 06–07 = 1–2 horas c/u · etapa 08 = medio día (requiere verificación con hardware real de cada modelo) · etapa 09 = 1 día (refactor + tests) · etapa 10 = 2–3 días (diseño de modelo + persistencia + coordinación con backend) · etapas 11–14 = 1 día total.

## 12Verificación end-to-end

Pruebas de campo + tests unitarios para validar cada P0. El proyecto está en Strict TDD — cada fix arranca con un test que falla, después se implementa, después se verifica el verde.

V1 · FIX 01

#### Recuperación sin reinicio

Verificar que tras un corte físico, la app recupera sola.

1.  Conectar la impresora USB y esperar status `connected`.
2.  Durante una sesión activa, desenchufar el cable USB.
3.  Esperar ~5 segundos. La app debe detectar la desconexión.
4.  Re-enchufar el cable USB.
5.  La app debe reconectar automáticamente sin necesidad de reiniciar el proceso. Verificar log `closeUsbPort -> true` antes del próximo open.

V2 · FIX 04

#### Sin papel = error

Verificar que el gate `isReadyToPrint` detecta correctamente la ausencia de papel.

1.  Conectar la impresora con papel cargado, esperar `connected` + `hasPaper`.
2.  Sacar el rollo de papel completamente.
3.  Esperar el próximo ciclo de monitoreo (~3s).
4.  El estado debe pasar a `hasPaper: false` + `isReadyToPrint: false`.
5.  Intentar imprimir un comprobante. La UI debe mostrar error "Sin papel", ****NO**** "Comprobante impreso".

V3 · FIX 05

#### "Éxito" sólo con impresión confirmada

Reproducir el escenario "bytes aceptados pero impresora no procesa".

1.  Conectar la impresora; ponerla offline (apagar mientras está enchufada al USB, o forzar tapa abierta).
2.  El estado puede demorar en actualizar; intentar imprimir antes de que el monitor lo detecte.
3.  Tras el envío, el `checkStatus` post-envío debe ver el estado no-listo.
4.  La UI debe mostrar error, ****NO**** success.

V4 · FIX 06

#### Sin bucle de duplicados

Reproducir el escenario del incidente del 22/06.

1.  Iniciar una transacción con un set de 3 vouchers para imprimir.
2.  Tras enviar el primer voucher, forzar offline (apagar impresora o sacar papel).
3.  Esperar a que la app marque error en ese voucher.
4.  Restaurar el estado (encender / poner papel).
5.  El reconnect no debe disparar reimpresión automática de vouchers ya aceptados. El voucher fallido se reporta como tal, sin ****ráfaga**** de duplicados.

V5 · TDD

#### Tests unitarios mínimos

Tests que deben existir antes de cerrar cada fix:

1.  Test del interpreter T20IIIL con bytes DLE EOT 4 con bit 6 seteado → `hasPaper == false`.
2.  Test del BLoC donde `sendRawData` devuelve `true` pero el `checkStatus` post-envío devuelve `!isReadyToPrint` → `PrintStatus.error`.
3.  Test de idempotencia: `StartPrintingVouchers` con un set que ya tiene 1 voucher en `confirmed` y 2 en `pending` → sólo envía los 2 pending.
4.  Test de connect: `connect()` con el mismo `devicePath` que ya está conectado → retorna `true` sin invocar `openUsbPort`.
5.  Comando: `flutter test test/viewmodels/printer test/models/printer test/services/printer`.

Para los tests del BLoC, mockear `PrinterService` via `MockPrinterService` que ya existe en `test/`. Para los del interpreter, usar bytes raw fabricados en el test.

Documento integral · subsistema de impresión · uso interno
Generado tras incidente de campo del 22 / 06 / 2026

AndresM · 23 / 06 / 2026
ti\_printer\_plugin v1.0.9 · Auto-Compra POS