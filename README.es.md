# goodix-27c6-5125-linux

Soporte Linux multi-distribución para el lector de huellas **Goodix
`27c6:5125`** de los Huawei MateBook 16 / MateBook 14 / MateBook D15 y Honor
MagicBook.

> **Estado: experimental.** Está basado en el merge request !648 de libfprint
> (todavía no fusionado). Probado en un Huawei MateBook 16 (CREM-WXX9, Ryzen 7
> 5800H) con firmware `GF_ST411SEC_APP_12508`.
>
> **Nunca se flashea firmware.** El driver se niega a sobrescribir una PSK que
> pertenezca a otro sistema operativo salvo que lo autorices explícitamente.

## Hardware soportado

| Campo | Valor |
|---|---|
| USB | `27c6:5125` |
| Sensor | Goodix ChicagoHS, chip `0x2504` |
| Imagen | 80 x 64 px, matching en el host |
| Firmware probado | `GF_ST411SEC_APP_12508` |
| Portátiles reportados | MateBook 16 CREM-WXX9, MateBook 14, MateBook D15, Honor MagicBook 16 |

## Instalación rápida

```sh
git clone https://github.com/dbyx00/goodix-27c6-5125-linux.git
cd goodix-27c6-5125-linux

# 1. Sonda de solo lectura (no escribe nada)
sudo ./scripts/goodix-ctl probe

# 2. Compila e instala en /opt/goodix-27c6-5125
sudo ./scripts/install.sh --deps

# 3. Reinicia fprintd y registra una huella
sudo systemctl restart fprintd
fprintd-enroll -f right-index-finger "$USER"
fprintd-verify "$USER"
```

La libfprint del sistema **no se toca**: se instala una copia privada en
`/opt/goodix-27c6-5125` y un drop-in de systemd solo para `fprintd`.

Desinstalar:

```sh
sudo ./scripts/uninstall.sh
```

## PSK y convivencia con Windows

El sensor solo guarda un contenedor de 102 bytes y publica su SHA-256. La PSK
real de 32 bytes la guarda el host:

- Linux: `/var/lib/fprint/goodix5125/psk` (0600).
- Windows: `Goodix_Cache.bin`, cifrado con DPAPI.

Casos:

| Situación | Resultado |
|---|---|
| Sensor virgen / PSK cero | El driver genera una PSK, la escribe una vez y verifica el hash |
| Sensor emparejado con este Linux | Usa la PSK guardada; no escribe |
| Sensor emparejado con Windows | **Se niega a sobrescribir**; importa la PSK o re-provisiona |
| Windows arranca tras cambiar la PSK en Linux | Windows tendrá que re-emparejar/re-enrolar |

Re-provisionar explícitamente (solo si no tienes la PSK de Windows):

```sh
sudo GOODIX5125_PROVISION_PSK=random systemctl restart fprintd
```

Eso **no toca el firmware**. Una instalación limpia de Windows podrá generar su
propia PSK después.

## Reglas de seguridad

1. Nunca flashear firmware. El driver no tiene código de actualización.
2. No sobrescribir una PSK ajena sin backup y sin `--yes`.
3. No publicar firmware, PSK, OTP, imágenes ni plantillas.
4. Mantener siempre la contraseña como método alternativo.

## El sensor está en el botón de encendido

En el MateBook, apoya el dedo **suavemente**; no aprietes, porque puedes
suspender el portátil.

## Documentación

- [Instalación y multi-distro](docs/install.md)
- [Conviviencia con Windows](docs/windows-coexistence.md)
- [Hardware y sonda](docs/hardware.md)
- [Validación](docs/validation.md)
- [Créditos y licencias](NOTICE.md)

## Licencia

Scripts y documentación: GPL-2.0-or-later. El driver y las fuentes de libfprint
mantienen sus licencias por fichero, mayoritariamente LGPL-2.1-or-later.
