# Alarm System

A comprehensive command-line alarm management tool for Linux systems. Supports one-time alarms, recurring scheduled alarms, and relative timers with desktop notifications and audio alerts.

**Available in two versions:** Traditional cron-based implementation and modern systemd timers implementation. The automated installer detects your system capabilities and selects the appropriate version.

## Features

- **Instant alarms**: Set alarms for specific times of day
- **Relative timers**: Create countdown timers with MM:SS format
- **Intelligent timer scheduling**: 
  - Cron version: Uses `sleep` for high precision (≤3min) or `cron` for long durations
  - Systemd version: Uses `sleep` for high precision (≤3min) or `systemd timers` with second-level precision
- **Configurable threshold**: Customize when to use `sleep` vs persistent scheduling with `--tempo-threshold`
- **Scheduled alarms**: Configure recurring alarms for specific days of the week
- **Silent mode**: Optional sound suppression
- **Complete management**: List, remove, and clear all configured alarms
- **Desktop notifications**: Automatic notifications via libnotify
- **Audio alerts**: Multiple audio backend support (PipeWire, PulseAudio, ALSA)
- **Automatic detection**: Installer selects optimal version based on system capabilities

## Dependencies

### System Requirements

**For cron version (alarm.sh):**
- **Bash**: Version 4.0 or higher (pre-installed on most Linux distributions)
- **cron**: Scheduling daemon (typically pre-installed or available as `cron` or `cronie` package)
- **notify-send**: Desktop notification system (libnotify package)
- **Audio backend**: One of PipeWire, PulseAudio, or ALSA

**For systemd version (alarm-v2.sh):**
- **Bash**: Version 4.0 or higher
- **systemd**: Init system with timer support (pre-installed on modern Linux distributions)
- **notify-send**: Desktop notification system (libnotify package)
- **Audio backend**: One of PipeWire, PulseAudio, or ALSA

**Note:** The automated installer detects available scheduling systems (cron, systemd, or both) and selects the appropriate version.

### Dependency Installation

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install libnotify-bin pipewire-pulse alsa-utils
# For traditional PulseAudio:
# sudo apt install libnotify-bin pulseaudio-utils alsa-utils
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install libnotify pipewire-pulseaudio alsa-utils
# For traditional PulseAudio:
# sudo dnf install libnotify pulseaudio-utils alsa-utils
```

**Arch Linux:**
```bash
sudo pacman -S libnotify pipewire-pulse alsa-utils
# For traditional PulseAudio:
# sudo pacman -S libnotify pulseaudio alsa-utils
```

**Note:** The automated installer detects your audio system (PipeWire or PulseAudio) and installs the appropriate dependencies.

## Installation

### Quick Installation

```bash
curl -fsSL https://raw.githubusercontent.com/FrancoCastro1990/alarm.sh/refs/heads/main/install.sh | bash
```

This command downloads and executes the automated installer, which detects your operating system, installs all required dependencies, and configures the tool.

**Security Note:** To review the installation script before execution, see [install.sh](https://github.com/FrancoCastro1990/alarm.sh/blob/main/install.sh) or use the manual installation method.

### Automated Installation (Alternative Method)

1. **Clone the repository:**
```bash
git clone https://github.com/FrancoCastro1990/alarm.sh.git
cd alarm.sh
```

2. **Execute the installation script:**
```bash
./install.sh
```

The installation script automatically:
- Detects your Linux distribution (Ubuntu, Debian, Fedora, Arch, etc.)
- Detects available scheduling systems (cron, systemd, or both)
- Selects the appropriate version (alarm.sh for cron or alarm-v2.sh for systemd)
- Detects your audio system (PipeWire, PulseAudio, or ALSA)
- Installs all required dependencies for your system
- Configures and verifies the corresponding service (cron or systemd)
- Makes the script executable
- Optionally installs the command globally
- Verifies successful installation

### Manual Installation

For manual installation or if the automated script fails on your system:

1. **Clone or download the repository:**
```bash
git clone https://github.com/FrancoCastro1990/alarm.sh.git
cd alarm.sh
```

2. **Install dependencies according to your distribution:**
   - **Ubuntu/Debian:** `sudo apt update && sudo apt install libnotify-bin pulseaudio-utils alsa-utils`
   - **Fedora/RHEL:** `sudo dnf install libnotify pulseaudio-utils alsa-utils`
   - **Arch Linux:** `sudo pacman -S libnotify pulseaudio alsa-utils`

3. **Make the script executable:**
```bash
chmod +x alarm.sh
```

4. **Optional: Install globally**

For systemd version:
```bash
sudo cp alarm-v2.sh /usr/local/bin/alarm
```

For cron version:
```bash
sudo cp alarm.sh /usr/local/bin/alarm
```

5. **Verify service status:**

For systemd:
```bash
systemctl status systemd-logind  # Verify systemd is active
systemctl --user list-timers     # List user timers
```

For cron:
```bash
sudo systemctl status cron
# On systemd-based systems:
sudo systemctl status cronie
```

## Usage

**Note:** Both `alarm.sh` (cron) and `alarm-v2.sh` (systemd) provide identical command-line interfaces. Use the version selected by the installer.

### Basic Syntax

```bash
# Set alarm for specific time
alarm HH:MM [-m "message"] [--no-sound]

