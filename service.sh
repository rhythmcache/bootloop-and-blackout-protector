#!/bin/bash

MODDIR="${0%/*}"
. "$MODDIR/util_functions.sh"

# Variables
SYSTEM_UI_PACKAGE="com.android.systemui"
UI_CHECK_INTERVAL=5  # Time in seconds between each check
UI_STOP_THRESHOLD=40  # Time in seconds to wait before disabling modules if UI is stopped
MODULES_DIR="/data/adb/modules"  # Path to the modules directory
BBOOTLOOP_LOG="/data/local/tmp/bbootloop.log"  # Path to the main log file
SYSTEM_UI_CRASH_LOG="/data/local/tmp/system_ui_crash.log"  # Log for system UI crashes
BOOT_TIMEOUT=90  # Time in seconds to wait for system boot to complete
BOOT_LOOP_THRESHOLD=3  # Number of boot attempts before considering it a boot loop
MODULE_ID="bbootloop"  # ID of this module

# Function to log messages with timestamp and log file size
log_message() {
    local message="$1"
    local log_file="$2"
    CURRENT_DATETIME=$(date '+%Y-%m-%d %H:%M:%S')  # Get current date and time
    LOG_SIZE=$(du -k "$BBOOTLOOP_LOG" | cut -f1)  # Get current log size
    echo "[$CURRENT_DATETIME] $message (Log size: ${LOG_SIZE}KB)" >> "$log_file"
}

# Function to disable all KernelSU/Magisk modules except this one
disable_all_modules_except_self() {
    log_message "Disabling all KernelSU/Magisk modules except this one..." "$BBOOTLOOP_LOG"
    for module in "$MODULES_DIR"/*/; do
        if [ -d "$module" ] && [[ "$module" != *"$MODULE_ID"* ]]; then
            touch "$module/disable"
            log_message "Created 'disable' file in $module" "$BBOOTLOOP_LOG"
        fi
    done
}

# Function to reboot the device
reboot_system() {
    log_message "Rebooting the system..." "$BBOOTLOOP_LOG"
    reboot
}

# Function to check if System UI is running
check_system_ui_status() {
    UI_STATUS=$(pidof $SYSTEM_UI_PACKAGE)
    if [ -z "$UI_STATUS" ]; then
        log_message "System UI is not running." "$BBOOTLOOP_LOG"
        return 1
    else
        log_message "System UI is running." "$BBOOTLOOP_LOG"
        return 0
    fi
}

# Function to log the time when System UI is stopped for more than 40 seconds
log_system_ui_stop() {
    log_message "System UI has been stopped for more than $UI_STOP_THRESHOLD seconds. Triggering module disable and system reboot." "$SYSTEM_UI_CRASH_LOG"
    log_message "System UI has been stopped for more than $UI_STOP_THRESHOLD seconds." "$BBOOTLOOP_LOG"
}

# Function to log boot timeout and action taken
log_boot_timeout() {
    log_message "Device failed to complete boot within $BOOT_TIMEOUT seconds. Disabling modules and rebooting." "$BBOOTLOOP_LOG"
}

# Function to check for boot loop
check_for_boot_loop() {
    local boot_attempts=0
    while true; do
        if [[ "$(getprop sys.boot_completed)" == '1' ]]; then
            log_message "Device has booted successfully." "$BBOOTLOOP_LOG"
            return 0
        fi
        boot_attempts=$((boot_attempts + 1))
        if [ $boot_attempts -ge $BOOT_LOOP_THRESHOLD ]; then
            log_message "Device is in boot loop. Disabling modules and rebooting." "$BBOOTLOOP_LOG"
            return 2
        fi
        sleep 5
    done
}

# Function to rotate logs based on size and age
rotate_log() {
    LOG_SIZE=$(du -k "$BBOOTLOOP_LOG" | cut -f1)
    if [ "$LOG_SIZE" -ge 100 ]; then
        mv "$BBOOTLOOP_LOG" "$BBOOTLOOP_LOG.$(date '+%Y%m%d%H%M%S')"
        touch "$BBOOTLOOP_LOG"
    fi

    find "$(dirname "$BBOOTLOOP_LOG")" -name "bbootloop.log*" -mtime +2 -exec rm {} \;
}

# Check if system boot is completed, wait max $BOOT_TIMEOUT seconds
boot_start_time=$(date +%s)
while [[ "$(getprop sys.boot_completed)" != '1' ]]; do
    current_time=$(date +%s)
    elapsed_boot_time=$((current_time - boot_start_time))
    if [ $elapsed_boot_time -ge $BOOT_TIMEOUT ]; then
        log_boot_timeout
        disable_all_modules_except_self
        reboot_system
        exit 1
    fi
    sleep 1
done

# Check for boot loop due to System UI issues
if check_for_boot_loop; then
    log_message "No boot loop detected." "$BBOOTLOOP_LOG"
else
    disable_all_modules_except_self
    reboot_system
    exit 1
fi

# Monitor System UI status and disable modules if stopped for more than 40 seconds
ui_stop_time=0
while :; do
    rotate_log  # Perform log rotation at each loop iteration
    if ! check_system_ui_status; then
        if [ $ui_stop_time -eq 0 ]; then
            ui_stop_time=$(date +%s)
        fi
        current_time=$(date +%s)
        elapsed_time=$((current_time - ui_stop_time))
        if [ $elapsed_time -ge $UI_STOP_THRESHOLD ]; then
            log_system_ui_stop
            disable_all_modules_except_self
            reboot_system
            break
        fi
    else
        ui_stop_time=0
    fi
    sleep $UI_CHECK_INTERVAL
done
