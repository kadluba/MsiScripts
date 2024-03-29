<#
	.SYNOPSIS
        Check-Tables checks the tables of an MSI for possible dangerous authoring
		which can lead to security problems when installing the file. The script 
		returns a risk score for the MSI ranging form 0 (low) to 100 (high).
	.PARAMETER tablesDir
        Directory with the extracted MSI tables in IDT format as created by msidb.exe.
#>

# Parameter definition
param (
	[string] $msi,
	[string] $tablesDir = "msi-tables"
)

# Variables
$g_logDir = "logs"
$g_utilDir = "..\util"
$g_msi = "$msi"
$g_tablesDir = "$tablesDir"
[int] $g_riskScore = 0

# Functions
function global:print-result([string] $text, [int] $result, [string] $details)
{
	[int] $position = 60
	if ($text.length -gt $position) {
		$text = $text.SubString(0, $position)
	}
	[int] $fillerLen = $position - $text.length
	[string] $filler = ""
	while ($fillerLen -gt 0) {
		$filler += " "
		$fillerLen--
	}

	write-host "* ${text}:$filler [ " -nonewline
	if ($result -eq 0) {
		write-host "NO"  -nonewline -foregroundcolor red
		write-host " ]"
		if ("$details" -ne "") {
			write-host "  ($details)"
		}
	} else {
		write-host "YES"  -nonewline -foregroundcolor green
		write-host " ]"
	}

}

function get-tablevalue([string] $table, [string] $searchCol, [string] $searchVal, [string] $resultCol)
{
	[string] $resultVal = ""
	[array] $rows = & "$g_utilDir\filter-rows" "$g_tablesDir\${table}.idt" "$searchCol" "$searchVal"
	if ($rows.Count -gt 0) {
		$resultVal = $rows[0].$resultCol
	}
	return $resultVal
}

function global:check-msifilesignature()
{
	[int] $result = 0

	$output = & .\signtool.exe verify "$msi" 2>&1
	for ($i = 0; $i -lt $output.length; $i++)
	{
		[string] $line = $output[$i]
		if (($i -eq 3) -and ($line.CompareTo("SignTool Error: A certificate chain processed, but terminated in a root") -eq 0)) {
			$result = 1
		}
	}

	if ($result -eq 0) {
		$script:g_riskScore += 1
	}
	print-result -text "MSI file has a valid signature" -result $result
}

function global:check-summaryinformation()
{
	[int] $result = 0

	$result = 0
	# Read: table: _SummaryInformation, column: Property = 19
	# Check: column: Value is '2'
	$summarySecurity = get-tablevalue -table "_SummaryInformation" -searchCol "PropertyId" -searchVal "19" -resultCol "Value"
	if ("$summarySecurity" -eq "0") {
		$result = 1
	} else {
		$script:g_riskScore += 1
	}
	print-result -text "Pacakge is read-only during installation" -result $result -detail "Security Summary Property is $summarySecurity"

	$result = 0
	# Read: table: _SummaryInformation, column: Property = 15
	# Check: column: Value bit 3 set (0x8)
	[int] $summaryWordCount = get-tablevalue -table "_SummaryInformation" -searchCol "PropertyId" -searchVal "15" -resultCol "Value"
	if (($summaryWordCount -band 8) -eq 8) {
		$result = 1
	} else {
		$script:g_riskScore += 5
	}
	print-result -text "Disables elevated privileges" -result $result -detail "WordCount Summary Property is $summaryWordCount"

	$result = 0
	# Read: table: _SummaryInformation, column: Property = 15
	# Check: column: Value bit 2 not set (0x4)
	if (($summaryWordCount -band 4) -ne 4) {
		$result = 1
	} else {
		$script:g_riskScore += 2
	}
	print-result -text "No administrative image" -result $result -detail "WordCount Summary Property is $summaryWordCount"

	$result = 0
	# Read: table: _SummaryInformation, column: Property = 15
	# Check: column: Value bit 1 set (0x2)
	if (($summaryWordCount -band 2) -eq 2) {
		$result = 1
	} else {
		$script:g_riskScore += 2
	}
	print-result -text "Uses compressed media" -result $result -detail "WordCount Summary Property is $summaryWordCount"

}

