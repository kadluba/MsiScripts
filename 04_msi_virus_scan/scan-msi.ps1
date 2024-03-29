<#
	.SYNOPSIS
        Scan-Msi scans the program files and binary table elements contained 
		in an MSI file for viruses. This tool helps to assess the risk of 
		installing downloaded MSI files.
	.PARAMETER msi
        Name and path of the MSI file to scan.
	.PARAMETER scanEngine
		Virus scan engine to use for scanning.
		 * "mse" - scan with Microsoft Security Essentials (default)
		 * other - scan with AVG
	.PARAMETER treatAsBinary
        If this parameter is set the specified file is scanned as a whole 
		instead of extracting its MSI contents.
#>

# Parameter definition
param (
	[string] $msi, 
	[string] $scanEngine = "mse", 
    [switch] $treatAsBinary
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
write-host "==== BEGIN ================================================="
if ("$msi" -eq "") {
	write-host "No file specified."
	break
} else {
	$msi = & "$g_utilDir\remove-dotslash" "$msi"
	if (!(test-path "$msi" -pathtype leaf)) {
		write-error "File $msi does not exist"
		break
	}
	write-host "FILE: $msi"
	if ($treatAsBinary -ne $true) {
		write-host "---- Extracting contents of MSI file -----------------------"
		$resExtract = & "$g_utilDir\extract-msi" -msi "$msi" -tablesDir "$g_tablesDir" -cabsDir "$g_cabsDir"
		write-host "------------------------------------------------------------"
	} else {
		write-host "Scanning unextracted file directly"
	}
}

$resScan = 0
if ($treatAsBinary -ne $true) {
	write-host "---- AV-scanning media files and binary table contents -----"
	$resScan = .\scan-binaries -tablesDir "$g_tablesDir" -cabsDir "$g_cabsDir" -scanEngine "$scanEngine"
	write-host "------------------------------------------------------------"
} else {
	write-host "---- AV-scanning single binary file ------------------------"
	$resScan = .\scan-binaries -binary "$msi" -scanEngine "$scanEngine"
	write-host "------------------------------------------------------------"
}

write-host "RESULT: $resScan"
$resScan
write-host "==== END ==================================================="
