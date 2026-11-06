# Matriz de pruebas – iOS

> **Nota de honestidad:** debido a la fecha límite y a que el entorno es un macOS virtualizado (sin GPU), solo se ejecutaron los casos con evidencia indicada. Los demás figuran como **No probado**; no se inventan resultados.

| Dato | Valor |
|---|---|
| macOS / Xcode | macOS Ventura 13.7.8 (virtualizado con docker-osx) / Xcode 15.2 |
| Flutter / Dart | Flutter 3.27.x (macOS; con `--no-enable-impeller`) / Dart 3.6.x |
| CocoaPods | 1.15.2 |
| Dispositivo 1 | iPhone 15 Pro · iOS 17.2 · simulador |
| Dispositivo 2 | No probado (iOS 15.x mínimo) |

## Parte 1 – Gestor de archivos (`gestor_archivos`)

| ID | Sistema / versión / dispositivo | Caso y pasos | Resultado esperado | Resultado obtenido | Evidencia |
|---|---|---|---|---|---|
| G-iOS-01 | iOS 17.2 · iPhone 15 Pro (sim.) | Instalar y abrir la app en modo avión | Abre y funciona sin Internet | La app compila, se instala y abre en el simulador (pantalla de inicio con *Ubicaciones*, *Carpetas autorizadas* y barra inferior). Modo avión no probado explícitamente (la app no usa red). | `ios_G01.png` |
| G-iOS-02 | iOS 17.2 · iPhone 15 Pro (sim.) | Ver el espacio privado de la app (*Ubicaciones*) | Lista la carpeta de la app con breadcrumbs | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-03 | iOS 17.2 · iPhone 15 Pro (sim.) | Autorizar carpeta (explicación → Archivos → elegir carpeta) | Aparece en *Carpetas autorizadas* y se puede abrir | OK: selector de Archivos → carpeta "Documentos" → mensaje "Acceso concedido a Documentos" y se lista `notas.md` (211 B, fecha). | `ios_G02.png`, `ios_G03.png` |
| G-iOS-04 | iOS 17.2 · iPhone 15 Pro (sim.) | Cancelar el selector de carpeta | Mensaje "Selección cancelada"; no se concede acceso | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-05 | iOS 17.2 · iPhone 15 Pro (sim.) | Cerrar y abrir la app | La carpeta autorizada sigue disponible (bookmark persistente) | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-06 | iOS 17.2 · iPhone 15 Pro (sim.) | Abrir `.txt` y `.md` | Se muestra el texto | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-07 | iOS 17.2 · iPhone 15 Pro (sim.) | Abrir `.json` y `.xml` | Texto con formato y resaltado de sintaxis | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-08 | iOS 17.2 · iPhone 15 Pro (sim.) | Abrir imagen; zoom con pellizco y rotar | Zoom y rotación funcionan | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-09 | iOS 17.2 · iPhone 15 Pro (sim.) | Abrir un formato no soportado (p. ej. `.zip`) | Diálogo con abrir / compartir / exportar | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-10 | iOS 17.2 · iPhone 15 Pro (sim.) | Ver detalles de un archivo | Nombre, tamaño, fechas, tipo (MIME/UTType); "No disponible" si falta | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-11 | iOS 17.2 · iPhone 15 Pro (sim.) | Renombrar en carpeta autorizada | Nombre actualizado | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-12 | iOS 17.2 · iPhone 15 Pro (sim.) | Copiar y mover a otra subcarpeta | Se copia / mueve correctamente | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-13 | iOS 17.2 · iPhone 15 Pro (sim.) | Eliminar (con confirmación) | Pide confirmación y elimina | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-14 | iOS 17.2 · iPhone 15 Pro (sim.) | Renombrar a un nombre que ya existe | Mensaje claro, no cierra la app | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-15 | iOS 17.2 · iPhone 15 Pro (sim.) | Quitar acceso a una carpeta autorizada | Desaparece de la lista; para volver hay que autorizarla | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-16 | iOS 17.2 · iPhone 15 Pro (sim.) | Borrar la carpeta autorizada desde Archivos y volver a la app | Error legible ("ya no existe"); la app sigue funcionando | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-17 | iOS 17.2 · iPhone 15 Pro (sim.) | Favoritos y recientes; cerrar y abrir | Se conservan | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-18 | iOS 17.2 · iPhone 15 Pro (sim.) | Compartir / exportar un archivo | Hoja de compartir / selector de destino de iOS | No probado (falta de tiempo / entorno virtualizado) | — |
| G-iOS-19 | iOS 17.2 · iPhone 15 Pro (sim.) | Tema Guinda y Azul, claro y oscuro | Colores correctos; sigue el modo del sistema | Parcial: se ve la pantalla de Ajustes con selector de tema (Guinda IPN / Azul ESCOM), caché y datos de ejemplo. No se probó el cambio de tema. | `ios_G05.png` |
| G-iOS-20 | iOS 17.2 · iPhone 15 Pro (sim.) | Girar el dispositivo / iPad | Interfaz responsiva | No probado (falta de tiempo / entorno virtualizado) | — |

## Parte 2 – Juego (`juego`)

| ID | Sistema / versión / dispositivo | Caso y pasos | Resultado esperado | Resultado obtenido | Evidencia |
|---|---|---|---|---|---|
| J-iOS-01 | iOS 17.2 · iPhone 15 Pro (sim.) | Abrir la app en modo avión | Funciona sin Internet | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-02 | iOS 17.2 · iPhone 15 Pro (sim.) | Jugar los dos modos | Puntuación, rachas, animaciones y sonido | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-03 | iOS 17.2 · iPhone 15 Pro (sim.) | Guardar partida en TXT, XML y JSON | Se crean los tres archivos | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-04 | iOS 17.2 · iPhone 15 Pro (sim.) | Cargar una partida de cada formato | Se recupera el mismo estado | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-05 | iOS 17.2 · iPhone 15 Pro (sim.) | Cerrar la app y abrirla | La partida se recupera sin perder progreso | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-06 | iOS 17.2 · iPhone 15 Pro (sim.) | Ver el contenido del archivo de guardado | Se muestra con formato | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-07 | iOS 17.2 · iPhone 15 Pro (sim.) | Etiquetar partidas y ver la lista con metadatos | Etiquetas y metadatos visibles | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-08 | iOS 17.2 · iPhone 15 Pro (sim.) | Exportar una partida (selector de Archivos) | Se crea el archivo en el destino elegido | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-09 | iOS 17.2 · iPhone 15 Pro (sim.) | Cancelar la exportación | Mensaje "Exportación cancelada" | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-10 | iOS 17.2 · iPhone 15 Pro (sim.) | Cargar un archivo vacío / truncado / corrupto | Error legible; las demás partidas siguen válidas | No probado (falta de tiempo / entorno virtualizado) | — |
| J-iOS-11 | iOS 17.2 · iPhone 15 Pro (sim.) | Temas Guinda/Azul, claro/oscuro, orientación | Se aplican y se adaptan | No probado (falta de tiempo / entorno virtualizado) | — |

### Evidencia adicional

- Menú de acciones por archivo (Abrir, Detalles, Favorito, Renombrar, Copiar a…, Mover a…, Eliminar, Compartir, Exportar copia…, Importar a la app): `ios_G04.png`.
- Entorno: `ios_entorno_*.png` (arranque de la VM, versiones, `flutter doctor`, pods, script, simulador y build).
- El juego (`juego`) se compila con el mismo script, pero **no se alcanzó a ejecutar** en iOS; además, `MainActivity.kt` del juego en Android aún no implementa el canal `mx.ipn.escom/archivos` (exportar).

