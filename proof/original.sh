#!/bin/sh
# usage: original.sh <docs-src/src/backend>  — empties the DB and serves the original on 8072
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$1"
set -a
. "$HERE/original.env"
set +a
[ -f "$HERE/jwt-key.pem" ] || openssl genrsa -out "$HERE/jwt-key.pem" 2048 2>/dev/null
export JWT_PRIVATE_KEY_FILE="$HERE/jwt-key.pem"
export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib
redis-cli -n 7 flushdb >/dev/null
redis-cli -n 6 flushdb >/dev/null
.venv/bin/python manage.py flush --noinput
exec .venv/bin/python manage.py runserver 127.0.0.1:8072 --noreload
