#!/bin/bash

# Usage: alarm HH:MM [-m "message"] [--no-sound]
#        alarm --tempo MM:SS [-m "message"] [--no-sound]
#        alarm --schedule HH:MM -m "message" --days DAYS [--no-sound]
#        alarm --list | --remove ID | --clear-all

# Systemd timer configuration
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
TIMER_PREFIX="alarm"
SCRIPT_PATH="$(readlink -f "$0")"

TIME=""
TEMPO_MODE=""
SCHEDULE_MODE=""
NO_SOUND=""
MESSAGE=""
DAYS=""
SCHEDULE_ID=""
ACTION=""
UUID=""
TEMPO_THRESHOLD=180  # Default: 3 minutes (180 seconds)

# Ensure systemd user directory exists
ensure_systemd_dir() {
    if [[ ! -d "$SYSTEMD_USER_DIR" ]]; then
        mkdir -p "$SYSTEMD_USER_DIR"
    fi
}

# Argument parsing with while loop
while [[ $# -gt 0 ]]; do
  case $1 in
    --tempo)
      TEMPO_MODE="true"
      TIME="$2"
      shift 2
      ;;
    --tempo-threshold)
      TEMPO_THRESHOLD="$2"
      # Validate that threshold is a positive integer
      if ! [[ "$TEMPO_THRESHOLD" =~ ^[0-9]+$ ]] || [[ "$TEMPO_THRESHOLD" -le 0 ]]; then
        echo -e "\e[31mError:\e[0m Tempo threshold must be a positive integer (seconds)"
        exit 1
      fi
      shift 2
      ;;
    --schedule)
      SCHEDULE_MODE="true"
      TIME="$2"
      shift 2
      ;;
    --days)
      DAYS="$2"
      shift 2
      ;;
    -m|--message)
      MESSAGE="$2"
      shift 2
      ;;
    --no-sound)
      NO_SOUND="true"
      shift
      ;;
    --list)
      ACTION="list"
      shift
      ;;
    --remove)
      ACTION="remove"
      SCHEDULE_ID="$2"
      shift 2
      ;;
    --clear-all)
      ACTION="clear"
      shift
      ;;
    --internal-trigger)
      # Internal mode for systemd timer execution
      ACTION="trigger"
      MESSAGE="$2"
      shift 2
      ;;
    --uuid)
      UUID="$2"
      shift 2
      ;;
    -h|--help)
      echo -e "\e[36mAlarm System v2 (systemd)\e[0m - A comprehensive alarm management tool"
      echo -e "Create instant alarms, schedule recurring alarms, or set relative time alarms."
      echo -e "All alarms show desktop notifications and play sound alerts.\n"
      echo -e "\e[32mUsage:\e[0m"
      echo -e "  alarm HH:MM [-m \"message\"] [--no-sound]"
      echo -e "  alarm --tempo MM:SS [-m \"message\"] [--no-sound] [--tempo-threshold SECONDS]"
      echo -e "  alarm --schedule HH:MM -m \"message\" --days DAYS [--no-sound]"
      echo -e "  alarm --list"
      echo -e "  alarm --remove ID"
      echo -e "  alarm --clear-all"
      echo -e "\e[32mExamples:\e[0m"
      echo -e "  alarm 14:30 -m \"Important meeting\""
      echo -e "  alarm --tempo 05:00 -m \"Break\" --no-sound"
      echo -e "  alarm --tempo 02:30 --tempo-threshold 60 -m \"Use sleep for ≤1min, systemd for >1min\""
      echo -e "  alarm --schedule 09:00 -m \"Daily Standup\" --days weekdays"
      echo -e "  alarm --schedule 18:00 -m \"Gym\" --days monday,wednesday,friday"
      echo -e "  alarm --list"
      echo -e "\e[32mValid days:\e[0m weekdays, weekend, daily, monday, tuesday, wednesday, thursday, friday, saturday, sunday"
      echo -e "  Also: monday,friday or tuesday,thursday (combinations)"
      echo -e "\e[32mTempo threshold:\e[0m --tempo-threshold SECONDS (default: 180)"
      echo -e "  Alarms ≤ threshold use sleep (precise), > threshold use systemd timers (second precision)"
      exit 0
      ;;
    *)
      # If not a known option and we don't have TIME, assume it's the time
      if [[ -z "$TIME" ]] && [[ "$1" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
        TIME="$1"
        shift
      else
        echo -e "\e[31mError:\e[0m Unknown parameter: $1"
        echo -e "Use alarm --help to see usage"
        exit 1
      fi
      ;;
  esac
done

# Audio system detection and helper functions
detect_audio_system() {
    # Check for PipeWire first (modern Linux systems)
    if command -v pw-play >/dev/null 2>&1; then
        echo "pipewire"
    # Check for PulseAudio
    elif command -v paplay >/dev/null 2>&1; then
        echo "pulseaudio"
    # Fallback to ALSA
    elif command -v aplay >/dev/null 2>&1; then
        echo "alsa"
    else
        echo "none"
    fi
}

setup_audio_environment() {
    local audio_system="$1"
    
    case "$audio_system" in
        "pipewire")
            # PipeWire uses PulseAudio compatibility but may not have the same socket path
            # Try to find PipeWire's PulseAudio socket
            if [[ -S "/run/user/$UID/pipewire-0" ]]; then
                export PULSE_RUNTIME_PATH="/run/user/$UID"
            elif [[ -S "/run/user/$UID/pulse/native" ]]; then
                export PULSE_SERVER="unix:/run/user/$UID/pulse/native"
            fi
            ;;
        "pulseaudio")
            # Traditional PulseAudio setup
            export PULSE_SERVER="unix:/run/user/$UID/pulse/native"
            ;;
        "alsa"|"none")
            # No special environment setup needed for ALSA
            ;;
    esac
}

