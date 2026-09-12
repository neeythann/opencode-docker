#!/bin/sh
set -e
export HOME=/home/dev
if [ -n "$ROOT_PASSWORD" ]; then
  echo "root:$ROOT_PASSWORD" | chpasswd
fi
exec setpriv --reuid=dev --regid=dev --init-groups "$@"
