# =============================================================================
#  Activar HTTPS (gratis) en Moodle sobre Windows 11 con IIS
#  Acebido · José Luis Díaz
# =============================================================================
#  Para el Moodle instalado con los scripts de github.com/acebido/instalar-moodle-windows
#  (sitio de IIS «Moodle», código en C:\moodle y PHP en C:\php).
#
#  Qué hace:
#   1. Crea un certificado para la dirección del campus (normalmente localhost),
#      válido 5 años. Lo crea el propio Windows: no se descarga ni se paga nada.
#   2. Lo añade a los certificados de confianza de este ordenador, para que
#      Edge y Chrome muestren el candado sin ningún aviso.
#   3. Añade a IIS el puerto 443 (HTTPS) con ese certificado.
#   4. Hace que quien entre por http:// pase solo a https:// (redirección de IIS).
#   5. Cambia la dirección de Moodle a https:// en config.php y en los enlaces
#      que ya estén guardados en los cursos, y vacía las cachés.
#
#  Para volver a como estaba:  .\activar_https.ps1 -Deshacer
#
#  Cómo se ejecuta: PowerShell COMO ADMINISTRADOR, en esta carpeta:  .\activar_https.ps1
#  (o doble clic en abrir-powershell-aqui.cmd y después la orden).
# =============================================================================
param([switch]$Deshacer)

$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Abre PowerShell como administrador y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }
# PHP escribe en UTF-8: sin esto, la consola enseña «├ëxito» en vez de «Éxito».
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$CODE    = 'C:\moodle'
$CFGF    = "$CODE\config.php"
$PHP     = 'C:\php\php.exe'
$SITIO   = 'Moodle'
$REDIR   = 'Moodle - redireccion a HTTPS'
$CARPETA = 'C:\inetpub\moodle-redireccion'

Write-Host '== Comprobaciones ==' -ForegroundColor Cyan
Write-Host '   Mira que Moodle, PHP y el sitio «Moodle» de IIS estén donde los dejaron los scripts de instalación.' -ForegroundColor Gray
foreach ($f in @($CFGF, $PHP)) {
  if (-not (Test-Path $f)) { Write-Host "  No existe $f. Este script es para el Moodle instalado con los scripts de instalar-moodle-windows." -ForegroundColor Red; exit 1 } }
Import-Module WebAdministration
if (-not (Get-Website -Name $SITIO -ErrorAction SilentlyContinue)) {
  Write-Host "  No existe el sitio «$SITIO» en IIS." -ForegroundColor Red; exit 1 }
$cfg = Get-Content $CFGF -Raw
if ($cfg -notmatch "\`$CFG->wwwroot\s*=\s*'([^']+)'") {
  Write-Host '  No encuentro $CFG->wwwroot en config.php.' -ForegroundColor Red; exit 1 }
$WWW = $Matches[1].TrimEnd('/')
$uri = [Uri]$WWW
$NOMBRE = $uri.Host
if ($uri.AbsolutePath -ne '/' -or -not $uri.IsDefaultPort) {
  Write-Host "  La dirección de Moodle es ${WWW}: este script solo sirve para direcciones sin puerto ni carpeta (http://localhost)." -ForegroundColor Red; exit 1 }
Write-Host "  dirección actual de Moodle: $WWW"

# Ejecuta un script de PHP sin que los avisos de PHP por la salida de errores corten el script.
function Php($guion, [string[]]$argumentos) {
  $ErrorActionPreference = 'Continue'
  & $PHP $guion @argumentos 2>&1 | ForEach-Object { Write-Host "  $_" }
  $ErrorActionPreference = 'Stop'
  if ($LASTEXITCODE -ne 0) { Write-Host "  PHP ha dado un error con $(Split-Path $guion -Leaf): mira los mensajes de arriba." -ForegroundColor Red; exit 1 }
}
# Cambia el principio de la dirección en config.php (copia antes, escribe aparte y luego copia).
function CambiaConfig($de, $a) {
  if (-not (Test-Path "$CFGF.antes-https")) { Copy-Item $CFGF "$CFGF.antes-https" }
  $nuevo = (Get-Content $CFGF -Raw) -replace ("(\`$CFG->wwwroot\s*=\s*')" + [regex]::Escape($de)), ('${1}' + $a)
  [IO.File]::WriteAllText("$CFGF.nuevo", $nuevo)
  Copy-Item "$CFGF.nuevo" $CFGF -Force; Remove-Item "$CFGF.nuevo"
}

