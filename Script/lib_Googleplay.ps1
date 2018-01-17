##Philip Meholm

function get-GPlaystoreHTML
{
    [cmdletbinding()]
    param(
    [String]$URL
    )

    $url += "&hl=en" #Get English language

    write-verbose "Fetching '$url'"
    $response = $(invoke-webrequest $url)
    return $response.ParsedHtml.body.innerHTML
}

Function list-GPlaystoreSearch
{
    [cmdletbinding()]
    param(
    [uri]$URL
    )

    #Load HTML Agility Pack
    $dll = Get-ChildItem -Filter "htmlagilitypack.dll" -Recurse -Path $PSScriptRoot|select -First 1

    #$dllpath = "C:\Users\phimegol\Documents\WindowsPowerShell\Modules\PIntune\Script\Lib"
    #[System.Reflection.Assembly]::UnsafeLoadFrom("$dllpath\HtmlAgilityPack.dll")
    add-type -Path $dll.fullname

    #Instanciate AgilityPack and load html to it
    $HTMLDocument = new-object HtmlAgilityPack.HtmlDocument
    $HTMLDocument.LoadHtml((get-GPlaystoreHTML -URL $URL))

    #Get Objects that have the class 'card-content id-track-click id-track-impression'
    $DisplayCards = $HTMLDocument.DocumentNode.SelectNodes('//div').where({$_.Attributes.Contains("class") -and $_.Attributes["class"].Value.Contains("card-content id-track-click id-track-impression")})

    #Test select first object
    foreach ($Thiscard in $DisplayCards)
    {
        #get Thiscard as documentnode (easier searching on all subelements)
        $ThisCardDocNode = new-object HtmlAgilityPack.HtmlDocument
        $ThisCardDocNode.LoadHtml($thiscard.innerHTML)

        $BaseURL = "https://play.google.com"

        #Get IMGurl (type:'img' , class:'cover-image').attribute.'data-cover-small'.value
        $CardimgUrl = "$($ThisCardDocNode.DocumentNode.SelectSingleNode("//img [contains(@class,'cover-image')]").Attributes|?{$_.name -eq 'data-cover-small'}|select -ExpandProperty value)"
        if(!$CardimgUrl.StartsWith("http"))
        {
            $CardimgUrl = "http:$CardimgUrl"
        }

        $cardSystemName = $ThisCardDocNode.DocumentNode.SelectSingleNode("//span [contains(@class,'preview-overlay-container')]").Attributes|?{$_.Name -eq "data-docid"}|select -ExpandProperty value

        #Get URL (type:'a', class:'card-click-target').attribute.'href'.value        
        $CardUrl = "$BaseURL$($ThisCardDocNode.DocumentNode.SelectSingleNode("//a [contains(@class,'card-click-target')]").Attributes|?{$_.name -eq 'href'}|select -ExpandProperty value)"

        #Get Title (type:'a', class:'title').attribute.'title'.value
        $CardTitle = $ThisCardDocNode.DocumentNode.SelectSingleNode("//a [contains(@class,'title')]").Attributes|?{$_.name -eq 'title'}|select -ExpandProperty value

        #Get Vendor (type:'a', class:'subtitle').attribute.'title'.value
        $CardVendor = $ThisCardDocNode.DocumentNode.SelectSingleNode("//a [contains(@class,'subtitle')]").Attributes|?{$_.name -eq 'title'}|select -ExpandProperty value

        #Get Short Description (type:'div', class:'description').childnodes['#text'].text
        $CardShortDesc = $ThisCardDocNode.DocumentNode.SelectSingleNode("//div [contains(@class,'description')]").ChildNodes|where{$_.Name -eq '#text'}|select -ExpandProperty text

        #Get price (type:'div', class:'display-price').childnodes['#text'].text
        $CardPrice = $ThisCardDocNode.DocumentNode.SelectSingleNode("//span [contains(@class,'display-price')]").ChildNodes|where{$_.Name -eq '#text'}|select -ExpandProperty text

        try
        {
            #Get Rating (type:'div', class:'display-price').childnodes['#text'].text
            $CardRating = $ThisCardDocNode.DocumentNode.SelectSingleNode("//div [contains(@class,'tiny-star star-rating-non-editable-container')]").Attributes|?{$_.name -eq 'aria-label'}|select -ExpandProperty value
            
            #replace "app go 4.0 start out of five"
            $CardRating = ($CardRating.Replace('.','').Replace(',','') -replace '\D+(\d+)\D+','$1').substring(0,1)
            $CardRating += "/5"
        }
        catch
        {
            $CardRating = "N/A"
        }
        $return = [pscustomobject]@{
                                            Type = "Application"
                                            Image = $CardimgUrl
                                            Url = $CardUrl
                                            Title = $CardTitle
                                            sellerName = $CardVendor
                                            ShortDesc = $CardShortDesc
                                            Price = $CardPrice
                                            Rating = $CardRating
                                            SystemName = $cardSystemName
                                        }
        $return.pstypenames.insert(0,"GPlayApp")
        $return
    }
}

Function Find-GPlayStoreApp
{
    [cmdletbinding()]
    param(
        [String]$Name,
        [String]$Vendor,
        [int]$Maxresult = 50
    )

    $PSList = list-GPlaystoreSearch -URL "https://play.google.com/store/search?&q=$Name&c=apps"
    Write-Verbose "$(@($PSList).count) results; Filtering on name like '*$name*'"
    $PSList = $PSList|? systemname -like "*$name*"
    Write-Verbose "$(@($PSList).count) results; setting maxresults = $maxresult"
    $pslist = $PSList|select -first $Maxresult
    #|where{$_.title -eq "*$name*"}|select -First $Maxresult

    if(![String]::IsNullOrEmpty($Vendor))
    {
        $PSList = $PSList |where{$_.vendor -like "$vendor"}
    }

    $PSList
}

Function Import-GplayPictures
{
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
            $GPlayApp,
        [String]$path = $pwd.Path,
        [Switch]$png
        )

    begin
    {
        if(!(test-path $path))
        {
            [void](New-Item -Path $path -Force -ItemType directory -ErrorAction SilentlyContinue)
        }
    }
    process
    {
        #$GPlayApp
        if(($GPlayApp.pstypenames) -contains "GPlayApp")
        {
            try
            {
                $filename = $(join-path $path $GPlayApp.systemname)
                if($jpeg)
                {
                    Invoke-WebRequest $GPlayApp.image -OutFile "$filename.jpg" 
                }
                else
                {
                    Invoke-WebRequest $GPlayApp.image -OutFile "$filename.png" 
                }
                write-host "Downloaded image for'$($GPlayApp.systemname)'"
            }
            catch
            {
                write-error "URL: $($GPlayApp.systemname), $_"
            }          
        }
    }

}

update-typedata -TypeName GPlayApp -DefaultDisplayPropertySet Image,Title,Url,Vendor,ShortDesc,Price,Rating,SystemName -Force