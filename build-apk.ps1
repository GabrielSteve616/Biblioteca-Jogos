$ErrorActionPreference = 'Stop'
$toolchain = 'C:\Walkman-tools'
$flutter = Join-Path $toolchain 'flutter\bin\flutter.bat'
$env:JAVA_HOME = Join-Path $toolchain 'java\jdk-17.0.21+9'
$env:ANDROID_HOME = Join-Path $toolchain 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
Push-Location $PSScriptRoot
try {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao resolver dependências.' }
    & $flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Análise estática falhou.' }
    & $flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Testes falharam.' }
    & $flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Compilação falhou.' }
    Copy-Item -LiteralPath 'build\app\outputs\flutter-apk\app-release.apk' -Destination 'Biblioteca.apk'
    Get-FileHash -Algorithm SHA256 -LiteralPath 'Biblioteca.apk'
} finally {
    Pop-Location
}