function global:check-properties()
{
	[int] $result = 0

	$result = 0
	# Read: table: _SummaryInformation, column: Property = 19
	# Check: column: Value is '2'
	$propAllUsers = get-tablevalue -table "Property" -searchCol "Property" -searchVal "ALLUSERS" -resultCol "Value"
	if ("$propAllUsers" -ne "1") {
		$result = 1
	} else {
		$script:g_riskScore += 1
	}
	print-result -text "Per-user installation" -result $result -detail "ALLUSERS Property is set to $propAllUsers"

}

function global:is-embeddedca([int] $type)
{
	if (1, 2, 5, 6, 37, 38 -contains $type) {
		return $true
	}
	return $false
}

function global:is-mediaca([int] $type)
{
	if (17, 18, 21, 22 -contains $type) {
		return $true
	}
	return $false
}

function global:is-commandca([int] $type)
{
	if (34, 50, 53, 54 -contains $type) {
		return $true
	}
	return $false
}

function global:print-caresults(
	[string] $context, 
	[int] $caEmb, 
	[int] $caMed, 
	[int] $caCmd, 
	[int] $caOth)
{
	[int] $caRiskScore = 0

	$detail = ""
	$result = 1
	if ($caEmb -gt 0) {
		$detail = "$caEmb actions found (types like 1, 2, 5, 6, 37, 38)"
		$result = 0
		$caRiskScore += 2
	}
	print-result -text "Free of $context context CAs embedded in package" -result $result -detail "$detail"

	$detail = ""
	$result = 1
	if ($caMed -gt 0) {
		$detail = "$caMed actions found (types like 17, 18, 21, 22)"
		$result = 0
		$caRiskScore += 2
	}
	print-result -text "Free of $context context CAs installed by package" -result $result -detail "$detail"

	$detail = ""
	$result = 1
	if ($caCmd -gt 0) {
		$detail = "$caCmd actions found (types like 34, 50, 53, 54)"
		$result = 0
		$caRiskScore += 5
	}
	print-result -text "Free of $context context CAs running system commands" -result $result -detail "$detail"

	$detail = ""
	$result = 1
	if ($caOth -gt 0) {
		$detail = "$caOth actions found"
		$result = 0
	}
	print-result -text "Free of other $context context CAs (set properties)" -result $result -detail "$detail"

	return $caRiskScore
}

