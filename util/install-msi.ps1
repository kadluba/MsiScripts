<#
	.SYNOPSIS
        Install-Msi installs or uninstalls an MSI package and waits 
		for it to complete.
	.PARAMETER msi
        Name and path of the MSI file to install or uninstall
	.PARAMETER prodCode
        Product code. Can be specified with action = 1 or 2. Is used if msi is empty
	.PARAMETER action
        Action to perform. 0 = install, 1 = uninstall, 2 = repair
	.PARAMETER wait
        Wait for the installation to complete.
	.PARAMETER log
        Name and path of the installer log file.
#>

# Parameter definition
param (
	[string] $msi, 
	[string] $prodCode, 
	[int] $action, 
	[bool] $wait, 
	[string] $log
)

# Variables
$g_utilDir = "..\util"

# Main part 
$cmd = "msiexec"
if ($action -eq 0) {
	$arguments = "/i $msi /quiet"
} else {
	if ($action -eq 1) {
		$arguments = "/x"
	} else {
		$arguments = "/fvamus"
	}
	if ($msi -ne "") {
		$arguments += " $msi"
	} else {
		$arguments += " $prodCode"
	}
}
$arguments += " /quiet"
if ($log -ne "") {
	$arguments += " /l*vx $log"
}

$result = & "$g_utilDir\run-process" -cmd "$cmd" -par "$arguments" -wait $wait
return $result
