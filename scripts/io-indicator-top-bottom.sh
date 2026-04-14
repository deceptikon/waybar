#!/bin/bash

# Get IOPS data from iostat
# Format: ↓READ_MB/s ↑WRITE_MB/s (IOPS: NUMBER)
io_data=$(iostat -d 1 2 | grep '^nvme' | tail -n 1)

# Extract values
read_mb=$(echo "$io_data" | awk '{print $3/1024}')
write_mb=$(echo "$io_data" | awk '{print $4/1024}')
iops=$(echo "$io_data" | awk '{print $2}')

# Calculate total MB/s for progress bar (assuming max around 2000 MB/s for NVMe)
total_mb=$(echo "$read_mb + $write_mb" | bc)
# Cap at 2000 MB/s for percentage calculation
if (( $(echo "$total_mb > 2000" | bc -l) )); then
    total_mb=2000
fi

# Calculate percentage for progress bar (0-2000 MB/s -> 0-100%)
usage_percent=$(echo "scale=0; $total_mb * 100 / 2000" | bc)
usage_int=$(printf "%.0f" "$usage_percent")

# Determine class based on usage
if (( usage_int <= 30 )); then
    io_class="transparent"
    io_icon="󰋊"
elif (( usage_int <= 50 )); then
    io_class="low"
    io_icon="󰋊"
elif (( usage_int <= 80 )); then
    io_class="medium"
    io_icon="󰋊"
else
    io_class="high"
    io_icon="󰋊"
fi

# Create thinner progress bar visualization (5 blocks)
filled_blocks=$(( usage_int / 20 ))  # Each block represents 20%
empty_blocks=$(( 5 - filled_blocks ))   # Total of 5 blocks for 100%

# Create the progress bar using block characters
progress_bar=""
for ((i=0; i<filled_blocks; i++)); do
    progress_bar+="█"
done
for ((i=0; i<empty_blocks; i++)); do
    progress_bar+="░"
done

# Format numbers for display (one decimal place)
read_formatted=$(printf "%.1f" "$read_mb")
write_formatted=$(printf "%.1f" "$write_mb")

# For top-bottom layout, we output the progress bar on first line, text on second
# Using newline to separate them
echo "{\"text\":\"$progress_bar\\n$io_icon ↓${read_formatted} ↑${write_formatted}\",\"tooltip\":\"IOPS: $iops | Read: ${read_formatted} MB/s | Write: ${write_formatted} MB/s\nProgress on top, details on bottom\",\"class\":\"$io_class\"}" | jq --compact-output