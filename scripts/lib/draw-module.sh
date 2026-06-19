# draw-module.sh — Base template for two-row module info boxes
#
# Provides: draw_module <icon> <row1> <row2> <color_hex> [class]
#
# Renders a Unicode box with icon in left column (merged vertical cells)
# and data text in right column (one cell per row).
#
#   icon      Nerd Font glyph (e.g. "󰢮")
#   row1      Top row content (may contain Pango markup)
#   row2      Bottom row content (may contain Pango markup)
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

  if [ -z "$icon" ]; then
    text=$(printf "<span fgcolor='%s'>%s\n%s</span>" "$color" "$row1" "$row2")
    jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
    return
  fi

  local r1p=$(echo "$row1" | sed 's/<[^>]*>//g')
  local r2p=$(echo "$row2" | sed 's/<[^>]*>//g')

  local w1=${#r1p}
  local w2=${#r2p}
  [ "$w2" -gt "$w1" ] && w1=$w2

  local ic=3        # icon col inner width: " 󰢮 "
  local dw=$((w1 + 2))   # data col inner width: " text"
  local p1=$((dw - 1 - w1))
  local p2=$((dw - 1 - w2))

  local h=$(printf '%*s' "$dw" '' | tr ' ' '─')
  local top=$(printf '┌%s┬%s┐' "$(printf '%*s' "$ic" '' | tr ' ' '─')" "$h")
  local mid=$(printf '├%s┼%s┤' "$(printf '%*s' "$ic" '' | tr ' ' '─')" "$h")
  local bot=$(printf '└%s┴%s┘' "$(printf '%*s' "$ic" '' | tr ' ' '─')" "$h")

  local line1=$(printf '│%s│ %s%*s│' " ${icon} " "$row1" "$p1" '')
  local line2=$(printf '│%*s│ %s%*s│' "$ic" '' "$row2" "$p2" '')

  local text=$(printf "<span fgcolor='%s'>%s\n%s\n%s\n%s\n%s</span>" \
    "$color" "$top" "$line1" "$mid" "$line2" "$bot")

  jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
}
