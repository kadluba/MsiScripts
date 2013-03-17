<#
	.SYNOPSIS
        Append-Workdir adds current directory to begin of given relative path.
	.PARAMETER path
        Input path.
#>

# Parameter definition
param (
	[string] $path
)

# Variables
$g_utilDir = "..\util"

if (($path.SubString(1, 1) -ne ':') -and (($path.SubString(0, 1) -ne '\') -and ($path.SubString(1, 1) -ne '\'))) {
    $absPath = ""
    $absPath += get-location
    $absPath += '\'
    $absPath += $path
	$path = $absPath
}

return $path
