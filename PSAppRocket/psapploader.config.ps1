<#
.SYNOPSIS
    psapploader.config.ps1 - configuration file for psapprocket.ps1
.DESCRIPTION
    This script is rather a configuration file than a real ppowershell script.
    It will be dotsourced by psapprocket.ps1 to load its configuration.
.EXAMPLE
    Due to the fact, that this is a configuration file, there is no real example for it.
.NOTES
    Following informations are for psapploader.config.ps1
    VERSION:            1.00.00
    WRITTEN BY:         Praetoriani
    DATE CERATED:       11.04.2026
    LAST UPDATE:        11.04.2026
#>

# STEP 01:
# Let's create an array, that will store all the informations needed to execute a program
# ----------------------------------------------------------------------------------------------------
[Array] $AppLoader = @()

<#
STEP 02:
Time to add some programs to the $AppLoader array.
Each program will be added as a string in the following format:

[PROGRAM_NAME;PATH_TO_EXECUTABLE;RUN_AS;WINDOW_STYLE;WAIT_SECS_AFTER_EXEC]

PROGRAM_NAME            THE NAME OF THE PROGRAM (MUST BE UNIQUE!!!)
PATH_TO_EXECUTABLE      THE FULL PATH TO THE EXECUTABLE (MUST EXIST!!!)
RUN_AS                  RUNS THE PROGRAM AS THE CURRENT USER (AsUser) OR AS ADMINISTRATOR (AsAdmin)
WINDOW_STYLE            NORMAL, HIDDEN, MINIMIZED, MAXIMIZED
WAIT_MILLISECS          THE NUMBER OF MILLISECONDS TO WAIT AFTER EXECUTING THE PROGRAM (in 100-STEP INCREMENTS, 0 TO NOT WAIT AT ALL)

#>

$AppLoader.Add("[`
                Notepad;`
                C:\Program Files\WindowsApps\Microsoft.WindowsNotepad_11.2512.26.0_x64__8wekyb3d8bbwe\Notepad\Notepad.exe;`
                AsUser,`
                Normal,`
                0`
                ]")