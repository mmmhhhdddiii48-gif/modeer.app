$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK غير موجود في PATH. ثبّت Flutter ثم أعد تشغيل الملف.'
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$tempRoot = Join-Path $env:TEMP ('nukhba_generators_flutter_' + [guid]::NewGuid().ToString('N'))

try {
  flutter create $tempRoot --project-name nukhba_generators_mobile --org com.nukhba --platforms=android,ios
  Copy-Item (Join-Path $tempRoot 'android') (Join-Path $projectRoot 'android') -Recurse -Force
  Copy-Item (Join-Path $tempRoot 'ios') (Join-Path $projectRoot 'ios') -Recurse -Force

  $gradleKts = Join-Path $projectRoot 'android\app\build.gradle.kts'
  if (Test-Path $gradleKts) {
    $content = Get-Content $gradleKts -Raw
    $content = $content -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24'
    Set-Content $gradleKts $content -Encoding UTF8
  }


  $podfile = Join-Path $projectRoot 'ios\Podfile'
  if (Test-Path $podfile) {
    $podContent = Get-Content $podfile -Raw
    if ($podContent -match "# platform :ios, '[^']+'") {
      $podContent = $podContent -replace "# platform :ios, '[^']+'", "platform :ios, '13.0'"
    } elseif ($podContent -match "platform :ios, '[^']+'") {
      $podContent = $podContent -replace "platform :ios, '[^']+'", "platform :ios, '13.0'"
    }
    Set-Content $podfile $podContent -Encoding UTF8
  }

  Push-Location $projectRoot
  flutter pub get
  flutter analyze
  flutter test
  Pop-Location

  Write-Host 'تم تجهيز Android وiOS وفحص مشروع Stage01.' -ForegroundColor Green
} finally {
  if (Test-Path $tempRoot) { Remove-Item $tempRoot -Recurse -Force }
}
