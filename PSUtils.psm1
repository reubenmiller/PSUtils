Add-Type -AssemblyName System.Web.Extensions

function json
{
    <#
    .synopsis
    Decode JSON
    .example
    PS> echo "{'x':123,'y':22}" | json | % y
    22
    #>

    param(
        [Parameter(ValueFromPipeline = $true)][string]$i)

    begin
    {
        $jsser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    }
    process
    {
        $jsser.MaxJsonLength = $i.length + 100 # Make limit big enough
        $jsser.RecursionLimit = 100
        $jsser.DeserializeObject($i)
    }
}

function unjson
{
    <#
    .synopsis
    Encode JSON
    .parameter pretty
    Print prety JSON
    .example
    PS> echo "{'x':123,'y':22}" | json | unjson
    {"x":123,"y":22}
    #>

    param(
        [switch]$pretty,
        [Parameter(ValueFromPipeline = $true)]$obj)

    begin
    {
        $jsser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    }
    process
    {
        $r = $jsser.Serialize($obj)
        if ($pretty)
        {
            $r | jq .
        }
        else
        {
            $r
        }
    }
}

# download page
function download([string]$url, [string]$path)
{
    <#
    .synopsis
    Download single file
    .parameter url
    URL of file to download
    .parameter path
    Download destination. Default is current path
    .example
    download "www.foo.org/1.jpg"
    .example
    download "www.foo.org/1.jpg" subdir
    #>

    $fname = split-path -leaf $url

    if (!$path)
    {
        $path = (gl).Path
    }

    if (test-path -pathType Container $path)
    {
        $path = join-path $path $fname
    }

    echo "Downloading $url to $path"

    $client = New-Object System.Net.WebClient
    $client.DownloadFile($url, $path)
}

function time([scriptblock]$s)
{
    <#
    .synopsis
    Measure time of script block
    .example
    time { foo; bar; baz; }
    #>
    $tm = get-date
    & $s;
    (get-date) - $tm;
}

function invoke-cmd([string]$f)
{
    <#
    .synopsis
    Invoke .bat file
    .description
    Invokes .bat files and saves environment changes
    #>
    cmd /c "$f && set" | % {
        if ($_ -match "^(.*?)=(.*)$") {
            sc "env:\$($matches[1])" $matches[2]
        }
    }
}

function unzip
{
    <#
    .synopsis
    Extract zip archive
    .parameter archive
    Archive file
    .parameter Output
    Output directory
    .example
    PS> unzip 1.zip out
    #>
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$archive,

        [string]$Output = ".",

        [Parameter(ValueFromRemainingArguments = $true)]
        $files)
    7z x $archive "-o$($Output)" -y $files | ? { $_ -match "^Extracting\s+(.*)$" } | % { $matches[1] }
}

function zip([string]$archive)
{
    <#
    .synopsis
    Make zip archive
    .description
    Passes all parameters to 7z
    #>
    7z a $archive $args -y
}

function lszip([string]$archive, [string]$Mask)
{
    <#
    .synopsis
    List zip archive contents
    .description
    List files in archive like 'ls'
    .parameter archive
    Archive file
    .parameter Mask
    Mask to filter files like in 'ls'
    .example
    PS> lszip 1.zip *.txt
    #>
    $result = 7z l $archive $Mask
    $start = $result | ? { $_ -match "^(((-+)\s+)+)(-+)" } | select -first 1 | % {
        $matches[1].length
        $line = $matches[4]
    }

    $result = $result | ? { $_.length -ge $start } | % { $_.substring($start) }
    $result = $result | select -skip ($result.IndexOf($line) + 1)
    $result = $result | select -first ($result.IndexOf($line))

    if ($Mask)
    {
        $result | ? { $_ -like "$($Mask)" }
    }
    else
    {
        $result
    }
}

