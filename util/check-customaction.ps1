<#
	.SYNOPSIS
        Check-Customaction searches through extracted MSI table filed (.idt) for a 
		given custom action and returns info about that action.
	.PARAMETER caName
        Name of the Custom Action to search for.
	.PARAMETER tablesDir
        Directory with the extracted MSI tables in IDT format as created by msidb.exe.
#>

param(
	[string] $caName, 
	[string] $tablesDir = "msi-tables"
)

# Variables
$g_utilDir = "..\util"
$g_tablesDir = "$tablesDir"

# $result is an array with information about the custom action
#
# $result[0] - exists 
#  0 - does not exist
#  1 - exists
# $result[1] - custom action basic type
#  1-54
#  see http://msdn.microsoft.com/en-us/library/windows/desktop/aa372048(v=vs.85).aspx
# $result[2] - custom action found in InstallUISequence table
#  0 - not found
#  1 - found but condition always false
#  2 - found and condition may be true
#  3 - found and condition is always true or no condition
# $result[3] - custom action found in InstallExecuteSequence table
#  0 - not found
#  1 - found but condition always false
#  2 - found and condition may be true
#  3 - found and condition is always true or no condition
# $result[5] - custom action found in ControlEvent table
#  0 - not found
#  1 - found but condition always false
#  2 - found and condition may be true
#  3 - found and condition is always true or no condition
# $result[6] - custom action scheduling
#  0 - Always execute. Action may run twice if present in both sequence tables.
#  1 - Execute no more than once if present in both sequence tables. 
#  2 - Execute once per process if in both sequence tables.
#  3 - Execute only if running on client after UI sequence has run.
#  see http://msdn.microsoft.com/en-us/library/windows/desktop/aa368067(v=vs.85).aspx
# $result[7] - custom action return processing
#  0 - A synchronous execution that fails if the exit code is not 0 (zero).
#  1 - A synchronous execution that ignores exit code and continues.
#  2 - An asynchronous execution that waits for exit code at the end of the sequence.
#  3 - An asynchronous execution that does not wait for completion.
#  see http://msdn.microsoft.com/en-us/library/windows/desktop/aa368071(v=vs.85).aspx
# $result[8] - custom action in-script execution options 1
#  0 - Immediate execution.
#  1 - Execution within script (deferred CA)
# $result[9] - custom action in-script execution options 2
#  0 - Normal CA.
#  1 - Rollback CA.
#  2 - Commit CA.
# $result[10] - custom action in-script execution options 3
#  0 - No impersonation (runs in SYSTEM context).
#  1 - Impersonation (runs in user contet).
# $result[10] - custom action in-script execution options 4
#  0
#  1 - During per-machine installs on a Terminal Server. 
# see http://msdn.microsoft.com/en-us/library/windows/desktop/aa368069(v=vs.85).aspx
#
	
[array] $result = @(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
[array] $caRows = & "$g_utilDir\filter-rows" "$g_tablesDir\CustomAction.idt" "Action" "$caName"
if ($caRows.Count -eq 0) {
	return $result
}
$result[0] = 1

foreach ($caRow in $caRows) {
	$action = $caRow.Action

	# Get basic type
	[int64] $type = $caRow.Type
	$result[1] = ($type -band 0x03f)
	
	# Check InstallUISequcence
	$result[2] = 0
	[array] $instUiRows = & "$g_utilDir\filter-rows" "$g_tablesDir\InstallUISequence.idt" "Action" "$action"
	if ($instUiRows.Count -gt 0) {
		foreach ($instUiRow in $instUiRows)
		{
			# Condition always false?
			$instUiCol = "Condition"
			$expr = & "$g_utilDir\check-msicondition" "$instUiRow.$instUiCol"
			$result[2] = $expr + 1
		}
	}

	# Check InstallExecuteSequcence
	$result[3] = 0
	[array] $instExRows = & "$g_utilDir\filter-rows" "$g_tablesDir\InstallExecuteSequence.idt" "Action" "$action"
	if ($instExRows.Count -gt 0) {
		foreach ($instExRow in $instExRows)
		{
			# Condition always false?
			$instExCol = "Condition"
			$expr = & "$g_utilDir\check-msicondition" "$instExRow.$instExCol"
			$result[3] = $expr + 1
		}
	}

	# Check ControlEvent table
	$result[4] = 0
	[array] $ctrlEventRows = & "$g_utilDir\filter-rows" "$g_tablesDir\ControlEvent.idt" "Argument" "$action"
	if ($ctrlEventRows.Count -gt 0) {
		foreach ($ctrlEventRow in $ctrlEventRows)
		{
			if (($ctrlEventRow.Event) -eq "DoAction") {
				# Condition always false?
				$ctrlEventCol = "Condition"
				$expr = & "$g_utilDir\check-msicondition" "$ctrlEventRow.$ctrlEventCol"
				$result[4] = $expr + 1
			}
		}
	}

	# If CA is used in a sequence table, evaluate relevant flags
	if (($result[2] -gt 0) -and ($result[3] -gt 0))
	{
		# Get scheduling options
		$result[5] = 0
		if (($type -band 0x100) -eq 0x100) {
			$result[5] = 1
		}
		if (($type -band 0x200) -eq 0x200) {
			if ($result[5] -eq 1) {
				$result[5] = 3
			} else {
				$result[5] = 2			
			}
		}

		# Get return processing options
		$result[6] = 0
		if (($type -band 0x40) -eq 0x40) {
			$result[6] = 1
		}
		if (($type -band 0x80) -eq 0x80) {
			if ($result[6] -eq 1) {
				$result[6] = 3
			} else {
				$result[6] = 2			
			}
		}

		# Get in-script options 1: immediate or deferred
		$result[7] = 0
		if (($type -band 0x400) -eq 0x400) {
			$result[7] = 1
		}

		# Get in-script options 2: normal, commit or rollback
		$result[8] = 0
		if (($type -band 0x100) -eq 0x100) {
			$result[8] = 1
		} elseif (($type -band 0x200) -eq 0x200) {
			$result[8] = 2
		}

		# Get in-script options 3: impersonate or not
		$result[9] = 0
		if (($type -band 0x800) -eq 0x800) {
			$result[9] = 1
		}

		# Get in-script options 4: terminal server aware
		$result[10] = 0
		if (($type -band 0x4000) -eq 0x4000) {
			$result[10] = 1
		}
	}
}

# write-host "Check-Customaction: $caName $result"

return $result
