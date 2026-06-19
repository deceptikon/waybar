#!/usr/bin/env bash
set -euo pipefail
metric="${1:-gpu}"
case "$metric" in
  gpu)  echo '{"text":" 󰢮 ","class":"good"}' ;;
  cpu)  echo '{"text":" 󰍛 ","class":"good"}' ;;
  ram)  echo '{"text":"  ","class":"good"}' ;;
  ssd)  echo '{"text":" 󰋊 ","class":"good"}' ;;
  temp) echo '{"text":" 󰔐 ","class":"good"}' ;;
  asus) echo '{"text":"  ","class":"good"}' ;;
  *)    echo '{"text":"?","class":"good"}' ;;
esac
