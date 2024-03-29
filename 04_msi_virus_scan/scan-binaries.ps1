<#
	.SYNOPSIS
        Scan-Binaries scans the media files and CustomAction binaries 
		contained in an MSI for viruses. It is also checked if
		infected a media files are getting installed. For CustomAction 
		binaries with infections it is checked it they are actually used 
		during installation.
	.PARAMETER tablesDir
        Directory with the extracted MSI tables in IDT format as created by msidb.exe.
	.PARAMETER cabsDir
        Directory with the extracted cabinet files used by the MSI. A subdir for each 
		cabinet is assumed.
	.PARAMETER scanEngine
		Virus scan engine to use for scanning.
		 * "mse" - scan with Microsoft Security Essentials (default)
		 * other - scan with AVG
	.PARAMETER binary
        Single binary file to scan. If this parameter is used, parameters cabsDir and 
		tablesDir are ignored and only the specified file is scanned.
#>

# Parameter definition
param (
	[string] $tablesDir = "msi-tables",
	[string] $cabsDir = "msi-cabs",
	[string] $scanEngine = "mse", 
	[string] $binary = ""
)

# Variables
$g_logDir = "logs\"
$g_utilDir = "..\util"
$g_tablesDir = "$tablesDir"
$g_cabsDir = "$cabsDir"

# Select virus scan engine. "mse" = ms security essentials, other value = AVG
$g_scanEngine = "$scanEngine" 
$g_scanEngineMse = "C:\Program Files\Microsoft Security Client\mpcmdrun.exe"
$g_scanEngineAvg = "C:\Program Files\AVG\AVG2013\avgscanx.exe"


# Functions
function global:scan-file {
    PARAM (
        [string] $file
    )

	if (!(test-path -path "$file" -pathtype leaf)) {
		return 1
	}

	$escapedFile = $file -replace ':', '-'
	$escapedFile = $escapedFile -replace '\\', '-'
	$escapedFile = $escapedFile -replace '/', '-'

	$absFile = resolve-path "$file"
	$result = 0

	if ($g_scanEngine.CompareTo("mse") -eq 0) {
		rm "$env:TEMP\mpcmdrun.log"
		$result = & "$g_scanEngineMse" -scan -scantype 3 -file "$absFile" -disableremediation > "$g_logDir\${escapedFile}.scan.log"
		$result = $lastexitcode
		if ($result -eq 1) {
			$result = 0
		}
		get-content "$env:TEMP\mpcmdrun.log" >> "$g_logDir\${escapedFile}.scan.log"
	} else {
		$result = & "$g_scanEngineAvg" /scan="$absFile" > "$g_logDir\${escapedFile}.scan.log"
		$result = $lastexitcode
	}

	return $result
}

function global:scan-media
{
	$currentDir = ""
	$currentDir += (get-location)
	[int] $overallResult = 0

	$cabDirs = get-childitem "$g_cabsDir"
	foreach ($cabDir in $cabDirs)
	{
		$cabItems = get-childitem "$g_cabsDir\$cabDir"
		foreach ($cabItem in $cabItems) {
			$file = "$currentDir\$g_cabsDir\$cabDir\$cabItem"
			[int] $result = scan-file "$file"
			if ($result -eq 0) {
				# write-host "Scan result for media file $file is $result"
			} else {
				# Infected file found
				write-warning "Scan result for media file $file is $result (infected)"

				# Check if file is actually used in a Feature/Component
				# also checks condition in Component table
				[int] $fileCheckResult = 0
				$fileCheckResult = check-fileentry -file "$cabItem"
				if ($fileCheckResult -eq 0) {
					write-warning "INFO: `t... seems not to be installed by the MSI file"
					$overallResult = 1
				} else {
					write-warning "WARNING: `t... seems to be installed when installing the MSI file!!!"
					$overallResult = 2
				}
			}
		}
	}

	return $overallResult
}

