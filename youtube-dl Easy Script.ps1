<#
# =====================================
#        Script Author: ThioJoe
#        Github.com/ThioJoe
# =====================================
#        Version: 1.3
# =====================================

# ----------------------------------- IMPORTANT STUFF -----------------------------------------
#
# THIS SCRIPT REQUIRES the "youtube-dl" program: https://yt-dl.org/
#
# Direct link to latest youtube-dl executable: https://yt-dl.org/latest/youtube-dl.exe
# YouTube-dl documentation: https://github.com/ytdl-org/youtube-dl/blob/master/README.md#readme
# Supported sites for Downloading: https://ytdl-org.github.io/youtube-dl/supportedsites.html
# See this script's Readme for more details
# ---------------------------------------------------------------------------------------------


Command Line Arguments:
========================

-exe <string>
    Set the name of the YouTube downloader executable.
    Example: -exe "youtube-dl.exe"
    Default: "yt-dlp.exe"

-desktop
    Place the 'Outputs' folder on the Desktop instead of the current directory.

-options <string>
    Manually set additional parameters for the YouTube downloader executable.
    Example: -options "--no-mtime --add-metadata --extract-audio"
    Default: "--no-mtime --add-metadata"
	
-debug
	Display potentially helpful info for debugging, including resulting variable values
	
#>

param (
    [string]$exe,
    [switch]$desktop,
    [string]$options,
    [switch]$debug
)

# PARAMETERS YOU MAY NEED/WISH TO CHANGE BELOW:
# Set ffmpeg location here. Make sure it is up to date (if using chocolatey:  chocolatey upgrade ffmpeg )
# Set output location and filename of downloaded files. Defaults to Desktop, with video title and video extension. See documentation on specifics.
# Set default options / parameters to apply to all downloads. See youtube-dl documentation for details. Includes ffmpeg location and output location using the other variables.
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ffmpegPath = Join-Path $scriptRoot "ffmpeg.exe"
$ffmpeg_location = $ffmpegPath # Keep Windows-style backslashes
$output_location="`"Outputs\%(title)s.%(ext)s`"" # Outputs to a folder called "Outputs" in the same directory as the script, with filename as video title
$downloader_exe="yt-dlp.exe" # "yt-dlp.exe"  or  "youtube-dl.exe"
$other_options = "--no-mtime --add-metadata"  # The variables for ffmpeg location and output location are added automatically later

# If exe parameter is not provided, look for yt-dlp.exe or youtube-dl.exe in the root folder
if (-not $exe) {
    $ytDlpPath = Join-Path $scriptRoot "yt-dlp.exe"
    $ytDlPath = Join-Path $scriptRoot "youtube-dl.exe"
    if (Test-Path $ytDlpPath) {
        $downloader_exe = $ytDlpPath
    } elseif (Test-Path $ytDlPath) {
        $downloader_exe = $ytDlPath
    }
} else {
    $downloader_exe = $exe
}

if ($desktop) {
    $output_location = "`"$HOME\Desktop\Outputs\%(title)s.%(ext)s`""
} else {
    $outputDir = Join-Path $scriptRoot "Outputs"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }
    $output_location = "`"$outputDir\%(title)s.%(ext)s`""
}

if ($options) {
    $other_options = $options
}

# Ensure proper path escaping for ffmpeg and output
$options = "$other_options --ffmpeg-location `"$ffmpeg_location`" --output $output_location --no-part"

if ($debug) {
    Write-Output "`nDebug Information:"
    Write-Output "=================="
    Write-Output "Downloader Executable: $downloader_exe"
    Write-Output "FFmpeg Location: $ffmpeg_location"
    Write-Output "FFmpeg Path Exists: $(Test-Path $ffmpegPath)"
    Write-Output "Output Location: $output_location"
    Write-Output "Other Options: $other_options"
    Write-Output "Final Options string: $options"
    Write-Output "==================`n"
}



#################### Functions ####################
function Format-PathVariable($path) {
    if ($path -notmatch '^".*"$') {
        $path = "`"$path`""
    } else {
        $path = $path -replace '(?<!`)("(?!"))', '``$1'
    }
    return $path
}

#Sets $format variable based on user-inputted choice, which is used in final command as format related parameters
function Set-Format {
	Switch ($choice)
	{
		1 {Write-Output $null} # Automatic default is best video + audio muxed
		2 {Write-Output "-f best"} # Best quality audio+video single file, no mux
		3 {Write-Output "-f bestvideo+bestaudio/best --merge-output-format mp4"} # Choose highest quality video and audio formats to combine
		4 {Write-Output -f $format --merge-output-format mp4} # Choose video and audio formats to combine
		5 {Write-Output -f $format} # Download only audio or video
		6 {Write-Output "-f $format"} # Specify single audio+video file
		# Note for later: Optiosn 5 and 6 likely need to be combined into one option, since they are the same thing
	}
}


# Outputs preview of format for user approval
function Check-Format {
	Write-Host "Output will be: " 
	Write-Host (& $downloader_exe $format $URL --get-format)
	Read-Host "Ok? (Enter Y/N)"
}

