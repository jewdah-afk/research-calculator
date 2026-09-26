#!/usr/bin/env bash
# build.sh - regenerate the whole Roblox publish media kit into art/marketing/out/ (see README.md).
#   cd art/marketing && ./build.sh            (about 10 minutes; the video segments are cached in work/video)
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/bin:$PATH"                    # luau
export NODE_PATH="${NODE_PATH:-$(npm root -g)}"  # playwright
node icon.js && python3 icon_post.py            # out/icon_512.png, out/icon_preview.jpg
node stills.js && node thumbs.js                # out/thumb_1..5.jpg
node video.js                                   # out/video_preview.mp4
ls -la out
