# YouTube Downloader with DPI Bypass

## Overview
This project provides a tool to download videos from YouTube while bypassing DPI restrictions. It offers the flexibility to save videos in various formats and resolutions.

## Usage Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/bartweimann80540g/yt-dlp-dpi.git
   cd yt-dlp-dpi
   ```
2. Install the required dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Run the downloader:
   ```bash
   python downloader.py [VIDEO_URL] [OPTIONS]
   ```
   Replace `[VIDEO_URL]` with the link to the desired YouTube video and `[OPTIONS]` with any specific download options you might need.

## API Documentation
The API provides endpoints for the following functionalities:
- **Download Video**: Initiates the download of a specified video.
- **List Available Formats**: Retrieves a list of available formats for the specified video.

Refer to the `api.py` file for detailed endpoint specifications and methods.

## Environment Variables
To configure the downloader, set the following environment variables:
- `VIDEO_FORMAT`: Specifies the format for downloaded videos (e.g., `mp4`, `mkv`).
- `DOWNLOAD_PATH`: Sets the default path where downloaded files will be saved.

Make sure to export these variables in your terminal before running the downloader.

## License
This project is licensed under the MIT License. See the LICENSE file for more details.
