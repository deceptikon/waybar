#!/bin/bash
if yad --title="Bluetooth" --text="Toggle Bluetooth?" --button="Yes:0" --button="No:1" --center --width=200 --borders=20 --undecorated --on-top; then
    rfkill toggle bluetooth
fi
