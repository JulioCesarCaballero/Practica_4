#!/usr/bin/env bash
# Prepara las dos apps Flutter para iOS. Ejecutar EN macOS, desde la raíz del repositorio:
#   chmod +x configurar_ios.sh && ./configurar_ios.sh
# Requisitos: Xcode (con "xcode-select -s" apuntando a él), Flutter, CocoaPods (incluye la gema xcodeproj).
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")" && pwd)"
IOS_MIN="15.0"

preparar() {
  local carpeta="$1" proyecto="$2" plugin="$3"
  echo "=== $carpeta ==="
  cd "$RAIZ/$carpeta"

  # 1) Genera solo la carpeta ios/ (android/ y lib/ no se tocan).
  [ -d ios ] || flutter create --org mx.ipn.escom --project-name "$proyecto" --platforms=ios .

  # 2) Copia el código nativo de iOS (canales propios + AppDelegate que los registra).
  cp ios_nativo/"$plugin" ios/Runner/"$plugin"
  cp ios_nativo/AppDelegate.swift ios/Runner/AppDelegate.swift

  # 3) Agrega SafPlugin/ExportarPlugin.swift al target Runner (si no, Xcode no lo compila).
  ruby -e '
    require "xcodeproj"
    proj = Xcodeproj::Project.open("ios/Runner.xcodeproj")
    target = proj.targets.find { |t| t.name == "Runner" }
    grupo = proj.main_group.find_subpath("Runner", true)
    archivo = ARGV[0]
    unless grupo.files.any? { |f| f.path == archivo }
      target.add_file_references([grupo.new_reference(archivo)])
    end
    proj.save
  ' "$plugin"

  # 4) Info.plist: carpeta de documentos visible en Archivos y apertura "en el lugar".
  local plist="ios/Runner/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :UIFileSharingEnabled bool true" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :LSSupportsOpeningDocumentsInPlace bool true" "$plist" 2>/dev/null || true

  # 5) iOS mínimo = 15.0 (proyecto de Xcode y Podfile).
  sed -i '' -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = ${IOS_MIN};/g" ios/Runner.xcodeproj/project.pbxproj
  flutter pub get
  [ -f ios/Podfile ] || flutter build ios --config-only --simulator
  sed -i '' -E "s/^#? ?platform :ios, '[0-9.]+'/platform :ios, '${IOS_MIN}'/" ios/Podfile
  (cd ios && pod install)
  cd "$RAIZ"
}

preparar gestor_archivos gestor_archivos SafPlugin.swift
preparar juego juego ExportarPlugin.swift

echo
echo "Listo. Abre el simulador (open -a Simulator) y ejecuta en cada app:  flutter run"
