<#
.SYNOPSIS
    Active Directory Benutzer Export mit WPF-Authentifizierung
.DESCRIPTION
    PowerShell Applikation zum Export von Active Directory Benutzerdaten mit moderner WPF-Benutzeroberfläche.
    Das Skript verwendet externe XAML-Dateien für alle Dialoge und bietet umfassende Fehlerbehandlung.
.NOTES
    Creation Date:  21.09.2025
    Version:        1.00.00
    Author:         Praetoriani
    Website:        https://github.com/praetoriani
#>

# Requires ActiveDirectory module
#Requires -Module ActiveDirectory

# Global application variables as per application rules
$global:AppName = "AD UserData LDAP Export"
$global:AppVers = "1.00.00"
$global:AppPath = $PSScriptRoot
$global:AppIcon = Join-Path $AppPath "appicon.ico"

# Global configuration variables for AD export
$global:ExportScope = "DC=domain,DC=com"  # Define your OU scope here (will be exported recursively)
$global:ExportAttributes = @(
    'SamAccountName',
    'UserPrincipalName', 
    'GivenName',
    'Surname',
    'DisplayName',
    'EmailAddress',
    'Mail',
    'Title',
    'Department',
    'Company',
    'Manager',
    'EmployeeID',
    'Office',
    'TelephoneNumber',
    'Mobile',
    'StreetAddress',
    'City',
    'PostalCode',
    'Country',
    'Enabled',
    'LastLogonDate',
    'Created',
    'DistinguishedName'
)

# Global XAML file paths - all XAML files must be in the same directory as script
$global:XamlAuthDialog = Join-Path $AppPath "user-authentication.xaml"
$global:XamlNoInput = Join-Path $AppPath "error-no-input.xaml"
$global:XamlUserInvalid = Join-Path $AppPath "error-user-invalid.xaml"
$global:XamlLdapAccess = Join-Path $AppPath "error-ldap-access.xaml"
$global:XamlCsvExport = Join-Path $AppPath "error-csv-export.xaml"
$global:XamlFinished = Join-Path $AppPath "script-finished.xaml"

# Global variables for credential handling
$global:UserCredentials = $null
$global:DialogResult = $false
$global:AuthWindowClosedByUser = $false

# Required assemblies for WPF functionality
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Minimize console window at startup
Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class WindowAPI {
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
        public const int SW_MINIMIZE = 6;
        public const int SW_RESTORE = 9;
    }
"@

# Minimize console window
$consoleWindow = [WindowAPI]::GetConsoleWindow()
if ($consoleWindow -ne [IntPtr]::Zero) {
    [WindowAPI]::ShowWindow($consoleWindow, [WindowAPI]::SW_MINIMIZE) | Out-Null
}

#region Logging Functions

function Write-EngLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

#endregion

#region XAML Helper Functions

function Test-XamlFile {
    param([string]$XamlPath)

    if (-not (Test-Path $XamlPath)) {
        Write-EngLog "XAML file not found: $XamlPath" -Level "ERROR"
        return $false
    }

    try {
        $xamlContent = Get-Content $XamlPath -Raw -Encoding UTF8
        [xml]$xamlContent | Out-Null
        return $true
    } catch {
        Write-EngLog "Invalid XAML format in file: $XamlPath - $_" -Level "ERROR"
        return $false
    }
}

function Show-XamlDialog {
    param(
        [string]$XamlPath,
        [hashtable]$Resources = @{},
        [string]$DefaultResult = $null,
        [switch]$IsErrorDialog = $false
    )
    Write-EngLog "Loading XAML dialog: $XamlPath"

    # Validate XAML file exists and is valid
    if (-not (Test-XamlFile -XamlPath $XamlPath)) {
        Write-EngLog "Failed to validate XAML file: $XamlPath" -Level "ERROR"
        return $null
    }

    try {
        # Load XAML content with proper encoding
        $xamlContent = Get-Content $XamlPath -Raw -Encoding UTF8

        # Parse XAML and create window
        $reader = [System.Xml.XmlNodeReader]::new([xml]$xamlContent)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        # Set dynamic resources if provided
        foreach ($key in $Resources.Keys) {
            $window.Resources.Add($key, $Resources[$key])
        }

        # Set window properties for proper display
        $window.WindowStartupLocation = "CenterScreen"
        $window.Topmost = $true

        # Add close event handler to terminate application if user closes with X button
        # Add close event handler - simplified for error dialogs
        $window.Add_Closing({
            param($sender, $e)
            if ($IsErrorDialog) {
                # For error dialogs: just close the dialog, don't exit application
                Write-EngLog "Error dialog closed by user"
            }
            # For main dialogs: let the calling function handle the logic
        })

        Write-EngLog "XAML dialog loaded successfully"
        return $window

    } catch {
        Write-EngLog "Error loading XAML dialog: $_" -Level "ERROR"
        return $null
    }
}

