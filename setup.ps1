function isInAdmin {
    $UID = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $UID.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (isInAdmin)) {
    Start-Process powershell.exe -ArgumentList "-NoExit -File ""$($MyInvocation.MyCommand.Path)""" -Verb RunAs
    exit 0
}
winget dsc main.dsc.yaml --accept-configuration-agreements