function global:check-customactions()
{
	[int] $result = 0

	$result = 0
	$detail = ""

	[int] $caSysBinTableCounter = 0   # 1, 2, 5, 6, 37, 38
	[int] $caSysFileTableCounter = 0  # 17, 18, 21, 22, 
	[int] $caSysCommandCounter = 0    # 34, 50, 53, 54
	[int] $caSysOtherCounter = 0
	[int] $caUsrBinTableCounter = 0   # 1, 2, 5, 6, 37, 38
	[int] $caUsrFileTableCounter = 0  # 17, 18, 21, 22, 
	[int] $caUsrCommandCounter = 0    # 34, 50, 53, 54
	[int] $caUsrOtherCounter = 0
	[int] $caCtrlEvtCounter = 0
	[int] $caUnusedCounter = 0

	# Read: table: CustomAction
	if (!(test-path "$g_tablesDir\CustomAction.idt")) {
		$detail = "No CustomAction table found"
		$result = 1
	} else {
		$table = import-csv -Delimiter `t "$g_tablesDir\CustomAction.idt"
		if ($? -eq $false) {
			$detail = "No CustomAction table found"
			$result = 1
		} else {
			[int] $rowNum = 0
			foreach ($row in $table) 
			{
				# Ignore first two rows containing table schema and foreign key
				if ($rowNum -gt 1) {
					$caName = ($row.Action)
					$caInfo = & "$g_utilDir\check-customaction" "$caName" "$g_tablesDir"
#					write-host "CA: $caName, INFO: $caInfo" -nonewline
					if (($caInfo[3] -gt 1) -and ($caInfo[9] -eq 0)) {
						# SYSTEM context CA: 3 - InstallExecuteSeq, 7 - Deferred, 9 - NoImpersonate
#						write-host ", CTX: sys" -nonewline
						if (is-embeddedca($caInfo[1])) {
#							write-host ", TYPE: emb"
							$caSysBinTableCounter++
						} elseif (is-mediaca($caInfo[1])) {
#							write-host ", TYPE: media"						
							$caSysFileTableCounter++
						} elseif (is-commandca($caInfo[1])) {
#							write-host ", TYPE: cmd"
							$caSysCommandCounter++
						} else {
#							write-host ", TYPE: other"
							$caSysOtherCounter++
						}
					} elseif (($caInfo[2] -gt 1) -or ($caInfo[3] -gt 1)) {
						# USER context CA: 2 - InstallUISEq or 3 - InstallExecuteSeq
#						write-host ", CTX: usr" -nonewline
						if (is-embeddedca($caInfo[1])) {
#							write-host ", TYPE: emb"
							$caUsrBinTableCounter++
						} elseif (is-mediaca($caInfo[1])) {
#							write-host ", TYPE: media"
							$caUsrFileTableCounter++
						} elseif (is-commandca($caInfo[1])) {
#							write-host ", TYPE: cmd"
							$caUsrCommandCounter++
						} else {
#							write-host ", TYPE: other"
							$caUsrOtherCounter++
						}						
					} elseif ($caInfo[4] -gt 1) {
						$caCtrlEvtCounter++					
					} else {
#						write-host ", UNUSED???"
						$caUnusedCounter++
					}
				}
				$rowNum++
			}
		}
	}

	$caSystemRiskScore = print-caresults -context "SYSTEM" -caEmb $caSysBinTableCounter -caMed $caSysFileTableCounter -caCmd $caSysCommandCounter -caOth $caSysOtherCounter
	$script:g_riskScore += $caSystemRiskScore * 2
	$caUserRiskScore = print-caresults -context "user" -caEmb $caUsrBinTableCounter -caMed $caUsrFileTableCounter -caCmd $caUsrCommandCounter -caOth $caUsrOtherCounter
	$script:g_riskScore += $caUserRiskScore

	$detail = ""
	$result = 1
	if ($caCtrlEvtCounter -gt 0) {
		$detail = "$caCtrlEvtCounter actions found"
		$result = 0
	} else {
		$script:g_riskScore += 2
	}
	print-result -text "Free of ControlEvent CAs" -result $result -detail "$detail"

	$detail = ""
	$result = 1
	if ($caUnusedCounter -gt 0) {
		$detail = "$caUnusedCounter actions found"
		$result = 0
	}
	print-result -text "Free of unused CAs" -result $result -detail "$detail"

	
	# TODO search ControlEvent table for used CAs
}

# Initial checks and preparation
if (!(test-path "$g_utilDir" -pathtype container)) {
    write-error "Util dir $g_utilDir not found!"
    break
}
if (!(test-path "$tablesDir" -pathtype container)) {
	write-error "Tables directory $tablesDir not found!"
	break
}
if (!(test-path $g_logDir)) {
    # Create log dir if it does not exist
    mkdir "$g_logDir" > $null
}

# Main part check MSI file for insecure authoring
write-host "MSI package file signature check"
check-msifilesignature
write-host "---"

write-host "Summary Information Stream checks"
check-summaryinformation
write-host "---"

write-host "Property table checks"
check-properties
write-host "---"

write-host "Custom action checks"
check-customactions
write-host "---"

write-host "Security risk score for MSI package $msi"
write-host "SCORE: $g_riskScore"
write-host "---"