function global:scan-binaryentries
{
	# Return: 0 - no virus, 1 - virus in unused binary, 2 - virus in CA binary
	
	if (!(test-path "$g_tablesDir\Binary" -pathtype container)) {
		write-host "No Binary table directory found $g_tablesDir\Binary"
		return 0
	}
	
	$currentDir = ""
	$currentDir += (get-location)
	[int] $overallResult = 0

	$binaryItems = get-childitem "$g_tablesDir\Binary"
	foreach ($binaryItem in $binaryItems) {
		$file = "$currentDir\$g_tablesDir\Binary\$binaryItem"
		[int] $result = scan-file "$file"
		if ($result -eq 0) {
			# write-host "Scan result for 'Binary'-table item $file is $result"
		} else {
			# Infected file found
			write-warning "Scan result for 'Binary'-table item $file is $result (infected)"

			$binName = & "$g_utilDir\get-binaryname" "$binaryItem" "$g_tablesDir"
			[int] $caCheckResult = 0
			[int] $ceCheckResult = 0
			if ("$binName" -ne "") {
				[array] $caRows = & "$g_utilDir\filter-rows" "$g_tablesDir\CustomAction.idt" "Source" "$binName"
				if ($caRows.Count -gt 0) {
					foreach ($caRow in $caRows)
					{
						$caName = ($caRow.Action)

						# Check if item is actually as a custom action code
						# also checks condition in sequence tables
						$caInfo = & "$g_utilDir\check-customaction" "$caName" "$g_tablesDir"
						if (($caInfo[2] -gt 1) -or ($caInfo[3] -gt 1)) {
							write-warning "WARNING: `t... $caName seems to be a sequenced CustomAction which is executed!!!"
							$caCheckResult = 1					
						}

						# Check if item is actually as a ControlEvent DoAction code
						# also checks condition in ControlEvent table
						if ($caInfo[4] -gt 1) {
							write-warning "WARNING: `t... $caName seems to be a ControlEvent CustomAction which is executed!!!"
							$ceCheckResult = 1
						}								
					}  # foreach $caRow
				}			
			}
			if (($caCheckResult -eq 0) -and ($ceCheckResult -eq 0)) {
				write-warning "INFO: `t... the infected file seems not to be used by any CustomActions or ControlEvents"
				$overallResult = 1
			} else {
				$overallResult = 2
			}
		}
	}

	return $overallResult
}

function global:check-fileentry([string] $file)
{
	# Result tells possible risk of an installed file
	#
	# Action does not run at all
	# 0 - not found in tables (or condition always false)
	# 1 - found in Files, Components and Features

	[int] $result = 0

#write-host "FILE $file"
	[array] $fileRows = & "$g_utilDir\filter-rows" "$g_tablesDir\File.idt" "File" "$file"
	if ($fileRows.Count -eq 0) {
		return 0
	}

	foreach ($fileRow in $fileRows) {
		$fileCol = "Component_"
		$component = $fileRow.$fileCol
#write-host "COMPONENT $component"

		[array] $compRows = & "$g_utilDir\filter-rows" "$g_tablesDir\Component.idt" "Component" "$component"
		if ($compRows.Count -gt 0) {
			foreach ($compRow in $compRows)
			{
				# Condition always false?
				$compCol = "Condition"
				$expr = & "$g_utilDir\check-msicondition" "$compRow.$compCol"
				if ($expr -gt 0) {
					
					[array] $fcRows = & "$g_utilDir\filter-rows" "$g_tablesDir\FeatureComponents.idt" "Component_" "$component"
					if ($fcRows.Count -gt 0) {
						# At least one Feature/Component uses the file
						$fcCol = "Feature_"
						$feature = $fcRows[0].$fcCol
#write-host "FEATURE $feature"

						# TODO - also check Condition table for Level of feature
						return 1
					}
				}
			}
		}
	}
	
	return 0
}

# Initial checks and preparation
if (!(test-path "$g_utilDir" -pathtype container)) {
    write-error "Util dir $g_utilDir not found!"
    break
}
if ($g_scanEngine.CompareTo("mse") -eq 0) {
	write-host "Scanning with Microsoft Security Essentials"
	if (!(test-path "$g_scanEngineMse" -pathtype leaf)) {
		write-error "Microsoft Security Essentials not found!"
		break
	}
} else {
	write-host "Scanning with AVG"
	if (!(test-path "$g_scanEngineAvg" -pathtype leaf)) {
		write-error "AVG not found!"
		break
	}
}
if ($binary.CompareTo("") -eq 0) {
	if (!(test-path "$tablesDir" -pathtype container)) {
		write-error "Tables directory $tablesDir not found!"
		break
	}
	if (!(test-path "$cabsDir" -pathtype container)) {
		write-error "Cabinet directory $cabsDir not found!"
		break
	}
}
if (!(test-path $g_logDir)) {
    # Create log dir if it does not exist
    mkdir "$g_logDir" > $null
}

# Main part
[int] $result = 0
if ($binary.CompareTo("") -eq 0) {
	# Scan files extracted from MSI
	write-host "Scanning media files for viruses"
	$resMedia = scan-media
	write-host "Scanning 'Binary'-table items for viruses"
	$resBinary = scan-binaryentries

	if (($resMedia -gt $resBinary)) {
		$result = $resMedia
	} else {
		$result = $resBinary
	}
} else {
	# Scan a single specified binary file
	write-host "Scanning file $binary"
	$result = scan-file "$binary"
	if ($result -eq 0) {
		write-host "Scan result for binary is $result - not infected"
	} else {
		write-warning "Scan result is $result - infected"
	}
}

$result