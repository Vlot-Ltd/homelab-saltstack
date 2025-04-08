#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 {measure_temp, get_throttled, measure_volts, measure_clock_arm}"
    exit 1
}

# Check if an argument is provided
if [ -z "$1" ]; then
    usage
fi

# Function to convert throttled state to JSON
get_throttled_json() {
    # Get the throttled state
    throttled_hex=$(vcgencmd get_throttled | awk -F'=' '{print $2}' | xargs)

    # Convert hex to binary and map to JSON
    throttled_binary=$(echo "obase=2;ibase=16;$throttled_hex" | bc)
    throttled_binary=$(printf "%016d" $throttled_binary)

    # Map binary to JSON
    json="{"
    json+="\"under_voltage\":\"${throttled_binary:0:1}\","
    json+="\"arm_frequency_capped\":\"${throttled_binary:1:1}\","
    json+="\"currently_throttled\":\"${throttled_binary:2:1}\","
    json+="\"soft_temperature_limit_active\":\"${throttled_binary:3:1}\","
    json+="\"under_voltage_has_occurred\":\"${throttled_binary:4:1}\","
    json+="\"arm_frequency_capping_has_occurred\":\"${throttled_binary:5:1}\","
    json+="\"throttling_has_occurred\":\"${throttled_binary:6:1}\","
    json+="\"soft_temperature_limit_has_occurred\":\"${throttled_binary:7:1}\""
    json+="}"

    echo $json
}

# Run the corresponding vcgencmd command based on the argument
case $1 in
    measure_temp)
        # Measure the temperature
        vcgencmd measure_temp | sed 's/[^0-9.]//g' # C
        ;;
    get_throttled)
        # Get the throttled state in JSON format
        get_throttled_json
        ;;
    measure_volts)
        # Measure the core voltage
        vcgencmd measure_volts core | awk -F'=' '{print $2}' | sed 's/V//' # V
        ;;
    measure_clock_arm)
        # Measure the ARM clock speed
        vcgencmd measure_clock arm | awk -F'=' '{print $2/1000000 }' #MHz
        ;;
    *)
        # Invalid option
        usage
        ;;
esac
