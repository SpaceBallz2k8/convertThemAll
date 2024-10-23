@echo off
setlocal EnableDelayedExpansion

REM Set root folder as the current working directory
set "root_folder=%cd%"

REM Function to process video files
:process_video
set "input_file=%~1"
set "filename=%~nx1"
set "dir=%~dp1"

REM Skip files that are already in x265 or HEVC format
echo %filename% | findstr /i "x265 HEVC" >nul
if %ERRORLEVEL% equ 0 (
    echo Skipping %filename% as it's already in x265/HEVC format.
    goto :eof
)

REM Replace video and audio codec names in the output filename
set "output=%filename%"
set "output=!output:h264=HEVC!"
set "output=!output:x264=HEVC!"
set "output=!output:H264=HEVC!"
set "output=!output:H.264=HEVC!"
set "output=!output:h.264=HEVC!"
set "output=!output:X264=HEVC!"
set "output=!output:xvid=HEVC!"
set "output=!output:XviD=HEVC!"
set "output=!output:divx=HEVC!"
set "output=!output:DivX=HEVC!"
set "output=!output:MP3=AAC!"
set "output=!output:mp3=AAC!"
set "output=!output:DTS=AAC!"
set "output=!output:dts=AAC!"
set "output=!output:WMA=AAC!"
set "output=!output:wma=AAC!"
set "output=!output:FLAC=AAC!"
set "output=!output:flac=AAC!"
set "output_file=!output:~0,-4!.mkv"

REM Run ffprobe to gather stream information
for /f "tokens=1,2 delims=," %%a in ('ffprobe -v error -show_entries stream=codec_name,codec_type -of csv^=p^=0 "%input_file%"') do (
    if %%b==video set "video_codec_info=%%a"
    if %%b==audio set "audio_codec_info=%%a"
    if %%b==subtitle set "subtitle_codec_info=%%a"
)

REM Print the input file and codec details
echo Processing: %input_file%
echo Detected Codecs:
echo   Video Codec   : %video_codec_info%
echo   Audio Codec   : %audio_codec_info%
echo   Subtitle Codec: %subtitle_codec_info%

REM Determine audio codec action: copy if it's AAC, AC3, or EAC3, else convert to AAC
if /i "%audio_codec_info%"=="aac" (
    set "audio_action=copy"
) else if /i "%audio_codec_info%"=="ac3" (
    set "audio_action=copy"
) else if /i "%audio_codec_info%"=="eac3" (
    set "audio_action=copy"
) else (
    set "audio_action=aac"
)

REM Handle subtitle stream: discard if incompatible, copy if supported
if "%subtitle_codec_info%"=="" (
    set "subtitle_action=-sn"
) else (
    set "subtitle_action=-c:s copy"
)

REM Construct and run the FFmpeg command for conversion, using -n to skip existing files
ffmpeg -n -i "%input_file%" -c:v hevc_nvenc -profile:v main10 -rc constqp -cq 20 -rc-lookahead 32 -g 600 -c:a %audio_action% %subtitle_action% "%dir%!output_file!"

echo Output saved to: %dir%!output_file!
echo ------------------------------------
goto :eof

REM Loop through all video files in the directory recursively
for %%F in ("%root_folder%\*.mp4" "%root_folder%\*.mkv" "%root_folder%\*.avi") do call :process_video "%%F"
