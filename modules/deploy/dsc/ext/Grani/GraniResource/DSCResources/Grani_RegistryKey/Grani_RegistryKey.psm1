#region Initialize

function Initialize
{
    # Enum for Ensure
    Add-Type -TypeDefinition @"
        public enum EnsureType
        {
            Present,
            Absent
        }
"@ -ErrorAction SilentlyContinue

    # Enum for RegistryRoot
    Add-Type -TypeDefinition @"
        public enum RegistryRoot
        {
            HKEY_CLASSES_ROOT,
            HKEY_CURRENT_CONFIG,
            HKEY_CURRENT_USER,
            HKEY_DYN_DATA,
            HKEY_LOCAL_MACHINE,
            HKEY_PERFORMANCE_DATA,
            HKEY_USERS
        }
"@ -ErrorAction SilentlyContinue

    # Enum for RegistryShortName for PSDrive
    Add-Type -TypeDefinition @"
        public enum RegistryRootPSName
        {
            HKCU,
            HKLM
        }
"@ -ErrorAction SilentlyContinue
    
    $PSRegistryNameToFullName = [PSCustomObject]@{
        [RegistryRootPSName]::HKCU.ToString() = [RegistryRoot]::HKEY_CURRENT_USER
        [RegistryRootPSName]::HKLM.ToString() = [RegistryRoot]::HKEY_LOCAL_MACHINE
    }

    $RegistryNameToRegistryObject = [PSCustomObject]@{
        [RegistryRoot]::HKEY_CLASSES_ROOT.ToString() = [Microsoft.Win32.Registry]::ClassesRoot
        [RegistryRoot]::HKEY_CURRENT_CONFIG.ToString() = [Microsoft.Win32.Registry]::CurrentConfig
        [RegistryRoot]::HKEY_CURRENT_USER.ToString() = [Microsoft.Win32.Registry]::CurrentUser
        [RegistryRoot]::HKEY_DYN_DATA.ToString() = [Microsoft.Win32.Registry]::DynData
        [RegistryRoot]::HKEY_LOCAL_MACHINE.ToString() = [Microsoft.Win32.Registry]::LocalMachine
        [RegistryRoot]::HKEY_PERFORMANCE_DATA.ToString() = [Microsoft.Win32.Registry]::PerformanceData
        [RegistryRoot]::HKEY_USERS.ToString() = [Microsoft.Win32.Registry]::Users
    }
}

. Initialize

#endregion

#region Message Definition

$verboseMessages = Data {
    ConvertFrom-StringData -StringData @"
"@
}

$debugMessages = Data {
    ConvertFrom-StringData -StringData @"
"@
}

$errorMessages = Data {
    ConvertFrom-StringData -StringData @"
"@
}

#endregion

#region *-TargetResource

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Key,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]$Ensure
    )

    # Change Key to Resitry Path Style
    $regPath = ConvertToRegistryFullQualifiedPath -Key $Key;

    # check Registry Key Exists
    if (IsRegistoryPathExists -Path $regPath)
    {
        # exists
        $ensureResult = [EnsureType]::Present.ToString();
    }
    else
    {
        # not exists
        $ensureResult = [EnsureType]::Absent.ToString();
    }

    return $returnValue = @{
        Key = $Key
        Ensure = $ensureResult
    };
}

function Set-TargetResource
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Key,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]$Ensure
    )

    # Change Key to Resitry Path Style
    $regPath = ConvertToRegistryFullQualifiedPath -Key $Key;
    
    if ($Ensure -eq [EnsureType]::Present)
    {
        # Create Registry Key
        SetRegistryKey -Path $regPath;
        return;
    }
    
    # Remove Registry Key
    RemoveRegistryKey -Path $regPath;
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Key,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]$Ensure
    )
    return (Get-TargetResource -Key $Key -Ensure $Ensure).Ensure -eq $Ensure;
}

#endregion

#region Registry Path helper

