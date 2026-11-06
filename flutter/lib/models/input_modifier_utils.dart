import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Sinaptic Remoto: lo que hay que mandar al equipo remoto por un cambio del
/// campo oculto del teclado blando de Android.
class CambioTecladoBlando {
  final int retrocesos;
  final String texto;

  /// El campo quedó desfasado respecto del teclado: hay que reiniciarlo.
  final bool resincronizar;

  const CambioTecladoBlando(this.retrocesos, this.texto, this.resincronizar);
}

/// Retrocesos que se aceptan por un solo cambio dentro del relleno. Samsung
/// acelera el borrado sostenido y quita varios caracteres de golpe; más que esto
/// no es el usuario borrando sino el teclado perdiendo el relleno.
const int kMaxRetrocesosEnRelleno = 32;

/// Compara lo ESCRITO, sin el relleno, para que el relleno nunca llegue al equipo
/// remoto: ni como texto ni como retrocesos que borren lo que ya había allá.
/// Cuenta puntos de código: un emoji es un retroceso y nunca se parte a la mitad.
///
/// [cursor] es la posición del cursor en [nuevo]; -1 si no se conoce.
CambioTecladoBlando diferenciaTecladoBlando(
  String anterior,
  String nuevo, {
  required int cursor,
  required String relleno,
}) {
  int rellenoInicial(String s, int fin) {
    var i = 0;
    while (i < fin && s[i] == relleno) {
      i++;
    }
    return i;
  }

  var resincronizar = false;
  // Lo escrito quedó en medio del relleno: el relleno de la derecha no es texto.
  var fin = nuevo.length;
  if (cursor >= 0 &&
      cursor < nuevo.length &&
      rellenoInicial(nuevo.substring(cursor), nuevo.length - cursor) ==
          nuevo.length - cursor) {
    fin = cursor;
    resincronizar = true;
  }

  final rellenoAntes = rellenoInicial(anterior, anterior.length);
  final rellenoAhora = rellenoInicial(nuevo, fin);
  final antes = anterior.substring(rellenoAntes).runes.toList(growable: false);
  final ahora = nuevo.substring(rellenoAhora, fin).runes.toList(growable: false);

  var comun = 0;
  while (comun < antes.length &&
      comun < ahora.length &&
      antes[comun] == ahora[comun]) {
    comun++;
  }
  var retrocesos = antes.length - comun;
  var texto = String.fromCharCodes(ahora.skip(comun));

  final perdido = rellenoAntes - (rellenoAhora + nuevo.length - fin);
  if (perdido > 0) {
    if (ahora.isNotEmpty) {
      // Escribió comiéndose relleno: eso no es texto del equipo remoto.
      resincronizar = true;
    } else if (perdido <= kMaxRetrocesosEnRelleno) {
      // Borrar con el campo «vacío» borra en el equipo remoto.
      retrocesos += perdido;
    } else {
      if (antes.isEmpty) {
        retrocesos += 1;
      }
      resincronizar = true;
    }
  } else if (perdido < 0) {
    if (perdido == -1 && antes.isEmpty && ahora.isEmpty) {
      // Un Enter sin nada escrito se confunde con relleno; uno solo es legítimo.
      texto = relleno;
    } else {
      resincronizar = true;
    }
  }
  return CambioTecladoBlando(retrocesos, texto, resincronizar);
}

/// Identifies where terminal input originated so paste data can bypass all
/// keyboard-only transformations.
enum TerminalInputSource {
  keyboard,
  paste,
}

/// Returns true when a stale mobile one-shot Shift state should be released
/// by replaying a tracked Shift key-down as a synthesized key-up.
///
/// This is only valid on mobile when Flutter's cached Shift state is still on
/// (`cachedShiftPressed == true`) but the current hardware/raw event reports
/// Shift as off (`actualShiftPressed == false`).
///
/// A tracked Shift key-down is required so the caller can safely synthesize the
/// matching key-up. Both `shiftLeft` and `shiftRight` are excluded because the
/// Shift key event itself must be processed first; otherwise we could release
/// the tracked key while still handling the original Shift press/release.
/// Callers should evaluate this only after their cached modifier state has been
/// updated for the current event.
///
/// When this returns true, the caller logs a line like:
/// `input: releasing stale mobile Shift before replaying tracked raw key-up`
/// immediately before calling `_releaseTrackedRawShiftKeyEventIfNeeded()`.
bool shouldReleaseStaleMobileShift({
  required bool isMobile,
  required bool cachedShiftPressed,
  required bool actualShiftPressed,
  required LogicalKeyboardKey logicalKey,
  required bool hasTrackedShiftKeyDown,
}) {
  if (!isMobile || !cachedShiftPressed || actualShiftPressed) {
    return false;
  }
  if (!hasTrackedShiftKeyDown) {
    return false;
  }
  if (logicalKey == LogicalKeyboardKey.shiftLeft ||
      logicalKey == LogicalKeyboardKey.shiftRight) {
    return false;
  }
  return true;
}

