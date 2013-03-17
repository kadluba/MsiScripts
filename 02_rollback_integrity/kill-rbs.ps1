<#
	.SYNOPSIS
        Kill-Rbs installs and then upgrades the prepared MSI package PauseRollback.msi.
		During upgrade a custom action in the MSI file waits until a file 
		c:\tests\06_rollback_itegrity\PauseRollback.txt exists and triggers a rollback 
		if the files does not contain the text "ok". 
		This script uses this pause to go after the rollback script created as 
		C:\Config.msi\*.rbs. It is shown that this file cannot be removed or manipulated 
		by anoter process while it exists.
#>

# Variables
$utilDir = "..\util"
$rollBackPath = "C:\Config.msi\"
$rbsPattern = "${rollBackPath}*.rbs"
[int] $waitTime = 40

# Main part
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
		[Security.Principal.WindowsBuiltInRole] "Administrator")) {
    write-error "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    break
}

# Cleanup
write-host "### Cleanup"
if (test-path ".\PauseRollback.txt") {
	rm PauseRollback.txt
}
rm *.log
& "$utilDir\install-msi" -msi "PauseRollback\Setup\bin\Debug\Setupv1.msi" -action 1 -wait $true -log "Setupv1-x.log"
& "$utilDir\install-msi" -msi "PauseRollback\Setup\bin\Debug\Setupv2.msi" -action 1 -wait $true -log "Setupv2-x.log"


# Install, then upgrade with pause
write-host "### Installing Setupv1.msi"
& "$utilDir\install-msi" -msi "PauseRollback\Setup\bin\Debug\Setupv1.msi" -action 0 -wait $true -log "Setupv1-i.log"
write-host "### Upgrading to Setupv2.msi"
& "$utilDir\install-msi" -msi "PauseRollback\Setup\bin\Debug\Setupv2.msi" -action 0 -wait $false -log "Setupv2-i.log"

# Wait for rbs file to be created
write-host "### Waiting for rollback script file $rbsPattern to be created: " -nonewline
[int] $count = $waitTime
[string] $rbsFile = ""
while (($count -ne 0) -and ($rbsFile -eq "")) {
	[array] $rbsFiles = get-childitem "$rbsPattern" -erroraction SilentlyContinue
	if (($rbsFiles -ne $null) -and ($rbsFiles.length -ge 1)) {
		$rbsFile = $rbsFiles[0]
		write-host ""
		write-host "Found rollback script file $rbsFile"
		# Make a local backup - for possible further investigations
		cp "$rbsFile" . -force
	} else {
		write-host "." -nonewline
		start-sleep -s 1
		$count--
	}
}
write-host ""

# Try to destroy or manipulate the found rbs
if ($rbsFile -ne "") {
	write-host "--- Trying to change rbs file ---------------------------"
	& "$utilDir\flip-bit" -file $rbsFile -byteOffset 45 -bitOffset 0
	write-host "---------------------------------------------------------"

	write-host "--- Trying to delete rbs file ---------------------------"
	rm "$rbsFile" -force
	write-host "---------------------------------------------------------"

	write-host "--- Trying to rename rbs file ---------------------------"
	mv "$rbsFile" "${rbsFile}.off" -force
	write-host "---------------------------------------------------------"
}

write-host "### Initiating rollback of upgrade to Setupv2.msi"
set-content -value "fail" -path PauseRollback.txt

write-host "### Waiting for rollback script file $rbsPattern to be deleted: " -nonewline
$count = $waitTime
while (($count -ne 0) -and ($rbsFile -ne "")) {
	if (!(test-path "$rbsFile")) {
		write-host ""
		write-host "Rollback script file $rbsFile was deleted"
		$rbsFile = ""
	} else {
		write-host "." -nonewline
		start-sleep -s 1
		$count--
	}
}
write-host ""

