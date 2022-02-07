using namespace System.Net.NetworkInformation
using namespace System.Threading.Tasks

class Ping
{
  [string]$Computer
  [string]$Status
  [string]$IPAddress
  [int]$TCnt
  [int]$SCnt

  hidden [object]$Task
  hidden [byte[]]$Buffer = 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69
  hidden [pingoptions]$Options
  hidden [int]$TimeToLive = 128
  hidden [int]$TimeOut = 100
  
  Ping() { }

  Ping([string]$computer)
  {
    $this.Computer = $computer
  }

  Ping([string]$computer, [object]$task)
  {
    $this.Computer = $computer
    $this.Task = $task
  }

  [void] SendPingAsync()
  {
    $this.Options = [pingoptions]::new($this.TimeToLive, $false)
    $this.Task = [system.net.networkinformation.ping]::new().sendPingAsync($this.Computer, $this.TimeOut, $this.Buffer, $this.Options)
    $this.TCnt++
  }
}

function Invoke-Ping {
  <#
    .SYNOPSIS
    Ping multiple computers over a specified timeframe and specified intervals.
    Data returned includes the total count of pings (TCnt) and successful count of pongs (SCnt).

    .DESCRIPTION
    Ping multiple computers over a specified timeframe and specified intervals.
    Data returned includes the total count of pings (TCnt) and successful count of pongs (SCnt).
    Data is either sent to the pipeline or exported to CSV.
    Default settings will ping for 4 hours at 60 second intervals.

    .PARAMETER Computers
    List of computer to ping.

    .PARAMETER Once
    Run once and return.

    .PARAMETER PingDurationInMinutes
    Total amount of time to ping in minutes.

    .PARAMETER PingIntervalInSeconds
    Time between ping sweeps in seconds.

    .PARAMETER Export
    Export data to CSV.

    .PARAMETER ExportPath
    Full path to export. Must be used with -Export.

    .INPUTS
    List of computer names as [String[]].

    .OUTPUTS
    System.Object[]. Invoke-Ping returns an array of custom [Ping] objects.

    .EXAMPLE
    Invoke-Ping -Computers $ComputerList
    Run command with default settings. Results are returned to console.

    .EXAMPLE
    Invoke-Ping -Computers $ComputerList -Once
    Run command once. Results are returned to console.

    .EXAMPLE
    $Ping = Invoke-Ping -Computers $ComputerList -PingDurationInMinutes 120 -PingIntervalInSeconds 60
    Run command with a ping duration of 2 hours and ping cycle of 1 minute. Results are returned to console.

    .EXAMPLE
    Invoke-Ping -Computers $ComputerList -Export -ExportPath 'C:\Users\MyUser\Desktop\Ping.csv'    
    Run command with default settings. Results exported to specified path.

    .NOTES
    Example Output
    -------------------
    Computer  : comp1
    Status    : Success
    IPAddress : 0.0.0.0
    TCnt      : 3
    SCnt      : 3
    
    Computer  : comp2
    Status    : Failure
    IPAddress : 0.0.0.1
    TCnt      : 0
    SCnt      : 3
    
    Computer  : comp3
    Status    : Success
    IPAddress : 0.0.0.2
    TCnt      : 3
    SCnt      : 3
  #>
  [cmdletbinding(defaultparametersetname='B')]
  param(
      [parameter(mandatory, position=0, valuefrompipeline, parametersetname='A')]
      [parameter(mandatory, position=0, valuefrompipeline, parametersetname='B')]
    [string[]]$Computers,
      [parameter(parametersetname='A')]
    [switch]$Once,
      [parameter(parametersetname='B')]
    [int]$PingDurationInMinutes = 240,
      [parameter(parametersetname='B')]
    [int]$PingIntervalInSeconds = 60,
    [switch]$Export,
    [string]$ExportPath = "C:$($env:HomePath)\Desktop\Ping_$([datetime]::Now.toString('ddMMMyy_HHmmss')).csv"
  )
  begin {
    $DurationTime = [datetime]::Now.addMinutes($PingDurationInMinutes)
    $NextCycle = [datetime]::Now.addSeconds($PingIntervalInSeconds)
  }
  process {
    Write-Verbose "Initializing..."
    foreach ($Computer in $Computers) {
      [ping[]]$Async += [ping]::new($Computer)
    }
  }
  end {
    while ([datetime]::Now -lt $DurationTime) {
      $NextCycle = [datetime]::Now.addSeconds($PingIntervalInSeconds)
      for ($i = 0; $i -lt $Async.Count; $i++) {
        $Async[$i].sendPingAsync()
      }
      Write-Progress -activity "Pinging Async..."
      Write-Verbose "Pinging Async..."
      try {
        [void][threading.tasks.task]::waitAll($Async.Task)
      }
      catch {
        #Nothing...
      }
      for ($i = 0; $i -lt $Async.Count; $i++) {
        if ($Async[$i].Task.IsFaulted) {
          switch ($Async[$i].Task.Exception.InnerException.InnerException.ErrorCode) {
            11001 { #No such host is known/DNS Missing
              $Async[$i].Status = "Failure"
              break
            }
            default {
              $Async[$i].Status = $Async[$i].Task.Exception.InnerException.InnerException.Message
              break
            }
          }
        }
        else {
          $Async[$i].Status = $Async[$i].Task.Result.Status
          $Async[$i].IPAddress = $Async[$i].Task.Result.Address.toString()
          if ($Async[$i].Task.Result.Status -like 'Success') {
            $Async[$i].SCnt++
          }
        }
      }
      if ($Export) {
        try {
          $Async | Export-Csv -path $ExportPath -noTypeInformation
        }
        catch {
          Write-Warning "Export to `"$($ExportPath)`" Failed! Default to `$env:Temp"
          $Async | Export-Csv -path "$($env:Temp)\Ping_$([string][random]::new().next(10000, 99999)).csv" -noTypeInformation
        }
      }
      if ($Once) {
        break
      }
      while ([datetime]::Now -lt $NextCycle) {
        Write-Progress "Cycle Time: $([datetime]::Now - $NextCycle), Remaining: $([datetime]::Now - $DurationTime)"
        Write-Verbose "Cycle Time: $([datetime]::Now - $NextCycle), Remaining: $([datetime]::Now - $DurationTime)"
        Start-Sleep -s (($NextCycle - [datetime]::Now).Seconds + 1)
      }
    }
    if (!$Export) {
      return $Async
    }
    return
  }
}