/// Applies the terminal Ctrl/Alt one-shot modifiers to a single input payload.
///
String applyTerminalInputModifiers(
  String data, {
  required bool ctrlLocked,
  required bool altLocked,
}) {
  var result = data;
  if (ctrlLocked) {
    result = _applyTerminalCtrlModifier(result);
  }
  if (altLocked) {
    result = '\x1B$result';
  }
  return result;
}

/// Builds the exact payload xterm sends for paste, without applying modifiers.
String terminalPastePayload(String text, {required bool bracketedPasteMode}) {
  if (!bracketedPasteMode) {
    return text;
  }
  return '\x1B[200~$text\x1B[201~';
}

/// Returns whether one-shot Ctrl/Alt may transform and consume this input.
///
/// xterm emits terminal control keys as either one control byte or a longer
/// escape sequence. Neither form is ordinary text input, so a pending modifier
/// must survive until the user enters a printable character.
bool shouldApplyTerminalInputModifiers(String data) {
  if (data.characters.length != 1) return false;
  final codeUnit = data.codeUnitAt(0);
  return codeUnit >= 0x20 && codeUnit != 0x7F;
}

/// Builds the payload sent to the remote terminal for keyboard and paste input.
///
/// Keyboard input keeps the mobile Enter workaround and one-shot Ctrl/Alt
/// mapping. Paste input deliberately bypasses both transformations so even a
/// one-character clipboard payload is preserved exactly.
String prepareTerminalInputPayload(
  String data, {
  required TerminalInputSource source,
  required bool isMobileOrWebMobile,
  required bool bracketedPasteMode,
  required bool ctrlLocked,
  required bool altLocked,
}) {
  if (source == TerminalInputSource.paste) {
    return terminalPastePayload(
      data,
      bracketedPasteMode: bracketedPasteMode,
    );
  }

  var result = data;
  if (isMobileOrWebMobile && result == '\n') {
    result = '\r';
  }
  if ((ctrlLocked || altLocked) && shouldApplyTerminalInputModifiers(result)) {
    result = applyTerminalInputModifiers(
      result,
      ctrlLocked: ctrlLocked,
      altLocked: altLocked,
    );
  }
  return result;
}

/// Returns true when a hardware paste shortcut must bypass keyboard modifiers.
///
/// xterm already handles each platform's paste shortcut in the common case.
/// Only intercept while a virtual Ctrl/Alt lock is active, because xterm can
/// emit a one-character paste as normal text when bracketed paste mode is off.
bool shouldHandleTerminalPasteShortcut({
  required TargetPlatform platform,
  required LogicalKeyboardKey logicalKey,
  required bool isKeyDown,
  required bool isKeyRepeat,
  required bool controlPressed,
  required bool metaPressed,
  required bool altPressed,
  required bool shiftPressed,
  required bool modifierLockActive,
}) {
  if (!modifierLockActive) return false;
  if (!isKeyDown && !isKeyRepeat) return false;
  if (logicalKey != LogicalKeyboardKey.keyV) return false;
  if (altPressed) return false;
  switch (platform) {
    case TargetPlatform.linux:
      return controlPressed && !metaPressed && shiftPressed;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return !controlPressed && metaPressed && !shiftPressed;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.windows:
      return controlPressed && !metaPressed && !shiftPressed;
  }
}

/// Returns true when collapsing Row3 should also clear hidden modifier state.
bool shouldClearTerminalModifiersWhenRow3Collapses({
  required bool wasExpanded,
  required bool willExpand,
  required bool ctrlLocked,
  required bool altLocked,
}) {
  return wasExpanded && !willExpand && (ctrlLocked || altLocked);
}

String _applyTerminalCtrlModifier(String data) {
  // Ctrl mappings are defined only for ASCII scalars. A visible character can
  // be multiple scalars (for example, a decomposed accent), so leave those
  // graphemes untouched instead of rewriting only their ASCII base letter.
  final graphemes = data.characters.toList(growable: false);
  if (graphemes.length != 1) {
    return data;
  }

  final runes = graphemes.single.runes.toList(growable: false);
  if (runes.length != 1) {
    return data;
  }

  final code = runes.single;
  if (code >= 0x61 && code <= 0x7A) {
    return String.fromCharCode(code - 0x60);
  }
  if (code >= 0x41 && code <= 0x5A) {
    return String.fromCharCode(code - 0x40);
  }
  if (code == 0x20) {
    return String.fromCharCode(0);
  }
  if (code == 0x5B) {
    return String.fromCharCode(27);
  }
  if (code == 0x5C) {
    return String.fromCharCode(28);
  }
  if (code == 0x5D) {
    return String.fromCharCode(29);
  }
  if (code == 0x5E) {
    return String.fromCharCode(30);
  }
  if (code == 0x5F || code == 0x2F) {
    return String.fromCharCode(31);
  }
  return data;
}
