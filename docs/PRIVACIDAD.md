# Politica de privacidad — POSIA

**Ultima actualizacion:** 21 de junio de 2026  
**Aplicacion:** POSIA (com.posia.posia_pos / com.posia.posiaPos)

## Resumen

POSIA es un punto de venta para comercios. Los datos de ventas, inventario y usuarios se almacenan **principalmente en el dispositivo** del negocio. No vendemos ni compartimos datos personales con terceros para publicidad.

## Datos que procesa la app

| Dato | Uso | Donde se guarda |
|------|-----|-----------------|
| Codigo de usuario y credenciales | Acceso a la caja segun rol | Dispositivo (hash de contrasena) |
| Ventas, productos, inventario | Operacion del negocio | Base SQLite local en el dispositivo |
| Audio del microfono | Comandos de voz opcionales en caja movil | Procesado en el dispositivo; no se envia a servidores POSIA por defecto |
| URL del hub de sincronizacion | Sincronizar sucursales (opcional) | Configuracion local; el administrador define el servidor |

## Permisos del dispositivo

- **Internet:** sincronizacion opcional con el hub configurado por el negocio.
- **Microfono y reconocimiento de voz (iOS/Android):** solo si el cajero usa venta por voz.

## Sincronizacion en la nube

Si el negocio configura un hub de sincronizacion, los eventos de venta e inventario se envian al servidor indicado por el administrador. POSIA no opera ese servidor; el responsable del tratamiento de datos en nube es el titular del negocio o su proveedor de hosting.

## Retencion y eliminacion

Los datos permanecen en el dispositivo hasta que el administrador los borre o desinstale la aplicacion. Para eliminar datos, desinstale la app o restablezca la base desde el panel de administracion del dispositivo.

## Menores

POSIA esta dirigida a negocios y personal adulto; no recopila datos de menores de forma intencional.

## Cambios

Publicaremos cambios relevantes en esta politica. La fecha de ultima actualizacion aparece al inicio del documento.

## Contacto

Para consultas sobre privacidad: **privacidad@posia.app** (reemplace con el correo de su organizacion antes de publicar en tiendas).

---

*Publique este documento en una URL publica (GitHub Pages, sitio web del negocio, etc.) y use esa URL en Google Play Console y App Store Connect.*
