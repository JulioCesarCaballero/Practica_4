# Práctica 4 – Gestión de archivos multiplataforma (Android e iOS)

**Instituto Politécnico Nacional · Escuela Superior de Cómputo**
Desarrollo de aplicaciones móviles nativas · Ingeniería en Sistemas Computacionales · Grupo 7CV4

**Integrantes:**
- Caballero Pérez Julio César: implementación y pruebas en Android
- Velazquez Beltran Brandon: implementación y pruebas en iOS

| App | Carpeta | Descripción |
|---|---|---|
| Parte 1 | [`gestor_archivos/`](gestor_archivos) | Gestor de archivos: explorador con breadcrumbs, visores de texto/Markdown, JSON y XML con resaltado, imágenes con zoom y rotación, metadatos, recientes, favoritos, caché de miniaturas y operaciones de copiar/mover/renombrar/eliminar. |
| Parte 2 | [`juego/`](juego) | **Memoria ESCOM**: juego de memoria con 2 modos, puntuación, rachas, sonido y animaciones; guarda y carga partidas en **TXT, XML y JSON**, con etiquetas, exportación y autoguardado. |

Ambas apps funcionan **100 % sin conexión**, tienen los temas **Guinda (IPN, `#6C1D45`)** y **Azul (ESCOM, `#003D79`)** y se adaptan automáticamente al modo claro/oscuro del sistema.


## Tecnología

- **Flutter** (lenguaje Dart) con la interfaz y la lógica compartidas entre Android e iOS.
- Código **específico de Android en Kotlin** (`MainActivity.kt` de cada app) para el Storage Access Framework, conectado con Dart mediante `MethodChannel`:
  - Gestor: canal `mx.ipn.escom/saf`
  - Juego: canal `mx.ipn.escom/archivos`

### Entorno de desarrollo (Android)

| Componente | Versión |
|---|---|
| Sistema operativo de desarrollo | Windows 11 Pro |
| Flutter | 3.47.2 · canal stable (revisión d3b14c8769, 26/08/2026) |
| Dart | 3.13.2 |
| DevTools | 2.60.0 |
| Android Studio | Android Studio Quail 3 - 2026.1.3 |
| JDK usado por Gradle | OpenJDK 25.0.2 (JetBrains Runtime incluido en Android Studio) |
| Gradle (wrapper) | 9.3.1 |
| Android Gradle Plugin | 9.1.0 |
| Kotlin (plugin de Gradle) | 2.4.0 |
| compileSdk / targetSdk | 36 / 36 (valores por defecto de Flutter 3.47) |
| **minSdk** | **24 (Android 7.0)** |
| Android SDK / Build-Tools | 36.1.0 / 36.1.0 (plataforma más reciente instalada: android-37.0) |
| Android SDK Platform adicional | 34 (la descargó Gradle para los plugins) |
| NDK | 28.2.13676358 (valor por defecto de Flutter) |
| Android Emulator | 37.1.11.0 |
| CMake | 3.22.1 (la instaló Gradle automáticamente) |

Se requiere Flutter **3.24 o superior**.

### Dispositivos de prueba (Android)

| Dispositivo | Tipo | Versión de Android (API) | Uso |
|---|---|---|---|
| Xiaomi 2511FPC34G | Físico | Android 16 (API 36) · HyperOS ⟨x⟩ | Pruebas principales |
| Pixel ⟨modelo⟩ | Emulador | Android 7.0 (API 24) | Compatibilidad mínima |
| Pixel ⟨modelo⟩ | Emulador | ⟨Android 15 (API 35)⟩ | Versión reciente |

### Dependencias

Versiones resueltas en `pubspec.lock`:

| Paquete | Versión | Uso | App |
|---|---|---|---|
| `path_provider` | 2.1.5 | Carpetas privadas de la app (documentos y caché) | ambas |
| `shared_preferences` | 2.5.3 | Tema, recientes, favoritos y opciones | ambas |
| `share_plus` | 10.1.4 | Compartir archivos con otras apps | ambas |
| `xml` | 6.6.1 | Formatear/validar XML (gestor) y serializar partidas (juego) | ambas |
| `path` | 3.0.1 | Manejo de rutas | ambas |
| `open_filex` | 4.7.0 | "Abrir con…" para archivos del almacenamiento privado | gestor |
| `mime` | 3.4.1 | Tipo MIME por extensión | gestor |
| `audioplayers` | 6.5.1 | Efectos de sonido | juego |
| `flutter_lints` | 4.0.0 | Reglas de análisis estático (desarrollo) | ambas |

---

## Compilar y ejecutar en Android

### 1. Preparar el entorno (una sola vez)

1. Instala **Android Studio** y, dentro de él, el plugin **Flutter** (instala Dart automáticamente).
2. Descarga el **Flutter SDK**, descomprímelo en una ruta sin espacios (por ejemplo `C:\dev\flutter`) y agrega `C:\dev\flutter\bin` a la variable de entorno `Path`.
3. En Android Studio ve a *Settings → Languages & Frameworks → Android SDK → SDK Tools* y marca **Android SDK Command-line Tools**.
4. En Android Studio ve a *Settings → Languages & Frameworks → Flutter* y escribe la ruta del SDK (`C:\dev\flutter`).
5. Acepta las licencias y verifica:
   ```bash
   flutter doctor --android-licenses
   flutter doctor
   ```
   La línea **Android toolchain** debe aparecer con ✓.

### 2. Obtener el código

```bash
git clone https://github.com/<usuario>/Aplicaciones_moviles_7CV4.git
cd Aplicaciones_moviles_7CV4/Practica_4/practica4
```