play_sound_file() {
    local sound_file="$1"
    local audio_system="$2"
    
    # Return false if file doesn't exist
    [[ ! -f "$sound_file" ]] && return 1
    
    case "$audio_system" in
        "pipewire")
            # Try pw-play first (native PipeWire)
            if pw-play "$sound_file" 2>/dev/null; then
                return 0
            # Fallback to paplay if available (PulseAudio compatibility)
            elif command -v paplay >/dev/null 2>&1 && paplay "$sound_file" 2>/dev/null; then
                return 0
            fi
            ;;
        "pulseaudio")
            # Use paplay for PulseAudio
            if paplay "$sound_file" 2>/dev/null; then
                return 0
            fi
            ;;
        "alsa")
            # Use aplay for ALSA (only works with .wav files)
            if [[ "$sound_file" == *.wav ]] && aplay "$sound_file" 2>/dev/null; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

play_alarm_sound() {
    # Skip if sound is disabled
    [[ -n "$NO_SOUND" ]] && return 0
    
    # Detect audio system
    local audio_system=$(detect_audio_system)
    
    # Set up audio environment
    setup_audio_environment "$audio_system"
    
    # Try different sound files in order of preference
    local sound_files=(
        "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
        "/usr/share/sounds/alsa/Front_Left.wav"
        "/usr/share/sounds/sound-icons/prompt.wav"
        "/usr/share/sounds/ubuntu/stereo/bell.ogg"
        "/usr/share/sounds/freedesktop/stereo/bell.oga"
        "/usr/share/sounds/freedesktop/stereo/complete.oga"
    )
    
    local sound_played=false
    for sound_file in "${sound_files[@]}"; do
        if play_sound_file "$sound_file" "$audio_system"; then
            sound_played=true
            break
        fi
    done
    
    # Final fallback: system beep
    if [[ "$sound_played" == "false" ]]; then
        printf '\a' # System beep
    fi
}

