<#
    .SYNOPSIS
        Flip-Bit flips a given bit in a given binary file.
    .PARAMETER file
        File to manipulate.
    .PARAMETER byteOffset
        Byte offset of within the file.
    .PARAMETER bitOffset
        Bit offset relative to byteOffset.
#>

# Parameter definition
param (
    [parameter(Mandatory = $true)]
    [string] $file, 
    [parameter(Mandatory = $true)]
    [int] $byteOffset, 
    [parameter(Mandatory = $true)]
    [validaterange(0, 7)]
    [int] $bitOffset
)

# Variables
$utilDir = "..\util"
[array] $result = @(0, 0, 0)

# Remove leading ".\" and append current directory if $file is a relative path
$file = & "$utilDir\remove-dotslash" "$file"
$file = & "$utilDir\append-workdir" "$file"

try {
    # Read from file
    $readStream = new-object System.IO.FileStream($file,
            [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
    $return = $readStream.Seek($byteOffset, [System.IO.SeekOrigin]::Begin)
    [System.Byte] $byte = $readStream.ReadByte()
    $readStream.Close()
    [System.Byte] $mask = 1
    switch ($bitOffset) {
        { $_ -eq 1 } { $mask = 2 }
        { $_ -eq 2 } { $mask = 4 }
        { $_ -eq 3 } { $mask = 8 }
        { $_ -eq 4 } { $mask = 16 }
        { $_ -eq 5 } { $mask = 32 }
        { $_ -eq 6 } { $mask = 64 }
        { $_ -eq 7 } { $mask = 128 }
    }
    [System.Byte] $byteFlipped = $byte -bxor $mask
	$result[1] = $byte
	$result[2] = $byteFlipped
    
    # Write to file
    $writeStream = new-object System.IO.FileStream($file,
            [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write)
    $return = $writeStream.Seek($byteOffset, [System.IO.SeekOrigin]::Begin)
    $writeStream.WriteByte($byteFlipped)
    $writeStream.Close()

#	write-host "Byte: $byteOffset, bit: $bitOffset, value: $byte, flipped: $byteFlipped"
} catch {
    write-error "Error patching file!"
    $_
    $result[0] = 1
}

return $result
