<#
    .SYNOPSIS
        Fuzz-Msi flips random bits in a given MSI file. Then tries to 
        install it and log result. This is repeated until interrupted 
        by the user.
    .PARAMETER msi
        Name and path of the MSI file to fuzz. Defaults to WixLanguage.msi.
    .PARAMETER mode
        Mode to use for selecting the bits to flip in the MSI file.
		  1 - try random bits in file (default)
		  2 - try all bits within file squentially
    .PARAMETER startByte
		First byte of the fuzzing range (inclusive, 0-based). Defaults to 0 if ommited.
    .PARAMETER numBytes
		Length of the fuzzing range starting from $startByte. Defaults to file-size - $startByte if ommited.
    .PARAMETER noInstallLogs
        Do not write Windows Installer log files.
#>

# Parameter definition
param (
    [string] $msi, 
    [int] $mode = 1,
    [int] $startByte = 0,
    [int] $numBytes = 0,
    [switch] $noInstallerLogs
)

# Variables
$g_utilDir = "..\util"
$g_logDir = ""  # Later set to ${msi}-logs\
$g_log = ""     # Later set to ${msi}.csv


# Initial checks and preparation
$msi = & "$g_utilDir\remove-dotslash" "$msi"
$msiBackup = $msi + ".bak"
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
		[Security.Principal.WindowsBuiltInRole] "Administrator")) {
    write-error "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    break
}
if (!(test-path .\msizap.exe -pathtype leaf)) {
    write-error "MsiZap.exe does not exist in current directory"
    break
}
if (($mode -ne 1) -and ($mode -ne 2)) {
    write-error "Invalid mode parameter $mode"
    break
}
if (!(test-path $msi -pathtype leaf)) {
    write-error "File $msi does not exist"
    break
}

[int] $msiFileSize = (get-item $msi).length
$maxStartByte = $msiFileSize - 1
if (($startByte -lt 0) -or ($startByte -ge $msiFileSize)) {
    write-error "Parameter startByte must be from 0 to $maxStartByte (MSI size - 1)"
    break
}
$maxNumBytes = $msiFileSize - $startByte
if ($numBytes -eq 0) {
	$numBytes = $maxNumBytes
}
[int] $endByte = $startByte + ($numBytes - 1)
if (($numBytes -lt 1) -or ($endByte -gt $msiFileSize)) {
    write-error "Parameter numBytes must be from 1 to $maxNumBytes"
    break
}

if (test-path $msiBackup) {
    write-error "Backup file $msiBackup already exists"
    break
}
copy-item $msi $msiBackup
if (!(test-path $msiBackup)) {
    write-error "Could not copy $msi to $msiBackup"
    break
}
$g_log = "${msi}.csv"
if (!(test-path $g_log)) {
    # Create log with header if it does not exist
    write "Time, Changed Byte Offset, Changed Bit Offset, Original Byte Value, Changed Byte Value, Result Code, MSI Log" > $g_log
}
$g_logDir = "${msi}-logs\"
if (($noInstallerLogs -ne $true) -and !(test-path "$g_logDir" -pathtype container)) {
    # Create log dir if it does not exist
    mkdir "$g_logDir" > $null
}

# Main part, fuzz and install
$rand = new-object System.Random
[int] $patchByte = $startByte
[int] $patchBit = 0

write-host "Starting fuzzer loop with byte range $startByte to $endByte"

while (!(($mode -eq 2) -and ($patchByte -gt $endByte))) {
    copy-item $msiBackup $msi -force
	if ($? -eq $false) {
		write-error "Could restore MSI $msi from backup copy $msiBackup"
		exit 1
	}
    
	if ($mode -eq 1) {
		# Mode 1: Flip a random bit in the MSI file
		$patchByte = $rand.Next($startByte, $endByte + 1)
		$patchBit = $rand.Next(0, 8)
	}

	$flipBitInfo = & "$g_utilDir\flip-bit" -file $msi -byteOffset $patchByte -bitOffSet $patchBit
    if ($flipBitInfo[0] -ne 0) {
        write-error "flip-bit.ps1 with file $msi byte $patchByte and bit $patchBit failed."
		exit 1
	}

	# Install
    $date = (get-date -uformat "%Y-%m-%dT%H-%M-%S")
	$randTag = $rand.Next(0, 10000)
	if ($noInstallerLogs -eq $true) {
		$installResult = & "$g_utilDir\install-msi" -msi "$msi" -action 0 -wait $true
		# Avoid disk full condition if MSI log is written by default to temp dir
		rm "${env:temp}\msi*.log"
	} else {
		$installLog = $msi + "_" + $date + "." + $randTag + ".log"
		$installResult = & "$g_utilDir\install-msi" -msi "$msi" -action 0 -wait $true -log "$g_logDir$installLog"
	}

	# Uninstall again if installed successfully
	if ($installResult -eq 0) {
		if ($noInstallerLogs -eq $true) {
			$uninstallResult = & "$g_utilDir\install-msi" -msi "$msi" -action 1 -wait $true
		} else {
			$uninstallLog = $msi + "_" + $date + "." + $randTag + "_x.log"
			$uninstallResult = & "$g_utilDir\install-msi" -msi "$msi" -action 1 -wait $true -log "$g_logDir$uninstallLog"
		}
		if ($uninstallResult -ne 0) {
			# Set installresult to -100
			$installResult = -100
		
			write-warning "Could not uninstall MSI anymore. Forcefully removing it with MsiZap."
			stop-service msiserver
			start-service msiserver
			.\msizap.exe tw! "$msi"
			# Ignore msizap return code, it always returned 1
			# if ($? -eq $false) {
			# 	write-error "MsiZap returned error $lastexitcode"
			#	exit 1
			# }
		}
	}

	# Log result
	write-host "Byte: $patchByte, Bit: $patchBit, Value: $($flipBitInfo[1]), Flipped: $($flipBitInfo[2]), MSI Return: $installResult"
	if ($noInstallerLogs -eq $true) {
		write "$date, $patchByte, $patchBit, $($flipBitInfo[1]), $($flipBitInfo[2]), $installResult" >> $g_log
	} else {
		write "$date, $patchByte, $patchBit, $($flipBitInfo[1]), $($flipBitInfo[2]), $installResult, $g_logDir$installLog" >> $g_log
	}
	if ($? -eq $false) {
		write-error "Could not write log entry to $g_log"
		exit 1
	}


	# Next round
	if ($mode -eq 2) {
		# Mode 2: Increment bit to flip in the MSI file
		$patchBit++
		if ($patchBit -eq 8) {
			$patchBit = 0
			$patchByte++
		}
	}
}

write-host "Fuzzer loop ended"

