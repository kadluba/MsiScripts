<#
	.SYNOPSIS
        Filter-Rows returns the rows that have a value specified by $filter
		in column $column. The rows are returned in an array of objects 
		as returned by import-csv.
	.PARAMETER tableName
        Name and path of the extraced table file in IDT format.
	.PARAMETER column
        Column to check.
	.PARAMETER filter
        Value to search for.
#>

# Parameter definition
param (
	[string] $tableFile,
	[string] $column,
	[string] $filter
)

[array] $result = @()


if (!(test-path "$tableFile" -pathtype leaf)) {
	return $result
}
$table = import-csv -Delimiter `t "$tableFile"
if ($? -eq $false) {
	return $result
}

foreach ($row in $table) 
{
	$field = ($row.$column)
	if ($field -eq $filter) {
		$result += $row
	}
}

return $result
