#!/bin/bash
KBD_LED="/sys/class/leds/asus::kbd_backlight/brightness"
TIMEOUT=10
KBD_DEV="/dev/input/by-path/platform-i8042-serio-0-event-kbd"
LAST_ACTION="/tmp/kbd_last_action"

# Функция для выключения света
function turn_off {
    echo 0 > "$KBD_LED"
}

# 1. Запускаем фоновый "чекер", который спит и проверяет время
(
    while true; do
        if [ -f "$LAST_ACTION" ]; then
            LAST=$(cat "$LAST_ACTION")
            NOW=$(date +%s)
            DIFF=$((NOW - LAST))

            # Если прошло больше времени, чем таймаут - гасим
            if [ "$DIFF" -ge "$TIMEOUT" ]; then
                # Проверяем, не горит ли уже 0, чтобы не писать лишний раз
                if [ "$(cat $KBD_LED)" -ne 0 ]; then
                    turn_off
                fi
            fi
        fi
        sleep 1 # Проверяем раз в секунду, этого достаточно
    done
) &

# 2. Основной цикл: просто записываем текущее время при каждом нажатии
# Теперь здесь НЕТ pkill и фоновых sleep, это максимально быстро
evtest "$KBD_DEV" | grep --line-buffered "value 1" | while read -r line; do
    # Включаем свет, если он был выключен
    if [ "$(cat $KBD_LED)" -eq 0 ]; then
        echo 2 > "$KBD_LED"
    fi
    # Обновляем метку времени
    date +%s > "$LAST_ACTION"
done

# #!/bin/bash
# KBD_LED="/sys/class/leds/asus::kbd_backlight/brightness"
# TIMEOUT=10
# # Проверяем путь (может быть event6, event7 и т.д., by-path надежнее)
# KBD_DEV="/dev/input/by-path/platform-i8042-serio-0-event-kbd"

# # Если путь поменялся, скрипт не упадет молча
# if [ ! -e "$KBD_DEV" ]; then
#     logger "Zenbook Error: Keyboard device $KBD_DEV not found"
#     exit 1
# fi

# # Принудительно гасим в начале
# echo 0 > "$KBD_LED"

# # Запускаем мониторинг
# # Используем более простой grep, чтобы точно поймать событие нажатия
# evtest "$KBD_DEV" | while read -r line; do
#     # Если в строке есть "value 1" (нажатие) или "value 2" (зажатие)
#     if [[ "$line" == *"value 1"* || "$line" == *"value 2"* ]]; then
#         # Включаем свет
#         echo 2 > "$KBD_LED"

#         # Убиваем старый таймер
#         pkill -f "sleep $TIMEOUT && echo 0 > $KBD_LED"

#         # Запускаем новый таймер в фоне
#         (sleep $TIMEOUT && echo 0 > "$KBD_LED") &
#     fi
# done