# =============================================================================
if ($Deshacer) {
  Write-Host '== Volver a http:// ==' -ForegroundColor Cyan
  Write-Host '   Deja Moodle como estaba antes de activar HTTPS.' -ForegroundColor Gray
  if (Get-Website -Name $REDIR -ErrorAction SilentlyContinue) { Remove-Website -Name $REDIR; Write-Host "  quitado el sitio «$REDIR»" }
  if (Test-Path $CARPETA) { Remove-Item $CARPETA -Recurse -Force }
  if (-not (Get-WebBinding -Name $SITIO -Protocol http -Port 80)) { New-WebBinding -Name $SITIO -Protocol http -Port 80 -IPAddress '*'; Write-Host '  el sitio «Moodle» vuelve a escuchar en el puerto 80' }
  if (Get-WebBinding -Name $SITIO -Protocol https -Port 443) { Get-WebBinding -Name $SITIO -Protocol https -Port 443 | Remove-WebBinding; Write-Host '  quitado el puerto 443' }
  if (Test-Path 'IIS:\SslBindings\0.0.0.0!443') { Remove-Item 'IIS:\SslBindings\0.0.0.0!443' }
  foreach ($almacen in 'Cert:\LocalMachine\My', 'Cert:\LocalMachine\Root') {
    Get-ChildItem $almacen | Where-Object { $_.FriendlyName -eq "Moodle $NOMBRE" } | Remove-Item
  }
  Write-Host '  certificado borrado'
  CambiaConfig "https://$NOMBRE" "http://$NOMBRE"
  Php "$CODE\public\admin\tool\replace\cli\replace.php" @("--search=https://$NOMBRE", "--replace=http://$NOMBRE", '--non-interactive')
  Php "$CODE\admin\cli\purge_caches.php" @()
  Write-Host "  OK: Moodle vuelve a estar en http://$NOMBRE" -ForegroundColor Green
  exit 0
}

# =============================================================================
Write-Host '== 1. Certificado ==' -ForegroundColor Cyan
Write-Host "   Crea con Windows un certificado para $NOMBRE, válido 5 años. Gratis y sin descargar nada." -ForegroundColor Gray
$cert = Get-ChildItem Cert:\LocalMachine\My |
        Where-Object { $_.FriendlyName -eq "Moodle $NOMBRE" -and $_.NotAfter -gt (Get-Date).AddDays(30) } |
        Select-Object -First 1
if ($cert) { Write-Host "  ya existía (caduca el $($cert.NotAfter.ToString('dd-MM-yyyy')))" }
else {
  $nombres = @($NOMBRE); if ($NOMBRE -ne 'localhost') { $nombres += 'localhost' }
  $cert = New-SelfSignedCertificate -DnsName $nombres -CertStoreLocation Cert:\LocalMachine\My `
          -FriendlyName "Moodle $NOMBRE" -NotAfter (Get-Date).AddYears(5) `
          -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256
  Write-Host "  creado: $($nombres -join ', ') (caduca el $($cert.NotAfter.ToString('dd-MM-yyyy')))"
}

Write-Host '== 2. Certificado de confianza ==' -ForegroundColor Cyan
Write-Host '   Lo añade a las «Entidades de certificación raíz de confianza» de este ordenador: así el navegador no avisa.' -ForegroundColor Gray
if (Test-Path "Cert:\LocalMachine\Root\$($cert.Thumbprint)") { Write-Host '  ya era de confianza' }
else {
  $cer = Join-Path $env:TEMP 'moodle-https.cer'
  Export-Certificate -Cert $cert -FilePath $cer | Out-Null
  Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
  Remove-Item $cer
  Write-Host '  añadido'
}

Write-Host '== 3. HTTPS en IIS (puerto 443) ==' -ForegroundColor Cyan
Write-Host '   Añade al sitio «Moodle» el puerto 443, el de HTTPS, con el certificado.' -ForegroundColor Gray
$otro = Get-WebBinding -Port 443 | Where-Object { $_.ItemXPath -notmatch "name='$SITIO'" }
if ($otro) { Write-Host '  Otro sitio de IIS ya usa el puerto 443: quítaselo en el Administrador de IIS y vuelve a ejecutar el script.' -ForegroundColor Red; exit 1 }
if (-not (Get-WebBinding -Name $SITIO -Protocol https -Port 443)) {
  $ocupa = Get-NetTCPConnection -LocalPort 443 -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -ne 4 } | Select-Object -First 1
  if ($ocupa) {
    $prog = (Get-Process -Id $ocupa.OwningProcess -ErrorAction SilentlyContinue).ProcessName
    Write-Host "  El puerto 443 lo usa otro programa ($prog). Ciérralo y vuelve a ejecutar el script." -ForegroundColor Red; exit 1 }
  New-WebBinding -Name $SITIO -Protocol https -Port 443 -IPAddress '*'
}
$ssl = 'IIS:\SslBindings\0.0.0.0!443'
if ((Test-Path $ssl) -and (Get-Item $ssl).Thumbprint -ne $cert.Thumbprint) { Remove-Item $ssl }
if (-not (Test-Path $ssl)) { (Get-WebBinding -Name $SITIO -Protocol https -Port 443).AddSslCertificate($cert.Thumbprint, 'My') }
Write-Host '  el sitio «Moodle» escucha en https://, puerto 443'