#endregion

#region Authentication Functions

function Show-AuthenticationDialog {
    Write-EngLog "Starting authentication dialog"
    
    # Loop until valid credentials or cancel
    do {
        $global:DialogResult = $false
        $global:AuthWindowClosedByUser = $false  # Reset flag
        
        # Load authentication dialog
        $authWindow = Show-XamlDialog -XamlPath $global:XamlAuthDialog -Resources @{
            "WindowTitle" = "Active Directory Anmeldung"
            "DialogMessage" = "Geben Sie Ihre Active Directory Anmeldedaten ein:"
        }
        
        if (-not $authWindow) {
            Write-EngLog "Failed to load authentication dialog" -Level "ERROR"
            return $false
        }
        
        # Get UI elements from XAML
        $txtUsername = $authWindow.FindName("txtUsername")
        $txtPassword = $authWindow.FindName("txtPassword")
        $btnOK = $authWindow.FindName("btnOK")
        $btnCancel = $authWindow.FindName("btnCancel")
        
        # Verify all required elements exist
        if (-not $txtUsername -or -not $txtPassword -or -not $btnOK -or -not $btnCancel) {
            Write-EngLog "Required UI elements not found in authentication XAML" -Level "ERROR"
            $authWindow.Close()
            return $false
        }
        
        # Set focus to username field
        $txtUsername.Focus()
        
        # OK button click handler
        $btnOK.Add_Click({
            Write-EngLog "OK button clicked in authentication dialog"
            
            $username = $txtUsername.Text.Trim()
            $password = $txtPassword.SecurePassword
            
            # Check if both fields contain input
            if ([string]::IsNullOrWhiteSpace($username) -or $password.Length -eq 0) {
                Write-EngLog "Empty username or password detected" -Level "WARNING"
                
                # Show error dialog and return to input (don't close auth dialog)
                Show-ErrorNoInput
                
                # Clear password field for security
                $txtPassword.Clear()
                $txtUsername.Focus()
                return
            }
            
            # Create PSCredential object
            try {
                $global:UserCredentials = New-Object System.Management.Automation.PSCredential($username, $password)
                Write-EngLog "Credentials created successfully for user: $username"
                
                # Validate credentials against Active Directory
                if (Test-ADCredentials -Credential $global:UserCredentials) {
                    Write-EngLog "AD credentials validated successfully" -Level "SUCCESS"
                    $global:DialogResult = $true
                    $global:AuthWindowClosedByUser = $true  # Mark as intentional close
                    $authWindow.Close()
                } else {
                    Write-EngLog "AD credential validation failed" -Level "ERROR"
                    
                    # Mark as intentional close and exit program
                    $global:AuthWindowClosedByUser = $true
                    $authWindow.Close()
                    Show-ErrorUserInvalid
                }
                
            } catch {
                Write-EngLog "Error creating credentials: $_" -Level "ERROR"
                
                # Mark as intentional close and exit program
                $global:AuthWindowClosedByUser = $true
                $authWindow.Close()
                Show-ErrorUserInvalid
            }
        })
        
        # Cancel button click handler
        $btnCancel.Add_Click({
            Write-EngLog "Cancel button clicked - terminating application" -Level "WARNING"
            [Environment]::Exit(0)
        })
        
        # Enter key handler for password field
        $txtPassword.Add_KeyDown({
            if ($_.Key -eq [System.Windows.Input.Key]::Enter) {
                Write-EngLog "Enter key pressed in password field"
                $btnOK.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
            }
        })
        
        # Show dialog modally
        Write-EngLog "Displaying authentication dialog"
        $authWindow.ShowDialog() | Out-Null
        
        # Check if user closed window with X button (unintentional close)
        if (-not $global:AuthWindowClosedByUser) {
            Write-EngLog "User closed authentication dialog with X button - terminating application" -Level "WARNING"
            [Environment]::Exit(0)
        }
        
        # Continue loop if authentication failed (except for invalid user which exits)
        
    } while (-not $global:DialogResult)
    
    return $global:DialogResult
}

