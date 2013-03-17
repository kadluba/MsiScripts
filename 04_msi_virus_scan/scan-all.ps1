<#
	.SYNOPSIS
        Scan-All acans all msi files in ..\test-packages\virus\ with specified 
		virus scanner and creates a CSV file showing the results.
		The scan is done in the following passes:
		 * Files extraced from MSI
		 * Complete MSI as binary
		 * Single malware.exe file
		Each of the passes scans all MSI files.
	.PARAMETER scanEngine
		Virus scan engine to use for scanning.
		 * "mse" - scan with Microsoft Security Essentials (default)
		 * other - scan with AVG
#>

# Parameter definition
param (
	[string] $scanEngine = "mse"
)

# Variables
$g_utilDir = "..\util"
$g_logDir = "logs"
$g_packagesDir = "..\test-packages\virus"


# Functions
function global:scan-cleandir {
	PARAM (
		[string] $method
	)

	if ($method.CompareTo("mse-script") -eq 0) {
		$resWixLang = .\scan-msi -msi "$g_packagesDir\00_clean\WixLanguage_clean.msi" -scanEngine "mse"
		$resWixUi = .\scan-msi -msi "$g_packagesDir\00_clean\WixUI_clean.msi" -scanEngine "mse"
	} elseif ($method.CompareTo("mse") -eq 0) {
		$resWixLang = .\scan-msi -msi "$g_packagesDir\00_clean\WixLanguage_clean.msi" -scanEngine "mse" -treatAsBinary
		$resWixUi = .\scan-msi -msi "$g_packagesDir\00_clean\WixUI_clean.msi" -scanEngine "mse" -treatAsBinary
	} elseif ($method.CompareTo("avg-script") -eq 0) {
		$resWixLang = .\scan-msi -msi "$g_packagesDir\00_clean\WixLanguage_clean.msi" -scanEngine "avg"
		$resWixUi = .\scan-msi -msi "$g_packagesDir\00_clean\WixUI_clean.msi" -scanEngine "avg"
	} elseif ($method.CompareTo("avg") -eq 0) {
		$resWixLang = .\scan-msi -msi "$g_packagesDir\00_clean\WixLanguage_clean.msi" -scanEngine "avg" -treatAsBinary
		$resWixUi = .\scan-msi -msi "$g_packagesDir\00_clean\WixUI_clean.msi" -scanEngine "avg" -treatAsBinary
	}

	# Write to CSV log
	[string] $csv = "cases\scan-all_${method}.csv"
	if (!(test-path "$csv")) {
		write "Malware, WixLanguage_vircab, WixLanguage_vircabunused, WixUI_virbinary, WixUI_virbinaryunused, malware.exe" > "$csv"
	}
	write "clean, $resWixLang, , $resWixUi, , " >> "$csv"
}

function global:scan-malwaredir {
	PARAM (
		[string] $method, 
		[string] $malwareDir
	)

	[string] $malware = $malwareDir.SubString(3)
	if ($method.CompareTo("mse-script") -eq 0) {
		$resVC = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixLanguage_vircab-${malware}.msi" -scanEngine "mse"
		$resVCu = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixLanguage_vircabunused-${malware}.msi" -scanEngine "mse"
		$resVB = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixUI_virbinarytab-${malware}.msi" -scanEngine "mse"
		$resVBu = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixUI_virbinarytabunused-${malware}.msi" -scanEngine "mse"
	} elseif ($method.CompareTo("mse") -eq 0) {
		$resVC = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixLanguage_vircab-${malware}.msi" -scanEngine "mse" -treatAsBinary
		$resVCu = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixLanguage_vircabunused-${malware}.msi" -scanEngine "mse" -treatAsBinary
		$resVB = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixUI_virbinarytab-${malware}.msi" -scanEngine "mse" -treatAsBinary
		$resVBu = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixUI_virbinarytabunused-${malware}.msi" -scanEngine "mse" -treatAsBinary
		$resMal = .\scan-msi -msi "$g_packagesDir\$malwareDir\malware.exe" -scanEngine "mse" -treatAsBinary
	} elseif ($method.CompareTo("avg-script") -eq 0) {
		$resVC = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixLanguage_vircab-${malware}.msi" -scanEngine "avg"
		$resVCu = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixLanguage_vircabunused-${malware}.msi" -scanEngine "avg"
		$resVB = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixUI_virbinarytab-${malware}.msi" -scanEngine "avg"
		$resVBu = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixUI_virbinarytabunused-${malware}.msi" -scanEngine "avg"
	} elseif ($method.CompareTo("avg") -eq 0) {
		$resVC = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixLanguage_vircab-${malware}.msi" -scanEngine "avg" -treatAsBinary
		$resVCu = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixLanguage_vircabunused-${malware}.msi" -scanEngine "avg" -treatAsBinary
		$resVB = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixUI_virbinarytab-${malware}.msi" -scanEngine "avg" -treatAsBinary
		$resVBu = .\scan-msi -msi "$g_packagesDir\$malwareDir\WixUI_virbinarytabunused-${malware}.msi" -scanEngine "avg" -treatAsBinary
		$resMal = .\scan-msi -msi "$g_packagesDir\$malwareDir\malware.exe" -scanEngine "avg" -treatAsBinary
	}

	# Write to CSV log
	[string] $csv = "cases\scan-all_${method}.csv"
	if (!(test-path "$csv")) {
		write "Malware, WixLanguage_vircab, WixLanguage_vircabunused, WixUI_virbinary, WixUI_virbinaryunused, malware.exe" > "$csv"
	}
	write "$malware, $resVC, $resVCu, $resVB, $resVBu, $resMal" >> "$csv"
}

# Main part
scan-cleandir -method "${scanEngine}-script"
scan-malwaredir -method "${scanEngine}-script" -malwareDir "01_eicar"
scan-malwaredir -method "${scanEngine}-script" -malwareDir "02_parite"
scan-malwaredir -method "${scanEngine}-script" -malwareDir "03_hahor"
scan-malwaredir -method "${scanEngine}-script" -malwareDir "04_lolol"
scan-malwaredir -method "${scanEngine}-script" -malwareDir "05_webdav"
scan-malwaredir -method "${scanEngine}-script" -malwareDir "06_iexploiter"
scan-malwaredir -method "${scanEngine}-script" -malwareDir "07_bifrose"
scan-malwaredir -method "${scanEngine}-script" -malwareDir "08_setcrack"

scan-cleandir -method "${scanEngine}"
scan-malwaredir -method "${scanEngine}" -malwareDir "01_eicar"
scan-malwaredir -method "${scanEngine}" -malwareDir "02_parite"
scan-malwaredir -method "${scanEngine}" -malwareDir "03_hahor"
scan-malwaredir -method "${scanEngine}" -malwareDir "04_lolol"
scan-malwaredir -method "${scanEngine}" -malwareDir "05_webdav"
scan-malwaredir -method "${scanEngine}" -malwareDir "06_iexploiter"
scan-malwaredir -method "${scanEngine}" -malwareDir "07_bifrose"
scan-malwaredir -method "${scanEngine}" -malwareDir "08_setcrack"