function IsRegistoryPathExists
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path
    )

    $root = GetRegistryRoot -Path $Path;
    $subkey = $Path -split "$root\\" | Select -Last 1;

    try
    {
        $result = $RegistryNameToRegistryObject.$root.OpenSubKey($subkey, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadSubTree);
        if ($null -eq $result)
        {
            return $false;
        }
        return $true;
    }
    finally
    {
        if ($null -ne $result){ $result.Dispose(); }        
    }
}

function SetRegistryKey
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path
    )

    $root = GetRegistryRoot -Path $Path;
    $subkey = $Path -split "$root\\" | Select -Last 1;
    
    try
    {
        # Create Key - even key contains hoge/piyo.
        $result = $RegistryNameToRegistryObject.$root.CreateSubKey($subkey, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree);
    }
    finally
    {
        if ($null -ne $result){ $result.Dispose(); }
    }
}

function RemoveRegistryKey
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path
    )

    $root = GetRegistryRoot -Path $Path;
    $subkey = $Path -split "$root\\" | Select -Last 1;
    
    try
    {
        $result = $RegistryNameToRegistryObject.$root.DeleteSubKey($subkey, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
    }
    finally
    {
        if ($null -ne $result){ $result.Dispose(); }
    }
}

function GetRegistryRoot
{
    [CmdletBinding()]
    [OutputType([RegistryRoot])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path
    )

    $roots = [enum]::GetNames([RegistryRoot]);
    foreach ($root in $roots)
    {
        if ($Path.ToUpper().Contains($root))
        {
            return [RegistryRoot]::$root;
        }
    }
    throw New-Object System.InvalidOperationException ("Could not retrieve RegistryRoot. Make sure you have passed full-qualified name like HKEY_LOCAL_MACHINE.");
}

#endregion

#region Registry Key helper

function ConvertToRegistryFullQualifiedPath
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Key
    )

    if (IsRegistryKeyRootFullQualified -Key $Key)
    {
        return "registry::{0}" -f $Key;
    }
    elseif (IsRegistryKeyRootPSDrive -Key $Key)
    {
        $fullQualifiedKey = ConvertPSDriveKeyToFullQualifiedKey -PSDriveKey $Key;
        return "registry::{0}" -f $fullQualifiedKey;
    }
    throw New-Object System.NullReferenceException ("Could not convert key '{0}' to FullQualified Key" -f $Key);
}

function ConvertPSDriveKeyToFullQualifiedKey
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$PSDriveKey
    )

    $root = (GetRegistryPSDrive -PSDriveKey $PSDriveKey).ToSTring();
    $result = $PSDriveKey.Replace(":", "").Replace($root.ToString(), $PSRegistryNameToFullName.$root.ToString());
    if ($result -ne $null)
    {
        return $result;
    }
    throw New-Object System.NullReferenceException ("Could not convert key '{0}' to FullQualified Key" -f $PSDriveKey);
}

function GetRegistryPSDrive
{
    [CmdletBinding()]
    [OutputType([RegistryRootPSName])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$PSDriveKey
    )

    $roots = [enum]::GetNames([RegistryRootPSName]);
    foreach ($root in $roots)
    {
        if ($PSDriveKey.ToUpper().Contains($root))
        {
            return [RegistryRootPSName]::$root;
        }
    }
    throw New-Object System.InvalidOperationException ("Could not retrieve RegistryRoot. Make sure you have passed PS Drive like HKLM: .");
}

function IsRegistryKeyRootFullQualified
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Key
    )

    $roots = [enum]::GetNames([RegistryRoot]);
    foreach ($root in $roots)
    {
        if ($Key.ToUpper().Contains($root))
        {
            return $true;
        }
    }
    return $false;
}

function IsRegistryKeyRootPSDrive
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Key
    )

    $roots = [enum]::GetNames([RegistryRootPSName]);
    foreach ($root in $roots)
    {
        if ($Key.ToUpper().Contains($root))
        {
            return $true;
        }
    }
    return $false;
}

#endregion

Export-ModuleMember -Function *-TargetResource