function codepage
{
    <#
    .synopsis
    Get or set codepage
    .parameter cp
    Codepage to set
    .parameter script
    Script to run with codepage. If set then codepage will be restored back after running script
    .example
    PS> codepage
    866
    PS> codepage 65001
    Active code page: 65001
    PS> codepage 65001 { cabal list }
    #>

    param(
        [Parameter(Position = 0)]
        [int]$cp,        
        [Parameter(Position = 1)]
        [scriptblock]$script)

    if (!$cp)
    {
        if ($(chcp) -match "\d+$") { $matches[0] }
    }
    elseif (!$script)
    {
        chcp $cp
    }
    else
    {
        $old = codepage
        codepage $cp | out-null
        $r = & $script
        codepage $old | out-null
        $r
    }
}

function encoding
{
    <#
    .synopsis
    Get or set output encoding
    .parameter encoding
    Encoding to set
    .parameter script
    Script to run with encoding. If set then encoding will be restored back after running script
    #>

    param(
        [Parameter(Position = 0)]
        [string]$encoding,
        [Parameter(Position = 1)]
        [scriptblock]$script)

    if (!$encoding)
    {
        $OutputEncoding
    }
    elseif (!$script)
    {
        Set-Variable -Name OutputEncoding -Value ([System.Text.Encoding]::GetEncoding($encoding)) -Scope Global
    }
    else
    {
        $old = encoding
        encoding $encoding
        $r = & $script
        $OutputEncoding = $old
        $r
    }
}

function path([string]$name)
{
    <#
    .synopsis
    Get path by name
    .parameter name
    Name of path (MyDocuments,MyPictures etc.)
    .example
    PS> path MyDocuments
    d:\users\voidex\Documents
    #>
    [Environment]::GetFolderPath($name)
}

function rhistory
{
    <#
    .synopsis
    Search in history
    .parameter h
    Regex to match
    .example
    PS> rhistory path

        Id CommandLine                                                                                                                                                                                                                                                                                                               
        -- -----------                                                                                                                                                                                                                                                                                                               
        67 path MyDocuments                                                                                                                                                                                                                                                                                                          
        68 path Documents                                                                                                                                                                                                                                                                                                            
        69 path MyPictures                                                                                                                                                                                                                                                                                                           
        70 path Documents | clip                                                                                                                                                                                                                                                                                                     
        71 path MyDocuments | clip                                                                                                                                                                                                                                                                                                   
        72 rhistory path                                                                                                                                                                                                                                                                                                             

    #>
    param([Parameter(Mandatory=$true)][string]$h)
    history | ? { $_.CommandLine -match $h }
}

Add-Type -Assembly PresentationCore

function clear-clipboard
{
    <#
    .synopsis
    Clear clipboard
    #>
    [Windows.Clipboard]::Clear()
}

set-alias clear-clip clear-clipboard

function set-clipboard
{
    <#
    .synopsis
    Set clipboard text
    .example
    PS> set-clipboard 123
    PS> get-clipboard
    123
    #>
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $inputText)

    [Windows.Clipboard]::SetText($inputText)
}

function out-clipboard
{
    <#
    .synopsis
    Output to clipboard
    .parameter Separator
    Separate lines with Separator, default is newline
    .parameter Echo
    Echo clipboarded data
    .example
    PS> 1, 2, 3, 4 | out-clipboard
    PS> get-clipboard
    1
    2
    3
    4
    PS> 1, 2, 3, 4 | out-clipboard -Separator ','
    PS> get-clipboard
    1,2,3,4
    PS> 1, 2, 3, 4 | out-clipboard -Separator ',' -Echo
    1,2,3,4
    #>
    param(
        [string]
        $Separator = "`r`n",
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $InputObject,
        [switch]
        $Echo)

    begin
    {
        [string[]]$clipboard = @()
        clear-clipboard
    }
    process
    {
        $clipboard += $InputObject
    }
    end
    {
        $result = $clipboard -join $Separator
        [Windows.Clipboard]::SetText($result)
        if ($Echo)
        {
            $result
        }
    }
}

set-alias out-clip out-clipboard