# For choices that require manually selecting formats using format codes (Choices 4 & 5)
function Custom-Formats {
	# Write-Host "I am inside custom-formats" #For Testing
	if ($choice -eq 4) {Write-Host "INSTRUCTIONS: Choose the format codes for the video and audio quality you want from the list at the top. ffmpeg must be installed and location specified in batch file."
		$videoFormat = Read-Host "Video Format Code"
		$audioFormat = Read-Host "Audio Format Code"
		$chosenFormat = ${videoFormat}+"+"+${audioFormat}
		Write-Output $chosenFormat #Returns this variable out of the function
	}
	elseif ($choice -eq 5) {Write-Host "INSTRUCTIONS: Choose the format code for the video or audio quality you want from the list at the top."
		$chosenFormat = Read-Host "Format Code"
		Write-Output $chosenFormat #Returns this variable out of the function
		 }
	
	elseif ($choice -eq 6) {Write-Host "INSTRUCTIONS: Choose the format code for a specific single audio+video file (one that DOESN'T say 'video only' or 'audio only')."
		$chosenFormat = Read-Host "Format Code"
		Write-Output $chosenFormat #Returns this variable out of the function
		 }
	}


# Updates youtube-dl (must be in same directory as script)
function Update-Program{
	& $downloader_exe --update
	exit
	}

# Function to check if the URL is a YouTube playlist
function Is-PlaylistUrl {
    param($url)
    return $url -like "*playlist?list=*"
}
function Is-DualUrl {
    param($url)
    return ($url -like "*list=*") -and ($url -like "*watch?v=*")
}

function Remove-PlaylistFromUrl {
    param($url)
    $url = $url -replace "&list=[^&]+", ""
    return $url
}

function Get-PlaylistId {
    param($url)
    $regex = [regex]"list=([^&/]+)"
    $match = $regex.Match($url)
    if ($match.Success) {
        return $match.Groups[1].Value
    } else {
        return $null
    }
}
	
##########################################################################	
# Run any utility functions
# $ffmpeg_location = Format-PathVariable($ffmpeg_location)
# $output_location = Format-PathVariable($output_location)

# =================================== Start Main Program ===================================
Write-Output ""
Write-Output '--------------------------------- Video Downloader Script ---------------------------------'
Write-Output ""
Write-Output 'REQUIRES the youtube-dl program from: https://youtube-dl.org/'
Write-Output 'Supported Video Sites: https://ytdl-org.github.io/youtube-dl/supportedsites.html'
Write-Output ""

# Prompt user for YouTube URL
$URL = Read-Host "Enter the YouTube video URL you want to download"

# Prompt user for save location
$customOutput = Read-Host "Enter the full path where you want to save the downloaded file (or press Enter to use default: $output_location)"
if ($customOutput -and $customOutput.Trim() -ne "") {
    $output_location = "`"$customOutput`""
    $options = "$other_options --ffmpeg-location $ffmpeg_location --output $output_location"
}

# Check if the URL is a regular playlist
if (Is-PlaylistUrl $URL) {
    Write-Output "Regular playlist URL detected. Skipping to format selection...`n"
    $isPlaylist = "true"
} elseif (Is-DualUrl $URL) {
    # Handle the dual URL case
    $playlistId = Get-PlaylistId $URL
    Write-Output "`nThe provided URL contains both a video ID and a playlist ID.`n"
    $choice = Read-Host "Do you want to download only the video or the entire playlist? (Enter 'V' for video or 'P' for playlist)"
    if ($choice -eq "P") {
        $isPlaylist = "true"
        $URL = "https://www.youtube.com/playlist?list=$playlistId"
        Write-Output "Will downloading playlist..."
    } else {
        $isPlaylist = "false"
        $URL = Remove-PlaylistFromUrl $URL
        Write-Output "Will download video..."
		& $downloader_exe --list-formats $URL
    }
} else {
    $isPlaylist = "false"
    Write-Output ""
    & $downloader_exe --list-formats $URL
}

while ($confirm -ne "y") {
	Write-Output ""
	Write-Output "---------------------------------------------------------------------------"
	Write-Output "Options:"
	Write-Output "1. Download automatically (default is best video + audio muxed)"
	Write-Output "2. Download the best quality audio+video single file, no mux"
	Write-Output "3. Download the highest quality audio + video formats, attempt merge to mp4"
	Write-Output "4. Let me individually choose the video and audio formats to combine"
	Write-Output "5. Download ONLY audio or video"
	Write-Output "6. Download a specific audio+video single file, no mux"
	Write-Output "7. -UPDATE PROGRAM- (Admin May Be Required)"
	Write-Output ""

	$choice = Read-Host "Type your choice number"
	if (($choice -eq 4) -or ($choice -eq 5) -or ($choice -eq 6)) { $format = Custom-Formats }
	if ($choice -eq 7) {Update-Program}
	# if ($choice -eq 6) {$id = Read-Host "Enter format ID"}
	$format = Set-Format
	if ($isPlaylist -eq "false"){
		$confirm = Check-Format
	}	else {
		Write-Host "Skipping format list for playlist..."
		$confirm = Read-Host "Proceed and download playlist videos? (Enter Y/N)"
	}
}

# Final Run
Write-Output ""
Write-Output "Running Command:   $downloader_exe $format $URL $options"
# Execute the command using Start-Process to handle arguments properly
Start-Process -FilePath $downloader_exe -ArgumentList "$format $URL $options" -NoNewWindow -Wait
cmd /c pause
