Add-BootsFunction -Type "System.Windows.Threading.DispatcherTimer"

function Start-BootsTimer {
#.Syntax
#  Creates a stay-on-top countdown timer
#.Description
#  A WPF borderless count-down timer, with audio/voice alarms and visual countdown + colored progress indication
#.Parameter EndMessage
#  The message to be spoken by a voice when the time is up...
#.Parameter StartMessage
#  A message to be spoken at start up (just to let you know, audibly, what's up).

#.Parameter Minutes
#  Some minutes to add to the timer
#.Parameter Seconds
#  Some seconds to add to the timer
#.Parameter Hours
#  Some hours to add to the timer

#.Parameter SoundFile
#  A .wav file to play as the alarm
#.Parameter FontSize
#  The size of the timer text
#.Parameter SingleAlarm
#  Only sound the alarm once

#.Example
#  Start-BootsTimer  180 "The three minute egg is ready!"
#
#  Starts a three minute timer with the specified voice alert at the end
#
#.Example
#  Start-BootsTimer  -End "The three minute egg is ready!" -Minute 3
#
#  Starts a three minute timer with the specified voice alert at the end
#
#.Example
#  Start-BootsTimer  "Your turn is over!" -Minutes 10 -Single -FontSize 18
#
#  Starts a 10 minute timer that only plays the alert once at the end, and has a small font, which would fit over the task bar or a window title bar...
[CmdletBinding(DefaultParameterSetName="Times")]
PARAM( 
   [Parameter(Position=2,ParameterSetName="Times",Mandatory=$false)]
   [Parameter(Position=1,ParameterSetName="Reasons", Mandatory=$true)]
   [string]$EndMessage
,  
   [Parameter(Position=2,ParameterSetName="Reasons", Mandatory=$false)]
   [string]$StartMessage
,  
   [Parameter(Position=3,ParameterSetName="Reasons", Mandatory=$false)]
   [int]$minutes   = 0
,
   [Parameter(Position=4,ParameterSetName="Reasons", Mandatory=$false)]
   [Parameter(Position=1,ParameterSetName="Times", Mandatory=$true)]
   [int]$seconds   = 0
,
   [Parameter()]
   [int]$hours     = 0
,
   [Parameter()]
   $SoundFile = "$env:SystemRoot\Media\notify.wav"
,
   [Parameter()]
   $FontSize = 125
, 
   [Parameter()]
   [Switch]$SingleAlarm
)

# Default to 10 seconds ... without adding 5 seconds when people specify minutes
if(($seconds + $Minutes + $hours) -eq 0) { $seconds = 10 }

$start = [DateTime]::Now

## We have to store all this stuff, because the powerboots window lasts longer than the script
$TimerStuff = @{}
$TimerStuff["seconds"] = [Math]::Abs($seconds) + [Math]::Abs([int]($minutes*60)) + [Math]::Abs([int]($hours*60*60))
$TimerStuff["TimerEnd"] = $start.AddSeconds( $TimerStuff["seconds"] )
$TimerStuff["SingleAlarm"] = $SingleAlarm

## Take care of as much overhead as we can before we need it...
if(Test-Path $soundFile) {
   $TimerStuff["Sound"] = new-Object System.Media.SoundPlayer
   $TimerStuff["Sound"].SoundLocation=$SoundFile
}
if($EndMessage -or $StartMessage) {
   $TimerStuff["Voice"] = new-object -com SAPI.SpVoice
}

## Store the "EndMessage" message
if($EndMessage) {
   $TimerStuff["EndMessage"] = $EndMessage
}
## If they provided a second status message, read it out loud
if($StartMessage) {
   $null = $TimerStuff["Voice"].Speak( $StartMessage, 1 )
}

$TimerStuff["FontSize"] = $FontSize

## Make the window ...
PowerBoots\New-BootsWindow -WindowStyle None -AllowsTransparency -Tag $TimerStuff {
   Param($window)
   TextBlock "00:00:00" -FontSize $window.Tag.FontSize -FontFamily Impact -margin 20   `
            -BitmapEffect $(OuterGlowBitmapEffect -GlowColor White -GlowSize 15)    `
            -Foreground $(LinearGradientBrush -Start "1,1" -End "0,1" {
                           GradientStop -Color Black -Offset 0.0
                           GradientStop -Color Black -Offset 0.95
                           GradientStop -Color Red -Offset 1.0
                           GradientStop -Color Red -Offset 1.0
                        }) # -TextDecorations ([System.Windows.TextDecorations]::Underline)

   ## We'll create a timer
   $window.Tag["Timer"] = DispatcherTimer -Tag $window -Interval "0:0:0.05" -On_Tick { 
      trap { 
         write-host "Error: $_" -fore Red 
         write-host $($_.InvocationInfo.PositionMessage) -fore Red 
         write-host $($_.Exception.StackTrace | Out-String) -fore Red 
      }

      $remain = 100
      if($this.Tag.Tag.TimerEnd -and $this.Tag.Content.Foreground.GradientStops.Count -ge 3) {
         Write-Verbose $($this.Tag.Tag|Out-String) #-fore magenta
         $diff = $this.Tag.Tag.TimerEnd - [DateTime]::Now;
         if($diff.Ticks -ge 0) {
            $this.Tag.Content.Text = ([DateTime]$diff.Ticks).ToString(" HH:mm.ss")
         } else {
            $this.Tag.Content.Text = ([DateTime][Math]::Abs($diff.Ticks)).ToString("-HH:mm.ss")
         }
         
         #Write-Host "Remain: $remain or $($diff.TotalSeconds) of $($this.tag.tag.seconds)"
         $remain = $diff.TotalSeconds / $this.tag.tag.seconds
         Write-Verbose "Remain: $remain or $($diff.TotalSeconds) of $($this.tag.tag.seconds)"
         ## Move the gradient a little bit each time.
         $this.tag.Content.Foreground.GradientStops[2].Offset = 0.0 # [Math]::Max(0.0, $remain)
         $this.tag.Content.Foreground.GradientStops[1].Offset = 0.0 # [Math]::Max(0.0, $remain - 0.05) 
         #Write-Host "Gradient:  $($this.tag.Content.Foreground.GradientStops[2].Offset) of $($this.tag.Content.Foreground.GradientStops[1].Offset)"
      } else { Write-Host "Wahat!" }
      ## When we get to the end ... make a few changes
      if($remain -le 0) {
         ## The first time we hit the end, we want to add a mouse click handler...
         if($this.Interval.Seconds -eq 0) {
            ## Which will now only fire every few seconds
            ## So it's easier to close the window ;)
            $this.Interval = [TimeSpan]"0:0:2"
            ## If you click on the finished window, it just goes away
            $this.tag.Add_MouseDown( { $this.tag.Close() } ) 
            ## But if they chose -SingleAlarm, they don't neeto bother
            if($this.tag.tag["SingleAlarm"]) { $this.tag.Close() }
         }
         & {
            if($this.tag.Tag["Sound"]) {
               $this.tag.Tag["Sound"].Play()
            } else {
               [System.Media.SystemSounds]::Exclamation.Play()
            }
            if($this.tag.Tag["EndMessage"]) {
               $null = $this.tag.Tag["Voice"].Speak( $this.tag.Tag["EndMessage"], 1 )
            }
         }
      }
   }
   ## Now handle starting and stopping the timer
   # $window.Add_SourceInitialized( { $window.Tag.Timer.Start() } )
   $window.Add_Closed( { Write-Host "Shutting Down $this"; $this.Tag.Timer.Stop() } )
   
} -On_MouseDown { 
   if($_.ChangedButton -eq "Left") { $this.DragMove()  }
} -Async -Topmost -Background Transparent -ShowInTaskbar:$False -Passthru | 
## In lieu of the SourceInitialized event which fires BEFORE we can hook it:
ForEach { Invoke-BootsWindow $_ { $BootsWindow.Tag.Timer.Start() } }

}