function Test-ADCredentials {
    param([System.Management.Automation.PSCredential]$Credential)

    Write-EngLog "Testing AD credentials for user: $($Credential.UserName)"

    try {
        # Use DirectoryServices for credential validation
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $domainName = $domain.Name

        $directoryEntry = New-Object System.DirectoryServices.DirectoryEntry(
            "LDAP://$domainName", 
            $Credential.UserName, 
            $Credential.GetNetworkCredential().Password
        )

        # Test connection by performing a simple search
        $searcher = New-Object System.DirectoryServices.DirectorySearcher($directoryEntry)
        $searcher.Filter = "(objectClass=user)"
        $searcher.PageSize = 1
        $result = $searcher.FindOne()

        Write-EngLog "AD credential validation successful" -Level "SUCCESS"
        return $true

    } catch {
        Write-EngLog "AD credential validation failed: $_" -Level "ERROR"
        return $false
    }
}

#endregion

#region Error Dialog Functions

function Show-ErrorNoInput {
    Write-EngLog "Displaying no input error dialog"

    $errorWindow = Show-XamlDialog -XamlPath $global:XamlNoInput -IsErrorDialog
    if (-not $errorWindow) { return }

    # Find OK button and add click handler
    $btnOK = $errorWindow.FindName("btnOK")
    if ($btnOK) {
        $btnOK.Add_Click({
            Write-EngLog "OK clicked on no input error dialog"
            $errorWindow.Close()
        })
    }

    $errorWindow.ShowDialog() | Out-Null
}

function Show-ErrorUserInvalid {
    Write-EngLog "Displaying invalid user error dialog"

    $errorWindow = Show-XamlDialog -XamlPath $global:XamlUserInvalid -IsErrorDialog
    if (-not $errorWindow) { return }

    # Find Exit button and add click handler
    $btnExit = $errorWindow.FindName("btnExit")
    if ($btnExit) {
        $btnExit.Add_Click({
            Write-EngLog "Exit clicked on invalid user error dialog - terminating application" -Level "WARNING"
            [Environment]::Exit(1)
        })
    }

    $errorWindow.ShowDialog() | Out-Null
}

function Show-ErrorLdapAccess {
    Write-EngLog "Displaying LDAP access error dialog"

    $errorWindow = Show-XamlDialog -XamlPath $global:XamlLdapAccess -IsErrorDialog
    if (-not $errorWindow) { return }

    # Find Exit button and add click handler
    $btnExit = $errorWindow.FindName("btnExit")
    if ($btnExit) {
        $btnExit.Add_Click({
            Write-EngLog "Exit clicked on LDAP access error dialog - terminating application" -Level "ERROR"
            [Environment]::Exit(2)
        })
    }

    $errorWindow.ShowDialog() | Out-Null
}

function Show-ErrorCsvExport {
    Write-EngLog "Displaying CSV export error dialog"

    $errorWindow = Show-XamlDialog -XamlPath $global:XamlCsvExport -IsErrorDialog
    if (-not $errorWindow) { return }

    # Find Exit button and add click handler
    $btnExit = $errorWindow.FindName("btnExit")
    if ($btnExit) {
        $btnExit.Add_Click({
            Write-EngLog "Exit clicked on CSV export error dialog - terminating application" -Level "ERROR"
            [Environment]::Exit(3)
        })
    }

    $errorWindow.ShowDialog() | Out-Null
}

function Show-ScriptFinished {
    Write-EngLog "Displaying script finished dialog"

    $finishedWindow = Show-XamlDialog -XamlPath $global:XamlFinished -IsErrorDialog
    if (-not $finishedWindow) { return }

    # Find OK button and add click handler
    $btnOK = $finishedWindow.FindName("btnOK")
    if ($btnOK) {
        $btnOK.Add_Click({
            Write-EngLog "OK clicked on script finished dialog"
            $finishedWindow.Close()
        })
    }

    $finishedWindow.ShowDialog() | Out-Null
}

