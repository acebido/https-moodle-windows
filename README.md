# HTTPS gratis en Moodle sobre Windows 11

Script del canal de Acebido (José Luis Díaz) para poner **https://** y el candado a un Moodle
instalado en Windows 11 con IIS. Gratis: el certificado lo crea el propio Windows, sin
descargar ni pagar nada.

Es la continuación de **[instalar-moodle-windows](https://github.com/acebido/instalar-moodle-windows)**
(vídeo: [«Cómo instalar Moodle 5.3 sobre Windows 11 a través de scripts»](https://youtu.be/sbFuGd2EJq8)).
Está pensado para el Moodle que dejan esos scripts: sitio de IIS «Moodle», código en `C:\moodle`
y PHP en `C:\php`.

> Sirve para un **ordenador de pruebas o de prácticas** que abre Moodle en **https://localhost**.
> No hace falta dominio, ni cuenta, ni tocar el router. El certificado solo es de confianza en
> ese ordenador: desde otro equipo saldrá el aviso de seguridad (para eso está
> [moodle-red-local-windows](https://github.com/acebido/moodle-red-local-windows)).

## 📄 Guía

**[Guía en PDF](Guia-HTTPS-Moodle-Windows.pdf)**: con el script y paso a paso a mano, cómo comprobarlo,
cómo volver atrás, los problemas más habituales y cómo proteger Moodle en un ordenador compartido.

## Cómo se ejecuta

1. En esta página, botón verde **Code → Download ZIP** y descomprímelo.
2. **Doble clic en `abrir-powershell-aqui.cmd`** y acepta el aviso de Windows: abre PowerShell
   como administrador, ya colocado en la carpeta y con el script permitido.
3. Escribe y pulsa Intro:

   ```powershell
   .\activar_https.ps1
   ```

4. Cierra el navegador, vuelve a abrirlo y entra en **https://localhost**: sale el candado.

No pregunta nada y tarda menos de un minuto. Debajo de cada paso, en gris, explica qué hace,
y termina con una **comprobación** en verde (bien) o en rojo (con el motivo). Si lo ejecutas
dos veces no pasa nada: lo que ya está hecho, lo deja como está.

## Desde otros equipos de la misma red

Este certificado solo es de confianza en este ordenador. Para que entren otros ordenadores o
móviles de la misma red (casa o aula), hay un segundo vídeo y otro script que parten de lo hecho
aquí: **[moodle-red-local-windows](https://github.com/acebido/moodle-red-local-windows)**.

## Ordenador compartido: proteger Moodle

Si en el ordenador con Moodle entran **otras personas con su propia cuenta de Windows** (un
ordenador del aula, por ejemplo), hay que protegerlo. Windows deja que cualquier usuario del
ordenador lea y cambie `C:\moodle`, `C:\moodledata`, `C:\php` y `C:\mariadb`. Con eso podría ver
la contraseña de la base de datos en `config.php`, copiar todo lo subido a Moodle o cambiar el
código. Quien entra **por el navegador** no puede hacer nada de esto: solo importa quien se sienta
delante del ordenador.

```powershell
.\proteger_moodle.ps1
```

Deja esas carpetas solo para los administradores del ordenador, IIS y MariaDB. `config.php`
queda de solo lectura incluso para IIS. Moodle sigue funcionando igual, con http:// o https://,
y las extensiones se instalan y se actualizan desde la web como siempre. Tarda unos minutos y
lo comprueba al final. Para volver atrás: `.\proteger_moodle.ps1 -Deshacer`.

Si el ordenador es solo tuyo, no hace falta.

## Qué hace

| Paso | Qué hace |
|---|---|
| 1. Certificado | Crea con Windows un certificado para `localhost`, válido 5 años |
| 2. Confianza | Lo añade a las *Entidades de certificación raíz de confianza* del equipo: Edge y Chrome no avisan |
| 3. HTTPS en IIS | Añade al sitio «Moodle» el puerto **443** con ese certificado |
| 4. De http a https | El puerto 80 lo atiende un sitio pequeño, «Moodle - redireccion a HTTPS», que manda cada visita a la misma página en https:// |
| 5. Moodle | Cambia `$CFG->wwwroot` a `https://localhost` en `config.php` (copia en `config.php.antes-https`), cambia los enlaces ya guardados en los cursos y vacía las cachés |

## A mano: las órdenes

Para quien siga la guía paso a paso (como en el vídeo). Cada una es **una sola línea**: cópiala
con el botón de la derecha, pégala en **Terminal (Administrador)** y pulsa Intro.

### Abrir el Terminal como administrador

- **Con el ratón:** botón derecho en el botón **Inicio** de Windows → **Terminal (Administrador)**
  → **Sí**. En Windows 10 se llama *Windows PowerShell (Administrador)*.
- **Con el teclado:** **Windows + X** y después la tecla **A** → **Sí**.
- **Con un doble clic:** descarga **[abrir-powershell-aqui.cmd](https://github.com/acebido/https-moodle-windows/raw/main/abrir-powershell-aqui.cmd)**
  y ábrelo: abre PowerShell como administrador (acepta el aviso de Windows con **Sí**; si sale
  «Windows protegió su PC», **Más información → Ejecutar de todas formas**).

La ventana sabe que es de administrador porque el título lo dice y la línea empieza por
`PS C:\Windows\system32>`. Para pegar: **botón derecho** del ratón o **Ctrl + V**.

Paso 1 · Crear el certificado:

```powershell
New-SelfSignedCertificate -DnsName localhost -CertStoreLocation Cert:\LocalMachine\My -FriendlyName "Moodle localhost" -NotAfter (Get-Date).AddYears(5)
```

Paso 2 · Abrir los certificados del equipo:

```powershell
certlm.msc
```

Pasos 3 y 4 · Abrir el Administrador de IIS:

```powershell
inetmgr
```

Paso 4 · Crear la carpeta del sitio de redirección:

```powershell
mkdir C:\inetpub\moodle-redireccion
```

Paso 4 · Destino de la **Redirección HTTP** (escríbelo tal cual y marca «Redirigir todas las solicitudes al
destino exacto»; `$S$Q` conserva la página y lo que va detrás del `?`):

```text
https://localhost$S$Q
```

Paso 5 · Abrir la configuración de Moodle (cambia `http://localhost` por `https://localhost` y guarda):

```powershell
notepad C:\moodle\config.php
```

Paso 5 · Reiniciar IIS después de guardar (PHP guarda `config.php` en memoria hasta un minuto):

```powershell
iisreset
```

Paso 5 · Cambiar los enlaces ya guardados en los cursos y vaciar las cachés (o desde Moodle, en
`https://localhost/admin/tool/replace/index.php` y `https://localhost/admin/purgecaches.php`):

```powershell
C:\php\php.exe C:\moodle\public\admin\tool\replace\cli\replace.php --search=http://localhost --replace=https://localhost --shorten --non-interactive
```

```powershell
C:\php\php.exe C:\moodle\admin\cli\purge_caches.php
```

## Volver atrás

```powershell
.\activar_https.ps1 -Deshacer
```

Deja Moodle otra vez en **http://localhost**: quita el sitio de la redirección, el puerto 443 y
el certificado, y devuelve la dirección y los enlaces a http://.

---
Acebido · Formación · Tecnología · Futuro — José Luis Díaz.
Moodle es software libre (GPLv3) de Moodle HQ; las marcas citadas pertenecen a sus titulares.
