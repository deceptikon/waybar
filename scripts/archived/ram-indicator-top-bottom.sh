#!/bin/bash

# Get memory usage in GB
mem_info=$(free | grep Mem)
mem_total_kb=$(echo "$mem_info" | awk '{print $2}')
mem_used_kb=$(echo "$mem_info" | awk '{print $3}')
mem_free_kb=$(echo "$mem_info" | awk '{print $4}')

# Convert to GB (rounded to nearest whole number)
mem_total_gb=$(echo "scale=0; $mem_total_kb / 1024 / 1024" | bc)
mem_used_gb=$(echo "scale=0; $mem_used_kb / 1024 / 1024" | bc)
mem_free_gb=$(echo "scale=0; $mem_free_kb / 1024 / 1024" | bc)

# Calculate usage percentage for progress bar and coloring
mem_usage=$(echo "scale=2; $mem_used_kb * 100 / $mem_total_kb" | bc)
mem_usage_int=$(printf "%.0f" "$mem_usage")

# Determine class based on usage
if (( mem_usage_int <= 30 )); then
    mem_class="transparent"
    mem_icon=""
elif (( mem_usage_int <= 50 )); then
    mem_class="low"
    mem_icon=""
elif (( mem_usage_int <= 80 )); then
    mem_class="medium"
    mem_icon=""
else
    mem_class="high"
    mem_icon=""
fi

# Create thinner progress bar visualization (5 blocks)
filled_blocks=$(( mem_usage_int / 20 ))  # Each block represents 20%
empty_blocks=$(( 5 - filled_blocks ))    # Total of 5 blocks for 100%

# Create the progress bar using block characters
progress_bar=""
for ((i=0; i<filled_blocks; i++)); do
    progress_bar+="█"
done
for ((i=0; i<empty_blocks; i++)); do
    progress_bar+="░"
done

# For top-bottom layout, we output the progress bar on first line, text on second
# Using newline to separate them
echo "{\"text\":\"$progress_bar\\n$mem_icon ${mem_used_gb}/${mem_total_gb}G\",\"tooltip\":\"RAM Usage: ${mem_used_gb}G/${mem_total_gb}G (${mem_usage_int}%)\nProgress on top, details on bottom\",\"class\":\"$mem_class\"}" | jq --compact-output