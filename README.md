# HTTPS gratis en Moodle sobre Windows 11

Script del canal de Acebido (José Luis Díaz) para poner **https://** y el candado a un Moodle
instalado en Windows 11 con IIS. Gratis: el certificado lo crea el propio Windows, sin
descargar ni pagar nada.

Es la continuación de **[instalar-moodle-windows](https://github.com/acebido/instalar-moodle-windows)**
(vídeo: [«Cómo instalar Moodle 5.3 sobre Windows 11 a través de scripts»](https://youtu.be/sbFuGd2EJq8)).
Está pensado para el Moodle que dejan esos scripts: sitio de IIS «Moodle», código en `C:\moodle`
y PHP en `C:\php`.

> Sirve para un **ordenador de pruebas o de prácticas** que abre Moodle en **https://localhost**.
> El certificado solo es de confianza en ese ordenador. Para un Moodle abierto a internet, con
> su dominio, hace falta un certificado de Let's Encrypt (también gratis): lo explica la guía.

## 📄 Guía

**[Guía en PDF](Guia-HTTPS-Moodle-Windows.pdf)**: con el script y paso a paso a mano, cómo comprobarlo,
cómo volver atrás y los problemas más habituales.

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

## Qué hace

| Paso | Qué hace |
|---|---|
| 1. Certificado | Crea con Windows un certificado para `localhost`, válido 5 años |
| 2. Confianza | Lo añade a las *Entidades de certificación raíz de confianza* del equipo: Edge y Chrome no avisan |
| 3. HTTPS en IIS | Añade al sitio «Moodle» el puerto **443** con ese certificado |
| 4. De http a https | El puerto 80 lo atiende un sitio pequeño, «Moodle - redireccion a HTTPS», que manda cada visita a la misma página en https:// |
| 5. Moodle | Cambia `$CFG->wwwroot` a `https://localhost` en `config.php` (copia en `config.php.antes-https`), cambia los enlaces ya guardados en los cursos y vacía las cachés |

## Volver atrás

```powershell
.\activar_https.ps1 -Deshacer
```

Deja Moodle otra vez en **http://localhost**: quita el sitio de la redirección, el puerto 443 y
el certificado, y devuelve la dirección y los enlaces a http://.

---
Acebido · Formación · Tecnología · Futuro — José Luis Díaz.
Moodle es software libre (GPLv3) de Moodle HQ; las marcas citadas pertenecen a sus titulares.
