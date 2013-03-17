<#
	.SYNOPSIS
        Tamper-Rbf installs and then upgrades the prepared MSI package PauseRollback.msi.
		During upgrade a custom action in the MSI file waits until a file 
		c:\tests\06_rollback_itegrity\PauseRollback.txt exists and triggers a rollback 
		if the files does not contain the text "ok". 
		This script uses this pause to try to manipulate the backup copies of the old 
		files made by the installer before they get replaced with new versions during the 
		upgrade. It is shown if those files (C:\Config.msi\*.rbf) can be manipulated to 
		get the installer to copy manipulated versions to the system when doing a rollback.
#>

# Variables
$utilDir = "..\util"


# Main part
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
		[Security.Principal.WindowsBuiltInRole] "Administrator")) {
    write-error "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    break
}

# Cleanup
write-host "Cleanup"
if (test-path ".\PauseRollback.txt") {
	rm PauseRollback.txt
}
rm *.log
& "$utilDir\install-msi" -msi "PauseRollback\Setup\bin\Debug\Setupv1.msi" -action 1 -wait $true -log "Setupv1-x.log"
& "$utilDir\install-msi" -msi "PauseRollback\Setup\bin\Debug\Setupv2.msi" -action 1 -wait $true -log "Setupv2-x.log"

write-host "Installing Setupv1.msi"
& "$utilDir\install-msi" -msi "PauseRollback\Setup\bin\Debug\Setupv1.msi" -action 0 -wait $true -log "Setupv1-i.log"
write-host "Upgrading to Setupv2.msi"
& "$utilDir\install-msi" -msi "PauseRollback\Setup\bin\Debug\Setupv2.msi" -action 0 -wait $false -log "Setupv2-i.log"

$rollBackPath = "C:\Config.msi\"
$rbfPattern = "${rollBackPath}*.rbf"
write-host "Manipulating $rbfPattern"
[int] $count = 30
[bool] $done = $false
while (($count -ne 0) -and ($done -eq $false)) {
	write-host "Pass $count of 30"
	if (test-path "$rollBackPath") {
		ls "${rollBackPath}*" -recurse

		# TODO manipulate files in c:\Config.msi\*.rbf
		# For now we just destroy the .rbs file to manipulate the integrity

		[array] $rbsFiles = get-childitem "$rbfPattern"
		if (($rbsFiles -ne $null) -and ($rbsFiles.length -ge 1)) {
			write-host "Found file $rbsFiles"
			& "$utilDir\flip-bit" -file $rbsFiles[0] -byteOffset 45 -bitOffset 0
			if ($? -eq $false) {
				write-host "flip-bit.ps1 with file $rbsFiles[0] byte 45 and bit 0 failed."
			}
			$done = $true
		}
	}

	start-sleep -s 3
	$count--
}

set-content -value "fail" -path PauseRollback.txt
write-host "Initiating rollback"

