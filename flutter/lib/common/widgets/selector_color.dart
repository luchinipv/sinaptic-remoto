// Sinaptic Remoto: selector del color de la app (Ajustes).
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';

/// Fila de círculos con los colores de [MyTheme.coloresDeApp]. Marca el actual
/// y, al tocar uno, lo guarda y lo aplica sin reiniciar.
class SelectorDeColor extends StatefulWidget {
  final VoidCallback? alCambiar;
  const SelectorDeColor({super.key, this.alCambiar});

  @override
  State<SelectorDeColor> createState() => _SelectorDeColorState();
}

class _SelectorDeColorState extends State<SelectorDeColor> {
  @override
  Widget build(BuildContext context) {
    final actual = MyTheme.accent.value;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: MyTheme.coloresDeApp.map((c) {
        final elegido = c.color.value == actual;
        return Tooltip(
          message: c.nombre,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              if (elegido) return;
              await MyTheme.cambiarColor(c.color);
              if (mounted) setState(() {});
              widget.alCambiar?.call();
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: elegido
                      ? Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black87
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: elegido
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Nombre del color actual (para mostrarlo en la lista de ajustes del móvil).
String nombreDelColorActual() {
  final v = MyTheme.accent.value;
  for (final c in MyTheme.coloresDeApp) {
    if (c.color.value == v) return c.nombre;
  }
  return '';
}
