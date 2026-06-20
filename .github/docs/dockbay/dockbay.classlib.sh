#!/usr/bin/env bash
cat << 'SCRIPT-INFO' > /dev/null
⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆
Script Name:     dockbay.classlib.sh
Version:         v1.00.00
Created on:      20.05.2026
Last update:     20.06.2026
Written by:      Praetoriani
Website:         https://github.com/praetoriani
⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆
TEST RESULTS:  ✗ NOT TESTED SINCE UPDATE
⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆
The DockBay Class Library is the new Core Library for the DockBay Project.
The  dockbay.classlib.sh  will fully replace  docbay.lib.sh  and its content/functionallity!
⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆
Example Usage:

... to be documented ...

⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆⋆
SCRIPT-INFO


# We need to make sure that we have at least Bash 4.0
if [ -z "${BASH_VERSINFO}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Runtime error in $0 !" >&2
    echo "This script requires Bash 4.0 or higher!" >&2
    exit 1
fi


# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
# → GLOBAL  🐳 DOCKBAY  CONFIGURATION

ScriptFullName="$(basename "${BASH_SOURCE[0]}")"                             # ← Gets the full script name 
ScriptFileName="${ScriptFullName%.*}"                                        # ← Remove the file extension
ScriptLocation="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"               # ← Gets the full path to the current location

MACHINE_NAME="$(hostname)"                                                   # ← Gets the current Hostname (name of the computer)
MACHINE_NAME="${MACHINE_NAME,,}"                                             # ← Convert it to lower cases (for certs etc.)
MACHINE_IPV4=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')   # ← Get the IPv4 of the current machine

SETUP_LOCATION="EMPTY"                                                       # ← Stores the Installation Location for the current script
DOCKBAY_PRECKECKS="false"                                                    # ← Stores is the PerformDockBayPrechecks-Function was performed or not

# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
# → GLOBAL PATH CONFIGURATION

declare -A DOCKBAY                                                           # ← Stores all important paths
DOCKBAY["ROOTPATH"]="/opt/dockbay"                                           # ← Root Directory of DockBay
DOCKBAY["SYSSTACK"]="/opt/dockbay/core"                                      # ← For Docker-Related Apps
DOCKBAY["APPSTACK"]="/opt/dockbay/apps"                                      # ← For general/regulas apps
DOCKBAY["SQLSTACK"]="/opt/dockbay/dbhost"                                    # ← For Database Apps only!

# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
# → GLOBAL FILE CONFIGURATION

SETUPLOG="${DOCKBAY["ROOTPATH"]}/dockbay-setup.log"                         # ← Full path to the DockBay Setup Logfile

DOCKBAYCONFIG="${DOCKBAY["ROOTPATH"]}/dockbay.config.json"                  # ← Full path to the DockBay Core Config JSON
SETUPCFGJSON="${DOCKBAY["ROOTPATH"]}/setup.config.json"                     # ← Full path to the DockBay Setup Config JSON
USERAUTHJSON="${DOCKBAY["ROOTPATH"]}/userauth.json"                         # ← Full path to the UserAuth Config JSON

DockBayScriptLocation=""                                                    # ← Will store the current working directory

# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

# Define color constants
# ============================================================
# Shell Color Constants
# ANSI 256-Color / xterm-256color
# ============================================================

# Reset / No Color
readonly NC=$'\033[0m'                           # No Color / Reset
# --- White / Black ---
readonly WHITE=$'\033[38;5;255m'                 # #EEEEEE
readonly WHITE_BOLD=$'\033[1;38;5;255m'          # #EEEEEE (BOLD)
readonly BLACK=$'\033[38;5;16m'                  # #000000
readonly BLACK_BOLD=$'\033[1;38;5;16m'           # #000000 (BOLD)
# --- Gray ---
readonly GRAY=$'\033[38;5;249m'                  # #BFBFBF
readonly GRAY_BOLD=$'\033[1;38;5;249m'           # #BFBFBF (BOLD)
readonly DARK_GRAY=$'\033[38;5;240m'             # #595959
readonly DARK_GRAY_BOLD=$'\033[1;38;5;240m'      # #595959 (BOLD)
# --- Red ---
readonly RED=$'\033[38;5;196m'                   # #E60000
readonly RED_BOLD=$'\033[1;38;5;196m'            # #E60000 (BOLD)
readonly RED_LIGHT=$'\033[38;5;203m'             # #FF3333
readonly RED_LIGHT_BOLD=$'\033[1;38;5;203m'      # #FF3333 (BOLD)
readonly RED_DARK=$'\033[38;5;160m'              # #B30000
readonly RED_DARK_BOLD=$'\033[1;38;5;160m'       # #B30000 (BOLD)
# --- Yellow ---
readonly YELLOW=$'\033[38;5;221m'                # #FFD11A
readonly YELLOW_BOLD=$'\033[1;38;5;221m'         # #FFD11A (BOLD)
readonly YELLOW_LIGHT=$'\033[38;5;222m'          # #FFE066
readonly YELLOW_LIGHT_BOLD=$'\033[1;38;5;222m'   # #FFE066 (BOLD)
readonly YELLOW_DARK=$'\033[38;5;220m'           # #E6B800
readonly YELLOW_DARK_BOLD=$'\033[1;38;5;220m'    # #E6B800 (BOLD)
# --- Orange ---
readonly ORANGE=$'\033[38;5;208m'                # #e67300
readonly ORANGE_BOLD=$'\033[1;38;5;208m'         # #e67300 (BOLD)
readonly ORANGE_LIGHT=$'\033[38;5;216m'          # #FF944D
readonly ORANGE_LIGHT_BOLD=$'\033[1;38;5;216m'   # #FF944D (BOLD)
readonly ORANGE_DARK=$'\033[38;5;166m'           # #e65c00
readonly ORANGE_DARK_BOLD=$'\033[1;38;5;166m'    # #e65c00 (BOLD)
# --- Green ---
readonly GREEN=$'\033[38;5;77m'                  # #33cc33
readonly GREEN_BOLD=$'\033[1;38;5;77m'           # #33cc33 (BOLD)
readonly GREEN_LIGHT=$'\033[38;5;120m'           # #4dff4d
readonly GREEN_LIGHT_BOLD=$'\033[1;38;5;120m'    # #4dff4d (BOLD)
readonly GREEN_DARK=$'\033[38;5;71m'             # #2d862d
readonly GREEN_DARK_BOLD=$'\033[1;38;5;71m'      # #2d862d (BOLD)
# --- Blue ---
readonly BLUE=$'\033[38;5;39m'                   # #0099ff
readonly BLUE_BOLD=$'\033[1;38;5;39m'            # #0099ff (BOLD)
readonly BLUE_LIGHT=$'\033[38;5;117m'            # #4db8ff
readonly BLUE_LIGHT_BOLD=$'\033[1;38;5;117m'     # #4db8ff (BOLD)
readonly BLUE_DARK=$'\033[38;5;32m'              # #007acc
readonly BLUE_DARK_BOLD=$'\033[1;38;5;32m'       # #007acc (BOLD)
# --- Cyan ---
readonly CYAN=$'\033[38;5;51m'                   # #00ffff
readonly CYAN_BOLD=$'\033[1;38;5;51m'            # #00ffff (BOLD)
readonly CYAN_LIGHT=$'\033[38;5;159m'            # #80ffff
readonly CYAN_LIGHT_BOLD=$'\033[1;38;5;159m'     # #80ffff (BOLD)
readonly CYAN_DARK=$'\033[38;5;44m'              # #00cccc
readonly CYAN_DARK_BOLD=$'\033[1;38;5;44m'       # #00cccc (BOLD)
# --- Magenta ---
readonly MAGENTA=$'\033[38;5;199m'               # #ff0080
readonly MAGENTA_BOLD=$'\033[1;38;5;199m'        # #ff0080 (BOLD)
readonly MAGENTA_LIGHT=$'\033[38;5;211m'         # #ff4da6
readonly MAGENTA_LIGHT_BOLD=$'\033[1;38;5;211m'  # #ff4da6 (BOLD)
readonly MAGENTA_DARK=$'\033[38;5;162m'          # #cc0066
readonly MAGENTA_DARK_BOLD=$'\033[1;38;5;162m'   # #cc0066 (BOLD)
# --- Purple ---
readonly PURPLE=$'\033[38;5;129m'                # #8000ff
readonly PURPLE_BOLD=$'\033[1;38;5;129m'         # #8000ff (BOLD)
readonly PURPLE_LIGHT=$'\033[38;5;135m'          # #9933ff
readonly PURPLE_LIGHT_BOLD=$'\033[1;38;5;135m'   # #9933ff (BOLD)
readonly PURPLE_DARK=$'\033[38;5;92m'            # #6600cc
readonly PURPLE_DARK_BOLD=$'\033[1;38;5;92m'     # #6600cc (BOLD)



# Professional logging functions
output_null()   { echo -e ""; }
output_text()   { echo -e "${DARK_GRAY_BOLD}$*${NC}"; }
output_info()   { echo -e "${BLUE_BOLD}$*${NC}"; }
output_warn()   { echo -e "${ORANGE_BOLD}$*${NC}"; }
output_fail()   { echo -e "${RED_BOLD}$*${NC}"; }
output_okay()   { echo -e "${GREEN_BOLD}$*${NC}"; }
output_note()   { echo -e "${PURPLE_LIGHT_BOLD}$*${NC}"; }
output_debug()  { echo -e "${YELLOW_DARK_BOLD}$*${NC}"; }
output_code()   { echo -e "$*"; }

# Small Helper-Function to reset the terminal
cleanup() {
  stty sane
  printf "\n"
}


# ____________________________________________________________________________________________________
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾


cat << 'DESCRIPTION' > /dev/null
Class:   DockBayCore

This Class includes several core functions like jsonGet() , jsonSet() etc.
DESCRIPTION
DockBayCore() {
    # Entrypoint for DockerClassLib
    # ----------------------------------------------------------------------
    local fxID="$1" # ← Param contains the function ID (mandatory)
    shift 1   # remove fxID, pass the rest to helper functions


cat << 'DESCRIPTION' > /dev/null
    -----CORE FUNCTION → jsonGet ----------------------------------------------------------
    This function is required to read from one of the globally defined JSON Files
    DOCKBAYCONFIG="${DOCKBAY["ROOTPATH"]}/dockbay.config.json"   # ← Full path to the DockBay Core Config JSON
    SETUPCFGJSON="${DOCKBAY["ROOTPATH"]}/setup.config.json"      # ← Full path to the DockBay Setup Config JSON
    USERAUTHJSON="${DOCKBAY["ROOTPATH"]}/userauth.json"          # ← Full path to the UserAuth Config JSON


    Reads a value for a given key from a JSON file using jq. Returns the raw value
    (without JSON quoting) on success. Uses jq's -r (raw output) flag so string values are
    returned without surrounding quotes, ready for use in shell variables.

    Returns:
    The raw value string on success
    "xx#<emoji> Fatal error in function: <name>#<detail>" on failure


    Usage:

    readJSON="$(jsonGet $SETUPCFGJSON ".app" "Etherpad")"
    if ! [[ "$readJSON" == *"xx"* ]]; then
        echo ".app.Etherpad:  $readJSON"
    else
        IFS="#" read -r -a errmsg <<< "$readJSON"
        echo "${errmsg[1]}"
        echo "${errmsg[2]}"
    fi

    enabled="$(jsonGet $DOCKBAYCONFIG ".dockbay.flags" "debug")"
    if [ "$enabled" = "true" ]; then
        echo "Debug mode is ON"
    fi

    # Int-Vergleich — funktioniert mit -eq (arithmetischer Vergleich)
    port="$(jsonGet $DOCKBAYCONFIG ".dockbay.network" "port")"
    if [ "$port" -eq 8080 ]; then
        echo "Standard port"
    fi
DESCRIPTION
    jsonGet() {

        # Get the passed arguments
        local jsonfile="$1"     # ← Full path to the json-file to read from
        local jsonpath="$2"     # ← The 'route' inside the json structure
        local entrykey="$3"     # ← The 'key' to read the value from

        # ---------------------------------------------------------------------------
        # [1] Validate: ensure all mandatory parameters are present
        # ---------------------------------------------------------------------------
        if [ -z "${jsonfile}" ] || [ -z "${jsonpath}" ] || [ -z "${entrykey}" ]; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#At least one mandatory param is missing!"
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [2] Validate: ensure the given JSON file actually exists
        #     Uses early-return pattern for consistency with jsonSet()
        # ---------------------------------------------------------------------------
        if [ "$(FileLookup "${jsonfile}")" != "ok" ]; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Failed to read value from JSON file! File not found!"
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [3] Validate: ensure the given key exists at the given path in the JSON file.
        #     Both stdout and stderr are suppressed to prevent uncontrolled output
        #     outside of this function's error protocol. [FIX: Problem 1]
        # ---------------------------------------------------------------------------
        if ! jq -e --arg key "$entrykey" "${jsonpath} | has(\$key)" "$jsonfile" >/dev/null 2>&1; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Failed to read value from JSON file! Key '${entrykey}' doesn't exist at path '${jsonpath}'!"
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [4] Read the requested value from the JSON file.
        #     IMPORTANT: 'local' and assignment MUST be on separate lines so that
        #     the exit code of the jq subshell is not silently overwritten by
        #     'local' (which always returns exit code 0). [FIX: Problem 3]
        #
        #     The -r flag (raw output) strips surrounding JSON quotes from strings
        #     so the value is returned as a plain shell string. [FIX: Problem 2]
        #
        #     stderr is suppressed to prevent uncontrolled jq error output.
        #     [FIX: Problem 1 / Problem 3]
        # ---------------------------------------------------------------------------
        local jsonval
        jsonval="$(jq -r --arg key "$entrykey" "${jsonpath}[\$key]" "$jsonfile" 2>/dev/null)"

        # Evaluate the exit code of the jq call — NOT of 'local' [FIX: Problem 3]
        if [ $? -ne 0 ]; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#jq failed to read value from JSON file! (jq exit code: $?)"
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [5] Guard against null values: jq returns the literal string "null" when
        #     the key exists but its value is JSON null. Report this explicitly
        #     rather than silently returning "null" to the caller. [FIX: Problem 5]
        # ---------------------------------------------------------------------------
        if [ "$jsonval" = "null" ]; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Key '${entrykey}' exists at path '${jsonpath}' but its value is null!"
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [6] All checks passed — return the value to the caller.
        #     Double-quoting prevents word splitting and glob expansion. [FIX: Problem 4]
        # ---------------------------------------------------------------------------
        echo "$jsonval"
        return 0
    }


cat << 'DESCRIPTION' > /dev/null
    -----CORE FUNCTION → jsonSet ----------------------------------------------------------
    This function is required to write one of the globally defined JSON Files
    DOCKBAYCONFIG="${DOCKBAY["ROOTPATH"]}/dockbay.config.json"   # ← Full path to the DockBay Core Config JSON
    SETUPCFGJSON="${DOCKBAY["ROOTPATH"]}/setup.config.json"      # ← Full path to the DockBay Setup Config JSON
    USERAUTHJSON="${DOCKBAY["ROOTPATH"]}/userauth.json"          # ← Full path to the UserAuth Config JSON

    Writes a new value for a given key to a JSON file using jq. Supports value types:
    string, bool, int. Uses a safe atomic write pattern: jq writes to a .tmp file,
    which is validated and then moved to replace the original file. Performs a read-after-write
    verification to confirm the written value matches the intended value.

    Returns:
    "ok" on full success
    "xx#<emoji> Fatal error in function: <name>#<detail>" on failure


    Usage:
    ROUTE=".dockbay.path"
    KEY="app-stack"

    # Write a string value
    jsonReturn="$(jsonSet $DOCKBAYCONFIG $ROUTE $KEY "/opt/docker/apps" "string")"

    # Write a boolean value
    jsonReturn="$(jsonSet $DOCKBAYCONFIG $ROUTE $KEY "true" "bool")"

    # Write an integer value
    jsonReturn="$(jsonSet $DOCKBAYCONFIG $ROUTE $KEY "8080" "int")"

    if [ "$jsonReturn" = "ok" ]; then
        echo "New value successfully written to json file."
    else
        IFS="#" read -r -a errmsg <<< "$jsonReturn"
        echo "${errmsg[1]}"
        echo "${errmsg[2]}"
    fi
DESCRIPTION
    jsonSet() {

        # Get the passed arguments
        local jsonfile="$1"     # ← Full path to the json-file to write to
        local jsonpath="$2"     # ← The 'route' inside the json structure
        local entrykey="$3"     # ← The 'key' whose value should be written
        local entryval="$4"     # ← The new value to write
        local jsontype="$5"     # ← The value type: 'string' | 'bool' | 'int'

        # ---------------------------------------------------------------------------
        # [1] Validate: ensure all mandatory parameters are present
        # ---------------------------------------------------------------------------
        if [ -z "${jsonfile}" ] || [ -z "${jsonpath}" ] || [ -z "${entrykey}" ] || [ -z "${entryval}" ] || [ -z "${jsontype}" ]; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#At least one mandatory param is missing!"
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [2] Validate: ensure jsontype is one of the allowed values
        # ---------------------------------------------------------------------------
        if [[ "$jsontype" != "string" && "$jsontype" != "bool" && "$jsontype" != "int" ]]; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Invalid type '${jsontype}'! Allowed types: 'string', 'bool', 'int'."
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [3] Validate: ensure the given JSON file actually exists
        # ---------------------------------------------------------------------------
        if [ "$(FileLookup "${jsonfile}")" != "ok" ]; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Failed to access JSON file! File not found!"
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [4] Validate: ensure the given key exists at the given path in the JSON file.
        #     Both stdout and stderr are suppressed to prevent uncontrolled output
        #     outside of this function's error protocol. [FIX: Problem 1]
        # ---------------------------------------------------------------------------
        if ! jq -e --arg key "$entrykey" "${jsonpath} | has(\$key)" "$jsonfile" >/dev/null 2>&1; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Failed to write to JSON file! Key '${entrykey}' doesn't exist at path '${jsonpath}'!"
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [5] Build the correct jq filter expression based on the specified type.
        #     [FIX: Problem 2]
        #       - 'string' → --arg        → value is always treated as a JSON string
        #       - 'bool'   → --argjson    → value is parsed as a raw JSON boolean
        #       - 'int'    → --argjson    → value is parsed as a raw JSON number
        # ---------------------------------------------------------------------------
        local jq_filter=""
        local jq_arg_flag=""

        case "$jsontype" in
            string)
                # --arg passes the value as a JSON string (e.g. "hello")
                jq_arg_flag="--arg"
                ;;
            bool|int)
                # --argjson passes the value as raw JSON (e.g. true, false, 42)
                # Validate bool values explicitly to give a clear error message
                if [ "$jsontype" = "bool" ] && [[ "$entryval" != "true" && "$entryval" != "false" ]]; then
                    echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Invalid boolean value '${entryval}'! Allowed values: 'true', 'false'."
                    return 1
                fi
                # Validate int values: must be a valid integer (positive, negative, or zero)
                if [ "$jsontype" = "int" ] && ! [[ "$entryval" =~ ^-?[0-9]+$ ]]; then
                    echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Invalid integer value '${entryval}'! Value must be a whole number."
                    return 1
                fi
                jq_arg_flag="--argjson"
                ;;
        esac

        jq_filter="${jsonpath}[\$key] = \$val"

        # ---------------------------------------------------------------------------
        # [6] Write the new value to a temporary file using jq.
        #     stderr is fully suppressed; the exit code is evaluated explicitly.
        #     If jq fails (non-zero exit), the .tmp file is cleaned up immediately.
        #     [FIX: Problem 3 + Problem 4]
        # ---------------------------------------------------------------------------
        if ! jq "$jq_arg_flag" key "$entrykey" "$jq_arg_flag" val "$entryval" \
                "$jq_filter" "$jsonfile" \
                > "$jsonfile.tmp" 2>/dev/null; then
            rm -f "$jsonfile.tmp"
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#jq failed to process JSON! Write operation aborted (jq exit code: $?)."
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [7] Validate: ensure the .tmp output file contains valid JSON.
        #     'jq empty' parses the file and exits 0 only if it is valid JSON.
        #     [FIX: Problem 5 — Part 1: Output validation]
        # ---------------------------------------------------------------------------
        if ! jq empty "$jsonfile.tmp" 2>/dev/null; then
            rm -f "$jsonfile.tmp"
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#jq output is not valid JSON! Write operation aborted."
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [8] Atomically replace the original JSON file with the validated .tmp file.
        #     If 'mv' fails (e.g. due to permissions), the .tmp file is cleaned up.
        #     [FIX: Problem 4 — exit-code evaluation on mv]
        # ---------------------------------------------------------------------------
        if ! mv "$jsonfile.tmp" "$jsonfile"; then
            rm -f "$jsonfile.tmp"
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Failed to replace JSON file! 'mv' operation failed."
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [9] Read-after-write verification: re-read the written value from the file
        #     and compare it to the intended value to confirm the write succeeded.
        #     [FIX: Problem 5 — Part 2: Read-after-write verify]
        # ---------------------------------------------------------------------------
        local written_val
        written_val="$(jq -r --arg key "$entrykey" "${jsonpath}[\$key]" "$jsonfile" 2>/dev/null)"

        if [ "$written_val" != "$entryval" ]; then
            echo "xx#✗ Fatal error in function:  ${FUNCNAME}#Write verification failed! Written value '${written_val}' does not match expected value '${entryval}'."
            return 1
        fi

        # ---------------------------------------------------------------------------
        # [10] All checks passed — report success to the caller
        # ---------------------------------------------------------------------------
        echo "ok"
        return 0
    }


    # DockBayCore Dispatcher
    # ----------------------------------------------------------------------

    case "$fxID" in
        jsonGet)
            jsonGet "$@"
            ;;
        jsonSet)
            jsonSet "$@"
            ;;
        *)
            echo "Error: Unknown function ID '$fID'"
            echo "Available fIDs: jsonRead, checkPackage, printHeader"
            return 1
            ;;
    esac
}


# ____________________________________________________________________________________________________
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

# Class for Docker-Based functions such as CheckContainer() , ContainerStatus() etc.
DockerClassLib() {
    # Entrypoint for DockerClassLib
    # ----------------------------------------------------------------------
    local fxID="$1" # ← Param contains the function ID (mandatory)
    shift 1   # remove fxID, pass the rest to helper functions

    # ... to be continued ...
}