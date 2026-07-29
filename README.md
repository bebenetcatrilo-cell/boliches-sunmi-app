# Boliches Soft · Sunmi (Caja + Impresora)

App todo-en-uno para aparatos Sunmi/Baiwang (Android):
- Abre el sistema Boliches Soft adentro (WebView) = CAJA + ADMIN + REPORTES.
- Un agente por atras lee la cola (tabla `impresiones`) de SU estacion e
  imprime en la impresora interna del Sunmi (venta de barra + reportes).
- La impresion del navegador queda anulada: todo sale por el agente.

Primera vez: pide el nombre de la estacion (ej: SUNMI 1) y lo guarda.
Boton flotante rosa (abajo derecha) = menu: prueba, recargar, cambiar estacion.

Compila con Codemagic (workflow "Boliches Sunmi Android").
