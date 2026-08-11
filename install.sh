#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec sh "$repo_root/platforms/unix/install.sh" "$@"
