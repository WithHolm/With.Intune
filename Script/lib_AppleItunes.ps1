Function Find-ItunesApp
{
    [cmdletbinding()]
    param(
    [String]$AppName
    )
    
    $baseurl = "https://itunes.apple.com/search?media=software&"

    $Search = "term=$($search.Replace(' ','+'))"
    $SearchURL = "$baseurl$search"
    $result = Invoke-itunesURL -URL $SearchURL
    foreach($res in $result.results)
    {
        $res.pstypenames.insert(0,'ItunesApp')
        $res
    }
    #$result.results|%{$_.pstypedata.add(0,"ItunesApp")}
}

Function Select-ItunesApp
{
    
}

Function Invoke-itunesURL
{
    [cmdletbinding()]
    param(
    [uri]$URL
    )
    $CC = "country=NO"
    $InvokedURL = "$($URL.OriginalString)&$CC" 
    write-verbose "Trying call for '$InvokedURL'"
    Invoke-RestMethod -Uri "$($URL.OriginalString)&$CC"
}

update-typedata -TypeName ItunesApp -MemberName "Name" -MemberType ScriptProperty -Value {$this.trackCensoredName} -Force
update-typedata -TypeName ItunesApp -MemberName "Devices" -MemberType ScriptProperty -Value {$this.supportedDevices} -Force
update-typedata -TypeName ItunesApp -MemberName "SizeMB" -MemberType ScriptProperty -Value {"$([math]::Round(($this.fileSizeBytes/1mb),1)) MB"} -Force
update-typedata -TypeName ItunesApp -MemberName "Vendor" -MemberType ScriptProperty -Value {$this.sellerName} -Force
update-typedata -TypeName ItunesApp -DefaultDisplayPropertySet "Vendor","name","formattedPrice",SizeMB -Force