function get-clipboard
{
    <#
    .synopsis
    Get clipboard contents
    .parameter Separator
    Separator to split clipboard with
    .example
    PS> 1, 2, 3, 4 | out-clipboard
    PS> get-clipboard | measure -Sum | select -exp Sum
    10
    PS> 1, 2, 3, 4 | out-clipboard -Separator ','
    PS> get-clipboard -Separator ','
    1
    2
    3
    4
    #>

    param(
        [string]
        $Separator = "`r`n")
    [Windows.Clipboard]::GetText() -split $Separator
}

set-alias get-clip get-clipboard

# taglib
$TagLib = $PSScriptRoot + "\taglib-sharp.dll"

[System.Reflection.Assembly]::LoadFile($TagLib) | out-null

# load file for tags
function tags([string]$path)
{
    <#
    .synopsis
    Get tags for audio file
    .description
    Returns TagLib.File for file specified.
    Can be used to get/set tags
    .example
    PS> $x = tags foo.mp3
    PS> $x.Tags.Title = "Some name"
    PS> $x.Save()
    .example
    PS> ls *.mp3 | % { $x = tags $_; if ($_.Name -match '\d+\.\s(.*)\.mp3') { $x.Tag.Title = $matches[1]; $x.Save(); } }
    #>

    [TagLib.File]::Create((ls $path))
}

function get-handle
{
    <#
    .synopsis
    Get opened handles with SysInternals handle util
    .description
    Returns opened handles
    .parameter Process
    Handle owning process (partial name)
    .parameter Name
    Handle partial name
    .parameter File
    Returns File handles
    .parameter Section
    Returns Section handles
    .example
    PS> get-handle -n txt -File | % Handle
    C:\ProgramData\Microsoft\Windows Defender\Network Inspection System\Support\NisLog.txt
    C:\Program Files (x86)\Steam\logs\bootstrap_log.txt
    C:\Program Files (x86)\Steam\logs\content_log.txt
    C:\Program Files (x86)\Steam\logs\remote_connections.txt
    C:\Program Files (x86)\Steam\logs\connection_log.txt
    C:\Program Files (x86)\Steam\logs\cloud_log.txt
    C:\Program Files (x86)\Steam\logs\parental_log.txt
    C:\Program Files (x86)\Steam\logs\appinfo_log.txt
    C:\Program Files (x86)\Steam\logs\stats_log.txt
    #>

    param(
        [string]
        $Process,
        [string]
        $Name,
        [switch]
        $File,
        [switch]
        $Section)

    if (!$File -and !$Section)
    {
        $File = $true
        $Section = $true
    }

    function psexe([string]$process_name)
    {
        if ($process_name -match '^(.*)\.exe$') { ps $matches[1] } else { $null }
    }
    function validate_type([ValidateSet('File', 'Section')][string]$type_name)
    {
        ($File -and ($type_name -eq 'File')) -or ($Section -and ($type_name -eq 'Section'))
    }

    $as = @()

    if ($Process)
    {
        $as = $as + @("-p", $Process)
    }
    if ($Name)
    {
        $as = $as + @($Name)
    }

    if ($Name)
    {
        &handle $as |
            ? { $_ -match "^(?<Process>[^\s]+)\s+pid:\s(?<PID>\d+)\s+type:\s(?<Type>\w+)\s+(?<ID>[\w\d]+):\s(?<Handle>.*)$" } |
            % { $matches } |
            ? { validate_type($_.Type) } |
            % {
                New-Object PSObject -Property @{
                    'Process'=psexe $_.Process;
                    'PID'=[int]$_.PID;
                    'Type'=$_.Type;
                    'ID'=$_.ID;
                    'Handle'=$_.Handle;
                }
            }
    }
    else
    {
        (&handle $as |
            % {
                if ($_ -match "^\-+$")
                {
                    $r = $result
                    $result = New-Object PSObject -Property @{
                        'Process'=$null;
                        'PID'=$null;
                        'User'=$null;
                        'Handles'=@()
                    }
                    $r
                }
                if ($_ -match "^(?<Process>[^\s]+)\spid:\s(?<PID>\d+)\s(?<User>.*)$")
                {
                    $matches | % {
                        $result.Process = psexe $_.Process
                        $result.PID = $_.PID
                        $result.User = $_.User
                    }
                }
                if ($_ -match "^\s*(?<ID>[\w\d]+):\s(?<Type>\w+)\s+(\((?<Read>[R\-])(?<Write>[W\-])(?<Delete>[D\-])\)\s+)?(?<Handle>.*)$")
                {
                    $matches | ? { validate_type($_.Type) } | % {
                        $h = New-Object PSObject -Property @{
                            'ID'=$_.ID;
                            'Type'=$_.Type;
                            'Access' = New-Object PSObject -Property @{
                                'Read'=$_.Read -eq 'R';
                                'Write'=$_.Write -eq 'W';
                                'Delete'=$_.Delete -eq 'D';
                            };
                            'Handle'=$_.Handle;
                        }
                        $result.Handles = $result.Handles + @($h)
                    }
                }
            }), $result
    }
}

