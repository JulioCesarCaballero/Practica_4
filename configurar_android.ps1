# Genera la carpeta android/ de cada app (Windows / PowerShell).
# Uso: abre PowerShell en la raíz del repo y ejecuta:  .\configurar_android.ps1
# Si Windows bloquea el script:  Set-ExecutionPolicy -Scope Process Bypass
$ErrorActionPreference = "Stop"
$apps = @(
  @{ dir = "gestor_archivos"; label = "Gestor ESCOM" },
  @{ dir = "juego";           label = "Memoria ESCOM" }
)
foreach ($a in $apps) {
  Write-Host "== Configurando $($a.dir) ==" -ForegroundColor Cyan
  Push-Location $a.dir
  # No sobrescribe archivos existentes (MainActivity.kt, lib/, pubspec.yaml).
  flutter create --org mx.ipn.escom --project-name $($a.dir) --platforms=android .
  foreach ($g in @("android/app/build.gradle.kts", "android/app/build.gradle")) {
    if (Test-Path $g) {
      $t = Get-Content $g -Raw
      $t = $t -replace 'flutter\.minSdkVersion', '24'
      Set-Content -Path $g -Value $t -NoNewline
      Write-Host "minSdk = 24 en $g"
    }
  }
  $m = "android/app/src/main/AndroidManifest.xml"
  $t = Get-Content $m -Raw
  $t = $t -replace 'android:label="[^"]*"', ('android:label="' + $a.label + '"')
  Set-Content -Path $m -Value $t -NoNewline
  flutter pub get
  Pop-Location
}
Write-Host "Listo. Revisa con 'git status' y haz commit." -ForegroundColor Green
