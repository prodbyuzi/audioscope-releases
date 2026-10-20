param([Parameter(Mandatory=$true)][string]$Installer, [string]$PreviousInstaller)
$ErrorActionPreference = 'Stop'
$registry = 'HKLM:\SOFTWARE\AudioScopePro'
if (Test-Path $registry) { throw 'Esta prueba requiere una máquina Windows desechable sin AudioScope instalado.' }
$marker = Join-Path $env:APPDATA 'AudioScopePro\presets\installer-smoke.ini'
New-Item -ItemType Directory -Force (Split-Path $marker) | Out-Null
Set-Content $marker 'preserve-this-preset'
$first = if ($PreviousInstaller) { $PreviousInstaller } else { $Installer }
$p = Start-Process -FilePath $first -ArgumentList '/S' -Wait -PassThru
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
if ($PreviousInstaller) {
 $before = (Get-ItemProperty $registry).Build
 $p = Start-Process -FilePath $Installer -ArgumentList '/UPDATE /S' -Wait -PassThru
 if ($p.ExitCode -ne 0) { throw "Actualización falló: $($p.ExitCode)" }
 if ([long](Get-ItemProperty $registry).Build -le [long]$before) { throw 'No avanzó el build instalado.' }
 if ((Get-Content $marker -Raw).Trim() -ne 'preserve-this-preset') { throw 'La actualización perdió los presets.' }
 if ((Get-ItemProperty $pref).CheckForUpdates -ne '0') { throw 'La actualización cambió la preferencia.' }
 $p = Start-Process -FilePath $exe -ArgumentList '--diagnose-updater' -Wait -PassThru
 if ($p.ExitCode -ne 0) { throw 'El actualizador de la versión nueva no arrancó.' }
}
$p = Start-Process -FilePath $Installer -ArgumentList '/UPDATE /S' -Wait -PassThru
if ($p.ExitCode -eq 0) { throw 'Una actualización con build igual debe rechazarse.' }
$p = Start-Process -FilePath (Join-Path $folder 'Desinstalar.exe') -ArgumentList '/S' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw 'Desinstalación falló.' }
for ($i=0; $i -lt 30 -and (Test-Path $exe); $i++) { Start-Sleep -Milliseconds 500 }
if (Test-Path $exe) { throw 'El ejecutable no se desinstaló.' }
if ((Get-Content $marker -Raw).Trim() -ne 'preserve-this-preset') { throw 'Se perdieron los presets del usuario.' }
Write-Output 'PASS: instalación, backend nativo, preferencias, rechazo de downgrade y desinstalación sin borrar presets.'