function dictionary
{
    <#
    .synopsis
    Get/set value from dictionary
    .description
    Get/set value to key-value dictionary
    .parameter key
    Key to get/set value
    .parameter value
    If specified, sets this value
    .parameter delete
    Delete specified key
    .parameter pretty
    Print pretty JSON
    .example
    PS> gc dict.json | dictionary "foo"
    123
    PS> gc dict.json | dictionary "foo" 135 | out-file dict.json
    #>

    param(
        [Parameter(Mandatory=$true)][string]
        $key,
        $value,
        [switch]
        $delete,
        [switch]
        $pretty,
        [Parameter(ValueFromPipeline = $true)]
        $inputText)

    if (!$inputText)
    {
        $inputText = "{}"
    }

    if ($delete)
    {
        json $inputText | % { $_.Remove($key); $_ } | unjson -pretty:$pretty
    }
    elseif ($value)
    {
        json $inputText | % { $_[$key] = $value; $_ } | unjson -pretty:$pretty
    }
    else
    {
        json $inputText | % { $_[$key] }
    }
}

set-alias dict dictionary

function gdict
{
    <#
    .synopsis
    Get dictionary contents
    .parameter path
    File of dictionary
    .example
    PS> gdict "1.json"
    foo = 123
    bar = 22
    #>

    param(
        [Parameter(Mandatory = $true)][string]
        $path)

    -join (gc (ls $path)) | json | % { $d = $_; $d.Keys | % { $_ + " = " + $d[$_] } }
}

function whereis
{
    <#
    .synopsis
    Get location of executable
    .parameter name
    Name of executable
    .example
    PS> whereis ping | % FullName
    C:\Windows\System32\PING.EXE
    #>

    param(
        [Parameter(Mandatory=$true)][string]
        $name)

    $path = where.exe $name 2> $null
    if ($?)
    {
        ls $path
    }
}

function select-group
{
    <#
    .synopsis
    Check whether input matches regex and returns matched group
    .parameter Regex
    Regular expression to match
    .parameter Group
    Group name of index to select, default is 1 (i.e returns first group)
    .example
    PS> 'foobar', 'foobaz', 'keke' | match-group 'foo(.*)'
    bar
    baz
    #>

    param(
        [string]
        $Regex,
        $Group = 1,
        [Parameter(ValueFromPipeline = $true)][string]
        $Input)

    process
    {
        if ($Input -match $Regex)
        {
            $matches[$Group]
        }
    }
}

function wait
{
    <#
    .synopsis
    Wait for process
    .parameter Process
    Process object
    .parameter Timeout
    Timeout to wait
    .parameter Kill
    To kill after timeout
    #>

    param(
        [Parameter(ValueFromPipeline = $true)]
        [System.Diagnostics.Process]$Process,
        [int]$Timeout = 0,
        [switch]$Kill)

    process
    {
        if ($Process)
        {
            $good = if (!$Timeout) { $Process.WaitForExit() } else { $Process.WaitForExit($Timeout) }
            if (!$good)
            {
                if ($Kill)
                {
                    $Process.Kill()
                }
            }
        }
    }
}

