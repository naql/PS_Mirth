# PS_Mirth
PowerShell wrapper for the Mirth REST API

This is a PowerShell 5.1 module which provides cmdlets that make calls to the various REST API endpoints of a Mirth Connect.
Using these commands, it is the intention of this project that you can do everything possible in the Mirth CLI and more.

Background
----------

I worked on a project where a mirth 3.6 based application was installed on windows servers using a powershell based script.  The install script used the MirthCLI and a text file of cli commands to import channels, code templates libraries, etc, for this mirth based application.  

This meant that the install was limited to the features of the Mirth CLI:  groups could not be imported, channel tags only set when imported with a channel, basic server settings omitted.  Furthermore, the application used the commercial SSL Manager extension, and keystores could not be configured as part of the install.

Working in a Windows environment, I had some interest in learning PowerShell, and I wanted to improve our installation process.  So this project combined both goals.  It is a PowerShell learning project with a practical application.

In addition to learning PowerShell syntax and programming, this project serves to document the use of the Mirth REST API, a murky, poorly documented, but powerful, aspect to Mirth Connect.

Installation
-------------
Download the PS_Mirth.psm1 module file.

If youi have Windows 10 with PowerShell 5.1 features installed, usage is simple.  

    To install a module folder:

        1. Create a Modules directory for the current user if one does
           not exist.

           To create a Modules directory, type:

               New-Item -Type Directory -Path $home\Documents\WindowsPowerShell\Modules

        2. Copy the entire module folder into the Modules directory. If you download a zip of the project, be 
           sure to rename the extracted folder to "PS_Mirth".  So, the entire pathname would be:
           $home\Documents\WindowsPowerShell\Modules\PS_Mirth

           You can use any method to copy the folder, including Windows
           Explorer and Cmd.exe, as well as Windows PowerShell.
                      In Windows PowerShell use the Copy-Item cmdlet. For example, to copy the
           MyModule folder from C:\ps-test\MyModule to the Modules directory, type:

               Copy-Item -Path c:\ps-test\MyModule -Destination $home\Documents\WindowsPowerShell\Modules

    You can install a module in any location, but installing your modules in a
    default module location makes them easier to manage. For more information about
    the default module locations, see the "MODULE AND DSC RESOURCE LOCATIONS,
    AND PSMODULEPATH" section.
           
Usage
-------------
The cmdlets are intended to be used in conjunction with each other and from client powershell scripts.  They may be used in an interactive manner in a powershell terminal;  when a connection has been made, a session variable is available by default to all of the commands.

From a powershell terminal type:  

    Import-Module PS_Mirth
    
You should see the current PS_Mirth output folder displayed when the module is imported.  This will generally be a new folder path called PS_Mirth_Output under the current working directory, and will be created when a PS_Mirth cmdlet saves output using the -saveXML switch.

A session is obtained by using the Connect-Mirth command:

    -serverUrl https://localhost:8443 -user admin -userPass admin
    
If no parameters are provided, the defaults are as above, the same as a default Mirth installation.

You can also pipe a connection into commands:

    Connect-Mirth | Get-MirthSeverConfig -saveXML -outFile myServerBackup.xml 
    
 At this point, you can play with various commands.  By default, PS_Mirth is verbose.  This was because it is also intended as a tool to explore the Mirth API and the responses that it sends. If you wish to suppress this, use the -quiet flag on all commands.  This is an administrative tool.  Be aware that there are some commands which could be considered "dangerous" in that they will apply changes en masse to all channels. 
 
 PowerShell is self-documenting.  Use the Get-Help command to see how to use the various commands and to see examples.
 
 
