#!/usr/bin/env bash
version=1

# abort on error, undefined var, or failed pipe
set -euo pipefail

# Column padding between fields
col_pad=3

# Parse command line arguments for quick status checks
LIST_DEVICES=false
SHOW_REGION=false
LIST_MAPPED=false
SHOW_VERSION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list) LIST_DEVICES=true; shift ;;
        -r|--region) SHOW_REGION=true; shift ;;
        -d|--device) LIST_MAPPED=true; shift ;;
        -v|--version) SHOW_VERSION=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Handle -v|--version: Display script and meshcore-cli versions
if $SHOW_VERSION; then
    echo "Script version: $version"
    echo "Current meshcore-cli version: $(meshcli -v | grep -oP 'v\K[0-9.]+' --color=never)"
    echo " Latest meshcore-cli version: $(curl -s https://pypi.org/pypi/meshcore-cli/json | jq -r '.info.version') (According to https://pypi.org/pypi/meshcore-cli)"
    exit 0
fi

# Handle -l|--list: List available serial devices with dynamic divider
if $LIST_DEVICES; then
    mapfile -t DEVICES < <(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | sort)
    if [[ ${#DEVICES[@]} -eq 0 ]]; then
        echo "No /dev/ttyUSB* or /dev/ttyACM* devices detected."
        exit 1
    fi

    # Load regions and maps for consistency with interactive mode
    declare -A REGION_COMMANDS
    declare -A MAC_NAME_MAP MAC_ROLE_MAP
    if [[ -f "regions.txt" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            [[ "$line" == \#* ]] && continue
            if [[ "$line" == Region=* ]]; then
                :
            elif [[ "$line" == *=* ]]; then
                region="${line%%=*}"
                cmd="${line#*=}"
                region=$(echo "$region" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                REGION_COMMANDS["$region"]="$cmd"
            fi
        done < regions.txt
    fi

    if [[ -f "devices.txt" ]]; then
        while IFS=',' read -r mac role name; do
            [[ -z "$mac" ]] && continue
            [[ "$mac" == \#* ]] && continue
            [[ "$mac" == Region=* ]] && continue
            mac=$(echo "$mac" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            role=$(echo "$role" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            mac_lc=$(echo "$mac" | tr '[:upper:]' '[:lower:]')
            MAC_ROLE_MAP["$mac_lc"]="$role"
            MAC_NAME_MAP["$mac_lc"]="$name"
        done < devices.txt
    fi

    # Collect data and calculate max widths for each column
    declare -a DATA_ROWS
    max_dev_len=0
    max_mac_len=0
    max_role_len=0
    max_name_len=0

    # Define header lengths
    header_dev="Device Path(s)"
    header_mac="Serial/MAC"
    header_role="Role"
    header_name="Name"

    # Get maximum lengths of headers
    max_dev_len=${#header_dev}
    max_mac_len=${#header_mac}
    max_role_len=${#header_role}
    max_name_len=${#header_name}

    for dev in "${DEVICES[@]}"; do
        mac=$(udevadm info --name="$dev" \
            | grep ID_SERIAL_SHORT= \
            | cut -d= -f2 \
            | sed -E 's/(..)/\1:/g; s/:$//')
        [[ -z "$mac" ]] && mac="N/A"
        mac_lc=$(echo "$mac" | tr '[:upper:]' '[:lower:]')
        role=${MAC_ROLE_MAP["$mac_lc"]:-N/A}
        name=${MAC_NAME_MAP["$mac_lc"]:-N/A}

        # Store raw data for later printing
        DATA_ROWS+=("$dev|$mac|$role|$name")

        # Calculate lengths
        (( ${#dev} > max_dev_len )) && max_dev_len=${#dev}
        (( ${#mac} > max_mac_len )) && max_mac_len=${#mac}
        (( ${#role} > max_role_len )) && max_role_len=${#role}
        (( ${#name} > max_name_len )) && max_name_len=${#name}
    done

    # Add padding to each column width except the last
    max_dev_len=$(( max_dev_len + col_pad ))
    max_mac_len=$(( max_mac_len + col_pad ))
    max_role_len=$(( max_role_len + col_pad ))
    # Last column does not get padding
    # max_name_len remains unchanged

    # Calculate total width for the divider
    total_width=$(( max_dev_len + max_mac_len + max_role_len + max_name_len ))

    # Create a divider line
    divider=$(printf '%*s' "$total_width" '' | tr ' ' '-')

    # Print the header with fixed widths
    printf "%-${max_dev_len}s%-${max_mac_len}s%-${max_role_len}s%s\n" "$header_dev" "$header_mac" "$header_role" "$header_name"
    echo "$divider"

    # Print data rows with fixed widths
    for row in "${DATA_ROWS[@]}"; do
        IFS='|' read -r d m r n <<< "$row"
        printf "%-${max_dev_len}s%-${max_mac_len}s%-${max_role_len}s%s\n" "$d" "$m" "$r" "$n"
    done
    exit 0
fi

# Handle -r|--region: Show current region and list available regions with dynamic divider
if $SHOW_REGION; then
    CURRENT_REGION="None"
    if [[ -f "devices.txt" ]]; then
        while IFS= read -r line; do
            if [[ "$line" == Region=* ]]; then
                CURRENT_REGION="${line#Region=}"
                CURRENT_REGION=$(echo "$CURRENT_REGION" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                break
            fi
        done < devices.txt
    fi
    echo "Current Region in devices.txt: $CURRENT_REGION"
    echo ""
    echo "Defined regions in regions.txt:"

    # Collect data and calculate max widths
    declare -a REGION_ROWS
    max_reg_len=0
    max_freq_len=0
    max_bw_len=0
    max_sf_len=0
    max_cr_len=0

    # Define header lengths
    header_reg="Regions"
    header_freq="Frequency"
    header_bw="Bandwidth"
    header_sf="Spread Factor"
    header_cr="Coding Rate"

    # Get maximum lengths of headers
    max_reg_len=${#header_reg}
    max_freq_len=${#header_freq}
    max_bw_len=${#header_bw}
    max_sf_len=${#header_sf}
    max_cr_len=${#header_cr}

    if [[ -f "regions.txt" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            [[ "$line" == \#* ]] && continue
            if [[ "$line" == *=* && "$line" != Region=* ]]; then
                region="${line%%=*}"
                cmd="${line#*=}"
                region=$(echo "$region" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                freq=""
                bw=""
                sf=""
                cr=""
                if [[ "$cmd" == set\ radio\ * ]]; then
                    params="${cmd#set radio }"
                    IFS=',' read -r freq bw sf cr <<< "$params"
                    freq=$(echo "$freq" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    bw=$(echo "$bw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    sf=$(echo "$sf" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    cr=$(echo "$cr" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                fi

                REGION_ROWS+=("$region|$freq|$bw|$sf|$cr")

                (( ${#region} > max_reg_len )) && max_reg_len=${#region}
                (( ${#freq} > max_freq_len )) && max_freq_len=${#freq}
                (( ${#bw} > max_bw_len )) && max_bw_len=${#bw}
                (( ${#sf} > max_sf_len )) && max_sf_len=${#sf}
                (( ${#cr} > max_cr_len )) && max_cr_len=${#cr}
            fi
        done < regions.txt
    fi

    # Add padding to each column width except the last
    max_reg_len=$(( max_reg_len + col_pad ))
    max_freq_len=$(( max_freq_len + col_pad ))
    max_bw_len=$(( max_bw_len + col_pad ))
    max_sf_len=$(( max_sf_len + col_pad ))
    # Last column does not get padding
    # max_cr_len remains unchanged

    # Calculate total width for the divider
    total_width=$(( max_reg_len + max_freq_len + max_bw_len + max_sf_len + max_cr_len ))

    # Create a divider line
    divider=$(printf '%*s' "$total_width" '' | tr ' ' '-')

    # Print the header with fixed widths
    printf "%-${max_reg_len}s%-${max_freq_len}s%-${max_bw_len}s%-${max_sf_len}s%s\n" "$header_reg" "$header_freq" "$header_bw" "$header_sf" "$header_cr"
    echo "$divider"

    # Print data rows with fixed widths
    for row in "${REGION_ROWS[@]}"; do
        IFS='|' read -r r f b s c <<< "$row"
        printf "%-${max_reg_len}s%-${max_freq_len}s%-${max_bw_len}s%-${max_sf_len}s%s\n" "$r" "$f" "$b" "$s" "$c"
    done
    exit 0
fi

# Handle -d|--device: List mapped devices from devices.txt with dynamic divider
if $LIST_MAPPED; then
    echo "Mapped devices in devices.txt:"

    declare -a MAPPED_ROWS
    max_mac_len=0
    max_role_len=0
    max_name_len=0

    # Define header lengths
    header_mac="Serial/MAC"
    header_role="Role"
    header_name="Name"

    # Get maximum lengths of headers
    max_mac_len=${#header_mac}
    max_role_len=${#header_role}
    max_name_len=${#header_name}

    if [[ -f "devices.txt" ]]; then
        while IFS=',' read -r mac role name; do
            [[ -z "$mac" ]] && continue
            [[ "$mac" == \#* ]] && continue
            [[ "$mac" == Region=* ]] && continue
            mac=$(echo "$mac" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            role=$(echo "$role" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            MAPPED_ROWS+=("$mac|$role|$name")

            (( ${#mac} > max_mac_len )) && max_mac_len=${#mac}
            (( ${#role} > max_role_len )) && max_role_len=${#role}
            (( ${#name} > max_name_len )) && max_name_len=${#name}
        done < devices.txt
    fi

    # Add padding to each column width except the last
    max_mac_len=$(( max_mac_len + col_pad ))
    max_role_len=$(( max_role_len + col_pad ))
    # Last column does not get padding
    # max_name_len remains unchanged

    # Calculate total width for the divider
    total_width=$(( max_mac_len + max_role_len + max_name_len ))

    # Create a divider line
    divider=$(printf '%*s' "$total_width" '' | tr ' ' '-')

    # Print the header with fixed widths
    printf "%-${max_mac_len}s%-${max_role_len}s%s\n" "$header_mac" "$header_role" "$header_name"
    echo "$divider"

    # Print data rows with fixed widths
    for row in "${MAPPED_ROWS[@]}"; do
        IFS='|' read -r m r n <<< "$row"
        printf "%-${max_mac_len}s%-${max_role_len}s%s\n" "$m" "$r" "$n"
    done
    exit 0
fi

# Load regions from regions.txt (format: Region=Command)
declare -A REGION_COMMANDS
DEFAULT_REGION=""
if [[ -f "regions.txt" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue                # skip empty lines
        [[ "$line" == \#* ]] && continue            # skip comment lines
        if [[ "$line" == Region=* ]]; then
            DEFAULT_REGION="${line#Region=}"
            DEFAULT_REGION=$(echo "$DEFAULT_REGION" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        elif [[ "$line" == *=* ]]; then
            region="${line%%=*}"
            cmd="${line#*=}"
            region=$(echo "$region" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            REGION_COMMANDS["$region"]="$cmd"
        fi
    done < regions.txt
fi

# Load MAC->Role and MAC->Name maps from devices.txt (comma-separated, order: MAC, Role, Name)
declare -A MAC_NAME_MAP MAC_ROLE_MAP DEVICE_REGION_MAP
if [[ -f "devices.txt" ]]; then
    while IFS=',' read -r mac role name; do
        [[ -z "$mac" ]] && continue                # skip empty lines
        [[ "$mac" == \#* ]] && continue            # skip comment lines
        mac=$(echo "$mac" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        role=$(echo "$role" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        mac_lc=$(echo "$mac" | tr '[:upper:]' '[:lower:]')
        MAC_ROLE_MAP["$mac_lc"]="$role"
        MAC_NAME_MAP["$mac_lc"]="$name"
    done < devices.txt

    # Check for a global Region= line in devices.txt
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        if [[ "$line" == Region=* ]]; then
            DEVICE_DEFAULT_REGION="${line#Region=}"
            DEVICE_DEFAULT_REGION=$(echo "$DEVICE_DEFAULT_REGION" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        fi
    done < devices.txt
fi

# Map each role to the command files that must be executed for that role
declare -A ROLE_FILES_MAP
ROLE_FILES_MAP["CB"]="cmd_com.txt"
ROLE_FILES_MAP["CU"]="cmd_com.txt"
ROLE_FILES_MAP["BR"]="cmd_rep.txt cmd_rep_bas.txt"
ROLE_FILES_MAP["MR"]="cmd_rep.txt cmd_rep_mob.txt"
ROLE_FILES_MAP["RS"]="cmd_roo.txt"
ROLE_FILES_MAP["RB"]="cmd_roo.txt cmd_rep.txt cmd_rep_bas.txt"
ROLE_FILES_MAP["RM"]="cmd_roo.txt cmd_rep.txt cmd_rep_mob.txt"

# Discover serial devices
mapfile -t DEVICES < <(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | sort)

if [[ ${#DEVICES[@]} -eq 0 ]]; then
    echo "No /dev/ttyUSB* or /dev/ttyACM* devices detected."
    exit 1
fi

# Define constants
max_idx_width=6

# Define headers
header_dev="Device Path(s)"
header_mac="Serial/MAC"
header_role="Role"
header_name="Name"

# Initialize max lengths with header lengths
max_dev_len=${#header_dev}
max_mac_len=${#header_mac}
max_role_len=${#header_role}
max_name_len=${#header_name}

# Simulated data arrays (replace with actual logic)
declare -a DEVICES=("/dev/ttyACM0")
declare -A MAC_ROLE_MAP=([8c:fd:49:b7:91:24]="CU")
declare -A MAC_NAME_MAP=([8c:fd:49:b7:91:24]="Hobbit")
declare -a INTERACTIVE_ROWS

# Process devices to find max lengths
for dev in "${DEVICES[@]}"; do
    mac="8C:FD:49:B7:91:24"
    mac_lc=$(echo "$mac" | tr '[:upper:]' '[:lower:]')
    role=${MAC_ROLE_MAP["$mac_lc"]:-N/A}
    name=${MAC_NAME_MAP["$mac_lc"]:-N/A}
    INTERACTIVE_ROWS+=("$dev|$mac|$role|$name")

    (( ${#dev} > max_dev_len )) && max_dev_len=${#dev}
    (( ${#mac} > max_mac_len )) && max_mac_len=${#mac}
    (( ${#role} > max_role_len )) && max_role_len=${#role}
    (( ${#name} > max_name_len )) && max_name_len=${#name}
done

# Apply padding to column widths (except the last)
max_dev_len=$(( max_dev_len + col_pad ))
max_mac_len=$(( max_mac_len + col_pad ))
max_role_len=$(( max_role_len + col_pad ))

# Calculate total width for the divider (sum of all column widths)
total_width=$(( max_dev_len + max_mac_len + max_role_len + max_name_len ))

# Generate divider line
divider=$(printf '%*s' "$total_width" '' | tr ' ' '-')

# Print Header with leading indentation to align with data content
printf "%${max_idx_width}s" ""
printf "%-${max_dev_len}s%-${max_mac_len}s%-${max_role_len}s%s\n" "$header_dev" "$header_mac" "$header_role" "$header_name"

# Print Divider with leading indentation
printf "%${max_idx_width}s" ""
echo "$divider"

# Print Data Rows
idx=1
for row in "${INTERACTIVE_ROWS[@]}"; do
    IFS='|' read -r d m r n <<< "$row"
    idx_str=$(printf "  %d) " "$idx")
    printf "%-6s" "$idx_str"
    printf "%-${max_dev_len}s%-${max_mac_len}s%-${max_role_len}s%s\n" "$d" "$m" "$r" "$n"
    ((idx++))
done

# Prompt for device selection
while true; do
    read -rp "Enter the number of the device to use: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#DEVICES[@]} )); then
        SELECTED_DEVICE="${DEVICES[$((choice-1))]}"
        break
    else
        echo "Invalid selection – please enter a number between 1 and ${#DEVICES[@]}."
    fi
done

# Determine MAC, role, and name for the selected device
selected_mac=$(udevadm info --name="$SELECTED_DEVICE" \
    | grep ID_SERIAL_SHORT= \
    | cut -d= -f2 \
    | sed -E 's/(..)/\1:/g; s/:$//')
[[ -z "$selected_mac" ]] && selected_mac="N/A"
selected_mac_upper=$(echo "$selected_mac" | tr '[:lower:]' '[:upper:]')
selected_mac_lc=$(echo "$selected_mac" | tr '[:upper:]' '[:lower:]')
SELECTED_ROLE=${MAC_ROLE_MAP["$selected_mac_lc"]}
SELECTED_NAME=${MAC_NAME_MAP["$selected_mac_lc"]:-N/A}

# Determine Region
SELECTED_REGION=""
if [[ -n "$DEVICE_DEFAULT_REGION" ]]; then
    SELECTED_REGION="$DEVICE_DEFAULT_REGION"
elif [[ -n "${REGION_COMMANDS[$selected_mac_lc]:-}" ]]; then
    SELECTED_REGION="$selected_mac_lc"
fi

# If region not found in devices.txt or MAC, prompt user
if [[ -z "$SELECTED_REGION" ]]; then
    echo "No region defined for this device in devices.txt."
    echo ""
    echo "Available regions from regions.txt:"
    for reg in "${!REGION_COMMANDS[@]}"; do
        echo "  $reg"
    done
    echo ""
    while true; do
        read -rp "Please enter the region code: " region_input
        region_input=$(echo "$region_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "${REGION_COMMANDS[$region_input]:-}" ]]; then
            SELECTED_REGION="$region_input"
            break
        else
            echo "Invalid region. Please choose from the list above."
        fi
    done
else
    # Check if the region defined in devices.txt is valid in regions.txt
    if [[ -z "${REGION_COMMANDS[$SELECTED_REGION]:-}" ]]; then
        echo "Region '$SELECTED_REGION' found in devices.txt but not in regions.txt."
        echo ""
        echo "Available regions from regions.txt:"
        for reg in "${!REGION_COMMANDS[@]}"; do
            echo "  $reg"
        done
        echo ""
        while true; do
            read -rp "Please enter a valid region code: " region_input
            region_input=$(echo "$region_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "${REGION_COMMANDS[$region_input]:-}" ]]; then
                SELECTED_REGION="$region_input"
                break
            else
                echo "Invalid region. Please choose from the list above."
            fi
        done
    else
        echo "Using region from devices.txt: $SELECTED_REGION"
    fi
fi

# Verify role – if unknown, ask the user to supply one with role definitions displayed
if [[ -z "$SELECTED_ROLE" || "$SELECTED_ROLE" == "N/A" ]]; then
    echo "Role for MAC $selected_mac not found in devices.txt."
    echo ""
    echo "Available role codes:"
    echo "CB = Companion Bluetooth"
    echo "CU = Companion USB"
    echo "BR = Base Repeater"
    echo "MR = Mobile Repeater"
    echo "RS = Room Server"
    echo "RB = Room Server/Repeater Base (Not recommended per MeshCore Documentation)"
    echo "RM = Room Server/Mobile Repeater (Not recommended per MeshCore Documentation)"
    echo ""
    while true; do
        read -rp "Please enter the role code: " role_input
        role_input=$(echo "$role_input" | tr '[:lower:]' '[:upper:]')
        if [[ "$role_input" =~ ^(CB|CU|BR|MR|RS|RB|RM)$ ]]; then
            SELECTED_ROLE="$role_input"
            break
        else
            echo "Invalid role code. Acceptable values are CB, CU, BR, MR, RS, RB, RM."
        fi
    done
else
    echo "Detected role for selected device: $SELECTED_ROLE"
fi

# Resolve command files for the determined role; default to companion set if unknown
IFS=' ' read -r -a ROLE_FILES <<< "${ROLE_FILES_MAP["${SELECTED_ROLE^^}"]}"
if [[ ${#ROLE_FILES[@]} -eq 0 ]]; then
    ROLE_FILES=("cmd_com.txt")                      # fallback to companion commands
fi

# Fixed generic pre- and post-files
PRE_FILE="cmd_pre.txt"
POST_FILE="cmd_pos.txt"

# Verify that all required files exist before any execution
for f in "$PRE_FILE" "$POST_FILE" "${ROLE_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "Required file \"$f\" not found in the current directory."
        exit 1
    fi
done

# Determine mesh name – use devices.txt name if available, otherwise prompt user
if [[ "$SELECTED_NAME" != "N/A" && -n "$SELECTED_NAME" ]]; then
    MESH_NAME="$SELECTED_NAME"
    echo "Using name from devices.txt: $MESH_NAME"
    SET_NAME=true
else
    while true; do
        read -rp "Do you want to set a mesh name? (y/n): " yn
        case "$yn" in
            [Yy]*) SET_NAME=true; break ;;
            [Nn]*) SET_NAME=false; break ;;
            *) echo "Please answer y (yes) or n (no)." ;;
        esac
    done
    if $SET_NAME; then
        while true; do
            read -rp "Enter the mesh name (no spaces): " MESH_NAME
            if [[ "$MESH_NAME" != *[[:space:]]* && -n "$MESH_NAME" ]]; then
                break
            else
                echo "Name must not contain spaces and cannot be empty."
            fi
        done
    fi
fi

# Extract frequency from region command for display
REGION_CMD="${REGION_COMMANDS[$SELECTED_REGION]}"
REGION_FREQ=""
if [[ -n "$REGION_CMD" ]]; then
    # Remove "set radio " prefix if present
    REGION_FREQ=$(echo "$REGION_CMD" | sed 's/^set radio //')
fi

# Final confirmation with Configuration Summary
echo ""
echo "Configuration Summary:"
echo "  Device: $SELECTED_DEVICE"
echo "  Serial/MAC: $selected_mac_upper"
echo "  Name: $MESH_NAME"
echo "  Role: $SELECTED_ROLE"
echo "  Region: $SELECTED_REGION"
echo "  Region Frequency: $REGION_FREQ"
echo ""
while true; do
    read -rp "Proceed with this configuration? (y/n): " go
    case "$go" in
        [Yy]*) break ;;
        [Nn]*) echo "Execution cancelled by user."; exit 0 ;;
        *) echo "Please answer y (yes) or n (no)." ;;
    esac
done

# Run a command file line-by-line; lines beginning with "bash " are executed as Bash commands
run_commands() {
    local label="$1" file="$2"
    while IFS= read -r line || [[ -n $line ]]; do
        [[ -z "$line" ]] && continue                      # skip empty lines
        [[ "$line" == \#* ]] && continue                  # skip comment lines
        if [[ "$line" == bash\ * ]]; then
            cmd="${line#bash }"
            bash -c "$cmd"
            continue
        fi
        read -ra ARGS <<< "$line"
        CMD=(meshcli -s "$SELECTED_DEVICE")
        [[ "$SELECTED_ROLE" =~ R ]] && CMD+=(-r -j)       # add -r -j for any repeater role
        CMD+=("${ARGS[@]}")
        echo "${CMD[@]}"
        "${CMD[@]}"
    done < "$file"
}

# Set mesh name if requested
set_mesh_name() {
    CMD=(meshcli -s "$SELECTED_DEVICE")
    [[ "$SELECTED_ROLE" =~ R ]] && CMD+=(-r -j)           # add -r -j for any repeater role
    CMD+=(set name "$MESH_NAME")
    echo "${CMD[@]}"
    "${CMD[@]}"
}

# Execute region command and reboot sequence
execute_region_and_reboot() {
    local region_cmd="${REGION_COMMANDS[$SELECTED_REGION]}"
    echo "Executing region command: $region_cmd"

    read -ra REGION_ARGS <<< "$region_cmd"

    CMD=(meshcli -s "$SELECTED_DEVICE")
    [[ "$SELECTED_ROLE" =~ R ]] && CMD+=(-r -j)
    CMD+=("${REGION_ARGS[@]}")
    echo "${CMD[@]}"
    "${CMD[@]}"

    echo -e "\033[0;31mThese errors, if any, are part of the reboot process.\033[0m"

    CMD=(meshcli -s "$SELECTED_DEVICE")
    [[ "$SELECTED_ROLE" =~ R ]] && CMD+=(-r -j)           # add -r -j for any repeater role
    CMD+=(reboot)
    echo "${CMD[@]}"
    "${CMD[@]}"

    echo -e "\033[0;31mBoard rebooting.\033[0m"
    sleep 5
    echo -e "\033[0;31mBoard reboot complete... hopefully.\033[0m"
}

# Execution order: name set -> region/reboot -> pre-generic -> role-specific files -> post-generic
if $SET_NAME; then
    set_mesh_name
fi
execute_region_and_reboot
run_commands "pre-generic" "$PRE_FILE"
for rf in "${ROLE_FILES[@]}"; do
    run_commands "$rf" "$rf"
done
run_commands "post-generic" "$POST_FILE"

echo "All batch commands completed successfully."