# Convert days to systemd calendar format
convert_days_to_systemd_calendar() {
    case "$1" in
        "weekdays"|"workdays")     echo "Mon-Fri" ;;
        "weekend")                 echo "Sat,Sun" ;;
        "daily"|"everyday")        echo "*-*-*" ;;
        "monday")                  echo "Mon" ;;
        "tuesday")                 echo "Tue" ;;
        "wednesday")               echo "Wed" ;;
        "thursday")                echo "Thu" ;;
        "friday")                  echo "Fri" ;;
        "saturday")                echo "Sat" ;;
        "sunday")                  echo "Sun" ;;
        "monday,wednesday,friday") echo "Mon,Wed,Fri" ;;
        "monday,tuesday,thursday") echo "Mon,Tue,Thu" ;;
        "monday,friday")           echo "Mon,Fri" ;;
        "tuesday,thursday")        echo "Tue,Thu" ;;
        "monday,wednesday")        echo "Mon,Wed" ;;
        "wednesday,friday")        echo "Wed,Fri" ;;
        *)
            # Try manual conversion for combinations
            local result=""
            IFS=',' read -ra DAY_ARRAY <<< "$1"
            for day in "${DAY_ARRAY[@]}"; do
                local day_name=""
                case "$day" in
                    "monday")    day_name="Mon" ;;
                    "tuesday")   day_name="Tue" ;;
                    "wednesday") day_name="Wed" ;;
                    "thursday")  day_name="Thu" ;;
                    "friday")    day_name="Fri" ;;
                    "saturday")  day_name="Sat" ;;
                    "sunday")    day_name="Sun" ;;
                    *) echo ""; return 1 ;;
                esac
                [[ -n "$result" ]] && result+=",$day_name" || result="$day_name"
            done
            echo "$result"
            ;;
    esac
}

convert_systemd_days_to_text() {
    case "$1" in
        "Mon-Fri")   echo "Mon-Fri" ;;
        "Sat,Sun")   echo "Sat,Sun" ;;
        "*-*-*")     echo "Daily" ;;
        "Mon")       echo "Monday" ;;
        "Tue")       echo "Tuesday" ;;
        "Wed")       echo "Wednesday" ;;
        "Thu")       echo "Thursday" ;;
        "Fri")       echo "Friday" ;;
        "Sat")       echo "Saturday" ;;
        "Sun")       echo "Sunday" ;;
        "Mon,Wed,Fri") echo "Mon,Wed,Fri" ;;
        "Mon,Tue,Thu") echo "Mon,Tue,Thu" ;;
        "Mon,Fri")   echo "Mon,Fri" ;;
        "Tue,Thu")   echo "Tue,Thu" ;;
        *)           echo "$1" ;;
    esac
}

add_scheduled_alarm() {
    local time="$1"
    local message="$2"
    local days="$3"
    local no_sound="$4"
    
    ensure_systemd_dir
    
    # Convert time HH:MM and days to systemd calendar format
    local hour="${time%:*}"
    local minute="${time#*:}"
    
    # Convert days to systemd format
    local systemd_days=$(convert_days_to_systemd_calendar "$days")
    if [[ -z "$systemd_days" ]]; then
        echo -e "\e[31mError:\e[0m Invalid days: $days"
        return 1
    fi
    
    # Generate unique ID for timer
    local timer_id=$(date +%s%N | sha256sum | head -c 8)
    local timer_name="${TIMER_PREFIX}-scheduled-${timer_id}"
    
    # Build command with optional no-sound flag
    local sound_flag=""
    [[ "$no_sound" == "true" ]] && sound_flag=" --no-sound"
    
    # Create .service file
    cat > "${SYSTEMD_USER_DIR}/${timer_name}.service" <<EOF
[Unit]
Description=Alarm: ${message}

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH} --internal-trigger "${message}"${sound_flag}
EOF
    
    # Create .timer file
    cat > "${SYSTEMD_USER_DIR}/${timer_name}.timer" <<EOF
[Unit]
Description=Scheduled alarm: ${message} (${systemd_days} ${time})

[Timer]
OnCalendar=${systemd_days} ${hour}:${minute}:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Reload systemd and enable timer
    systemctl --user daemon-reload
    systemctl --user enable --now "${timer_name}.timer" 2>/dev/null
    
    echo -e "\e[32m✓ Alarm scheduled:\e[0m $time - \"$message\" ($(convert_systemd_days_to_text "$systemd_days"))"
}

