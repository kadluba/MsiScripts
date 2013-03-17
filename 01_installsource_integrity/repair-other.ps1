<#
	.SYNOPSIS
        Repair-Other installs Setup.msi, then deletes the cached MSI from 
		C:\Windows\Installer and attempts a repair install with a slightly 
		different version of Setup.msi where only an installed file is changed.
		This attempts to test if the installer checks a hash of the MSI at 
		INSTALLLSOURCE against a stored hash of the originally installed MSI
		to protect against malicious repairs.
#>

# Variables
$utilDir = "..\util"
$msiCachePath = "C:\Windows\Installer\"
$msiCachePattern = "${msiCachePath}*.msi"
$programDir = "C:\Program Files\SmallChange"
$programFile = "App.exe"
$origMsi = "SmallChange\Setup\bin\Debug\Setupv1.msi"
$alteredMsi = "SmallChange\Setup\bin\Debug\Setupv2.msi"
$installMsi = "Setup.msi"
$prodCode = "{C5EC18CD-2836-4126-BEBC-5B26F0036728}"

# Main part
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
		[Security.Principal.WindowsBuiltInRole] "Administrator")) {
    write-error "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    break
}
if (!(test-path "$origMsi")) {
    write-error "Original MSI $origMsi not found!"
    break
}
if (!(test-path "$alteredMsi")) {
    write-error "Original MSI $alteredMsi not found!"
    break
}

# Cleanup
write-host "### Cleanup"
& "$utilDir\install-msi" -msi "$origMsi" -action 1 -wait $true
& "$utilDir\install-msi" -msi "$alteredMsi" -action 1 -wait $true


# Install original MSI
write-host "### Installing $origMsi"
cp "$origMsi" "$installMsi"
& "$utilDir\install-msi" -msi "$installMsi" -action 0 -wait $true -log "${origMsi}-i.log"
if ($? -ne $true) {
	break
}
mv "${origMsi}-i.log" . -force
cp "${programDir}\${programFile}" "orig-${programFile}"

# Remove original cached MSI file
write-host "### Remove original cached MSI package"
[array] $cachedMsiFiles = get-childitem "$msiCachePattern" | sort-object -property CreationTime -descending
if (($cachedMsiFiles -eq $null) -or ($cachedMsiFiles.length -eq 0)) {
	write-error "Could not find original cached MSI file!"
	break
}
$cachedMsiFile = $cachedMsiFiles[0]
write-host "Found original cached MSI package $cachedMsiFile"
mv "$cachedMsiFile" "orig-cached.msi"
if ($? -ne $true) {
	break
}
write-host "Removed cached file"



# Install altered MSI
write-host "### Repairing installation with $alteredMsi"
cp "$alteredMsi" "$installMsi" -force
$result = & "$utilDir\install-msi" -prodCode "$prodCode" -action 3 -wait $true -log "${alteredMsi}-fvamus.log"
#$result = & "$utilDir\install-msi" -msi "$installMsi" -action 3 -wait $true -log "${alteredMsi}-fvamus.log"
mv "${alteredMsi}-fvamus.log" . -force
cp "${programDir}\${programFile}" "new-${programFile}"
write-host "Result: $result"

# Copy new cached MSI file
write-host "### Copy new cached MSI package"
[array] $cachedMsiFiles = get-childitem "$msiCachePattern" | sort-object -property CreationTime -descending
if (($cachedMsiFiles -eq $null) -or ($cachedMsiFiles.length -eq 0)) {
	write-error "Could not find new cached MSI file!"
	break
}
$cachedMsiFile = $cachedMsiFiles[0]
write-host "Found new cached MSI package $cachedMsiFile"
cp "$cachedMsiFile" "new-cached.msi"
if ($? -ne $true) {
	break
}
write-host "Removed cached file"
