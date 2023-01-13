@{
  RootModule           = 'PS_Mirth.psm1'
  ModuleVersion        = '1.3.1'
  PowerShellVersion    = "6.0"
  RequiredAssemblies   = @('Microsoft.PowerShell.Commands.Utility.dll')
  GUID                 = '6b42c995-67da-4139-be79-597a328056cc'
  Author               = 'Andrew Hart'
  CompanyName          = 'DataSprite'
  Copyright            = '(c) 2020 DataSprite. All rights reserved.'
  Description          = 'Provides a PowerShell wrapper for the Mirth RESTful API.'
  FunctionsToExport    = @("*-Mirth*", "*-PSMirth*", "*-PSConfig", "*Completer")
  CmdletsToExport      = @()
  VariablesToExport    = @()
  AliasesToExport      = '*'
  DscResourcesToExport = @()
}