[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

$src = @'
using System;
using System.Runtime.InteropServices;

namespace PInvoke
{
    public static class NativeMethods 
    {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;        // x position of upper-left corner
        public int Top;         // y position of upper-left corner
        public int Right;       // x position of lower-right corner
        public int Bottom;      // y position of lower-right corner
    }
}
'@

Add-Type -TypeDefinition $src
Add-Type -AssemblyName System.Drawing

function save-screenshot
{
    <#
    .synopsis
    Take screenshot as bitmap object
    .parameter Out
    Output directory or file name, default is current directory
    .parameter Process
    Process to shot
    #>

    param(
        [string]$Out,
        [System.Diagnostics.Process]$Process)

    $res = $null

    if (!$Out)
    {
        $dir = gl
        $num = ls $dir -Filter 'Screenshot (*).png' | select-group 'Screenshot \((.*)\)\.png' | measure -Maximum | % { $_.Maximum + 1 }
        if (!$num) { $num = 0 }
        $res = join-path $dir "Screenshot ($($num)).png"
    }
    else
    {
        if (test-path $Out -PathType Container)
        {
            $dir = resolve-path $Out
            $num = ls $dir -Filter 'Screenshot (*).png' | select-group 'Screenshot \((.*)\)\.png' | measure -Maximum | % { $_.Maximum + 1 }
            if (!$num) { $num = 0 }
            $res = join-path $dir "Screenshot ($($num)).png"
        }
        elseif (!(split-path $Out))
        {
            $dir = gl
            $res = join-path $dir $Out
        }
        elseif (test-path (split-path $Out) -PathType Container)
        {
            $dir = resolve-path (split-path $Out)
            $name = split-path $Out -Leaf
            $res = join-path $dir $name
        }
        else
        {
            throw "Invalid out"
        }
    }

    $screen = screenshot -Process $Process
    $screen.Save($res)
    $screen.Dispose()
    ls $res
}

function screenshot
{
    <#
    .synopsis
    Take screenshot
    .parameter Process
    Process to take screenshot of, $null for full screen
    #>

    param(
        [System.Diagnostics.Process]$Process)

    $bounds = $null
    if ($Process)
    {
        $rect = New-Object PInvoke.RECT
        if ([PInvoke.NativeMethods]::GetWindowRect($Process.MainWindowHandle, [ref]$rect))
        {
            $bounds = [Drawing.Rectangle]::new($rect.Left, $rect.Top, $rect.Right - $rect.Left + 1, $rect.Bottom - $rect.Top + 1)
        }
    }
    if (!$bounds)
    {
        $bounds = [Windows.Forms.SystemInformation]::VirtualScreen
    }

    $screen = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [Drawing.Graphics]::FromImage($screen)
    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)
    $graphics.Dispose()
    return $screen
}

function timer
{
    <#
    .synopsis
    Run some code with interval
    .parameter interval
    Interval in msecs (default 1 sec)
    .parameter count
    Times to invoke (infinite by default)
    .parameter script
    Script to run
    #>

    param(
        [scriptblock]$script,
        [int]$interval=1000,
        [int]$count=0)

    & {
        $n = 0
        while (($n -lt $count) -or ($count -eq 0))
        {
            sleep -Milliseconds $interval
            $n = $n + 1
            $n
        }
    } | % $script
}

function now
{
    <#
    .synopsis
    Returns current date or/and time
    .parameter Date
    Return date only
    .parameter Time
    Return time only
    .parameter File
    Result can be used as name of file, i.e. no semicolons
    .parameter Format
    Specify format
    .example
    PS> now
    2015-01-25 07:22:27
    PS> now -Date
    2015-01-25
    PS> now -File
    2015-01-25 07.25.03
    PS> now -Format HH
    07
    #>

    param(
        [switch]$Date,
        [switch]$Time,
        [switch]$File,
        [string]$Format)

    $fmt = "yyyy-MM-dd HH:mm:ss"
    if ($File) { $fmt = "yyyy-MM-dd HH.mm.ss" }
    if ($Date) { $fmt = "yyyy-MM-dd" }
    if ($Time) {
        if ($File) { $fmt = "HH.mm.ss" }
        else { $fmt = "HH:mm:ss" }
    }
    if ($Format) { $fmt = $Format }
    get-date -f $fmt
}