#endregion

#region Active Directory Functions

function Test-ADScope {
    param(
        [string]$SearchBase,
        [System.Management.Automation.PSCredential]$Credential
    )

    Write-EngLog "Testing AD scope access: $SearchBase"

    try {
        # Try to access the specified OU/scope
        $testParams = @{
            SearchBase = $SearchBase
            SearchScope = "Base"
            Filter = "*"
            Credential = $Credential
            ErrorAction = "Stop"
        }

        Get-ADObject @testParams | Out-Null
        Write-EngLog "AD scope access successful" -Level "SUCCESS"
        return $true

    } catch {
        Write-EngLog "AD scope access failed: $_" -Level "ERROR"
        return $false
    }
}

function Export-ADUserData {
    param(
        [string]$SearchBase,
        [array]$Properties,
        [System.Management.Automation.PSCredential]$Credential
    )

    Write-EngLog "Starting AD user data export from scope: $SearchBase"
    Write-EngLog "Exporting $($Properties.Count) user attributes"

    try {
        # Get all users from specified scope (recursive)
        $adUsers = Get-ADUser -SearchBase $SearchBase -SearchScope Subtree -Filter * -Properties $Properties -Credential $Credential

        Write-EngLog "Found $($adUsers.Count) users in AD scope" -Level "SUCCESS"

        if ($adUsers.Count -eq 0) {
            Write-EngLog "No users found in specified scope" -Level "WARNING"
            return @()
        }

        # Prepare export data with German column headers
        $exportData = foreach ($user in $adUsers) {
            [PSCustomObject]@{
                'Anmeldename' = $user.SamAccountName
                'Benutzerprinzipalname' = $user.UserPrincipalName
                'Vorname' = $user.GivenName
                'Nachname' = $user.Surname
                'Anzeigename' = $user.DisplayName
                'E-Mail-Adresse' = if($user.EmailAddress) { $user.EmailAddress } elseif($user.Mail) { $user.Mail } else { "" }
                'Berufsbezeichnung' = $user.Title
                'Abteilung' = $user.Department
                'Unternehmen' = $user.Company
                'Vorgesetzter' = if($user.Manager) { try { (Get-ADUser $user.Manager -Credential $Credential).DisplayName } catch { $user.Manager } } else { "" }
                'Mitarbeiter-ID' = $user.EmployeeID
                'Büro' = $user.Office
                'Telefonnummer' = $user.TelephoneNumber
                'Mobiltelefon' = $user.Mobile
                'Straße' = $user.StreetAddress
                'Ort' = $user.City
                'Postleitzahl' = $user.PostalCode
                'Land' = $user.Country
                'Konto aktiviert' = if($user.Enabled) { "Ja" } else { "Nein" }
                'Letzte Anmeldung' = if($user.LastLogonDate) { $user.LastLogonDate.ToString("dd.MM.yyyy HH:mm") } else { "Nie" }
                'Erstellt am' = if($user.Created) { $user.Created.ToString("dd.MM.yyyy HH:mm") } else { "" }
                'Distinguished Name' = $user.DistinguishedName
            }
        }

        Write-EngLog "User data prepared for export: $($exportData.Count) records" -Level "SUCCESS"
        return $exportData

    } catch {
        Write-EngLog "Error during AD user data export: $_" -Level "ERROR"
        return $null
    }
}

#endregion

#region File Dialog Functions

function Show-SaveCsvDialog {
    Write-EngLog "Opening Save CSV file dialog"

    try {
        # Create SaveFileDialog with CSV filter
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "CSV-Dateien (*.csv)|*.csv"
        $saveDialog.Title = "CSV-Datei speichern"
        $saveDialog.DefaultExt = "csv"
        $saveDialog.FileName = "AD-Benutzer-Export-$(Get-Date -Format 'yyyyMMdd-HHmm')"
        $saveDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

        # Show dialog
        $result = $saveDialog.ShowDialog()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Write-EngLog "User selected file: $($saveDialog.FileName)" -Level "SUCCESS"
            return $saveDialog.FileName
        } else {
            Write-EngLog "User cancelled save dialog" -Level "WARNING"
            return $null
        }

    } catch {
        Write-EngLog "Error in save dialog: $_" -Level "ERROR"
        return $null
    }
}

