param([Parameter(Mandatory=$true)][string]$Installer)
$ErrorActionPreference = 'Stop'
$registry = 'HKLM:\SOFTWARE\AudioScopePro'
if (Test-Path $registry) { throw 'Esta prueba requiere una máquina Windows desechable sin AudioScope instalado.' }
$marker = Join-Path $env:APPDATA 'AudioScopePro\presets\installer-smoke.ini'
New-Item -ItemType Directory -Force (Split-Path $marker) | Out-Null
Set-Content $marker 'preserve-this-preset'
$p = Start-Process -FilePath $Installer -ArgumentList '/S' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Instalador falló: $($p.ExitCode)" }
$folder = (Get-ItemProperty $registry).InstallDir
$exe = Join-Path $folder 'AudioScope.exe'
$dll = Join-Path $folder 'assets\updater\WinSparkle.dll'
if (!(Test-Path $exe) -or !(Test-Path $dll)) { throw 'Faltan la aplicación o WinSparkle.' }
if (!((Get-Item (Join-Path $folder 'assets') -Force).Attributes -band [IO.FileAttributes]::Hidden)) { throw 'assets debe estar oculta.' }
$pref = 'HKCU:\Software\AudioScopePro\Updates'
New-Item -Path $pref -Force | Out-Null
New-ItemProperty -Path $pref -Name CheckForUpdates -Value '0' -PropertyType String -Force | Out-Null
$p = Start-Process -FilePath $exe -ArgumentList '--diagnose-updater' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw 'No se pudo inicializar el backend WinSparkle real.' }
if ((Get-ItemProperty $pref).CheckForUpdates -ne '0') { throw 'Se sobrescribió la preferencia de comprobación automática.' }
$p = Start-Process -FilePath $Installer -ArgumentList '/UPDATE /S' -Wait -PassThru
if ($p.ExitCode -eq 0) { throw 'Una actualización con build igual debe rechazarse.' }
$p = Start-Process -FilePath (Join-Path $folder 'Desinstalar.exe') -ArgumentList '/S' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw 'Desinstalación falló.' }
for ($i=0; $i -lt 30 -and (Test-Path $exe); $i++) { Start-Sleep -Milliseconds 500 }
if (Test-Path $exe) { throw 'El ejecutable no se desinstaló.' }
if ((Get-Content $marker -Raw).Trim() -ne 'preserve-this-preset') { throw 'Se perdieron los presets del usuario.' }
Write-Output 'PASS: instalación, backend nativo, preferencias, rechazo de downgrade y desinstalación sin borrar presets.'
