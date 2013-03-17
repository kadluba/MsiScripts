<#
	.SYNOPSIS
        Check-Msicondition checks if a given msi conditional expression is 
		always true or always false.
	.PARAMETER condition
        Name of the Custom Action to search for.
#>

param(
	[string] $condition
)

# Return: 
# 0 - condition always false
# 1 - condition result unknown
# 2 - condition always true
#
# Conditional Statement Syntax: 
# http://msdn.microsoft.com/en-us/library/windows/desktop/aa368012(v=vs.85).aspx

if ("$condition" -eq "") {
	return 2
}

if ("$condition" -match "^[1-9]$") {
	return 2
}

if ("$condition" -eq "0") {
	return 0
}

if ("$condition" -match "[^0-9a-z]or 1$") {
	return 2
}

if ("$condition" -match "[^0-9a-z]and 0$") {
	return 0
}

return 1
