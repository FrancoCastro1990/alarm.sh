#!/bin/bash

# Usage: alarm HH:MM [-m "message"] [--no-sound]
#        alarm --tempo MM:SS [-m "message"] [--no-sound]
#        alarm --schedule HH:MM -m "message" --days DAYS [--no-sound]
#        alarm --list | --remove ID | --clear-all

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
      # Internal mode for cron execution
      ACTION="trigger"
      MESSAGE="$2"
      shift 2
      ;;
    --uuid)
      UUID="$2"
      shift 2
      ;;
    -h|--help)
      echo -e "\e[36mAlarm System\e[0m - A comprehensive alarm management tool"
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
      echo -e "  alarm --tempo 02:30 --tempo-threshold 60 -m \"Use sleep for ≤1min, cron for >1min\""
      echo -e "  alarm --schedule 09:00 -m \"Daily Standup\" --days weekdays"
      echo -e "  alarm --schedule 18:00 -m \"Gym\" --days monday,wednesday,friday"
      echo -e "  alarm --list"
      echo -e "\e[32mValid days:\e[0m weekdays, weekend, daily, monday, tuesday, wednesday, thursday, friday, saturday, sunday"
      echo -e "  Also: monday,friday or tuesday,thursday (combinations)"
      echo -e "\e[32mTempo threshold:\e[0m --tempo-threshold SECONDS (default: 180)"
      echo -e "  Alarms ≤ threshold use sleep (precise), > threshold use cron (minute precision)"
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

# Helper functions
convert_days_to_cron() {
    case "$1" in
        "weekdays"|"workdays")     echo "1-5" ;;
        "weekend")                 echo "0,6" ;;
        "daily"|"everyday")        echo "*" ;;
        "monday")                  echo "1" ;;
        "tuesday")                 echo "2" ;;
        "wednesday")               echo "3" ;;
        "thursday")                echo "4" ;;
        "friday")                  echo "5" ;;
        "saturday")                echo "6" ;;
        "sunday")                  echo "0" ;;
        "monday,wednesday,friday") echo "1,3,5" ;;
        "monday,tuesday,thursday") echo "1,2,4" ;;
        "monday,friday")           echo "1,5" ;;
        "tuesday,thursday")        echo "2,4" ;;
        "monday,wednesday")        echo "1,3" ;;
        "wednesday,friday")        echo "3,5" ;;
        *)
            # Intentar conversión manual para combinaciones
            local result=""
            IFS=',' read -ra DAY_ARRAY <<< "$1"
            for day in "${DAY_ARRAY[@]}"; do
                case "$day" in
                    "monday")    [[ -n "$result" ]] && result+=",1" || result="1" ;;
                    "tuesday")   [[ -n "$result" ]] && result+=",2" || result="2" ;;
                    "wednesday") [[ -n "$result" ]] && result+=",3" || result="3" ;;
                    "thursday")  [[ -n "$result" ]] && result+=",4" || result="4" ;;
                    "friday")    [[ -n "$result" ]] && result+=",5" || result="5" ;;
                    "saturday")  [[ -n "$result" ]] && result+=",6" || result="6" ;;
                    "sunday")    [[ -n "$result" ]] && result+=",0" || result="0" ;;
                    *) echo ""; return 1 ;;
                esac
            done
            echo "$result"
            ;;
    esac
}

convert_days_to_text() {
    case "$1" in
        "1-5")   echo "Mon-Fri" ;;
        "0,6")   echo "Sat,Sun" ;;
        "*")     echo "Daily" ;;
        "1")     echo "Monday" ;;
        "2")     echo "Tuesday" ;;
        "3")     echo "Wednesday" ;;
        "4")     echo "Thursday" ;;
        "5")     echo "Friday" ;;
        "6")     echo "Saturday" ;;
        "0")     echo "Sunday" ;;
        "1,3,5") echo "Mon,Wed,Fri" ;;
        "1,2,4") echo "Mon,Tue,Thu" ;;
        "1,5")   echo "Mon,Fri" ;;
        "2,4")   echo "Tue,Thu" ;;
        *)       echo "$1" ;;
    esac
}

add_scheduled_alarm() {
    local time="$1"
    local message="$2"
    local days="$3"
    local no_sound="$4"
    
    # Convert time HH:MM to cron format (minute hour)
    local hour="${time%:*}"
    local minute="${time#*:}"
    
    # Convert days to cron format
    local cron_days=$(convert_days_to_cron "$days")
    if [[ -z "$cron_days" ]]; then
        echo -e "\e[31mError:\e[0m Invalid days: $days"
        return 1
    fi
    
    # Build command
    local sound_flag=""
    [[ "$no_sound" == "true" ]] && sound_flag="--no-sound"
    
    # Create cron entry
    local cron_entry="$minute $hour * * $cron_days $0 --internal-trigger \"$message\" $sound_flag # ALARM_SCHEDULED"
    
    # Add to crontab (keeping existing alarms)
    (crontab -l 2>/dev/null || true; echo "$cron_entry") | crontab -
    
    echo -e "\e[32m✓ Alarm scheduled:\e[0m $time - \"$message\" ($(convert_days_to_text "$cron_days"))"
}

