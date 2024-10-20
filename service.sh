#!/bin/bash

MODDIR="${0%/*}"
. "$MODDIR/util_functions.sh"

# Variables
SYSTEM_UI_PACKAGE="com.android.systemui"
UI_CHECK_INTERVAL=5  # Time in seconds between each check
UI_STOP_THRESHOLD=40  # Time in seconds to wait before disabling modules if UI is stopped
MODULES_DIR="/data/adb/modules"  # Path to the modules directory
LOG_FILE="/data/local/tmp/system_ui_stop.log"  # Path to log file
BOOT_TIMEOUT=90  # Time in seconds to wait for system boot to complete
BOOT_LOOP_THRESHOLD=3  # Number of boot attempts before considering it a boot loop
MODULE_ID="abootloop"  # ID of this module

# Function to disable all KernelSU/Magisk modules except this one
disable_all_modules_except_self() {
    echo "Disabling all KernelSU/Magisk modules except this one..."
    for module in "$MODULES_DIR"/*/; do
        # Check if the module directory contains the module ID file
        if [ -d "$module" ] && [[ "$module" != *"$MODULE_ID"* ]]; then
            touch "$module/disable"
            echo "Created 'disable' file in $module"
        fi
    done
}

# Function to reboot the device
reboot_system() {
    echo "Rebooting the system..."
    reboot
}

# Function to check if System UI is running
check_system_ui_status() {
    UI_STATUS=$(pidof $SYSTEM_UI_PACKAGE)
    if [ -z "$UI_STATUS" ]; then
        echo "System UI is not running."
        return 1
    else
        echo "System UI is running."
        return 0
    fi
}

# Function to log the time and reason when System UI is stopped
log_system_ui_stop() {
    local stop_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$stop_time] System UI has been stopped for more than $UI_STOP_THRESHOLD seconds. Triggering module disable and system reboot." >> "$LOG_FILE"
    echo "Log written to $LOG_FILE"
}

# Function to log boot timeout and action taken
log_boot_timeout() {
    local boot_timeout_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$boot_timeout_time] Device failed to complete boot within $BOOT_TIMEOUT seconds. Disabling modules and rebooting." >> "$LOG_FILE"
    echo "Log written to $LOG_FILE"
}

# Function to check for boot loop
check_for_boot_loop() {
    local boot_attempts=0
    local boot_start_time=$(date +%s)

    while true; do
        # Check if boot is completed
        if [[ "$(getprop sys.boot_completed)" == '1' ]]; then
            echo "Device has booted successfully."
            return 0  # Exit boot loop check
        fi
        
        # Increment boot attempts
        boot_attempts=$((boot_attempts + 1))
        
        # Check for logs related to System UI or framework issues
        if grep -q "System UI" /data/local/tmp/system_ui_stop.log; then
            echo "Detected System UI issues."
            return 1  # Boot loop detected due to System UI issues
        fi
        
        # Check if attempts exceed the threshold
        if [ $boot_attempts -ge $BOOT_LOOP_THRESHOLD ]; then
            echo "Device is in boot loop. Disabling modules and rebooting."
            return 2  # Boot loop confirmed
        fi
        
        # Sleep for a short period before the next check
        sleep 5
    done
}

# Check if system boot is completed, wait max $BOOT_TIMEOUT seconds
boot_start_time=$(date +%s)
while [[ "$(getprop sys.boot_completed)" != '1' ]]; do
    # Calculate elapsed time since the script started checking for boot completion
    current_time=$(date +%s)
    elapsed_boot_time=$((current_time - boot_start_time))

    if [ $elapsed_boot_time -ge $BOOT_TIMEOUT ]; then
        # If boot is not completed within the timeout, log the event, disable modules, and reboot
        log_boot_timeout
        disable_all_modules_except_self
        reboot_system
        exit 1  # Exit after reboot is triggered
    fi

    # Check every second if boot is completed
    sleep 1
done

# Check for boot loop due to System UI issues
if check_for_boot_loop; then
    echo "No boot loop detected."
else
    disable_all_modules_except_self
    reboot_system
    exit 1
fi

# Monitor System UI status and disable modules if stopped for more than 40 seconds
ui_stop_time=0
while :; do
    if ! check_system_ui_status; then
        # If System UI is stopped, start counting the time
        if [ $ui_stop_time -eq 0 ]; then
            ui_stop_time=$(date +%s)
        fi

        # Check how long the System UI has been stopped
        current_time=$(date +%s)
        elapsed_time=$((current_time - ui_stop_time))

        if [ $elapsed_time -ge $UI_STOP_THRESHOLD ]; then
            log_system_ui_stop
            disable_all_modules_except_self
            reboot_system
            break
        fi
    else
        # Reset the timer if System UI is running again
        ui_stop_time=0
    fi

    # Wait for the next interval before checking again
    sleep $UI_CHECK_INTERVAL
done
