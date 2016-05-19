Filter Get-OUPath {

<#
.SYNOPSIS
	Convert AD object's 'DistinguishedName' property to path-like format.
.DESCRIPTION
	This filter convert Active Directory object's 'DistinguishedName' property to path-like format.
	Active Directory hierarchy view like this: 'Domainname\TopLevelOU\North\HR' or without domain name 'TopLevelOU\North\HR'.
.PARAMETER IncludeDomainName
	If ommited doesn't include Domain Name to the path.
	Useful in multi domain forests.
.PARAMETER ExcludeObjectName
	If ommited include object name in the path.
.PARAMETER UCaseDomainName
	Convert Domain Name to UPPERCASE, otherwise only the capital letter is uppercased.
	contoso -> CONTOSO -> Contoso.
	Does nothing if 'IncludeDomainName' ommited.
.EXAMPLE
	PS C:\> Get-ADUser user1 |Get-OUPath
.EXAMPLE
	PS C:\> Get-ADUser -Filter {SamAccountName -like 'user*'} |select Name,@{N='OUPath';E={$_.DistinguishedName |Get-OUPath}}
	Add calculated property 'OUPath' to existing objects.
	This technique will work with all types of objects (users/computers/groups/OU etc).
.EXAMPLE
	PS C:\> Get-ADGroup -Filter {SamAccountName -like 'hr*'} |select Name,@{N='OUPath';E={$_.DistinguishedName |Get-OUPath -IncludeDomainName}} |ft -au
.EXAMPLE
	PS C:\> Get-ADGroupMember HR |select Name,@{N='OUPath';E={$_.DistinguishedName |Get-OUPath}} |sort OUPath,Name |ft -au
.EXAMPLE
	PS C:\> Get-ADOrganizationalUnit -Filter {Name -like 'North*'} |select @{N='DN';E={$_}},@{N='OUPath';E={$_ |Get-OUPath -IncludeDomainName}} |sort DN
.EXAMPLE
	PS C:\> $DNs = @()
	PS C:\> $DNs += 'CN=User1,OU=HR,OU=Northwest,OU=North,DC=contoso,DC=co,DC=il'
	PS C:\> $DNs += 'CN=User2,CN=Users,DC=contoso,DC=co,DC=il'
	PS C:\> $DNs += 'CN=Server1,CN=Computers,DC=contoso,DC=co,DC=il'
	PS C:\> $DNs += 'OU=Northwest,OU=north,DC=contoso,DC=co,DC=il'
	PS C:\> $DNs += 'OU=TopLevelOU,DC=contoso,DC=co,DC=il'
	PS C:\> $DNs |select @{N='DN';E={$_}},@{N='OUPath';E={$_ |Get-OUPath -IncludeDomainName}}
	These DNs for the different AD object types: User, User in the default 'Users' container, Computer, OU and top level OU.
.EXAMPLE
	PS C:\> Get-ADDomainController -Filter * |Get-OUPath -IncludeDomainName
.INPUTS
	[Microsoft.ActiveDirectory.Management.ADUser[]]               Active Directory user objects, returned by Get-ADUser cmdlet.
	[Microsoft.ActiveDirectory.Management.ADGroup[]]              Active Directory group objects, returned by Get-ADGroup cmdlet.
	[Microsoft.ActiveDirectory.Management.ADPrincipal[]]          Active Directory objects, returned by Get-ADGroupMember cmdlet.
	[Microsoft.ActiveDirectory.Management.ADComputer[]]           Active Directory computer objects, returned by Get-ADComputer cmdlet.
	[Microsoft.ActiveDirectory.Management.ADDomainController[]]   Active Directory DC objects, returned by Get-ADDomainController cmdlet.
	[Microsoft.ActiveDirectory.Management.ADObject[]]             Active Directory objects, returned by Get-ADObject cmdlet.
	[Microsoft.ActiveDirectory.Management.ADOrganizationalUnit[]] Active Directory OU objects, returned by Get-ADOrganizationalUnit cmdlet.
	[System.String[]]                                             Strings that represent any object's 'DistinguishedName' property.
	Or any object that have 'DistinguishedName' property.
.OUTPUTS
	[System.String[]]
	If you use '-ExcludeObjectName' switch without '-IncludeDomainName'
	both the object itself and a domain name are not included in the returned string
	and you will get EMPTY path for TOP LEVEL OU containers.
.NOTES
	Author: Roman Gelman.
	Version 1.0 :: 18-May-2016 :: Release :: This function was fully rewrited from the original 'Get-OUTree'.
.LINK
	https://goo.gl/wOzNOe
#>

Param ([switch]$IncludeDomainName,[switch]$ExcludeObjectName,[switch]$UCaseDomainName)

	If     ($_.GetType().Name -eq 'string')             {$DN = $_}
	ElseIf ($_.GetType().Name -eq 'ADDomainController') {$DN = $_.ComputerObjectDN}
	Else                                                {$DN = $_.DistinguishedName}

	If ($IncludeDomainName)	{
		If ($ExcludeObjectName) {
			### Top level OU ###
			If (($DN -split ',')[1].ToLower().StartsWith('dc=')) {$rgxDN2OU = '(?i)^(cn|ou)=.+?,(?<OUPath>dc=.+?),'}
			### Non top level OU ###
			Else                                                 {$rgxDN2OU = '(?i)^(cn|ou)=.+?,(?<OUPath>(ou=.+?|cn=.+?),dc=.+?),'}
		}
		Else {
			$rgxDN2OU = '(?i)^(?<OUPath>(ou=.+?|cn=.+?),dc=.+?),'
		}
	}
	Else {
		If ($ExcludeObjectName) {$rgxDN2OU = '(?i)^(cn|ou)=.+?,(?<OUPath>ou=.+?|cn=.+?),dc='}
		Else                    {$rgxDN2OU = '(?i)^(?<OUPath>ou=.+?|cn=.+?),dc='}
	}

	Try
		{
			$arrOU = [regex]::Match($DN, $rgxDN2OU).Groups['OUPath'].Value -replace ('ou=|cn=|dc=', $null) -split (',')
			[array]::Reverse($arrOU)
			If ($IncludeDomainName) {
				If ($UCaseDomainName) {$Domain = $arrOU[0].ToUpper()}
				Else                  {$Domain = (Get-Culture).TextInfo.ToTitleCase($arrOU[0])}
				If ($arrOU.Length -gt 1) {return $Domain + '\' + ($arrOU[1..($arrOU.Length-1)] -join ('\'))} Else {return $Domain}
			}
			Else {return $arrOU -join ('\')}
		}
	Catch 
		{return $null}
	
} #EndFilter Get-OUPath

Function Write-Menu {

<#
.SYNOPSIS
	Display custom menu in the PowerShell console.
.DESCRIPTION
	This cmdlet writes numbered and colored menues in the PS console window
	and returns the choiced entry.
.PARAMETER Menu
	Menu entries.
.PARAMETER PropertyToShow
	If your menu entries are objects and not the strings
	this is property to show as entry.
.PARAMETER Prompt
	User prompt at the end of the menu.
.PARAMETER Header
	Menu title (optional).
.PARAMETER Shift
	Quantity of <TAB> keys to shift the menu right.
.PARAMETER TextColor
	Menu text color.
.PARAMETER HeaderColor
	Menu title color.
.PARAMETER AddExit
	Add 'Exit' as very last entry.
.EXAMPLE
	PS C:\> Write-Menu -Menu "Open","Close","Save" -AddExit -Shift 1
	Simple manual menu with 'Exit' entry and 'one-tab' shift.
.EXAMPLE
	PS C:\> Write-Menu -Menu (Get-ChildItem 'C:\Windows\') -Header "`t`t-- File list --`n" -Prompt 'Select any file'
	Folder content dynamic menu with the header and custom prompt.
.EXAMPLE
	PS C:\> Write-Menu -Menu (Get-Service) -Header ":: Services list ::`n" -Prompt 'Select any service' -PropertyToShow DisplayName
	Display local services menu with custom property 'DisplayName'.
.EXAMPLE
      PS C:\> Write-Menu -Menu (Get-Process |select *) -PropertyToShow ProcessName |fl
      Display full info about choicen process.
.INPUTS
	[string[]] [pscustomobject[]] or any!!! type of array.
.OUTPUTS
	[The same type as input object] Single menu entry.
.NOTES
	Author       ::	Roman Gelman.
	Version 1.0  ::	21-Apr-2016  :: Release.
.LINK
	http://goo.gl/MgLch1
#>

[CmdletBinding()]

Param (

	[Parameter(Mandatory,Position=0)]
		[Alias("MenuEntry","List")]
	$Menu
	,
	[Parameter(Mandatory=$false,Position=1)]
	[string]$PropertyToShow = 'Name'
	,
	[Parameter(Mandatory=$false,Position=2)]
		[ValidateNotNullorEmpty()]
	[string]$Prompt = 'Pick a choice'
	,
	[Parameter(Mandatory=$false,Position=3)]
		[Alias("MenuHeader")]
	[string]$Header = ''
	,
	[Parameter(Mandatory=$false,Position=4)]
		[ValidateRange(0,5)]
		[Alias("Tab","MenuShift")]
	[int]$Shift = 0
	,
	#[Enum]::GetValues([System.ConsoleColor])
	[Parameter(Mandatory=$false,Position=5)]
		[ValidateSet("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta",
		"DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")]
		[Alias("Color","MenuColor")]
	[string]$TextColor = 'White'
	,
	[Parameter(Mandatory=$false,Position=6)]
		[ValidateSet("Black","DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta",
		"DarkYellow","Gray","DarkGray","Blue","Green","Cyan","Red","Magenta","Yellow","White")]
	[string]$HeaderColor = 'Yellow'
	,
	[Parameter(Mandatory=$false,Position=7)]
		[ValidateNotNullorEmpty()]
		[Alias("Exit","AllowExit")]
	[switch]$AddExit
)

Begin {

	$ErrorActionPreference = 'Stop'
	If ($Menu -isnot 'array') {Throw "The menu entries must be array or objects"}
	If ($AddExit) {$MaxLength=8} Else {$MaxLength=9}
	If ($Menu.Length -gt $MaxLength) {$AddZero=$true} Else {$AddZero=$false}
	[hashtable]$htMenu = @{}
}

Process {

	### Write menu header ###
	If ($Header -ne '') {Write-Host $Header -ForegroundColor $HeaderColor}
	
	### Create shift prefix ###
	If ($Shift -gt 0) {$Prefix = [string]"`t"*$Shift}
	
	### Build menu hash table ###
	For ($i=1; $i -le $Menu.Length; $i++) {
		If ($AddZero) {
			If ($AddExit) {$lz = ([string]($Menu.Length+1)).Length - ([string]$i).Length}
			Else          {$lz = ([string]$Menu.Length).Length - ([string]$i).Length}
			$Key = "0"*$lz + "$i"
		} Else {$Key = "$i"}
		$htMenu.Add($Key,$Menu[$i-1])
		If ($Menu[$i] -isnot 'string' -and ($Menu[$i-1].$PropertyToShow)) {
			Write-Host "$Prefix[$Key] $($Menu[$i-1].$PropertyToShow)" -ForegroundColor $TextColor
		} Else {Write-Host "$Prefix[$Key] $($Menu[$i-1])" -ForegroundColor $TextColor}
	}
	If ($AddExit) {
		[string]$Key = $Menu.Length+1
		$htMenu.Add($Key,"Exit")
		Write-Host "$Prefix[$Key] Exit" -ForegroundColor $TextColor
	}
	
	### Pick a choice ###
	Do {
		$Choice = Read-Host -Prompt $Prompt
		If ($AddZero) {
			If ($AddExit) {$lz = ([string]($Menu.Length+1)).Length - $Choice.Length}
			Else          {$lz = ([string]$Menu.Length).Length - $Choice.Length}
			If ($lz -gt 0) {$KeyChoice = "0"*$lz + "$Choice"} Else {$KeyChoice = $Choice}
		} Else {$KeyChoice = $Choice}
	} Until ($htMenu.ContainsKey($KeyChoice))
}

End {return $htMenu.get_Item($KeyChoice)}

} #EndFunction Write-Menu

Export-ModuleMember -Alias '*' -Function '*'