add_onetime_alarm() {
    local target_timestamp="$1"
    local message="$2"
    local no_sound="$3"
    
    # Convert timestamp to cron format (force decimal interpretation)
    local minute=$((10#$(date -d "@$target_timestamp" +"%M")))
    local hour=$((10#$(date -d "@$target_timestamp" +"%H")))
    local day=$((10#$(date -d "@$target_timestamp" +"%d")))
    local month=$((10#$(date -d "@$target_timestamp" +"%m")))
    local target_date=$(date -d "@$target_timestamp" +"%Y-%m-%d %H:%M")
    
    # Build command
    local sound_flag=""
    [[ "$no_sound" == "true" ]] && sound_flag="--no-sound"
    
    # Create unique identifier for auto-cleanup
    local alarm_uuid=$(date +%s%N | sha256sum | head -c 8)
    
    # Create cron entry for specific date/time
    local cron_entry="$minute $hour $day $month * $0 --internal-trigger \"$message\" $sound_flag --uuid $alarm_uuid # ALARM_ONETIME"
    
    # Add to crontab
    (crontab -l 2>/dev/null || true; echo "$cron_entry") | crontab -
    
    echo -e "\e[32m✓ Alarm set for:\e[0m $target_date - \"$message\""
}

list_scheduled_alarms() {
    local scheduled_alarms=$(crontab -l 2>/dev/null | grep "# ALARM_SCHEDULED")
    local onetime_alarms=$(crontab -l 2>/dev/null | grep "# ALARM_ONETIME")
    
    if [[ -z "$scheduled_alarms" ]] && [[ -z "$onetime_alarms" ]]; then
        echo -e "\e[33mNo alarms configured\e[0m"
        return
    fi
    
    # Show scheduled (recurring) alarms
    if [[ -n "$scheduled_alarms" ]]; then
        echo -e "\e[32mScheduled alarms (recurring):\e[0m"
        echo -e "\e[36mID  TIME    DAYS          MESSAGE\e[0m"
        echo "$scheduled_alarms" | nl -w2 -s'. ' | while read line; do
            local id=$(echo "$line" | awk '{print $1}' | sed 's/\.//')
            local minute=$(echo "$line" | awk '{print $2}')
            local hour=$(echo "$line" | awk '{print $3}')
            local days=$(echo "$line" | awk '{print $6}')
            local message=$(echo "$line" | sed 's/.*--internal-trigger "\([^"]*\)".*/\1/')
            
            # Force decimal interpretation to avoid octal error
            printf "%-3s %02d:%02d   %-12s %s\n" "$id" "$((10#$hour))" "$((10#$minute))" "$(convert_days_to_text "$days")" "$message"
        done
        echo
    fi
    
    # Show one-time alarms
    if [[ -n "$onetime_alarms" ]]; then
        echo -e "\e[32mOne-time alarms:\e[0m"
        echo -e "\e[36mID  TIME    DATE          MESSAGE\e[0m"
        local counter=1
        if [[ -n "$scheduled_alarms" ]]; then
            counter=$(($(echo "$scheduled_alarms" | wc -l) + 1))
        fi
        
        echo "$onetime_alarms" | while read line; do
            local minute=$(echo "$line" | awk '{print $1}')
            local hour=$(echo "$line" | awk '{print $2}')
            local day=$(echo "$line" | awk '{print $3}')
            local month=$(echo "$line" | awk '{print $4}')
            local message=$(echo "$line" | sed 's/.*--internal-trigger "\([^"]*\)".*/\1/')
            
            # Format date
            local current_year=$(date +%Y)
            local alarm_date=$(date -d "$current_year-$month-$day" +"%b %d" 2>/dev/null || echo "$month/$day")
            
            # Check if alarm is today
            local today=$(date +"%m %d")
            local alarm_md=$(printf "%02d %02d" "$((10#$month))" "$((10#$day))")
            if [[ "$today" == "$alarm_md" ]]; then
                alarm_date="Today"
            fi
            
            printf "%-3s %02d:%02d   %-12s %s\n" "$counter" "$((10#$hour))" "$((10#$minute))" "$alarm_date" "$message"
            counter=$((counter + 1))
        done
    fi
}

remove_scheduled_alarm() {
    local alarm_id="$1"
    
    # Get all alarm lines (both scheduled and one-time)
    local scheduled_lines=$(crontab -l 2>/dev/null | grep "# ALARM_SCHEDULED")
    local onetime_lines=$(crontab -l 2>/dev/null | grep "# ALARM_ONETIME")
    local all_alarms=""
    
    # Combine all alarms with line numbers
    if [[ -n "$scheduled_lines" ]]; then
        all_alarms="$scheduled_lines"
    fi
    if [[ -n "$onetime_lines" ]]; then
        if [[ -n "$all_alarms" ]]; then
            all_alarms="$all_alarms"$'\n'"$onetime_lines"
        else
            all_alarms="$onetime_lines"
        fi
    fi
    
    if [[ -z "$all_alarms" ]]; then
        echo -e "\e[31mError:\e[0m No alarms configured"
        return 1
    fi
    
    local target_line=$(echo "$all_alarms" | sed -n "${alarm_id}p")
    
    if [[ -z "$target_line" ]]; then
        echo -e "\e[31mError:\e[0m Alarm with ID $alarm_id does not exist"
        return 1
    fi
    
    # Remove specific line from crontab
    crontab -l 2>/dev/null | grep -v -F "$target_line" | crontab -
    
    local message=$(echo "$target_line" | sed 's/.*--internal-trigger "\([^"]*\)".*/\1/')
    echo -e "\e[32m✓ Alarm removed:\e[0m \"$message\""
}

clear_all_alarms() {
    local scheduled_count=$(crontab -l 2>/dev/null | grep "# ALARM_SCHEDULED" | wc -l)
    local onetime_count=$(crontab -l 2>/dev/null | grep "# ALARM_ONETIME" | wc -l)
    local total_count=$((scheduled_count + onetime_count))
    
    if [[ "$total_count" -eq 0 ]]; then
        echo -e "\e[33mNo alarms to remove\e[0m"
        return
    fi
    
    # Remove all alarms (both scheduled and one-time)
    crontab -l 2>/dev/null | grep -v "# ALARM_SCHEDULED" | grep -v "# ALARM_ONETIME" | crontab -
    
    echo -e "\e[32m✓ Removed $total_count alarm(s)\e[0m"
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
    # Cron execution mode - jump to end
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

# Handle trigger mode (executed by cron)
if [[ "$ACTION" == "trigger" ]]; then
  # Set up environment for GUI applications when run from cron
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
  
  # Optional sound - try multiple sound files
  if [[ -z "$NO_SOUND" ]]; then
    # Set up audio environment for cron execution
    export PULSE_SERVER=unix:/run/user/$UID/pulse/native
    
    # Try different sound files in order of preference
    sound_files=(
      "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
      "/usr/share/sounds/alsa/Front_Left.wav"
      "/usr/share/sounds/sound-icons/prompt.wav"
      "/usr/share/sounds/ubuntu/stereo/bell.ogg"
    )
    
    sound_played=false
    for sound_file in "${sound_files[@]}"; do
      if [[ -f "$sound_file" ]]; then
        # Try paplay first
        if paplay "$sound_file" 2>/dev/null; then
          sound_played=true
          break
        fi
        # Try aplay as fallback for wav files
        if [[ "$sound_file" == *.wav ]] && command -v aplay >/dev/null 2>&1; then
          aplay "$sound_file" 2>/dev/null &
          sound_played=true
          break
        fi
      fi
    done
    
    # Fallback: use system beep if no sound files worked
    if [[ "$sound_played" == "false" ]]; then
      printf '\a' # System beep
    fi
  fi
  
  # Auto-cleanup: remove one-time alarms from crontab after execution
  if [[ -n "$UUID" ]]; then
    # Remove the specific alarm entry using UUID
    temp_crontab=$(mktemp)
    crontab -l 2>/dev/null | grep -v -- "--uuid $UUID" > "$temp_crontab"
    crontab "$temp_crontab"
    rm "$temp_crontab"
  fi
  
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
    # For longer durations, use cron (seconds will be ignored)
    if [[ $TOTAL_SECONDS -lt $TEMPO_THRESHOLD ]]; then
      # Direct execution with sleep - no cron needed
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
        
        # Play sound if not disabled
        if [[ -z "$NO_SOUND" ]]; then
          # Set up audio environment
          export PULSE_SERVER=unix:/run/user/$UID/pulse/native
          
          # Try different sound files in order of preference
          sound_files=(
            "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
            "/usr/share/sounds/alsa/Front_Left.wav"
            "/usr/share/sounds/sound-icons/prompt.wav"
            "/usr/share/sounds/ubuntu/stereo/bell.ogg"
          )
          
          sound_played=false
          for sound_file in "${sound_files[@]}"; do
            if [[ -f "$sound_file" ]]; then
              if paplay "$sound_file" 2>/dev/null; then
                sound_played=true
                break
              fi
              if [[ "$sound_file" == *.wav ]] && command -v aplay >/dev/null 2>&1; then
                aplay "$sound_file" 2>/dev/null &
                sound_played=true
                break
              fi
            fi
          done
          
          # Fallback: use system beep if no sound files worked
          if [[ "$sound_played" == "false" ]]; then
            printf '\a' # System beep
          fi
        fi
      ) &
      
      exit 0
    else
      # For longer durations, use cron (seconds will be rounded up to next minute)
      TARGET_TIME=$((NOW + TOTAL_SECONDS))
      # Round up to next minute since cron can't handle seconds
      TARGET_TIME=$(((TARGET_TIME + 59) / 60 * 60))
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

# Add one-time alarm to cron
add_onetime_alarm "$TARGET_TIME" "$MESSAGE" "$NO_SOUND"

