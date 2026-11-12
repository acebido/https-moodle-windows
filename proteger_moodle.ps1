# =============================================================================
#  Proteger Moodle en un ordenador compartido (Windows 11 con IIS)
#  Acebido · José Luis Díaz
# =============================================================================
#  Para el Moodle instalado con los scripts de github.com/acebido/instalar-moodle-windows
#  (C:\moodle, C:\moodledata, C:\php y C:\mariadb).
#
#  El problema: esas carpetas cuelgan de C:\, y Windows deja que CUALQUIER usuario
#  del ordenador las lea y las modifique. Alguien que se siente en este ordenador
#  con su propia cuenta podría:
#   - leer config.php, con la contraseña de la base de datos;
#   - ver y copiar todo lo que se ha subido a Moodle (C:\moodledata);
#   - cambiar el código de Moodle o de PHP (y hacerse administrador);
#   - copiar la base de datos entera (C:\mariadb\data).
#
#  Qué hace: deja esas carpetas solo para
#   - los administradores del ordenador y el sistema (control total);
#   - IIS, que escribe en C:\moodledata y en el código de Moodle (así se pueden
#     instalar y actualizar extensiones desde la web); config.php solo lo puede leer;
#   - el servicio de MariaDB, en C:\mariadb.
#  Moodle sigue funcionando igual desde el navegador, en este equipo y en la red,
#  y las extensiones se instalan y se actualizan como siempre.
#
#  No hace falta si el ordenador es solo tuyo (o solo lo usa una persona).
#
#  Formas de usarlo:
#   .\proteger_moodle.ps1             protege las carpetas
#   .\proteger_moodle.ps1 -Deshacer   deja los permisos como estaban
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta
#  (o doble clic en abrir-powershell-aqui.cmd y después la orden).
# =============================================================================
param([switch]$Deshacer)

$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$SITIO = 'Moodle'
$CFGF  = 'C:\moodle\config.php'
# Las cuentas van por su número (SID), que es el mismo en Windows en español o en inglés.
$ADMIN = '*S-1-5-32-544'          # Administradores
$SYS   = '*S-1-5-18'              # SYSTEM (también el cron de Moodle)
$IUSR  = '*S-1-5-17'              # IUSR: con él lee y escribe PHP los ficheros (fastcgi.impersonate)
$GRUPO = 'IIS AppPool\Moodle'     # el grupo de aplicaciones de IIS del sitio «Moodle»
$MARIA = 'NT SERVICE\MariaDB'     # el servicio de MariaDB
$USERS = '*S-1-5-32-545'          # Usuarios

# Carpeta → quién entra y cómo. F = control total, M = modificar, RX = leer y ejecutar.
$CARPETAS = [ordered]@{
  'C:\moodle'      = @("${ADMIN}:(OI)(CI)F", "${SYS}:(OI)(CI)F", "${IUSR}:(OI)(CI)M",  "${GRUPO}:(OI)(CI)M")
  'C:\moodledata'  = @("${ADMIN}:(OI)(CI)F", "${SYS}:(OI)(CI)F", "${IUSR}:(OI)(CI)M",  "${GRUPO}:(OI)(CI)M")
  'C:\php'         = @("${ADMIN}:(OI)(CI)F", "${SYS}:(OI)(CI)F", "${IUSR}:(OI)(CI)RX", "${GRUPO}:(OI)(CI)RX", "${USERS}:(OI)(CI)RX")
  'C:\mariadb'     = @("${ADMIN}:(OI)(CI)F", "${SYS}:(OI)(CI)F", "${MARIA}:(OI)(CI)F")
  'C:\instaladores'= @("${ADMIN}:(OI)(CI)F", "${SYS}:(OI)(CI)F", "${USERS}:(OI)(CI)RX")
}
$QUE = @{
  'C:\moodle'       = 'el código de Moodle (IIS puede instalar y actualizar extensiones)'
  'C:\moodledata'   = 'los ficheros subidos a Moodle'
  'C:\php'          = 'PHP: los demás usuarios pueden usarlo, pero no cambiarlo'
  'C:\mariadb'      = 'la base de datos'
  'C:\instaladores' = 'los ZIP de instalación: los demás pueden verlos, pero no cambiarlos'
}

