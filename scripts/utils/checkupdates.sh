#!/bin/bash

count=`yay -Qu | grep -v "\[ignored\]" | wc -l`

if [[ "$count" != "0" ]]; then
    echo '{"text":" <sup>'$count'</sup>","tooltip":"'$count updates pending'","class":"notify"}' | jq --compact-output
else
  echo '{"text":"  ","tooltip":"System is up-to-date","class":"good"}' | jq --compact-output
fi
