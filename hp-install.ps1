<#
.SYNOPSIS
HP Printer install script by Angelo Lombardo @GRSD Amsterdam

.DESCRIPTION
Install HP Printer on a remote pc using the HP Universal PCL6 driver

.PARAMETER remotepc
HOST name or IP address of the remote PC where to install the printer
.PARAMETER port
Printer IP Address
.PARAMETER printerName 
Printer name to show in the installed printer list
.PARAMETER enableBdi
Set to $false if you want to disable the bidirectional printing (set to $false for HP p1606)
.EXAMPLE
./hp-install.ps1 hostpc 10.20.30.40 printername $true
.EXAMPLE
./hp-install.ps1 hostpc 10.20.30.40 printername (Bidirectional enabled by default)

.NOTES
For HP p1606 set the bidirectional to $false

#>
param ([Parameter(Mandatory=$true,HelpMessage="PC host name or address is required")][string]$remotepc,
[Parameter(Mandatory=$true,HelpMessage="Printer's IP Address is required")][string]$port,
[Parameter(Mandatory=$true,HelpMessage="Printer name is required")][string]$printerName, 
[bool]$enableBdi=$true)


Add-Type -assembly "system.io.compression.filesystem"

$DrvName = "HP Universal Printing PCL 6"

$DriverPath = "C:\HP Universal driver\"

$DriverInf = "hpbuio200l.inf"

$errorflag = $false

$spath = Split-Path -Parent $PSCommandPath

$dest = "\\"+ $remotepc + "\c$\"

$destzip = $dest + "hpgeneric.zip"

$destDriverPath = $dest + $DriverPath.SubString($DriverPath.length - 20, 20)

$isDriver =$true
$isPort = $true
$isPrinter = $true

# Unzip function
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    Write-Host "Unzipping..."

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

Function CreatePrinterPort {
    Param ($PrinterIP, $PrinterPort, $PrinterPortName, $Computer)
    $WMI = [WMIClass]"\\$Computer\Root\cimv2:win32_tcpipPrinterPort"
    $WMI.psbase.scope.options.enablePrivileges = $True
    $Port = $WMI.createInstance()
    $Port.name = $PrinterPortName
    $Port.hostAddress = $PrinterIP
    $Port.portNumber = $PrinterPort
    $Port.SNMPEnabled = $False
    $Port.Protocol = 1
    $Port.put()
    }

Function InstallPrinterDriver {
    Param ($DriverName, $DriverPath, $DriverInf, $Computer)
    $WMI = [WMIClass]"\\$Computer\Root\cimv2:Win32_PrinterDriver"
    $WMI.psbase.scope.options.enablePrivileges = $True
    $WMI.psbase.Scope.Options.Impersonation = [System.Management.ImpersonationLevel]::Impersonate
    $Driver = $WMI.CreateInstance()
    $Driver.Name = $DriverName
    $Driver.DriverPath = $DriverPath
    $Driver.InfName = $DriverInf
    $WMI.AddPrinterDriver($Driver)
    $WMI.Put()
    }

Function CreatePrinter {
    Param ($PrinterCaption, $PrinterPortName, $DriverName, $Computer , $EnableBIDI)
    $WMI = ([WMIClass]"\\$Computer\Root\cimv2:Win32_Printer")
    $Printer = $WMI.CreateInstance()
    $Printer.Caption = $PrinterCaption
    $Printer.DriverName = $DriverName
    $Printer.PortName = $PrinterPortName
    $Printer.DeviceID = $PrinterCaption
    $Printer.EnableBIDI = $EnableBIDI
    $Printer.Put()
    }

# Registry patch function    
Function RegistryFix {


        $scriptBlock = { 

            $registryPath = "HKLM:\Software\Policies\Microsoft\Windows NT\Printers"
        
            $Name = "RegisterSpoolerRemoteRpcEndPoint"
        
            $value = "1"
            
            IF(!(Test-Path $registryPath))
        
            {
        
            New-Item -Path $registryPath -Force | Out-Null
        
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        
            }
            ELSE {
            
                New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
            }
            
            Restart-Service -Name Spooler -Verbose -Force
            
            }

    Write-Host "Unable to get the remote spooler, fixing the remote registry..."
    Invoke-Command -ComputerName $remotepc -ScriptBlock $scriptBlock
    Write-Host "Restart the command to install the printer."
}



try {

    Write-Host "Check for installed driver...`r`n"
    $instDriver = Get-PrinterDriver -ComputerName $remotepc -ErrorAction Stop

}
catch {

    RegistryFix
    exit
    
}

foreach ($driver in $instDriver) {
    
    if ($driver.name -contains $DrvName){

        Write-Host $DrvName " already installed! Skip installation..."
        $isDriver = $true
        break
    }

    $isDriver = $false

}


if (!$isDriver){

    Write-Host "`r`rProcessing printer driver " $DrvName " for " $remotepc

    $spath += "\hpgeneric.zip"
    
    try {

        Write-Host "`r`nCopying zipped driver to " $dest

        $testPath = Test-Path -Path $destzip

        if (!$testPath) {

        Copy-Item -Path $spath -Destination $dest

        
        }
        else {

            Write-Host "`r`n" $destzip " already exits, skipping copy `r`n"

        }

        $testPath = Test-Path -Path $destDriverPath

        if (!$testPath){

            Write-Host "`r`nUnzip driver to " $dest

            Unzip $destzip $dest
            
        }
        else {

            Write-Host $destDriverPath " already exits, skipping unzip"

        }
        
        
        Write-Host "`r`nInstalling printer driver " $DrvName " for " $remotepc "`r`n"

        InstallPrinterDriver $DrvName $DriverPath $DriverInf $remotepc
    
    }
    catch {
        Write-Host "Installation failed!`r`n"
        $errorflag = $true
    }

}

try {

    Write-Host "Check for installed port...`r`n"
    $instPort = Get-PrinterPort -ComputerName $remotepc -ErrorAction Stop 

}
catch {

    RegistryFix
    exit
    
}

foreach ($ports in $instPort) {
    
    if ($ports.name -contains $port){
    
        Write-Host "port " $port " already installed! Skip installation..."
        $isPort = $true
        break
    }

    $isPort = $false
}

if (!$isPort){

    Write-Host "Installing port  " $port " for " $remotepc

    try {

        CreatePrinterPort $port 9100 $port $remotepc
    
    }
    catch {
        Write-Host "Installation failed!"
        $errorflag = $true
    }

}


try {

    Write-Host "Check for installed printer..."
    $instPrinter = Get-Printer -ComputerName $remotepc -ErrorAction Stop

}
catch {

    RegistryFix
    exit

}

foreach ($printers in $instPrinter) {
    
    if ($printers.name -contains $printerName){
    
        Write-Host "`r`nprinter " $printerName " already installed! Skip installation..."
        $isPrinter = $true
        break
    }

    $isPrinter = $false
}

if (!$isPrinter){

    Write-Host "`r`nInstalling " $printerName " for " $remotepc

    try {
        
        CreatePrinter -PrinterCaption $printerName -PrinterPortName $port -DriverName $DrvName -Computer $remotepc -EnableBIDI $enableBdi
        
    }
    catch {
        Write-Host "Installation failed!"
        $errorflag = $true
    }
}

if ($errorflag){

    Write-Host "`r`nInstallation completed with errors on  " $remotepc
    

}
else {
Write-Host "`r`nInstallation successfully completed on  " $remotepc
}