function Icacls([string[]]$argumentos) {
  $salida = & icacls.exe @argumentos /C /Q 2>&1
  if ($LASTEXITCODE -ne 0) { Write-Host "  icacls ha dado un error: $salida" -ForegroundColor Red; exit 1 }
}

Write-Host '== Comprobaciones ==' -ForegroundColor Cyan
Write-Host '   Mira que Moodle, PHP, MariaDB y el sitio «Moodle» de IIS estén donde los dejaron los scripts de instalación.' -ForegroundColor Gray
foreach ($f in 'C:\moodle\config.php', 'C:\moodledata', 'C:\php\php.exe', 'C:\mariadb\data') {
  if (-not (Test-Path $f)) { Write-Host "  No existe $f. Este script es para el Moodle instalado con los scripts de instalar-moodle-windows." -ForegroundColor Red; exit 1 } }
Import-Module WebAdministration
if (-not (Get-Website -Name $SITIO -ErrorAction SilentlyContinue)) { Write-Host "  No existe el sitio «$SITIO» en IIS." -ForegroundColor Red; exit 1 }
if ((Get-ItemProperty "IIS:\AppPools\$SITIO" -Name processModel).identityType -ne 'ApplicationPoolIdentity') {
  Write-Host "  El grupo de aplicaciones «$SITIO» no usa su identidad propia (ApplicationPoolIdentity): este script no sabe qué cuenta usa IIS." -ForegroundColor Red; exit 1 }
if (-not (Get-Service MariaDB -ErrorAction SilentlyContinue)) { Write-Host '  No existe el servicio MariaDB.' -ForegroundColor Red; exit 1 }
Write-Host '  todo en su sitio'

# =============================================================================
if ($Deshacer) {
  Write-Host '== Volver a los permisos de antes ==' -ForegroundColor Cyan
  Write-Host '   Las carpetas vuelven a heredar los permisos de C:\ (todos los usuarios pueden leerlas y cambiarlas).' -ForegroundColor Gray
  foreach ($c in $CARPETAS.Keys) {
    if (-not (Test-Path $c)) { continue }
    Icacls @($c, '/inheritance:e')
    Icacls @($c, '/remove:g', $ADMIN, $SYS, $IUSR, $GRUPO, $MARIA, $USERS)
    Write-Host "  $c"
  }
  if (Test-Path $CFGF) { Icacls @($CFGF, '/reset') }
  # El servicio de MariaDB necesita su permiso en data (lo puso el script de instalación).
  Icacls @('C:\mariadb\data', '/grant', "${MARIA}:(OI)(CI)F")
  Write-Host '  OK: permisos como al instalar' -ForegroundColor Green
  Write-Host '  (config.php conserva la carpeta temporal propia de Moodle: sin ella no se instalan extensiones desde la web)' -ForegroundColor Gray
  exit 0
}

# =============================================================================
Write-Host '== Carpeta temporal de Moodle ==' -ForegroundColor Cyan
Write-Host '   Moodle descomprime las extensiones en una carpeta temporal. La de Windows (C:\Windows\Temp) no le sirve: le da una propia en C:\moodledata.' -ForegroundColor Gray
# Sin esto, instalar o actualizar una extensión desde la web falla («C:\WINDOWS\TEMP/requestdir/... can not
# be created»): el cron, que va como SYSTEM, crea antes C:\Windows\Temp\requestdir, y dentro IIS no puede escribir.
$texto = [IO.File]::ReadAllText($CFGF)
if ($texto -match 'localrequestdir') { Write-Host '  config.php ya la tenía' }
else {
  $linea = "`$CFG->localrequestdir = 'C:/moodledata/localrequestdir';   // carpeta temporal propia (proteger_moodle.ps1)`r`n`r`n"
  $patron = [regex]"(?m)^require_once\(__DIR__ \. '/lib/setup\.php'\);"
  $nuevo = $patron.Replace($texto, [Text.RegularExpressions.MatchEvaluator]{ param($m) $linea + $m.Value }, 1)
  if ($nuevo -eq $texto) { Write-Host '  No encuentro la línea require_once(...setup.php) en config.php.' -ForegroundColor Red; exit 1 }
  Copy-Item $CFGF "$CFGF.antes-proteger" -Force
  [IO.File]::WriteAllText($CFGF, $nuevo)
  Write-Host '  config.php: $CFG->localrequestdir = C:/moodledata/localrequestdir (copia en config.php.antes-proteger)'
}

