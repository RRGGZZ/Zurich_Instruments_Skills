[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('discover', 'status', 'list', 'read', 'sample', 'write')]
    [string]$Command = 'discover',

    [string]$Device,
    [string]$Node,
    [string]$Value,
    [ValidateRange(0, 7)]
    [int]$Demod = 0,
    [string]$ServerHost,
    [ValidateRange(1, 65535)]
    [int]$Port,
    [ValidateSet(1, 4, 5, 6)]
    [int]$ApiLevel,
    [ValidateSet('auto', 'double', 'integer', 'string')]
    [string]$Type = 'auto',
    [switch]$AllowWrite,
    [string]$ConfirmDevice,
    [switch]$AllowVersionMismatch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-JsonResult {
    param([Parameter(Mandatory)]$InputObject)
    $InputObject | ConvertTo-Json -Depth 12
}

function Get-LabOneAssemblyPath {
    $candidates = @(
        'C:\Program Files\Zurich Instruments\LabOne\API\DotNET\ziDotNET-win64.dll',
        'C:\Program Files\Zurich Instruments\LabOne\API\DotNET\ziDotNETCore-win64.dll'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw 'LabOne .NET API was not found. Install LabOne with the .NET API component.'
}

function Get-DiscoveryRecords {
    param([Parameter(Mandatory)]$Daq)
    $records = @()
    foreach ($id in @($Daq.discoveryFindAll())) {
        $record = $Daq.discoveryGet($id) | ConvertFrom-Json
        $records += [pscustomobject]@{
            device = $record.deviceid.ToUpperInvariant()
            device_type = $record.devicetype
            server_address = $record.serveraddress
            server_port = [int]$record.serverport
            api_level = [int]$record.apilevel
            interfaces = @($record.interfaces)
            connected = $record.connected
            available = [System.Convert]::ToBoolean($record.available)
            owner = $record.owner
            status = $record.status
            firmware_revision = [long]$record.firmwarerev
        }
    }
    return $records
}

function Select-DiscoveryRecord {
    param(
        [Parameter(Mandatory)]$Daq,
        [string]$RequestedDevice
    )
    $records = @(Get-DiscoveryRecords -Daq $Daq | Where-Object { $_.device_type -eq 'MFLI' })
    if ($RequestedDevice) {
        $serial = $RequestedDevice.ToUpperInvariant()
        $match = @($records | Where-Object { $_.device -eq $serial })
        if ($match.Count -ne 1) { throw "MFLI device $serial was not found by LabOne discovery." }
        return $match[0]
    }
    if ($records.Count -eq 0) { throw 'No MFLI device was found by LabOne discovery.' }
    if ($records.Count -gt 1) { throw 'Multiple MFLI devices were found. Specify -Device explicitly.' }
    return $records[0]
}

function Get-ApiEnum {
    param([Parameter(Mandatory)][int]$Level)
    $name = "ZI_API_VERSION_$Level"
    if (-not [Enum]::IsDefined([zhinst.ZIAPIVersion_enum], $name)) {
        throw "The installed LabOne API does not support API level $Level."
    }
    return [Enum]::Parse([zhinst.ZIAPIVersion_enum], $name)
}

function Get-NodeMetadata {
    param(
        [Parameter(Mandatory)]$Daq,
        [Parameter(Mandatory)][string]$Path
    )
    $flags = [zhinst.ZIListNodes_enum]::ZI_LIST_NODES_ALL -bor
             [zhinst.ZIListNodes_enum]::ZI_LIST_NODES_ABSOLUTE
    $metadata = $Daq.listNodesJSON($Path, $flags) | ConvertFrom-Json
    $property = @($metadata.psobject.Properties)[0]
    if ($null -eq $property) { throw "Node not found: $Path" }
    return $property.Value
}

function Read-NodeValue {
    param(
        [Parameter(Mandatory)]$Daq,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Metadata,
        [string]$RequestedType = 'auto'
    )
    $nodeType = if ($RequestedType -eq 'auto') { ([string]$Metadata.Type).ToLowerInvariant() } else { $RequestedType }
    switch -Regex ($nodeType) {
        'double' { return $Daq.getDouble($Path) }
        'integer|int64|int32|int' { return $Daq.getInt($Path) }
        'string|byte' { return $Daq.getByte($Path) }
        default { throw "Unsupported scalar node type '$($Metadata.Type)'." }
    }
}

function Set-NodeValue {
    param(
        [Parameter(Mandatory)]$Daq,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$NewValue,
        [Parameter(Mandatory)]$Metadata,
        [string]$RequestedType = 'auto'
    )
    $nodeType = if ($RequestedType -eq 'auto') { ([string]$Metadata.Type).ToLowerInvariant() } else { $RequestedType }
    switch -Regex ($nodeType) {
        'double' { $Daq.setDouble($Path, [double]::Parse($NewValue, [Globalization.CultureInfo]::InvariantCulture)); break }
        'integer|int64|int32|int' { $Daq.setInt($Path, [long]::Parse($NewValue, [Globalization.CultureInfo]::InvariantCulture)); break }
        'string|byte' { $Daq.setByte($Path, $NewValue); break }
        default { throw "Unsupported scalar node type '$($Metadata.Type)'." }
    }
}

Add-Type -Path (Get-LabOneAssemblyPath)
$daq = New-Object zhinst.ziDotNET
$initialized = $false

try {
    if ($Command -eq 'discover') {
        Write-JsonResult ([pscustomobject]@{
            operation = 'discover'
            api_version = $daq.version()
            devices = @(Get-DiscoveryRecords -Daq $daq)
        })
        exit 0
    }

    $record = Select-DiscoveryRecord -Daq $daq -RequestedDevice $Device
    $selectedHost = if ($ServerHost) { $ServerHost } else { $record.server_address }
    $selectedPort = if ($Port) { $Port } else { $record.server_port }
    $selectedApiLevel = if ($ApiLevel) { $ApiLevel } else { $record.api_level }
    $daq.init($selectedHost, [uint16]$selectedPort, (Get-ApiEnum -Level $selectedApiLevel))
    $initialized = $true

    $clientVersion = $daq.version()
    $serverVersion = $daq.getByte('/ZI/ABOUT/VERSION')
    $versionMatch = $clientVersion -eq $serverVersion
    $base = [ordered]@{
        operation = $Command
        device = $record.device
        host = $selectedHost
        port = $selectedPort
        api_level = $selectedApiLevel
        client_version = $clientVersion
        server_version = $serverVersion
        version_match = $versionMatch
    }

    switch ($Command) {
        'status' {
            $base.device_type = $daq.getByte("/$($record.device)/FEATURES/DEVTYPE")
            $base.device_options = $daq.getByte("/$($record.device)/FEATURES/OPTIONS")
            $base.discovery = $record
            Write-JsonResult ([pscustomobject]$base)
        }
        'list' {
            $path = if ($Node) { $Node } else { "/$($record.device)/*" }
            $flags = [zhinst.ZIListNodes_enum]::ZI_LIST_NODES_ALL -bor
                     [zhinst.ZIListNodes_enum]::ZI_LIST_NODES_ABSOLUTE
            $base.path = $path
            $base.nodes = $daq.listNodesJSON($path, $flags) | ConvertFrom-Json
            Write-JsonResult ([pscustomobject]$base)
        }
        'read' {
            if (-not $Node) { throw 'The read command requires -Node.' }
            $metadata = Get-NodeMetadata -Daq $daq -Path $Node
            if ([string]$metadata.Properties -notmatch 'Read') { throw "Node is not readable: $Node" }
            $base.node = $metadata.Node
            $base.metadata = $metadata
            $base.value = Read-NodeValue -Daq $daq -Path $Node -Metadata $metadata -RequestedType $Type
            Write-JsonResult ([pscustomobject]$base)
        }
        'sample' {
            $path = "/$($record.device)/DEMODS/$Demod/SAMPLE"
            $sample = $daq.getDemodSample($path)
            $base.node = $path
            $base.sample = [ordered]@{
                timestamp = $sample.timeStamp
                x = $sample.x
                y = $sample.y
                r = [Math]::Sqrt(($sample.x * $sample.x) + ($sample.y * $sample.y))
                theta_rad = [Math]::Atan2($sample.y, $sample.x)
                frequency_hz = $sample.frequency
                phase_rad = $sample.phase
                aux_in_0 = $sample.auxIn0
                aux_in_1 = $sample.auxIn1
            }
            Write-JsonResult ([pscustomobject]$base)
        }
        'write' {
            if (-not $Node) { throw 'The write command requires -Node.' }
            if ($Node -match '[*?]') { throw 'Wildcard writes are prohibited.' }
            if (-not $PSBoundParameters.ContainsKey('Value')) { throw 'The write command requires -Value.' }
            if (-not $AllowWrite) { throw 'Write blocked: pass -AllowWrite only after explicit user confirmation.' }
            if (-not $ConfirmDevice -or $ConfirmDevice.ToUpperInvariant() -ne $record.device) {
                throw "Write blocked: -ConfirmDevice must exactly match $($record.device)."
            }
            if (-not $versionMatch -and -not $AllowVersionMismatch) {
                throw "Write blocked: LabOne client $clientVersion and server $serverVersion do not match."
            }
            $metadata = Get-NodeMetadata -Daq $daq -Path $Node
            if ([string]$metadata.Properties -notmatch 'Write|Setting') { throw "Node is not writable: $Node" }
            $oldValue = Read-NodeValue -Daq $daq -Path $Node -Metadata $metadata -RequestedType $Type
            Set-NodeValue -Daq $daq -Path $Node -NewValue $Value -Metadata $metadata -RequestedType $Type
            $newValue = Read-NodeValue -Daq $daq -Path $Node -Metadata $metadata -RequestedType $Type
            $base.node = $metadata.Node
            $base.metadata = $metadata
            $base.old_value = $oldValue
            $base.requested_value = $Value
            $base.readback_value = $newValue
            Write-JsonResult ([pscustomobject]$base)
        }
    }
}
catch {
    Write-JsonResult ([pscustomobject]@{
        operation = $Command
        success = $false
        error = $_.Exception.Message
    })
    exit 1
}
finally {
    if ($initialized) {
        try { $daq.disconnect() } catch { }
    }
}
