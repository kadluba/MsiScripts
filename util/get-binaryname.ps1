<#
	.SYNOPSIS
        Get-Binaryname Gets the name of a Binary table entry corresponding to a 
		given extracted Binary table file (.idb)
	.PARAMETER fileName
        Name of the Binary table extracted file to search for (e.g. myca.idb).
	.PARAMETER tablesDir
        Directory with the extracted MSI tables in IDT format as created by msidb.exe.
#>

param(
	[string] $fileName, 
	[string] $tablesDir = "msi-tables"
)

# Variables
$g_utilDir = "..\util"
$g_tablesDir = "$tablesDir"

[array] $binaryRows = & "$g_utilDir\filter-rows" "$g_tablesDir\Binary.idt" "Data" "$fileName"
[string] $name = ""

if ($binaryRows.Count -gt 0) {
	$column = "Name"
	$name = $binaryRows[0].$column
}

return $name