# =============================================================================
Write-Host '== Permisos de las carpetas ==' -ForegroundColor Cyan
Write-Host '   Cada carpeta deja de heredar los permisos de C:\ y queda solo para quien la necesita. Tarda unos minutos: son miles de ficheros.' -ForegroundColor Gray
foreach ($c in $CARPETAS.Keys) {
  if (-not (Test-Path $c)) { Write-Host "  $c no existe: la salto" -ForegroundColor Yellow; continue }
  # Primero se dan los permisos nuevos y después se corta la herencia: nunca se queda sin acceso.
  Icacls (@($c, '/grant:r') + $CARPETAS[$c])
  Icacls @($c, '/inheritance:r')
  # Por si algún fichero de dentro tiene permisos propios: que herede los de la carpeta.
  Icacls @("$c\*", '/reset', '/T')
  Write-Host "  $c → $($QUE[$c])"
}
# config.php lleva la contraseña de la base de datos: IIS solo lo lee (Moodle nunca lo cambia).
Icacls (@($CFGF, '/grant:r', "${ADMIN}:F", "${SYS}:F", "${IUSR}:R", "${GRUPO}:R"))
Icacls @($CFGF, '/inheritance:r')
Write-Host "  $CFGF → solo lectura para IIS (lleva la contraseña de la base de datos)"
Write-Host '  IIS se reinicia para que PHP vuelva a abrir los ficheros con los permisos nuevos'
& iisreset /noforce 2>&1 | Out-Null
Restart-Service MariaDB

Write-Host '== Comprobación ==' -ForegroundColor Cyan
Write-Host '   Mira que los usuarios normales ya no entran y que Moodle sigue respondiendo.' -ForegroundColor Gray
$bien = $true
$abierto = @('S-1-5-11', 'S-1-1-0')     # Usuarios autentificados, Todos
foreach ($f in 'C:\moodle\config.php', 'C:\moodledata', 'C:\mariadb\data') {
  $quien = (Get-Acl $f).Access | ForEach-Object { try { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } catch { '' } }
  if ($quien | Where-Object { $_ -in ($abierto + 'S-1-5-32-545') }) { $bien = $false; Write-Host "  $f sigue abierto a los usuarios" -ForegroundColor Red }
  else { Write-Host "  OK: $f solo para administradores y servicios" -ForegroundColor Green }
}
Start-Sleep 3
$wwwroot = if ((Get-Content C:\moodle\config.php -Raw) -match "\`$CFG->wwwroot\s*=\s*'([^']+)'") { $Matches[1].TrimEnd('/') } else { 'http://localhost' }
try {
  $req = [Net.HttpWebRequest]::Create("$wwwroot/login/index.php"); $req.Timeout = 90000
  $r = $req.GetResponse(); $codigo = [int]$r.StatusCode; $html = (New-Object IO.StreamReader($r.GetResponseStream())).ReadToEnd(); $r.Close()
  if ($html -match 'loginform|id="username"') { Write-Host "  OK: Moodle responde en $wwwroot ($codigo)" -ForegroundColor Green }
  else { $bien = $false; Write-Host "  $wwwroot responde ($codigo), pero no sale la página de entrada" -ForegroundColor Red }
} catch { $bien = $false; Write-Host "  $wwwroot no responde: $(if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message })" -ForegroundColor Red }

if ($bien) {
  Write-Host '  Listo: los demás usuarios de este ordenador ya no pueden ver ni cambiar Moodle, sus ficheros ni la base de datos.' -ForegroundColor Green
  Write-Host '  Las extensiones se siguen instalando y actualizando desde Moodle (Administración del sitio → Extensiones).' -ForegroundColor Green
}
else { Write-Host '  Algo no ha ido bien: mira los mensajes de arriba. Para volver atrás:  .\proteger_moodle.ps1 -Deshacer' -ForegroundColor Red; exit 1 }
