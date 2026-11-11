# umami-analytics

Infraestructura de la analítica web self-hosted de Hemia / MedSync con [Umami](https://umami.is).

- **Panel:** https://analytics.hemia.cloud (el dominio anterior, analytics.medsync.mx, se retiró el 2026-11-10)
- **Versión:** Umami 3.4.1 + PostgreSQL 16 (alpine), en Docker
- **Servidor:** VPS Contabo `vmi3712604`, carpeta `/opt/umami`
- **Puerto interno:** `127.0.0.1:3100` → contenedor `umami:3000` (no expuesto a internet; entra por Nginx)

> Este repo **no** contiene secretos. Las contraseñas viven en `/opt/umami/.env` y `/opt/umami/CREDENCIALES.txt` en el VPS (solo root) y en el gestor de contraseñas del equipo. Mantén el repo **privado**.

La integración del front (el código que carga `stats.js` y manda las visitas) **no** está aquí: vive en el front de MedSync, `hemia-labs/medsync-front-legacy`, archivo `src/config/analytics.config.js`.

## Contenido

| Archivo | En el VPS | Qué es |
|---|---|---|
| `docker-compose.yml` | `/opt/umami/docker-compose.yml` | Contenedores `umami` y `umami-db` |
| `.env.example` | `/opt/umami/.env` | Variables necesarias (sin valores) |
| `backup.sh` | `/opt/umami/backup.sh` | Respaldo de Postgres (retención 14 días) |
| `cron/umami-backup` | `/etc/cron.d/umami-backup` | Respaldo diario 09:15 UTC (03:15 hora de México) |
| `nginx/analytics.conf` | `/etc/nginx/conf.d/analytics.hemia.cloud.conf` | Virtual host (proxy a 127.0.0.1:3100 + SSL de certbot) |

## Sitios registrados

| Nombre | Dominio medido | Website ID |
|---|---|---|
| MedSync App | app.medsync.mx | `f31fac4b-3403-46f5-8901-fe224350ac00` |

El website ID no es secreto: queda visible en el HTML de cualquier sitio que usa Umami.

```html
<script defer src="https://analytics.hemia.cloud/stats.js"
        data-website-id="f31fac4b-3403-46f5-8901-fe224350ac00"
        data-domains="app.medsync.mx"></script>
```

## Instalación desde cero

```bash
mkdir -p /opt/umami && cd /opt/umami
# copiar docker-compose.yml y backup.sh de este repo
cp .env.example .env && nano .env        # poner contraseñas nuevas
chmod 700 /opt/umami && chmod 600 .env
docker compose up -d
curl -s http://127.0.0.1:3100/api/heartbeat   # -> {"ok":true}

# Nginx + SSL
cp nginx/analytics.conf /etc/nginx/conf.d/
nginx -t && systemctl reload nginx
certbot --nginx -d analytics.hemia.cloud

# Respaldo diario
cp backup.sh /opt/umami/ && chmod 700 /opt/umami/backup.sh
cp cron/umami-backup /etc/cron.d/
```

Después de instalar, entra al panel y cambia la contraseña por defecto (`admin` / `umami`).

## Operación (como root en el VPS)

```bash
cd /opt/umami
docker compose ps                              # estado
docker compose logs -f umami                   # logs
docker compose restart umami                   # reiniciar
docker compose pull && docker compose up -d    # actualizar Umami
/opt/umami/backup.sh                           # respaldo manual
curl -s http://127.0.0.1:3100/api/heartbeat    # salud -> {"ok":true}

# Restaurar un respaldo (¡reemplaza los datos actuales!)
gunzip -c backups/ARCHIVO.sql.gz | docker exec -i umami-db psql -U umami umami
```

Antes de actualizar a una versión mayor, haz un respaldo manual y revisa las notas de versión: https://github.com/umami-software/umami/releases

## Historial

- **2026-10-30:** instalación inicial en `analytics.medsync.mx`.
- **2026-11-10:** se agrega `analytics.hemia.cloud` al mismo virtual host y al certificado (SAN con ambos dominios).
- **2026-11-10:** el front de producción (v0.3.1) ya usa `analytics.hemia.cloud`, así que se retira `analytics.medsync.mx`: sale del `server_name`, se emite un certificado solo para `analytics.hemia.cloud` (vence 2027-02-09, renovación automática), se borra el certificado anterior y el vhost se renombra a `analytics.hemia.cloud.conf`.

## Pendiente

- Borrar el registro DNS `analytics` de `medsync.mx`. El bloque `if ($host = analytics.medsync.mx)` del puerto 80 lo dejó certbot y ya no se usa; se puede quitar del vhost.
- `docker-compose.yml` usa la imagen `umami:latest`, así que un `docker compose pull` puede saltar a una versión mayor sin aviso. Conviene fijar la versión (por ejemplo `umami:3.4.1`) y subirla a mano después de un respaldo.
- Seguridad del VPS (fuera de este repo): ufw permite desde cualquier IP los puertos 3306, 5432, 6379 y 5672. Se recomienda restringirlos.
