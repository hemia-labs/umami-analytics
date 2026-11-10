#!/bin/bash
# Respaldo diario de la base de Umami. Conserva 14 dias.
set -e
cd /opt/umami
F=backups/umami-$(date +%F_%H%M).sql.gz
docker exec umami-db pg_dump -U umami umami | gzip > "$F"
chmod 600 "$F"
find backups -name "umami-*.sql.gz" -mtime +14 -delete