add_onetime_alarm() {
    local target_timestamp="$1"
    local message="$2"
    local no_sound="$3"
    
    ensure_systemd_dir
    
    # Convert timestamp to systemd calendar format
    local target_datetime=$(date -d "@$target_timestamp" +"%Y-%m-%d %H:%M:%S")
    local target_date_display=$(date -d "@$target_timestamp" +"%Y-%m-%d %H:%M")
    
    # Generate unique ID for timer
    local timer_id=$(date +%s%N | sha256sum | head -c 8)
    local timer_name="${TIMER_PREFIX}-onetime-${timer_id}"
    
    # Build command with optional no-sound flag
    local sound_flag=""
    [[ "$no_sound" == "true" ]] && sound_flag=" --no-sound"
    
    # Use systemd-run for transient one-time timer
    systemd-run --user \
        --on-calendar="${target_datetime}" \
        --unit="${timer_name}" \
        --description="ALARM_ONETIME|${message}|${target_timestamp}" \
        "${SCRIPT_PATH}" --internal-trigger "${message}"${sound_flag}
    
    echo -e "\e[32m✓ Alarm set for:\e[0m $target_date_display - \"$message\""
}

list_scheduled_alarms() {
    # Get all alarm timers (both running and loaded)
    local all_timers=$(systemctl --user list-timers --all --no-pager --no-legend 2>/dev/null | grep "${TIMER_PREFIX}-" | awk '{print $NF}' | sed 's/\.timer$//')
    local persistent_timers=$(ls "${SYSTEMD_USER_DIR}/${TIMER_PREFIX}-scheduled-"*.timer 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.timer$//')
    
    # Combine and deduplicate
    local all_timer_names=$(echo -e "${all_timers}\n${persistent_timers}" | grep -v "^$" | sort -u)
    
    if [[ -z "$all_timer_names" ]]; then
        echo -e "\e[33mNo alarms configured\e[0m"
        return
    fi
    
    # Separate scheduled and one-time alarms
    local scheduled_alarms=""
    local onetime_alarms=""
    
    while IFS= read -r timer_name; do
        if [[ "$timer_name" =~ ${TIMER_PREFIX}-scheduled- ]]; then
            scheduled_alarms="${scheduled_alarms}${timer_name}"$'\n'
        elif [[ "$timer_name" =~ ${TIMER_PREFIX}-onetime- ]]; then
            onetime_alarms="${onetime_alarms}${timer_name}"$'\n'
        fi
    done <<< "$all_timer_names"
    
    # Show scheduled (recurring) alarms
    if [[ -n "$scheduled_alarms" ]]; then
        echo -e "\e[32mScheduled alarms (recurring):\e[0m"
        echo -e "\e[36mID  TIME    DAYS          MESSAGE\e[0m"
        local counter=1
        
        while IFS= read -r timer_name; do
            [[ -z "$timer_name" ]] && continue
            
            local timer_file="${SYSTEMD_USER_DIR}/${timer_name}.timer"
            if [[ -f "$timer_file" ]]; then
                local description=$(grep "^Description=" "$timer_file" | cut -d: -f2- | sed 's/^ *//')
                local calendar=$(grep "^OnCalendar=" "$timer_file" | cut -d= -f2)
                
                # Parse time and days from calendar
                local time_part=$(echo "$calendar" | awk '{print $NF}' | cut -d: -f1-2)
                local days_part=$(echo "$calendar" | sed 's/ [0-9][0-9]:[0-9][0-9]:[0-9][0-9]$//')
                
                printf "%-3s %s   %-12s %s\n" "$counter" "$time_part" "$(convert_systemd_days_to_text "$days_part")" "$description"
            fi
            counter=$((counter + 1))
        done <<< "$scheduled_alarms"
        echo
    fi
    
    # Show one-time alarms
    if [[ -n "$onetime_alarms" ]]; then
        echo -e "\e[32mOne-time alarms:\e[0m"
        echo -e "\e[36mID  TIME    DATE          MESSAGE\e[0m"
        local counter=1
        if [[ -n "$scheduled_alarms" ]]; then
            counter=$(echo "$scheduled_alarms" | grep -c . || echo 0)
            counter=$((counter + 1))
        fi
        
        while IFS= read -r timer_name; do
            [[ -z "$timer_name" ]] && continue
            
            # Get timer description
            local description=$(systemctl --user show "${timer_name}.timer" --property=Description 2>/dev/null | cut -d= -f2-)
            
            # Parse description format: ALARM_ONETIME|message|timestamp
            if [[ "$description" =~ ALARM_ONETIME\|([^|]+)\|([0-9]+) ]]; then
                local message="${BASH_REMATCH[1]}"
                local timestamp="${BASH_REMATCH[2]}"
                
                local alarm_time=$(date -d "@$timestamp" +"%H:%M" 2>/dev/null || echo "??:??")
                local alarm_date=$(date -d "@$timestamp" +"%b %d" 2>/dev/null || echo "Unknown")
                
                # Check if alarm is today
                local today=$(date +%Y-%m-%d)
                local alarm_day=$(date -d "@$timestamp" +%Y-%m-%d 2>/dev/null)
                if [[ "$today" == "$alarm_day" ]]; then
                    alarm_date="Today"
                fi
                
                printf "%-3s %s   %-12s %s\n" "$counter" "$alarm_time" "$alarm_date" "$message"
            fi
            counter=$((counter + 1))
        done <<< "$onetime_alarms"
    fi
}

remove_scheduled_alarm() {
    local alarm_id="$1"
    
    # Get all alarm timers
    local all_timers=$(systemctl --user list-timers --all --no-pager --no-legend 2>/dev/null | grep "${TIMER_PREFIX}-" | awk '{print $NF}' | sed 's/\.timer$//')
    local persistent_timers=$(ls "${SYSTEMD_USER_DIR}/${TIMER_PREFIX}-"*.timer 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.timer$//')
    
    # Combine and deduplicate
    local all_timer_names=$(echo -e "${all_timers}\n${persistent_timers}" | grep -v "^$" | sort -u)
    
    if [[ -z "$all_timer_names" ]]; then
        echo -e "\e[31mError:\e[0m No alarms configured"
        return 1
    fi
    
    # Get the target timer by ID
    local target_timer=$(echo "$all_timer_names" | sed -n "${alarm_id}p")
    
    if [[ -z "$target_timer" ]]; then
        echo -e "\e[31mError:\e[0m Alarm with ID $alarm_id does not exist"
        return 1
    fi
    
    # Get message for confirmation
    local message=""
    if [[ -f "${SYSTEMD_USER_DIR}/${target_timer}.timer" ]]; then
        message=$(grep "^Description=" "${SYSTEMD_USER_DIR}/${target_timer}.timer" | cut -d: -f2- | sed 's/^ *//')
    else
        local description=$(systemctl --user show "${target_timer}.timer" --property=Description 2>/dev/null | cut -d= -f2-)
        if [[ "$description" =~ ALARM_ONETIME\|([^|]+)\| ]]; then
            message="${BASH_REMATCH[1]}"
        fi
    fi
    
    # Stop and disable timer
    systemctl --user stop "${target_timer}.timer" 2>/dev/null
    systemctl --user disable "${target_timer}.timer" 2>/dev/null
    
    # Remove unit files if they exist
    rm -f "${SYSTEMD_USER_DIR}/${target_timer}.timer" 2>/dev/null
    rm -f "${SYSTEMD_USER_DIR}/${target_timer}.service" 2>/dev/null
    
    # Reload systemd
    systemctl --user daemon-reload
    
    echo -e "\e[32m✓ Alarm removed:\e[0m \"${message}\""
}

clear_all_alarms() {
    # Get all alarm timers
    local all_timers=$(systemctl --user list-timers --all --no-pager --no-legend 2>/dev/null | grep "${TIMER_PREFIX}-" | awk '{print $NF}' | sed 's/\.timer$//')
    local persistent_timers=$(ls "${SYSTEMD_USER_DIR}/${TIMER_PREFIX}-"*.timer 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.timer$//')
    
    # Combine and deduplicate
    local all_timer_names=$(echo -e "${all_timers}\n${persistent_timers}" | grep -v "^$" | sort -u)
    
    if [[ -z "$all_timer_names" ]]; then
        echo -e "\e[33mNo alarms to remove\e[0m"
        return
    fi
    
    local count=0
    while IFS= read -r timer_name; do
        [[ -z "$timer_name" ]] && continue
        
        # Stop and disable timer
        systemctl --user stop "${timer_name}.timer" 2>/dev/null
        systemctl --user disable "${timer_name}.timer" 2>/dev/null
        
        # Remove unit files
        rm -f "${SYSTEMD_USER_DIR}/${timer_name}.timer" 2>/dev/null
        rm -f "${SYSTEMD_USER_DIR}/${timer_name}.service" 2>/dev/null
        
        count=$((count + 1))
    done <<< "$all_timer_names"
    
    # Reload systemd
    systemctl --user daemon-reload
    
    echo -e "\e[32m✓ Removed $count alarm(s)\e[0m"
}

# Handle scheduling actions
if [[ "$ACTION" == "list" ]]; then
    list_scheduled_alarms
    exit 0
elif [[ "$ACTION" == "remove" ]]; then
    if [[ -z "$SCHEDULE_ID" ]]; then
        echo -e "\e[31mError:\e[0m Must specify an ID to remove"
        echo -e "Use: alarm --list to see scheduled alarms"
        exit 1
    fi
    remove_scheduled_alarm "$SCHEDULE_ID"
    exit 0
elif [[ "$ACTION" == "clear" ]]; then
    clear_all_alarms
    exit 0
elif [[ "$ACTION" == "trigger" ]]; then
    # Systemd timer execution mode - jump to end
    :
fi

# Handle scheduling mode
if [[ "$SCHEDULE_MODE" == "true" ]]; then
    # Scheduling validations
    if [[ -z "$TIME" ]]; then
        echo -e "\e[31mError:\e[0m Must specify a time with --schedule"
        exit 1
    fi
    
    if [[ -z "$DAYS" ]]; then
        echo -e "\e[31mError:\e[0m Must specify days with --days"
        echo -e "Valid days: weekdays, weekend, daily, monday, tuesday, etc."
        exit 1
    fi
    
    if [[ -z "$MESSAGE" ]]; then
        echo -e "\e[31mError:\e[0m Must specify a message with -m for scheduled alarms"
        exit 1
    fi
    
    # Validate time format
    if [[ ! "$TIME" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
        echo -e "\e[31mError:\e[0m Invalid time format. Use HH:MM"
        exit 1
    fi
    
    add_scheduled_alarm "$TIME" "$MESSAGE" "$DAYS" "$NO_SOUND"
    exit 0
fi

# Validations for normal modes (tempo and immediate)
if [[ "$ACTION" != "trigger" ]] && [[ -z "$TIME" ]]; then
  echo -e "\e[31mError:\e[0m Must specify a time or use --tempo"
  echo -e "\e[33mUsage:\e[0m alarm HH:MM [-m \"message\"] [--no-sound]"
  echo -e "\e[33m   or:\e[0m alarm --tempo MM:SS [-m \"message\"] [--no-sound] [--tempo-threshold SECONDS]"
  echo -e "\e[33m   or:\e[0m alarm --schedule HH:MM -m \"message\" --days DAYS [--no-sound]"
  echo -e "Use alarm --help for more information"
  exit 1
fi

# Default message if not specified with -m
if [[ -z "$MESSAGE" ]]; then
  if [[ "$TEMPO_MODE" == "true" ]]; then
    MESSAGE="⏰ Alarm after $TIME"
  else
    MESSAGE="⏰ It's $TIME"
  fi
fi

NOW=$(date +%s)

# Handle trigger mode (executed by systemd timer)
if [[ "$ACTION" == "trigger" ]]; then
  # Set up environment for GUI applications when run from systemd
  export DISPLAY=:0
  
  # Try to find the user's D-Bus session
  if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
    dbus_pid=$(pgrep -u "$USER" dbus-daemon | head -1)
    if [[ -n "$dbus_pid" ]]; then
      export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$dbus_pid/environ | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-)
    fi
  fi
  
  # Direct execution of alarm (no sleep)
  notify-send "⏰ Alarm" "$MESSAGE" 2>/dev/null
  
  # Play alarm sound using unified function
  play_alarm_sound
  
  exit 0
fi

NOW=$(date +%s)

if [[ "$TEMPO_MODE" == "true" ]]; then
  # Tempo mode: calculate target time from MM:SS format
  if [[ "$TIME" =~ ^([0-9]+):([0-9]+)$ ]]; then
    MINUTES=${BASH_REMATCH[1]}
    SECONDS=${BASH_REMATCH[2]}
    TOTAL_SECONDS=$((MINUTES * 60 + SECONDS))
    
    # For short durations (less than threshold), use sleep for precision
    # For longer durations, use systemd-run with relative time
    if [[ $TOTAL_SECONDS -lt $TEMPO_THRESHOLD ]]; then
      # Direct execution with sleep - no systemd needed
      echo -e "\e[32m✓ Alarm set for:\e[0m $MINUTES:$(printf "%02d" $SECONDS) from now - \"$MESSAGE\""
      
      # Fork a background process to handle the alarm
      (
        sleep $TOTAL_SECONDS
        
        # Set up environment for GUI applications
        export DISPLAY=:0
        
        # Try to find the user's D-Bus session
        if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
          dbus_pid=$(pgrep -u "$USER" dbus-daemon | head -1)
          if [[ -n "$dbus_pid" ]]; then
            export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$dbus_pid/environ | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-)
          fi
        fi
        
        # Show notification
        notify-send "⏰ Alarm" "$MESSAGE" 2>/dev/null
        
        # Play alarm sound using unified function
        play_alarm_sound
      ) &
      
      exit 0
    else
      # For longer durations, use systemd-run with relative time
      local timer_id=$(date +%s%N | sha256sum | head -c 8)
      local timer_name="${TIMER_PREFIX}-tempo-${timer_id}"
      
      # Build command with optional no-sound flag
      local sound_flag=""
      [[ "$NO_SOUND" == "true" ]] && sound_flag=" --no-sound"
      
      # Use systemd-run for transient relative timer
      systemd-run --user \
          --on-active="${TOTAL_SECONDS}s" \
          --unit="${timer_name}" \
          --description="ALARM_TEMPO|${MESSAGE}|${TOTAL_SECONDS}" \
          "${SCRIPT_PATH}" --internal-trigger "${MESSAGE}"${sound_flag}
      
      echo -e "\e[32m✓ Alarm set for:\e[0m $MINUTES:$(printf "%02d" $SECONDS) from now - \"$MESSAGE\""
      exit 0
    fi
  else
    echo -e "\e[31mError:\e[0m Invalid format for --tempo. Use MM:SS (e.g.: 05:30 for 5 minutes and 30 seconds)"
    exit 1
  fi
else
  # Specific time mode: calculate target time for today/tomorrow
  TARGET=$(date -d "$TIME" +%s 2>/dev/null)
  
  if [[ $? -ne 0 ]]; then
    echo -e "\e[31mError:\e[0m Invalid time format. Use HH:MM"
    exit 1
  fi
  
  if [[ $TARGET -le $NOW ]]; then
    TARGET=$(date -d "tomorrow $TIME" +%s)
  fi
  
  TARGET_TIME=$TARGET
fi

# Add one-time alarm using systemd-run
add_onetime_alarm "$TARGET_TIME" "$MESSAGE" "$NO_SOUND"
