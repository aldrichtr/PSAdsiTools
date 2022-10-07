
class ADPerson {
    [string]$displayName
    [string]$distinguishedName
    [string]$sAMAccountName
    [AdAccountControl]$userAccountControl
    [datetime]$lastLogonTimestamp
    [datetime]$accountExpires
    [timespan]$passwordAge
    [datetime]$passwordLastSet
    [string[]]$memberOf
    [datetime]$lockoutTime
}
