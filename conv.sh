#!/bin/bash

# Root folder as the current working directory
root_folder=$(pwd)

# Function to process a video file
process_video() {
    input_file="$1"
    filename=$(basename "$input_file")
    dir=$(dirname "$input_file")

    # Skip files that are already in x265 or HEVC format
    if [[ $filename == *x265* || $filename == *HEVC* ]]; then
        echo "Skipping $filename as it's already in x265/HEVC format."
        return
    fi

    # Replace h264, x264, etc., in the filename for HEVC conversion and handle audio format changes
    output="${filename//h264/HEVC}"
    output="${output//x264/HEVC}"
    output="${output//H264/HEVC}"
    output="${output//H.264/HEVC}"
    output="${output//h.264/HEVC}"
    output="${output//X264/HEVC}"
    output="${output//xvid/HEVC}"
    output="${output//XviD/HEVC}"
    output="${output//divx/HEVC}"
    output="${output//DivX/HEVC}"

    # Replace common audio formats with AAC in the output filename
    output="${output//MP3/AAC}"
    output="${output//mp3/AAC}"
    output="${output//DTS/AAC}"
    output="${output//dts/AAC}"
    output="${output//WMA/AAC}"
    output="${output//wma/AAC}"
    output="${output//FLAC/AAC}"
    output="${output//flac/AAC}"
    output_file="${output%.*}.mkv"  # Keep .mkv format without extra strings
    output_path="$dir/$output_file"

    # Run ffprobe to gather stream information
    codec_info=$(ffprobe -v error -show_entries stream=codec_name,codec_type -of csv=p=0 "$input_file")

    # Ensure ffprobe has finished by waiting before processing codecs
    wait

    # Initialize codec variables
    video_codec_info=""
    audio_codec_info=""
    subtitle_codec_info=""

    # Read codec information line by line
    while IFS=',' read -r codec_name codec_type; do
        case "$codec_type" in
            video)
                video_codec_info="$codec_name"
                ;;
            audio)
                audio_codec_info="$codec_name"
                ;;
            subtitle)
                subtitle_codec_info="$codec_name"
                ;;
        esac
    done <<< "$codec_info"

    # Print the input file and codec details
    echo "Processing: $input_file"
    echo "Detected Codecs:"
    echo "  Video Codec   : ${video_codec_info:-Unknown}"
    echo "  Audio Codec   : ${audio_codec_info:-Unknown}"
    echo "  Subtitle Codec: ${subtitle_codec_info:-None}"

    # Determine audio codec action: copy if it's AAC, AC3, or EAC3, else convert to AAC
    if [[ "$audio_codec_info" == "aac" || "$audio_codec_info" == "ac3" || "$audio_codec_info" == "eac3" ]]; then
        audio_action="copy"
    else
        audio_action="aac"
    fi

    # Handle subtitle stream: convert to a compatible format or discard if unsupported
    if [[ -z "$subtitle_codec_info" ]]; then
        subtitle_action="-sn"  # Discard subtitles if none or not compatible
    else
        subtitle_action="-c:s copy"  # Copy the subtitles if already in a compatible format
    fi

    # Construct and run the FFmpeg command for conversion, using -n to skip existing files
    ffmpeg -n -i "$input_file" \
        -c:v hevc_nvenc -profile:v main10 -rc constqp -cq 20 -rc-lookahead 32 -g 600 \
        -c:a "$audio_action" $subtitle_action \
        "$output_path"
    
    # Wait for ffmpeg to finish
    wait

    echo "Output saved to: $output_path"
    echo "------------------------------------"
}

# Loop through all video files in the directory recursively
shopt -s globstar nullglob
for video_file in **/*.{mp4,mkv,avi}; do
    if [ -f "$video_file" ]; then
        process_video "$video_file"
    fi
done
