@{
  RootModule = 'PS_Mirth.psm1'
  ModuleVersion = '1.2.0'
  PowerShellVersion = "6.0"
  GUID = '6b42c995-67da-4139-be79-597a328056cc'
  Author = 'Andrew Hart'
  CompanyName = 'DataSprite'
  Copyright = '(c) 2020 DataSprite. All rights reserved.'
  Description = 'Provides a PowerShell wrapper for the Mirth RESTful API.'
  FunctionsToExport = @("*-Mirth*", "*-PSMirth*", "*-SkipCertificateCheck")
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  DscResourcesToExport = @()
}