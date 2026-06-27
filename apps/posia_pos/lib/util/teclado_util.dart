/// Utilidades para ocultar el teclado virtual.
library;

import 'package:flutter/material.dart';

/// Quita el foco del campo activo y oculta el teclado.
void ocultarTeclado(BuildContext context) {
	FocusManager.instance.primaryFocus?.unfocus();
}