Write-Host '== 4. De http:// a https:// ==' -ForegroundColor Cyan
Write-Host '   El puerto 80 lo atiende un sitio pequeño que solo manda cada visita a la misma página en https://.' -ForegroundColor Gray
if ((Get-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect).State -ne 'Enabled') {
  Write-Host '  activando «Redirección HTTP» de IIS ...'
  Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect -All -NoRestart | Out-Null
}
if (Get-WebBinding -Name $SITIO -Protocol http -Port 80) {
  Get-WebBinding -Name $SITIO -Protocol http -Port 80 | Remove-WebBinding
  Write-Host '  el sitio «Moodle» deja el puerto 80' }
New-Item -ItemType Directory -Path $CARPETA -Force | Out-Null
# exactDestination="false": añade a la dirección la página que se pedía (y lo que va detrás del ?).
# Found (302) y no Permanent (301): el navegador no la guarda para siempre, por si se deshace.
@"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <httpRedirect enabled="true" destination="https://$NOMBRE" exactDestination="false" childOnly="false" httpResponseStatus="Found" />
  </system.webServer>
</configuration>
"@ | Set-Content -Path "$CARPETA\web.config" -Encoding UTF8
if (-not (Get-Website -Name $REDIR -ErrorAction SilentlyContinue)) {
  New-Website -Name $REDIR -Port 80 -PhysicalPath $CARPETA -ApplicationPool $SITIO -Force | Out-Null }
Start-Website -Name $REDIR
Write-Host "  sitio «$REDIR» en el puerto 80"

Write-Host '== 5. Moodle con https:// ==' -ForegroundColor Cyan
Write-Host '   Cambia la dirección en config.php y en los enlaces guardados en los cursos, y vacía las cachés.' -ForegroundColor Gray
if ($WWW -like 'https://*') { Write-Host '  config.php ya tenía https://' }
else { CambiaConfig "http://$NOMBRE" "https://$NOMBRE"; Write-Host "  config.php: https://$NOMBRE (copia en config.php.antes-https)" }
# --shorten: «https» tiene una letra más; Moodle solo recorta si un texto no cabe en su campo.
Php "$CODE\public\admin\tool\replace\cli\replace.php" @("--search=http://$NOMBRE", "--replace=https://$NOMBRE", '--shorten', '--non-interactive')
Php "$CODE\admin\cli\purge_caches.php" @()
Write-Host '  cachés vaciadas'

Write-Host '== Comprobación ==' -ForegroundColor Cyan
Write-Host '   Abre Moodle por https:// (con el certificado comprobado como lo haría el navegador) y prueba la redirección.' -ForegroundColor Gray
Start-Sleep 2
$bien = $true
try {
  $req = [Net.HttpWebRequest]::Create("https://$NOMBRE/login/index.php"); $req.AllowAutoRedirect = $false; $req.Timeout = 60000
  $r = $req.GetResponse(); $codigo = [int]$r.StatusCode; $r.Close()
  Write-Host "  OK: https://$NOMBRE responde ($codigo) con un certificado de confianza" -ForegroundColor Green
} catch { $bien = $false; Write-Host "  https://$NOMBRE no responde bien: $(if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message })" -ForegroundColor Red }
try {
  $req = [Net.HttpWebRequest]::Create("http://$NOMBRE/course/view.php?id=1"); $req.AllowAutoRedirect = $false; $req.Timeout = 30000
  $r = $req.GetResponse(); $destino = $r.Headers['Location']; $r.Close()
  if ($destino -eq "https://$NOMBRE/course/view.php?id=1") { Write-Host "  OK: http://$NOMBRE/course/view.php?id=1 pasa a $destino" -ForegroundColor Green }
  elseif ($destino -like "https://$NOMBRE*") { Write-Host "  http:// pasa a https://, pero a $destino (se esperaba la misma página)" -ForegroundColor Yellow }
  else { $bien = $false; Write-Host "  http:// no pasa a https:// (Location: $destino)" -ForegroundColor Red }
} catch { $bien = $false; Write-Host "  http://$NOMBRE no responde: $($_.Exception.Message)" -ForegroundColor Red }
if ($bien) { Write-Host "  Listo: abre https://$NOMBRE en el navegador. Si lo tenías abierto, ciérralo y vuelve a abrirlo." -ForegroundColor Green }
else { Write-Host '  Algo no ha ido bien: mira los mensajes de arriba. Para volver atrás:  .\activar_https.ps1 -Deshacer' -ForegroundColor Red; exit 1 }
