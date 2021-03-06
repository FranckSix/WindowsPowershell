param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    $username
)

begin {
	# see http://www.sapienpress.com/downloads/ADChap5_secure.pdf
	function ConvertTo-ADSLargeInteger {
	param (
		[object]$adsLargeInteger
	)
		$highPart = $adsLargeInteger.GetType().InvokeMember('HighPart', 'GetProperty', $null, $adsLargeInteger, $null)
		$lowPart = $adsLargeInteger.GetType().InvokeMember('LowPart', 'GetProperty', $null, $adsLargeInteger, $null)
		$bytes = [System.BitConverter]::GetBytes($HighPart)
		$tmp = [System.Byte[]]@(0,0,0,0,0,0,0,0)
		[System.Array]::Copy($bytes, 0, $tmp, 4, 4)
		$highPart = [System.BitConverter]::ToInt64($tmp, 0)
		$bytes = [System.BitConverter]::GetBytes($lowPart)
		$lowPart = [System.BitConverter]::ToUInt32($bytes, 0)

		$lowPart + $highPart
	}

	[void] (Import-Assembly System.DirectoryServices)

	$dsroot = new-object System.DirectoryServices.DirectoryEntry('LDAP://DTC')
	$searcher = new-object System.DirectoryServices.DirectorySearcher
}

process {
	$searcher.Filter = "(&(objectClass=User)(samaccountname=$username))"
	[void] $searcher.PropertiesToLoad.Add('pwdlastset')
	[void] $searcher.PropertiesToLoad.Add('memberOf')

	$result = $searcher.FindOne()

	$output = New-Object PSObject

	$pwdLastSet = [DateTime]::FromFileTimeUtc($result.Properties['pwdlastset'][0])
	$isLocked = ($result.Properties['lockoutTime'].Count -ge 0 -and $result.Properties['lockoutTime'][0] -ne 0)
	$maxpwdageValue = (ConvertTo-ADSLargeInteger $dsroot.maxpwdage.value)
	$maxpwdage = ($maxpwdageValue / -864000000000)
	$pwdExpireDate = [DateTime]::FromFileTimeUtc($result.Properties['pwdlastset'][0] - $maxpwdageValue)
	$isExpired = [DateTime]::Compare([DateTime]::UtcNow, $pwdExpireDate) -ge 0

	$output |
		Add-Member NoteProperty UserName $username -pass | 
		Add-Member NoteProperty PasswordLastSet $pwdLastSet -pass |
		Add-Member NoteProperty IsLocked $isLocked -pass |
		Add-Member NoteProperty IsExpired $isExpired -pass |
		Add-Member NoteProperty PasswordExpiration $pwdExpireDate -pass | 
		Add-Member NoteProperty MaxPasswordAge $maxpwdage

	$output
}

end {}