function Export-ToCsv {
    param(
        [array]$Data,
        [string]$FilePath
    )

    Write-EngLog "Exporting $($Data.Count) records to CSV file: $FilePath"

    try {
        # Export to CSV with proper encoding and delimiter
        $Data | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"

        # Verify file was created
        if (Test-Path $FilePath) {
            $fileInfo = Get-Item $FilePath
            Write-EngLog "CSV export successful - File size: $($fileInfo.Length) bytes" -Level "SUCCESS"
            return $true
        } else {
            Write-EngLog "CSV file was not created" -Level "ERROR"
            return $false
        }

    } catch {
        Write-EngLog "Error during CSV export: $_" -Level "ERROR"
        return $false
    }
}

#endregion

#region Main Application Logic

function Start-Application {
    Write-EngLog "=== Starting $global:AppName v$global:AppVers ===" -Level "SUCCESS"
    Write-EngLog "Application path: $global:AppPath"
    Write-EngLog "Export scope: $global:ExportScope"
    Write-EngLog "Export attributes count: $($global:ExportAttributes.Count)"

    # Check if ActiveDirectory module is available
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-EngLog "ActiveDirectory PowerShell module not available" -Level "ERROR"
        [Environment]::Exit(4)
    }

    # Import ActiveDirectory module
    try {
        Import-Module ActiveDirectory -Force
        Write-EngLog "ActiveDirectory module imported successfully" -Level "SUCCESS"
    } catch {
        Write-EngLog "Failed to import ActiveDirectory module: $_" -Level "ERROR"
        [Environment]::Exit(5)
    }

    # Verify all XAML files exist
    $xamlFiles = @($global:XamlAuthDialog, $global:XamlNoInput, $global:XamlUserInvalid, $global:XamlLdapAccess, $global:XamlCsvExport, $global:XamlFinished)
    foreach ($xamlFile in $xamlFiles) {
        if (-not (Test-Path $xamlFile)) {
            Write-EngLog "Required XAML file missing: $xamlFile" -Level "ERROR"
            [Environment]::Exit(6)
        }
    }
    Write-EngLog "All required XAML files found" -Level "SUCCESS"

    # Step 1: Show authentication dialog
    Write-EngLog "Step 1: Authentication"
    if (-not (Show-AuthenticationDialog)) {
        Write-EngLog "Authentication failed or was cancelled" -Level "ERROR"
        return
    }

    # Step 2: Test AD scope access
    Write-EngLog "Step 2: Testing AD scope access"
    if (-not (Test-ADScope -SearchBase $global:ExportScope -Credential $global:UserCredentials)) {
        Write-EngLog "AD scope access test failed" -Level "ERROR"
        Show-ErrorLdapAccess
        return
    }

    # Step 3: Export AD user data
    Write-EngLog "Step 3: Exporting AD user data"
    $userData = Export-ADUserData -SearchBase $global:ExportScope -Properties $global:ExportAttributes -Credential $global:UserCredentials
    if ($null -eq $userData) {
        Write-EngLog "AD user data export failed" -Level "ERROR"
        Show-ErrorLdapAccess
        return
    }

    # Step 4: Show save dialog and export to CSV
    Write-EngLog "Step 4: CSV export"
    $csvFilePath = Show-SaveCsvDialog
    if ($null -eq $csvFilePath) {
        Write-EngLog "User cancelled CSV save dialog - terminating" -Level "WARNING"
        return
    }

    if (-not (Export-ToCsv -Data $userData -FilePath $csvFilePath)) {
        Write-EngLog "CSV export failed" -Level "ERROR"
        Show-ErrorCsvExport
        return
    }

    # Step 5: Show success message
    Write-EngLog "Step 5: Export completed successfully" -Level "SUCCESS"
    Write-EngLog "Exported $($userData.Count) user records to: $csvFilePath" -Level "SUCCESS"
    Show-ScriptFinished

    Write-EngLog "Application completed successfully" -Level "SUCCESS"
}

#endregion

# Application entry point
try {
    Start-Application
} catch {
    Write-EngLog "Unhandled application error: $_" -Level "ERROR"
    Write-EngLog "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    [Environment]::Exit(99)
}

Write-EngLog "Application terminated normally"