# Relative timer (alarm after MM:SS)
alarm --tempo MM:SS [-m "message"] [--no-sound] [--tempo-threshold SECONDS]

# Scheduled recurring alarm
alarm --schedule HH:MM -m "message" --days DAYS [--no-sound]

# Alarm management
alarm --list
alarm --remove ID
alarm --clear-all
```

### Practical Examples

#### One-Time Alarms
```bash
# Alarm at 2:30 PM
alarm 14:30

# Alarm with custom message
alarm 09:00 -m "Important meeting"

# Silent alarm
alarm 16:45 -m "End of workday" --no-sound
```

#### Relative Timers
```bash
# 5-minute timer
alarm --tempo 05:00

# 25-minute timer for Pomodoro technique
alarm --tempo 25:00 -m "Pomodoro break"

# Short 2-minute timer (uses sleep for high precision)
alarm --tempo 02:00 -m "Quick timer"

# Force sleep usage for 5-minute timer
alarm --tempo 05:00 --tempo-threshold 600 -m "Sleep up to 10 minutes"

# Force backend usage for 1-minute timer
# (cron in alarm.sh, systemd in alarm-v2.sh)
alarm --tempo 01:00 --tempo-threshold 30 -m "Backend for >30 seconds"

# Silent 1 hour 30 minute timer
alarm --tempo 90:00 -m "Meeting finished" --no-sound
```

#### Scheduled Recurring Alarms
```bash
# Daily alarm at 9:00 AM
alarm --schedule 09:00 -m "Daily Standup" --days daily

# Weekday alarm (Monday through Friday)
alarm --schedule 08:00 -m "Work time" --days weekdays

# Weekend alarm
alarm --schedule 10:00 -m "Relaxed breakfast" --days weekend

# Specific days
alarm --schedule 18:00 -m "Gym" --days monday,wednesday,friday

# Single specific day
alarm --schedule 20:00 -m "Favorite show" --days friday
```

#### Alarm Management
```bash
# List all configured alarms
alarm --list

# Remove specific alarm (use ID from list)
alarm --remove 1

# Remove all alarms
alarm --clear-all
```

### Valid Day Specifications for Scheduled Alarms

- **Day groups**: `daily`, `weekdays`, `weekend`
- **Individual days**: `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `sunday`
- **Combinations**: `monday,friday`, `tuesday,thursday`, etc.

### Available Options

| Option | Description |
|--------|-------------|
| `-m, --message` | Custom message for the alarm |
| `--no-sound` | Suppress audio alert |
| `--tempo` | Timer mode (MM:SS format) |
| `--tempo-threshold SECONDS` | Threshold for `sleep` vs backend scheduling (default: 180 seconds/3 minutes) |
| `--schedule` | Schedule recurring alarm |
| `--days` | Specify days for scheduled alarms |
| `--list` | List all configured alarms |
| `--remove ID` | Remove specific alarm by ID |
| `--clear-all` | Remove all alarms |
| `-h, --help` | Display detailed help |

## Audio Files

