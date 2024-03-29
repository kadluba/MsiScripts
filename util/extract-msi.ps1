<#
	.SYNOPSIS
        Extract-Msi extracts the tables, including the binary table, and media 
		contained in an MSI file.
	.PARAMETER msi
        Name and path of the MSI file to check. Defaults to WixLanguage.msi.
	.PARAMETER tablesDir
        Name of the local directory where to extract the table data and 
		binary table files. Directory is overwritten if it exists.
	.PARAMETER cabsDir
        Name of the local directory extract the media files from embedded or
		external cabinet files. Directory is overwritten if it exists.
#>

# Parameter definition
param (
	[string] $msi,
	[string] $tablesDir = "msi-tables",
	[string] $cabsDir = "msi-cabs"
)

# Variables
$g_logDir = "logs"
$g_utilDir = "..\util"


# Initial checks and preparation
$msi = & "$g_utilDir\remove-dotslash" "$msi"
$msi = & "$g_utilDir\append-workdir" "$msi"
$tablesDir = & "$g_utilDir\remove-dotslash" "$tablesDir"
$tablesDir = & "$g_utilDir\append-workdir" "$tablesDir"
$cabsDir = & "$g_utilDir\remove-dotslash" "$cabsDir"
$cabsDir = & "$g_utilDir\append-workdir" "$cabsDir"
if (!(test-path "$g_utilDir\msidb.exe" -pathtype leaf)) {
	write-error "$g_utilDir\msidb.exe not found. Please copy it from Windows Platform SDK."
	break
}
if (!(test-path $msi -pathtype leaf)) {
    write-error "File $msi does not exist"
    break
}
if (!(test-path $g_logDir)) {
    # Create log dir if it does not exist
    mkdir "$g_logDir" > $null
}

# Main part, examine, extract and do AV scan
if (test-path "$tablesDir") {
	rm "$tablesDir" -recurse -force
	sleep 2
}
mkdir "$tablesDir" > $null
sleep 2

if (test-path "$cabsDir") {
	rm "$cabsDir" -recurse -force
	sleep 2
}
mkdir "$cabsDir" > $null
sleep 2

write-host "Extracting tables to $tablesDir"
& "$g_utilDir\run-process" -cmd "$g_utilDir\msidb.exe" -par "-e -f $tablesDir -d $msi *" -wait $true
if ($? -eq $false) {
	write-error "Could not extract tables from $msi"
	break
}

$media = import-csv -Delimiter `t "$tablesDir\Media.idt"
if ($? -eq $false) {
	break
}
[int] $rowNum = 1
foreach ($row in $media)
{
	if ($rowNum -gt 2 -and (($row.Cabinet).CompareTo("") -ne 0))
	{
		$cab = ($row.Cabinet).SubString(1)
		$cabDir = "$cabsDir\$cab"
		write-host "Extracting cabinet: $cab to $cabDir"
		if (test-path "$cab") {
			rm "$cab" -force
		}
		$resMsiDb = & "$g_utilDir\run-process" -cmd "$g_utilDir\msidb.exe" -par "-x $cab -d $msi" -wait $true
		if ($resMsiDb -ne 0) {
			write-error "Could not extract stream $cab from $msi"
			break
		}
		
		if (test-path "$cabDir") {
			rm "$cabDir" -recurse -force
		}
		mkdir "$cabDir" > $null
		$resExpand = & "$g_utilDir\run-process" -cmd "expand" -par "-F:* $cab $cabDir" -wait $true -stdOutFile "$g_logDir\${cab}.expand-stdout.log" -stdErrFile "$g_logDir\${cab}.expand-stderr.log"
		if ($resExpand -ne 0) {
			write-error "Could expand files from $cab"
			break
		}
		rm "$cab" -force
	}
	$rowNum++
}

