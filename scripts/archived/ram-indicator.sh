#!/bin/bash
set -euo pipefail

# Get memory usage in GB
read -r mem_total_kb mem_used_kb mem_free_kb < <(free | awk '/Mem/{print $2, $3, $4}')
read -r swap_total_kb swap_used_kb < <(free | awk '/^Swap/{print $2, $3}')

# Convert to GB (1 decimal)
mem_total_gb=$(awk "BEGIN{printf \"%.1f\", $mem_total_kb/1048576}")
mem_used_gb=$(awk "BEGIN{printf \"%.1f\", $mem_used_kb/1048576}")
swap_used_gb=$(awk "BEGIN{printf \"%.1f\", ${swap_used_kb:-0}/1048576}")

# Calculate usage percentage for coloring
mem_usage_int=$(awk "BEGIN{printf \"%d\", ($mem_used_kb/$mem_total_kb)*100}")

# Determine class based on usage
if (( mem_usage_int <= 30 )); then
    mem_class="transparent"
elif (( mem_usage_int <= 50 )); then
    mem_class="low"
elif (( mem_usage_int <= 80 )); then
    mem_class="medium"
else
    mem_class="high"
fi

# Progress bar (5 blocks)
filled_blocks=$(( mem_usage_int / 20 ))
empty_blocks=$(( 5 - filled_blocks ))

progress_bar=""
for ((i=0; i<filled_blocks; i++)); do
    progress_bar+="█"
done
for ((i=0; i<empty_blocks; i++)); do
    progress_bar+="░"
done

# Compact text: icon bar used/totalG [swap]
text=" $progress_bar ${mem_used_gb}/${mem_total_gb}G"
if (( $(awk "BEGIN{print ($swap_used_gb > 0.01)}") )); then
    text+=" ⇄ ${swap_used_gb}G"
fi

# Output JSON for Waybar
jq -n --arg t "$text" --arg tip "RAM: ${mem_used_gb}G/${mem_total_gb}G (${mem_usage_int}%)\nSwap: ${swap_used_gb}G" --arg c "$mem_class" \
    '{text:$t,tooltip:$tip,class:$c}' --compact-output