The script automatically searches for audio files in the following order:
1. `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`
2. `/usr/share/sounds/alsa/Front_Left.wav`
3. `/usr/share/sounds/sound-icons/prompt.wav`
4. `/usr/share/sounds/ubuntu/stereo/bell.ogg`

If no audio file is found, the system uses the terminal bell as fallback.

## Intelligent Timer System

The system employs two different methods for handling timers based on duration:

### Sleep Mode (High Precision)
- **When**: Timers ≤ threshold (default: 180 seconds/3 minutes)
- **Advantages**: Second-level precision, immediate execution
- **Limitation**: Process must remain running

### Persistent Backend (Cron or Systemd)
- **When**: Timers > threshold
- **Advantages**: Persists across terminal sessions, handles long-duration timers
- **alarm.sh (cron)**: Minute-level precision (seconds rounded)
- **alarm-v2.sh (systemd)**: Second-level precision

### Threshold Configuration

```bash
# Use sleep for timers ≤ 60 seconds
alarm --tempo 02:00 --tempo-threshold 60

# Use sleep for timers ≤ 10 minutes  
alarm --tempo 05:00 --tempo-threshold 600

# Default value (180 seconds = 3 minutes)
alarm --tempo 02:30  # Uses sleep (≤3min)
alarm --tempo 05:00  # Uses persistent backend (>3min)
```

## Version Comparison

| Feature | alarm.sh (cron) | alarm-v2.sh (systemd) |
|---------|-----------------|----------------------|
| **Backend** | cron daemon | systemd timers |
| **Alarm precision** | Minute | Second |
| **Timer precision** | Minute (>threshold) | Second |
| **Persistence** | Yes | Yes |
| **Requirements** | cron installed | systemd installed |
| **Compatibility** | All Unix-like systems | Modern Linux distributions |
| **Management** | crontab -l | systemctl --user list-timers |
| **Logs** | /var/log/syslog | journalctl --user |

## Troubleshooting

### Desktop notifications not appearing
- Verify `notify-send` is installed
- Ensure your desktop environment supports libnotify notifications

### No audio playback
- Verify audio system is functioning (PipeWire, PulseAudio, or ALSA)
- Check that audio files exist at specified paths
- Test audio playback manually:
  - PipeWire: `pw-play /usr/share/sounds/alsa/Front_Left.wav`
  - PulseAudio: `paplay /usr/share/sounds/alsa/Front_Left.wav`
  - ALSA: `aplay /usr/share/sounds/alsa/Front_Left.wav`

### Alarms not executing (alarm.sh with cron)
- Verify cron service is running: `sudo systemctl status cron` or `sudo systemctl status cronie`
- Check your crontab: `crontab -l`
- Review system logs: `grep CRON /var/log/syslog`

### Alarms not executing (alarm-v2.sh with systemd)
- Verify user timers: `systemctl --user list-timers`
- Check specific timer status: `systemctl --user status alarm-ID.timer`
- Review logs: `journalctl --user -u alarm-ID.service`
- Verify systemd user timers are enabled: `loginctl show-user $USER`

### Scheduled alarms not working

**For alarm.sh (cron):**
- Verify cron is running: `sudo systemctl status cron`
- Check script has execution permissions
- Review cron logs: `sudo tail -f /var/log/cron`
- Verify timezone: `date`
- Ensure time format is correct (HH:MM in 24-hour format)

**For alarm-v2.sh (systemd):**
- List active timers: `systemctl --user list-timers --all`
- Verify timer calendar specification: `systemctl --user cat alarm-ID.timer`
- Test service manually: `systemctl --user start alarm-ID.service`
- Verify day specifications are valid

## Limitations

- System must be powered on for alarms to execute
- **alarm.sh**: Scheduled alarms depend on cron service (minute-level precision)
- **alarm-v2.sh**: Scheduled alarms depend on systemd timers (second-level precision)
- Desktop notifications require an active desktop environment

## Contributing

Contributions are welcome. Please follow these steps:
1. Fork the project
2. Create a feature branch (`git checkout -b feature/new-functionality`)
3. Commit your changes (`git commit -am 'Add new functionality'`)
4. Push to the branch (`git push origin feature/new-functionality`)
5. Open a Pull Request

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Author

**Franco Castro**