La carpeta `android/` de cada app ya está en el repositorio, así que no hace falta ejecutar `flutter create`.

### 3. Ejecutar

1. Conecta un celular con **Depuración USB** activada, o enciende un emulador desde *Device Manager*.
2. Ejecuta cada app:
   ```bash
   cd gestor_archivos
   flutter pub get
   flutter run
   ```
   ```bash
   cd juego
   flutter pub get
   flutter run
   ```
   También puedes abrir la carpeta de cada app en Android Studio (*File → Open*), elegir el dispositivo y presionar ▶.

> La **primera compilación tarda entre 10 y 20 minutos**, porque Gradle descarga sus dependencias, la plataforma 34 del SDK y CMake. Las siguientes tardan menos de 2 minutos.

### 4. Pruebas unitarias

```bash
cd gestor_archivos && flutter test
cd juego && flutter test
```
Las pruebas del juego verifican que guardar y cargar en TXT, XML y JSON recupera exactamente la misma partida, y que se rechazan los archivos vacíos, truncados o manipulados.

### 5. Generar APK (opcional)

```bash
flutter build apk --release
```
El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.

### Solución de problemas

| Problema | Solución |
|---|---|
| `Dart SDK is not configured` | No se necesita descargar Dart; viene con Flutter. Configura la ruta del Flutter SDK en *Settings → Languages & Frameworks → Flutter* y abre la **carpeta** de la app, no un archivo suelto. |
| `Build failed due to use of deleted Android v1 embedding` | La carpeta `android/` está incompleta. Ejecuta `flutter create --org mx.ipn.escom --project-name <app> --platforms=android .` y vuelve a poner el `MainActivity.kt` del repositorio (el generado no trae el código SAF). |
| `INSTALL_FAILED_USER_RESTRICTED` (Xiaomi/POCO/Redmi) | En *Opciones de desarrollador*, activa **Instalar vía USB** y **Depuración USB (ajustes de seguridad)**. Esto requiere cuenta Xiaomi y SIM. Durante la instalación, acepta el aviso en el celular antes de que termine la cuenta regresiva. |
| `flutter` no se reconoce | Agrega `C:\dev\flutter\bin` al `Path` y abre una terminal nueva. |
| Avisos `WARNING` de Java o de *Kotlin Gradle Plugin (share_plus)* | Son solo advertencias; no impiden compilar. |

---

## Compilar y ejecutar en iOS

> Sección a cargo de Velazquez Beltran Brandon. Debe incluir: requisitos (macOS, Xcode, CocoaPods), `flutter create --platforms=ios .`, `pod install`, configuración de *Signing & Capabilities* en Xcode, ejecución en el simulador o en un iPhone, y la implementación iOS de los canales `mx.ipn.escom/saf` y `mx.ipn.escom/archivos` (`UIDocumentPickerViewController`).

---

## Estructura

```
practica4/
├── gestor_archivos/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/        tema.dart, errores.dart, formato.dart
│   │   ├── data/        entrada.dart, archivos.dart, preferencias.dart, tipos.dart
│   │   ├── platform/    saf_android.dart  ← puente Dart ↔ Kotlin
│   │   └── ui/          pantalla_inicio, explorador, visor, resaltado, listas, ajustes...
│   ├── android/app/src/main/kotlin/mx/ipn/escom/gestor_archivos/MainActivity.kt  ← SAF
│   ├── assets/ejemplo/  imagen de ejemplo
│   └── test/
├── juego/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/        tema.dart, efectos.dart, formato.dart
│   │   ├── data/        modelo.dart, serializacion.dart (TXT/XML/JSON), repositorio.dart, ajustes.dart
│   │   ├── platform/    exportar_android.dart
│   │   └── ui/          menu, pantalla_juego, partidas, ver_archivo, opciones...
│   ├── android/app/src/main/kotlin/mx/ipn/escom/juego/MainActivity.kt  ← exportar (SAF)
│   ├── assets/sonidos/
│   └── test/            pruebas de serialización
├── docs/                reporte, matriz de pruebas, capturas
├── configurar_android.ps1 / configurar_android.sh
└── README.md
```

## Permisos y seguridad en Android

- **No se declara** `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` ni `MANAGE_EXTERNAL_STORAGE`. Se respeta **Scoped Storage**.
- El acceso fuera del espacio privado se hace solo con el **Storage Access Framework**:
  - `ACTION_OPEN_DOCUMENT_TREE`: el usuario autoriza una carpeta. El permiso se conserva con `takePersistableUriPermission` y se puede quitar desde la app.
  - `ACTION_OPEN_DOCUMENT`: el usuario abre un archivo suelto.
  - `ACTION_CREATE_DOCUMENT`: el usuario elige dónde exportar.
- Antes de abrir un selector, la app explica para qué lo necesita. Si el usuario cancela, se respeta su decisión.
- Antes de escribir, la app valida el destino, los nombres duplicados, las capacidades del proveedor (`FLAG_SUPPORTS_DELETE/RENAME/WRITE`, `FLAG_DIR_SUPPORTS_CREATE`) y el espacio libre (`StatFs`).
- Las acciones destructivas piden confirmación.
- Los errores (permiso revocado, archivo inexistente, lectura fallida, falta de espacio) se muestran con un mensaje claro y nunca cierran la app.
- Ninguna función depende de Internet: las dos apps funcionan completamente sin conexión (verificado en modo avión).

## Ramas

- `main`: versión estable
- `android`: desarrollo de Android
- `ios`: desarrollo de iOS

