Function Write-Log
{
    [cmdletbinding()]
    Param(
        [String]$Outpath,
        [String]$LogText = "",
        [String]$Type = "",
        [String]$component = "",
        [String]$context = "",
        [String]$thread = "",
        [Datetime]$Time,
        [String]$file = ""
    )

    if($time -ne $null)
    {
        $timeString = $Time.ToString('HH-mm-ss.ffff').Replace("-",":")
        $datestring = $Time.Date.ToString('M-d-yyyy')
    }
    else
    {
        $timeString = ""
        $datestring = ""
    }

    $typeint = 0
    switch ($type)
    {
        'Error' {$typeint = 3}
        'Warning' {$typeint = 2}
        Default {$typeint = 1}
    }

    $TexToFile =  "<![LOG[$LogText]LOG]!>" +` 
        "<time=`"$timeString`" " +` 
        "date=`"$datestring`" " +` 
        "component=`"$component`" " +` 
        "context=`"$context`" " +` 
        "type=`"$typeint`" " +` 
        "thread=`"$thread`" " +` 
        "file=`"$file`">" 
    #return $TexToFile    
    "$TexToFile".Trim() | Out-File -FilePath $Outpath -Append -Encoding utf8 -ErrorAction SilentlyContinue
}

Function NOTINUSEConvertFrom-IntuneLogs
{
    param(
        [Parameter(ValueFromPipeline=$true)]
            $Path,
            [Switch]$Async
    )
    begin
    {
        if($Async)
        {
            Get-Job|Stop-Job
            Get-Job|Remove-Job
        }
    }
    process
    {
        $string = ""
        if($Path.gettype().name -eq "FileInfo")
        {
            $string = $Path.FullName
        }
        elseif($Path.gettype().name -eq "String")
        {
            $string = $Path
        }

        if($string.EndsWith('.log') -and ((split-path $path -Leaf) -notlike "Processed*"))
        {

            if ($Async)
            {
                $string
                $sb = {
                            param($path)
                            Get-Content $path | `
                                %{$lines = $_.split('	');if (@($lines).count -gt 5){"<![LOG[$($lines[6])]LOG]!> <time=`"$([datetime]::Parse($lines[0]))`" date=`"$([datetime]::Parse($lines[0]))`" component=`"$($lines[3])`" context=`"$($lines[2].Trim())`" type=`"$($lines[6])`" thread=`"$($lines[4].Trim())`" file=`"$($lines[6])`">"}else{"$line"}}|`
                                out-file (join-path $(split-path $path -Parent) "Processed-$(split-path $path -leaf)") -Append -Encoding utf8
                    }
                start-job -Name "Convert $(Split-Path $string -Leaf)" -ScriptBlock $sb -ArgumentList $string
            }
            else
            {
                $string
                try-Convert -path $string
            }
        }
    }
    end
    {
        Get-Job | Wait-Job
        get-job | receive-job
    }

}

function async-convert
{
    param($path)
    Get-Content $path | `
        %{$lines = $line.split('	');if (@($lines).count -gt 5){"<![LOG[$($lines[6])]LOG]!> <time=`"$([datetime]::Parse($lines[0]))`" date=`"$($lines[6])`" component=`"$($lines[3])`" context=`"$($lines[2].Trim())`" type=`"$($lines[6])`" thread=`"$($lines[4].Trim())`" file=`"$($lines[6])`">"}else{"$line"}}|`
        out-path (join-path $(split-path $path -Parent) "Processed-$(split-path $path -leaf)")
}

function try-Convert
{
    param($path)
    Get-Content $path | 
    if((split-path $path -Leaf) -notlike "Processed*")
    {
        $Filename = (split-path $path -Leaf)
        $Newname = $path.Replace($Filename,"PROCESSED-$($Filename)")
    
        $AllLines = Get-Content $path
        $count = 0
        foreach($line in $AllLines)
        {
                
            Write-Progress -Activity "Reading $Filename" -Status "$count/$(@($AllLines).count)" -PercentComplete $(($count/@($AllLines).count)*100)
            $lines = $line.split('	')

            try
            {
                Write-Log -Outpath $Newname -LogText $lines[6].Trim() -Type $lines[1].Trim() -component $lines[3].Trim() -context $lines[2].Trim() -thread $lines[4].Trim() -Time ([datetime]::Parse($lines[0])) -file $item.Name -ErrorAction Stop
            }
            catch
            {
                Write-Log -Outpath $Newname -LogText $line.Trim()
            }
            $count++
        }
    }
}

