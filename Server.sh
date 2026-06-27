#!/bin/sh
printf '\033c\033]0;%s\a' AmongBots
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Server.x86_64" "$@"
