<div dir="ltr">

# 🌍 Social Media Downloader
[![فارسی](https://img.shields.io/badge/lang-فارسی-blue.svg)](README.fa.md)

This README is available in Persian. Please click on the badge above to view it.

---

**For English speakers:** The main documentation is in Persian. For any questions, please open an issue.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Workflow-blue)](https://github.com/features/actions)

A powerful tool that uses GitHub Actions to download content from **SoundCloud, Twitter (X), YouTube, Instagram, and TikTok** directly into your repository. Just paste your links, choose a quality, and let it run.

## ✨ Features

- **SoundCloud:** Single tracks, albums, and playlists (with automatic track numbering)
- **Twitter (X):** Download tweets with images or videos
- **YouTube:** Single videos, playlists, and channels (quality selection: 144p to 1080p, best, audio)
- **Instagram:** Posts, reels, stories, and recent profile posts
- **TikTok:** Single videos (with browser impersonation)
- **Auto Platform Detection:** Just paste the link, the system will figure it out
- **Short URL Support:** Works with `on.soundcloud.com`, `youtu.be`, `t.co`, etc.
- **Error Handling:** Failed downloads won't stop the entire process
- **Easy Sharing:** Downloaded files are stored in your GitHub repo; you can share the raw link with anyone

## 🚀 Quick Start Guide

### 1. Fork the Repository
Click the **Fork** button at the top right of this page to create your own copy.

### 2. Set Up Workflow Permissions
The bot needs permission to save files in your repository.

1.  Go to your repository **Settings** → **Actions** → **General**.
2.  Scroll down to **Workflow Permissions**.
3.  Select **Read and write permissions** and click **Save**.

### 3. (For YouTube Only) Set Up Cookies
To use the YouTube downloader, you must provide your browser cookies. This helps `yt-dlp` appear as a real user.

1.  Install the **"Get cookies.txt LOCALLY"** browser extension ([Chrome link](https://chrome.google.com/webstore/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc) - [Firefox link](https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/)).
2.  Go to [youtube.com](https://youtube.com) and **log into your account**.
3.  Click the extension icon and select **Export**. A `cookies.txt` file will be downloaded.
4.  Go to your GitHub repository: **Settings** → **Secrets and variables** → **Actions**
5.  Click **New repository secret**.
6.  Set the **Name** to `YOUTUBE_COOKIES`.
7.  For the **Secret**, open the `cookies.txt` file with a text editor, copy **its entire content**, and paste it into the field.
8.  Click **Add secret**.

### 4. Start Downloading (Single Method)

**This project only uses the manual `workflow_dispatch` method.**

1.  In your repository, go to the **Actions** tab.
2.  From the left sidebar, select the **Universal Downloader** workflow.
3.  Click the **Run workflow** button.
4.  A form will appear. Fill it out:
    - **Enter URLs (one per line):** Paste your links, one per line. For example:
    - https://soundcloud.com/artist/sets/album
    - https://www.youtube.com/watch?v=XXXXX
    - https://x.com/user/status/123456
    - **YouTube quality (for video entries):** Select the download quality for YouTube links (default: `480p`).
- The other fields (Twitter profile count, Instagram profile count, YouTube channel count) are optional.
5.  Click the green **Run workflow** button.

After a few minutes (depending on the file sizes), the downloaded files will appear in the `downloads/` folder of your repository.

## 📂 Output File Structure
downloads/
├── soundcloud/
│ ├── Artist - Track Name.mp3 (single track)
│ └── Album Name.zip (album with numbered tracks)
├── twitter/
│ └── username - YYYY-MM-DD - tweet_id.zip (includes tweet text, metadata, and media)
├── youtube/
│ ├── Video Title (480p).mp4
│ ├── Video Title (BEST).mp4
│ └── Video Title (AUDIO).mp3
├── instagram/
│ ├── post_xxxxxx.mp4
│ ├── story_username_xxxxxx.mp4
│ └── username - last 10 posts.zip
└── tiktok/
└── username - Video Title.mp4

## ⚙️ Platform Scripts & Behavior

| Platform | Script File | Behavior |
| :--- | :--- | :--- |
| **SoundCloud** | `scripts/soundcloud/single.sh`, `album.sh` | Single track → `Artist - Title.mp3`. Album/Playlist → `Album.zip` with numbered tracks |
| **Twitter (X)** | `scripts/twitter/single.sh` | Only processes tweets with media; creates a `username - date - tweet_id.zip` archive |
| **YouTube** | `scripts/youtube/single.sh`, `playlist.sh`, `channel.sh` | Uses user-selected quality. Supports `--use-postprocessor` to bypass restrictions |
| **Instagram** | `scripts/instagram/single.sh`, `story.sh`, `profile.sh` | Requires `INSTAGRAM_COOKIES`. Downloads post, story (last 24h), and last N profile posts |
| **TikTok** | `scripts/tiktok/single.sh` | Uses `yt-dlp` to download as `%(uploader)s - %(title)s.%(ext)s` |

## ❓ Frequently Asked Questions

### Why only use the `workflow_dispatch` method?
The `workflow_dispatch` (manual run) method allows users to paste multiple links cleanly and select a quality for YouTube videos. It's more stable and user-friendly than the old `sc: URL` approach.

### Can I use short links?
Yes. Short links from all platforms (`on.soundcloud.com`, `youtu.be`, `t.co`, `instagr.am`, etc.) are automatically recognized and processed.

### How to fix `ERROR: Sign in to confirm you’re not a bot` for YouTube?
Make sure you have completed Step 3 (YouTube cookies) and are using a recent version of `yt-dlp`. You can also update the `Install dependencies` section in `downloader.yml`.

### Do I need cookies for Instagram?
Yes. Instagram requires `INSTAGRAM_COOKIES` to access profile content, stories, and even posts. The setup is the same as for YouTube (use the secret name `INSTAGRAM_COOKIES`).

## 🤝 Contributing

Ideas, issues, and pull requests are welcome! Please use the [Issues page](https://github.com/BakerStreetBoys/socialmedia-downloader/issues) for discussions.

## ⚠️ Legal Disclaimer

**By using this tool, you accept full responsibility for your actions.**

1.  **Educational Purpose Only:** This project was created solely for **educational purposes** and to demonstrate automation and download infrastructure concepts.
2.  **Personal Liability:** Any use of this tool to download copyrighted material without permission from the rights holder is **strictly illegal**. The **end user** assumes all legal liability, including any fines, penalties, or lawsuits.
3.  **Developer Liability:** The project developer(s) (individual or organization) has no control over what users choose to download and accepts **no responsibility** for any misuse of this tool.
4.  **GitHub Liability:** GitHub, as a code hosting platform, is also not responsible for the tool's functionality or how it is used.
5.  **Your Obligations:** By using this project, you agree that you will:
    - Only download content you own or have explicit permission to download.
    - Comply with all applicable copyright laws and the Terms of Service of each platform (YouTube, SoundCloud, Instagram, etc.).
    - Otherwise, you are solely liable and accountable.

**THIS TOOL IS PROVIDED "AS IS", WITHOUT ANY WARRANTIES, EXPRESS OR IMPLIED.**

## 📄 License

This project is licensed under the **MIT License**.

</div>
