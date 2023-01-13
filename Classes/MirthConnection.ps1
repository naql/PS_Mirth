# The custom MirthConnection object is created and returned by Connect-Mirth.
# All of the other functions which make calls to the Mirth REST API will require one.
# (It is not mandatory because they are designed to work in an "interactive" manner.
#  When omitted, the dynamically scoped $currentConnection variable is used as the 
#  default.)
#
# New-Object -TypeName MirthConnection -ArgumentList $session, $serverUrl, $userName, $userPass
class MirthConnection {
    [ValidateNotNullOrEmpty()][Microsoft.PowerShell.Commands.WebRequestSession]$session
    [ValidateNotNullOrEmpty()][string]$serverUrl
    [ValidateNotNullOrEmpty()][string]$userName
    [ValidateNotNullOrEmpty()][securestring]$userPass

    MirthConnection($session, $serverUrl, $userName, $userPass) {
        $this.session = $session
        $this.serverUrl = $serverUrl
        $this.userName = $userName
        $this.userPass = $userPass
    }

    [String] ToString() {
        return "MirthConnection" + ":" + $this.serverUrl + ":" + $this.userName + ":" + $this.userPass
    }
}