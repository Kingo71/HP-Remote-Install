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
.EXAMPLE
./hp-install.ps1 hostpc 10.20.30.40 printername 
.EXAMPLE
./hp-install.ps1 hostpc 10.20.30.40 printername 



#>
param ([Parameter(Mandatory=$true,HelpMessage="PC host name or address is required")][string]$remotepc,
[Parameter(Mandatory=$true,HelpMessage="Printer's IP Address is required")][string]$port,
[Parameter(Mandatory=$true,HelpMessage="Printer name is required")][string]$printerName)


$DrvName = "HP Universal Printing PCL 6"

$DriverPath = "C:\HP Universal driver\"

$DriverInf = "hpcu215u.inf"

$portname = $port + "_"

$errorflag = $false

$spath = Split-Path -Parent $PSCommandPath

$dest = "\\"+ $remotepc + "\c$\"

$destzip = $dest + "hpgeneric.zip"

$destDriverPath = $dest + $DriverPath.SubString($DriverPath.length - 20, 20)

$infPath = $DriverPath + $DriverInf

$isDriver =$true
$isPort = $true
$isPrinter = $true

# Unzip function
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    Write-Host "Unzipping..."

    Invoke-Command -ComputerName $remotepc {
        Add-Type -assembly "system.io.compression.filesystem"
        [System.IO.Compression.ZipFile]::ExtractToDirectory($using:zipfile, $using:outpath)}
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
    Param ($PrinterCaption, $PrinterPortName, $DriverName, $Computer)
    $WMI = ([WMIClass]"\\$Computer\Root\cimv2:Win32_Printer")
    $Printer = $WMI.CreateInstance()
    $Printer.Caption = $PrinterCaption
    $Printer.DriverName = $DriverName
    $Printer.PortName = $PrinterPortName
    $Printer.DeviceID = $PrinterCaption
    $Printer.Put()
    }
Function PortCheck {
        Param ($Computer, $ckportname)
        Write-Host "Check for installed port..."
        $instPort = Get-PrinterPort -ComputerName $Computer -ErrorAction Stop 
            
        foreach ($ports in $instPort) {
            
            if ($ports.name -contains $ckportname){
            
                Write-Host "port " $ckportname " already installed! Skip installation...`r`n"
                return $true
            }
    
        }
    
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

    Write-Host "Check for installed printer..."
    $instPrinter = Get-Printer -ComputerName $remotepc -ErrorAction Stop

}
catch {

    RegistryFix
    exit

}

foreach ($printers in $instPrinter) {
    
    if ($printers.name -contains $printerName){
    
        Write-Host " printer " $printerName " already installed! Exit installation..."
        $isPrinter = $true
        exit 
    }

    $isPrinter = $false
}

try {

    Write-Host "Check for installed driver..."
    $instDriver = Get-PrinterDriver -ComputerName $remotepc -ErrorAction Stop

}
catch {

    RegistryFix
    exit
    
}

foreach ($driver in $instDriver) {
    
    if ($driver.name -contains $DrvName){

        Write-Host $DrvName " already installed! Skip installation...`r`n"
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
        Write-Host "`r`nDone!`r`n"
        
        }
        else {

            Write-Host "`r`n" $destzip " already exits, skipping copy `r`n"

        }

        $testPath = Test-Path -Path $destDriverPath

        if (!$testPath){

            Write-Host "`r`nUnzip driver to " $dest

            Unzip $destzip $dest
            Write-Host "`r`nDone!`r`n"
            
        }
        else {

            Write-Host $destDriverPath " already exits, skipping unzip"

        }
        
        
        Write-Host "`r`nInstalling printer driver " $DrvName " for " $remotepc "`r`n"
        
        # Invoke-Command -ComputerName $remotepc {pnputil.exe -a "C:\HP Universal driver\hpcu215u.inf" }
        Invoke-Command -ComputerName $remotepc {pnputil.exe -a $using:infPath}
        add-printerdriver -computername $remotepc -name $DrvName
        Write-Host "`r`nDone!`r`n"
        # InstallPrinterDriver $DrvName $DriverPath $DriverInf $remotepc
    
    }
    catch {
        Write-Host "Installation failed!`r`n"
        $errorflag = $true
    }

}

$isPort = PortCheck $remotepc $portname

if (!$isPort) {
    
    Write-Host "Installing port  " $portname " for " $remotepc

    try {

        #CreatePrinterPort $port 9100 $port $remotepc
        Add-PrinterPort -ComputerName $remotepc -Name $portname -PrinterHostAddress $port
        Write-Host "`r`nDone!`r`n"
        
    }
    catch {
        Write-Host "Installation failed!"
        $errorflag = $true
    }

}


if (!$isPrinter){

    Write-Host "`r`nInstalling " $printerName " for " $remotepc

    try {
        
        CreatePrinter -PrinterCaption $printerName -PrinterPortName $portname -DriverName $DrvName -Computer $remotepc
        Write-Host "`r`nDone!`r`n"
        #Add-Printer -Name $printerName -DriverName $DrvName -PortName $portname
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




