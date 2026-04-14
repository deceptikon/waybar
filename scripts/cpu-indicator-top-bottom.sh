#!/bin/bash

# Get CPU usage percentage and per-core usage
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Get per-core usage (simplified - showing average)
cpu_usage_int=$(printf "%.0f" "$cpu_usage")

# Determine class based on usage
if (( cpu_usage_int <= 30 )); then
    cpu_class="transparent"
    cpu_icon=""
elif (( cpu_usage_int <= 50 )); then
    cpu_class="low"
    cpu_icon=""
elif (( cpu_usage_int <= 80 )); then
    cpu_class="medium"
    cpu_icon=""
else
    cpu_class="high"
    cpu_icon=""
fi

# Create thinner progress bar visualization (5 blocks)
filled_blocks=$(( cpu_usage_int / 20 ))  # Each block represents 20%
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
echo "{\"text\":\"$progress_bar\\n$cpu_icon $cpu_usage_int%\",\"tooltip\":\"CPU Usage: $cpu_usage_int%\nProgress on top, details on bottom\",\"class\":\"$cpu_class\"}" | jq --compact-output