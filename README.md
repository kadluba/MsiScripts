# MsiScripts

A collection of PowerShell scripts written for research purpose during the writing of my thesis "Windows Installer Security" at the University of Applied Science Technikum Wien in March 2013.

## License

The scripts are licensed under the MIT License. You can find the license text in the LICENSE file.

## Prerequisites

The scripts were tested and developed on Microsoft Windows 7 with PowerShell 2.0 and Windows Installer 5.07601.17514.

Some of the tools used by the scripts are not included for legal reasons. However, these tools are freely available for download as part of the Microsoft SDK.
<ul>
	<li>Copy MsiZap.exe into 03_fuzzer
	<li>Copy SignTool.exe into 05_msi_sec_audit
 	<li>Copy MsiDb.Exe into util
</ul>

For using the 04_msi_virus_scan script it is recommended that you install e Microsoft Security Essentials 4.1.522.0 or AVG 2013.0.2805 although the script can easily be adapted to any other AV scanner as long as it offers a command line interface.

## The Scripts

A brief overview of the different scripts.

### 01_installsource_integrity

Tries to install a prepared installer package (SmallChange) and then repair it with a slightly modified version showing that overwriting files by repair is possible.

### 02_rollback_integrity

Installs and then upgrades a specially prepared installer package (PauseRollback). On the rollback the installation pauses until a specific file is created. This gives the script the opportunitiy to try to manipulate the temporary rollback files (.rbs and .rbf) of Windows Installer.

### 03_fuzzer

Flips a random bit of an MSI file and tries to install and uninstall it. The error code is written to a CSV log file. This is done in a loop. There is a second mode to flip bits sequentially with a specified byte offset and length.

### 04_msi_virus_scan

Extracts the contents of an MSI file and scans it with a locally installed antivirus scanner. The setup logic and privileges of the installer package are taken into account to make a risk assessment.

### 05_msi_sec_audit

Scans the contents of an MSI file for bad and possibly risky authoring and calculates a risk score based on this information.