function Convert-IntuneLogs
{
    param(
    [String]$Logpath
    )
    $items = Get-ChildItem $Logpath -Filter "*.log"
    
    Write-Output "This will process $(@($items).count) items."
    $a = Read-Host "Continue? (y/n)"
    if ($a -match "n|no|nei")
    {
        return "Aborting.."
    }
    cls
    Write-Output "" "" "" "" "" "" ""
    $itemcount = 0
    foreach($item in $items)
    {  
        [Boolean]$iOSLog = $false
        $itemcount++
        if($item.Name -notlike "Processed*")
        {
            
            $Newname = $item.FullName.Replace($item.Name,"PROCESSED-$($item.Name)")            
            $AllLines = Get-Content $item.fullname
            $AllProcessedLines = @()
            $count = 0
            if($($AllLines[0..3] -like "*SSP States*") -ne $null)
            {
                $iOSLog = $true
                $sspstate = $false
            }

            if($iOSLog)
            {
                $LogtypeString = "iOS"
            }
            else
            {
                $LogtypeString = "Android"
            }

            Write-Host "($itemcount/$(@($items).count))Processing $item. $($AllLines[0].split('	').Count) columns"
            foreach($line in $AllLines|where{![String]::IsNullOrWhiteSpace($_)})
            {               
                Write-Progress -Activity "($LogtypeString) Reading $($item.name)" -Status "$count/$(@($AllLines).count)" -PercentComplete $(($count/@($AllLines).count)*100)                
                #Android Flow
                if($iOSLog = $false)
                {
                    $lines = $line.split('	')
                    try
                    {
                    
                        $date = ([datetime]::Parse($lines[0]))
                        $timeString = $date.ToString('HH-mm-ss.ffff').Replace("-",":")
                        $datestring = $date.Date.ToString('M-d-yyyy')

                        $AllProcessedLines += "<![LOG[$($lines[6].Trim())]LOG]!>" +` 
                                                "<time=`"$($timeString)`" " +` 
                                                "date=`"$($datestring)`" " +` 
                                                "component=`"$($lines[3].Trim())`" " +` 
                                                "context=`"$($lines[2].Trim())`" " +` 
                                                "type=`"$($lines[1].Trim())`" " +` 
                                                "thread=`"$($lines[4].Trim())`" " +` 
                                                "file=`"$file`">".Trim()
                        #Write-Log -Outpath $Newname -LogText $lines[6].Trim() -Type $lines[1].Trim() -component $lines[3].Trim() -context $lines[2].Trim() -thread $lines[4].Trim() -Time ([datetime]::Parse($lines[0])) -file $item.Name -ErrorAction Stop
                    }
                    catch
                    {
                        #Write-Log -Outpath $Newname -LogText $line.Trim()
                    }
                }
                #IOS Workflow
                else
                {
                    if($line -like "*SSP States*")
                    {
                        if($sspstate -eq $true)
                        {
                            $sspstate = $false
                        }
                        else
                        {
                            $sspstate = $true
                        }
                    }

                    if($sspstate -or ($line -like "*SSP States*"))
                    {
                        $AllProcessedLines += "<![LOG[$line]LOG]!>" +` 
                                                "<time=`"`" " +` 
                                                "date=`"`" " +` 
                                                "component=`"`" " +` 
                                                "context=`"`" " +` 
                                                "type=`"`" " +` 
                                                "thread=`"`" " +` 
                                                "file=`"`">".Trim()
                    }
                    else
                    {

                        
                        $AllProcessedLines += "<![LOG[$line]LOG]!>" +` 
                                                "<time=`"`" " +` 
                                                "date=`"`" " +` 
                                                "component=`"`" " +` 
                                                "context=`"`" " +` 
                                                "type=`"`" " +` 
                                                "thread=`"`" " +` 
                                                "file=`"`">".Trim() 
                    }

                }
                $count++
            }
            $AllProcessedLines.count


        }
        else
        {
            Write-Output "Skipping $($item.Name)"
        }
    
    }
}


function test-forandforeach
{
    param(
    [String]$Logpath
    )

    $items = Get-ChildItem $Logpath -Filter "*.log"
    
    
    Write-Output "This will process $(@($items).count) items."
    $itemcount = 0
    foreach($item in $items)
    {  


    ##For
        #Write-Output "1. Reading $($item.name)"
        #$AllLines = Get-Content $item.fullname
        #$starttime = Get-Date
        #for ($i = 1; $i -lt @($AllLines).count; $i++)
        #{ 
        #    #Write-Progress -Activity "1. Reading $($item.name)" -Status "$i/$(@($AllLines).count)" -PercentComplete $(($i/@($AllLines).count)*100)
        #    #$items[$i]
        #}
        #
        #$endtime = get-date
        #write-host "finished in $(($endtime-$starttime).TotalSeconds)"

    ##Foreach
        #Write-Output "2. Reading $($item.name)"
        #$starttime = Get-Date
        #$count = 0
        #foreach($line in $AllLines)
        #{
        #    #$line
        #    #Write-Progress -Activity "2. Reading $($item.name)" -Status "$count/$(@($AllLines).count)" -PercentComplete $(($count/@($AllLines).count)*100)
        #    $count++
        #}       
        #$endtime = get-date
        #write-host "finished in $(($endtime-$starttime).TotalSeconds)"

    ##Parallel (c# code)
        Write-Output "3. Reading $($item.name)"
        $starttime = Get-Date
        #ad
$Source = @” 
using System.Threading.Tasks;
using System;

namespace Log 
{ 
    public static class Converter  
    { 
        public static string Read(String[] LogFile) 
        { 
            string str = "";
            int count=0;
            Parallel.For(0, LogFile.Length, x =>
            {
                Console.WriteLine(LogFile[x]);
            }); 
            str = count.ToString();
            return str;
        } 
    } 
} 
“@ 
               [System.Threading.Tasks.Parallel]::For(0,@($alllines).Count,)
                Add-Type -TypeDefinition $Source -Language CSharp
                [Log.converter]::Read(@($alllines))
                $endtime = get-date
                write-host "finished in $(($endtime-$starttime).TotalSeconds)"
                    }
}

workflow ForParalell
{
    param(
        [string[]] $Loglines
        )

    


    foreach -parallel($Computer in $ComputerName)
    {
        sequence {
        Get-WmiObject -PSComputerName $Computer -PSCredential $MachineCred
        Add-Computer -PSComputerName $Computer -PSCredential $DomainCred
        Restart-Computer -ComputerName $Computer -Credential $MachineCred -For PowerShell -Force -Wait -PSComputerName ""
        Get-WmiObject -PSComputerName $Computer -PSCredential $MachineCred
        }
    }

}



test-forandforeach -Logpath 'D:\Kunde Dok\Norwegian\EMS\Log\stian'