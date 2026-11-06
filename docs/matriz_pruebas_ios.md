# Matriz de pruebas – iOS

> **Cómo llenarla:** ejecuta cada caso en el simulador (o iPhone) y completa *Resultado obtenido* y *Evidencia* con lo que realmente observes. Guarda las capturas en `docs/capturas/ios/` con el nombre indicado. No dejes resultados sin probar: si un caso falla, anótalo tal cual.

| Dato | Valor |
|---|---|
| macOS / Xcode | ⟨versión⟩ / ⟨versión⟩ |
| Flutter / Dart | ⟨versión⟩ / ⟨versión⟩ |
| Dispositivo 1 | iPhone ⟨modelo⟩ · iOS ⟨versión⟩ · simulador |
| Dispositivo 2 | iPhone ⟨modelo⟩ · iOS 15.x · simulador (mínimo) |

## Parte 1 – Gestor de archivos (`gestor_archivos`)

| ID | Sistema / versión / dispositivo | Caso y pasos | Resultado esperado | Resultado obtenido | Evidencia |
|---|---|---|---|---|---|
| G-iOS-01 | iOS ⟨v⟩ · ⟨sim⟩ | Instalar y abrir la app en modo avión | Abre y funciona sin Internet | ⟨⟩ | `ios_G01.png` |
| G-iOS-02 | ⟨⟩ | Ver el espacio privado de la app (*Ubicaciones*) | Lista la carpeta de la app con breadcrumbs | ⟨⟩ | `ios_G02.png` |
| G-iOS-03 | ⟨⟩ | Autorizar carpeta (explicación → Archivos → elegir carpeta) | Aparece en *Carpetas autorizadas* y se puede abrir | ⟨⟩ | `ios_G03.png` |
| G-iOS-04 | ⟨⟩ | Cancelar el selector de carpeta | Mensaje "Selección cancelada"; no se concede acceso | ⟨⟩ | `ios_G04.png` |
| G-iOS-05 | ⟨⟩ | Cerrar y abrir la app | La carpeta autorizada sigue disponible (bookmark persistente) | ⟨⟩ | `ios_G05.png` |
| G-iOS-06 | ⟨⟩ | Abrir `.txt` y `.md` | Se muestra el texto | ⟨⟩ | `ios_G06.png` |
| G-iOS-07 | ⟨⟩ | Abrir `.json` y `.xml` | Texto con formato y resaltado de sintaxis | ⟨⟩ | `ios_G07.png` |
| G-iOS-08 | ⟨⟩ | Abrir imagen; zoom con pellizco y rotar | Zoom y rotación funcionan | ⟨⟩ | `ios_G08.png` |
| G-iOS-09 | ⟨⟩ | Abrir un formato no soportado (p. ej. `.zip`) | Diálogo con abrir / compartir / exportar | ⟨⟩ | `ios_G09.png` |
| G-iOS-10 | ⟨⟩ | Ver detalles de un archivo | Nombre, tamaño, fechas, tipo (MIME/UTType); "No disponible" si falta | ⟨⟩ | `ios_G10.png` |
| G-iOS-11 | ⟨⟩ | Renombrar en carpeta autorizada | Nombre actualizado | ⟨⟩ | `ios_G11.png` |
| G-iOS-12 | ⟨⟩ | Copiar y mover a otra subcarpeta | Se copia / mueve correctamente | ⟨⟩ | `ios_G12.png` |
| G-iOS-13 | ⟨⟩ | Eliminar (con confirmación) | Pide confirmación y elimina | ⟨⟩ | `ios_G13.png` |
| G-iOS-14 | ⟨⟩ | Renombrar a un nombre que ya existe | Mensaje claro, no cierra la app | ⟨⟩ | `ios_G14.png` |
| G-iOS-15 | ⟨⟩ | Quitar acceso a una carpeta autorizada | Desaparece de la lista; para volver hay que autorizarla | ⟨⟩ | `ios_G15.png` |
| G-iOS-16 | ⟨⟩ | Borrar la carpeta autorizada desde Archivos y volver a la app | Error legible ("ya no existe"); la app sigue funcionando | ⟨⟩ | `ios_G16.png` |
| G-iOS-17 | ⟨⟩ | Favoritos y recientes; cerrar y abrir | Se conservan | ⟨⟩ | `ios_G17.png` |
| G-iOS-18 | ⟨⟩ | Compartir / exportar un archivo | Hoja de compartir / selector de destino de iOS | ⟨⟩ | `ios_G18.png` |
| G-iOS-19 | ⟨⟩ | Tema Guinda y Azul, claro y oscuro | Colores correctos; sigue el modo del sistema | ⟨⟩ | `ios_G19.png` |
| G-iOS-20 | ⟨⟩ | Girar el dispositivo / iPad | Interfaz responsiva | ⟨⟩ | `ios_G20.png` |

## Parte 2 – Juego (`juego`)

| ID | Sistema / versión / dispositivo | Caso y pasos | Resultado esperado | Resultado obtenido | Evidencia |
|---|---|---|---|---|---|
| J-iOS-01 | ⟨⟩ | Abrir la app en modo avión | Funciona sin Internet | ⟨⟩ | `ios_J01.png` |
| J-iOS-02 | ⟨⟩ | Jugar los dos modos | Puntuación, rachas, animaciones y sonido | ⟨⟩ | `ios_J02.png` |
| J-iOS-03 | ⟨⟩ | Guardar partida en TXT, XML y JSON | Se crean los tres archivos | ⟨⟩ | `ios_J03.png` |
| J-iOS-04 | ⟨⟩ | Cargar una partida de cada formato | Se recupera el mismo estado | ⟨⟩ | `ios_J04.png` |
| J-iOS-05 | ⟨⟩ | Cerrar la app y abrirla | La partida se recupera sin perder progreso | ⟨⟩ | `ios_J05.png` |
| J-iOS-06 | ⟨⟩ | Ver el contenido del archivo de guardado | Se muestra con formato | ⟨⟩ | `ios_J06.png` |
| J-iOS-07 | ⟨⟩ | Etiquetar partidas y ver la lista con metadatos | Etiquetas y metadatos visibles | ⟨⟩ | `ios_J07.png` |
| J-iOS-08 | ⟨⟩ | Exportar una partida (selector de Archivos) | Se crea el archivo en el destino elegido | ⟨⟩ | `ios_J08.png` |
| J-iOS-09 | ⟨⟩ | Cancelar la exportación | Mensaje "Exportación cancelada" | ⟨⟩ | `ios_J09.png` |
| J-iOS-10 | ⟨⟩ | Cargar un archivo vacío / truncado / corrupto | Error legible; las demás partidas siguen válidas | ⟨⟩ | `ios_J10.png` |
| J-iOS-11 | ⟨⟩ | Temas Guinda/Azul, claro/oscuro, orientación | Se aplican y se adaptan | ⟨⟩ | `ios_J11.png` |
