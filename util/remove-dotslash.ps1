<#
	.SYNOPSIS
        Remove-Dotslash removes a leading ".\" sequence from a relative path.
	.PARAMETER path
        Input path.
#>

# Parameter definition
param (
	[string] $path
)

if (($path.SubString(0, 1) -eq '.') -and ($path.SubString(1, 1) -eq '\')) {
	return $path.SubString(2)
}

return $path
