#!/usr/bin/env bash
# Genera la carpeta android/ de cada app (Linux / macOS).
# Uso:  bash configurar_android.sh
set -e
configurar() {
  dir="$1"; label="$2"
  echo "== Configurando $dir =="
  cd "$dir"
  # No sobrescribe archivos existentes (MainActivity.kt, lib/, pubspec.yaml).
  flutter create --org mx.ipn.escom --project-name "$dir" --platforms=android .
  for g in android/app/build.gradle.kts android/app/build.gradle; do
    [ -f "$g" ] && sed -i.bak 's/flutter\.minSdkVersion/24/g' "$g" && rm -f "$g.bak" && echo "minSdk = 24 en $g"
  done
  sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$label\"/" android/app/src/main/AndroidManifest.xml
  rm -f android/app/src/main/AndroidManifest.xml.bak
  flutter pub get
  cd ..
}
configurar gestor_archivos "Gestor ESCOM"
configurar juego "Memoria ESCOM"
echo "Listo. Revisa con 'git status' y haz commit."
