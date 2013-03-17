<#
	.SYNOPSIS
        Run-Process runs a process and waits for it to complete.
	.PARAMETER cmd
        Name and path the program to execute.
	.PARAMETER par
        Command line parameters to pass to the program.
	.PARAMETER wait
        Wait for the process to complete.
	.PARAMETER stdOutFile
        Name and path of the log file for stdout.
		Leave blank to use stdout.
	.PARAMETER stdErrFile
        Name and path of the log file for stdout.
		Leave blank to use stdout.
#>

# Parameter definition
param (
	[string] $cmd, 
	[string] $par, 
	[bool] $wait, 
	[string] $stdOutFile = "",
	[string] $stdErrFile = ""
)

# Variables
$g_utilDir = "..\util"

# Main part 
$procInfo = New-Object Diagnostics.ProcessStartInfo
if (($cmd.SubString(0, 1) -eq ".") -and ($cmd.SubString(1, 1) -eq "\")) {
	$cmd = & "$g_utilDir\remove-dotslash" "$cmd"
	$cmd = & "$g_utilDir\append-workdir" "$cmd"
} elseif (($cmd.SubString(0, 1) -eq ".") -and ($cmd.SubString(1, 1) -eq ".") -and ($cmd.SubString(2, 1) -eq "\")) {
	$cmd = & "$g_utilDir\append-workdir" "$cmd"
}

$procInfo.FileName = "$cmd"
$procInfo.WorkingDirectory = get-location
if ("$stdOutFile" -ne "") {
	$procInfo.RedirectStandardOutput = $true;
}
if ("$stdErrFile" -ne "") {
	$procInfo.RedirectStandardError = $true;
}
$procInfo.UseShellExecute = $false
$procInfo.Arguments = $par

#write-host "Run-Process: $cmd $par"
$proc = [Diagnostics.Process]::Start($procInfo)

if ("$stdOutFile" -ne "") {
	$stdout = $proc.StandardOutput.ReadToEnd()
	write "$stdout" > "$stdOutFile"
}
if ("$stdErrFile" -ne "") {
	$stderr = $proc.StandardOutput.ReadToEnd()
	write "$stderr" > "$stdErrFile"
}

if ($wait) {
	$proc.WaitForExit() 
}
return $proc.ExitCode
