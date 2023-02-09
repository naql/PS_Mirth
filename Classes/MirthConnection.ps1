# The custom MirthConnection object is created and returned by Connect-Mirth.
# All of the other functions which make calls to the Mirth REST API will require one.
# (It is not mandatory because they are designed to work in an "interactive" manner.
#  When omitted, the dynamically scoped $currentConnection variable is used as the 
#  default.)
#
# New-Object -TypeName MirthConnection -ArgumentList $session, $serverUrl, $userName
class MirthConnection {
    [ValidateNotNullOrEmpty()][Microsoft.PowerShell.Commands.WebRequestSession]$session
    [ValidateNotNullOrEmpty()][string]$serverUrl
    [ValidateNotNullOrEmpty()][string]$username

    MirthConnection($session, $serverUrl, $username) {
        $this.session = $session
        $this.serverUrl = $serverUrl
        $this.username = $username
    }

    [String] ToString() {
        return "MirthConnection" + ":" + $this.serverUrl + ":" + $this.username
    }
}