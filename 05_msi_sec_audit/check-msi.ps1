<#
	.SYNOPSIS
        Check-Msi checks an MSI file for installation options and custom actions that 
		could pose a security risk. This tool helps to assess the risk of installing 
		downloaded MSI files.
	.PARAMETER msi
        Name and path of the MSI file to check.
#>

# Parameter definition
param (
	[string] $msi
)

# Variables
$g_utilDir = "..\util"
$g_logDir = "logs"
$g_tablesDir = "msi-tables"
$g_cabsDir = "msi-cabs"

# Initial checks and preparation
if (!(test-path "$g_utilDir" -pathtype container)) {
    write-error "Util dir $g_utilDir not found!"
    break
}
if (test-path "$g_logDir" -pathtype container) {
    rm "$g_logDir" -force -recurse
}
mkdir "$g_logDir" > $null

# Main part
if ("$msi" -eq "") {
	write-host "No MSI file specified. Using existing tables and cabs directories."
} else {
	$msi = & "$g_utilDir\remove-dotslash" "$msi"
	if (!(test-path "$msi" -pathtype leaf)) {
		write-error "MSI file $msi does not exist"
		break
	}
	write-host "---- Extracting contents of MSI file -----------------------"
	& "$g_utilDir\extract-msi" -msi "$msi" -tablesDir "$g_tablesDir" -cabsDir "$g_cabsDir"
	write-host "------------------------------------------------------------"
}

write-host "---- Checking package for insecure authoring ---------------"
.\check-tables -msi "$msi" -tablesDir "$g_tablesDir"
write-host "------------------------------------------------------------"

