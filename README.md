# HP-Remote-Install
Powershell script to remote install HP Printers with Generic PCL6 driver



get-help .\hp-install.ps1 -detailed

NAME
    hp-install.ps1

SYNOPSIS
    HP Printer install script by Angelo Lombardo @GRSD Amsterdam


SYNTAX
    ./hp-install.ps1 [-remotepc] <String> [-port] <String> [-printerName] <Strin
    [[-enableBdi] <Boolean>] [<CommonParameters>]


DESCRIPTION
    Install HP Printer on a remote pc using the HP Universal PCL6 driver


PARAMETERS
    -remotepc <String>
        HOST name or IP address of the remote PC where to install the printer

    -port <String>
        Printer IP Address

    -printerName <String>
        Printer name to show in the installed printer list

    -enableBdi <Boolean>
        Set to $false if you want to disable the bidirectional printing (set to $false for HP p1606)

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS C:\>./hp-install.ps1 hostpc 10.20.30.40 printername $true






    -------------------------- EXAMPLE 2 --------------------------

    PS C:\>./hp-install.ps1 hostpc 10.20.30.40 printername (Bidirectional enabled by default)






REMARKS
    To see the examples, type: "get-help hp-install.ps1 -examples".
    For more information, type: "get-help hp-install.ps1 -detailed".
    For technical information, type: "get-help hp-install.ps1 -full".

