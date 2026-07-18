# draw-module.sh — Template for up to three-row module info boxes
#
# Provides: draw_module <icon> <row1> <row2> <color_hex> [class] [row3]
#
# When icon is empty: plain Pango text lines separated by newlines.
# When icon is set: draws a Unicode box with icon in left column
# (vertically centered) and data rows in right column.
#
#   icon      Nerd Font glyph (e.g. "󰢮") — empty for plain text
#   row1/2/3  Row content (may contain Pango markup)
#   color_hex Accent color e.g. "#fab387"
#   class     Waybar state class: good|medium|warning|critical
#
# Output: Waybar JSON with Pango text and class.

draw_module() {
  local icon="$1"
  local row1="$2"
  local row2="$3"
  local color="$4"
  local cls="${5:-good}"
  local row3="${6:-}"
  local row4="${7:-}"

  if [ -z "$icon" ]; then
    if [ -n "$row4" ]; then
      text=$(printf "<span fgcolor='%s'>%s\n%s\n%s\n%s</span>" "$color" "$row1" "$row2" "$row4" "$row3")
    elif [ -n "$row3" ]; then
      text=$(printf "<span fgcolor='%s'>%s\n%s\n%s</span>" "$color" "$row1" "$row2" "$row3")
    else
      text=$(printf "<span fgcolor='%s'>%s\n%s</span>" "$color" "$row1" "$row2")
    fi
    jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
    return
  fi

  local r1p=$(echo "$row1" | sed 's/<[^>]*>//g')
  local r2p=$(echo "$row2" | sed 's/<[^>]*>//g')
  local r3p=""
  [ -n "$row3" ] && r3p=$(echo "$row3" | sed 's/<[^>]*>//g')

  local w1=${#r1p} w2=${#r2p} w3=${#r3p}
  local nrows=2; [ -n "$row3" ] && nrows=3
  for w in "$w2" "$w3"; do [ "$w" -gt "$w1" ] && w1=$w; done

  local ic=3
  local dw=$((w1 + 2))
  local p1=$((dw - 1 - w1))
  local p2=$((dw - 1 - w2))
  local p3=$((dw - 1 - w3))

  local h=$(printf '%*s' "$dw" ''); h="${h// /─}"
  local ic_line=$(printf '%*s' "$ic" ''); ic_line="${ic_line// /─}"
  local top=$(printf '┌%s┬%s┐' "$ic_line" "$h")
  local mid=$(printf '├%s┼%s┤' "$ic_line" "$h")
  local bot=$(printf '└%s┴%s┘' "$ic_line" "$h")

  local line1=$(printf '│%s│ %s%*s│' " ${icon} " "$row1" "$p1" '')
  local line2=$(printf '│%*s│ %s%*s│' "$ic" '' "$row2" "$p2" '')
  local line3=$(printf '│%*s│ %s%*s│' "$ic" '' "$row3" "$p3" '')

  if [ "$nrows" -eq 3 ]; then
    local text=$(printf "<span fgcolor='%s'>%s\n%s\n%s\n%s\n%s\n%s\n%s</span>" \
      "$color" "$top" "$line1" "$mid" "$line2" "$mid" "$line3" "$bot")
  else
    local text=$(printf "<span fgcolor='%s'>%s\n%s\n%s\n%s\n%s</span>" \
      "$color" "$top" "$line1" "$mid" "$line2" "$bot")
  fi

  jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
}

# draw_box <line1> [<line2> ...]
# Wraps Pango-formatted lines (each padded to same visual width) in a unicode box.
# Output: Pango text (no JSON wrapper).
draw_box() {
  local -a lines=("$@")
  local maxw=0
  for line in "${lines[@]}"; do
    local plain=$(echo "$line" | sed 's/<[^>]*>//g')
    [ ${#plain} -gt $maxw ] && maxw=${#plain}
  done

  local bw=$((maxw + 2))
  local h=$(printf '%*s' "$bw" ''); h="${h// /─}"

  local result="╭${h}╮"
  for line in "${lines[@]}"; do
    result+=$'\n'"│ ${line} │"
  done
  result+=$'\n'"╰${h}╯"

  echo "$result"
}
