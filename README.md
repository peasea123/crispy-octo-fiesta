# Web Slideshow for Roku

A sideloaded Roku channel that plays a slideshow of images (with background
music) pulled from a folder on your website. The TV fetches the files over
HTTPS each time the channel runs, so updating the slideshow is just a matter
of dropping new files into the folder.

## What's in here

```
.
├── manifest                       # Roku channel manifest
├── source/main.brs                # entry point
├── components/
│   ├── SlideshowScene.xml/.brs    # main scene: fetch, crossfade, audio
│   └── FetchTask.xml/.brs         # async HTTP task
├── images/                        # icons + splash screens
├── manifest.example.json          # sample playlist file (host on your site)
├── build.sh                       # rebuilds roku-slideshow.zip
└── roku-slideshow.zip             # sideload-ready package
```

The pre-built `roku-slideshow.zip` is what you upload to your Roku in
developer mode.

## Installing on your Roku TV

1. Enable Developer Mode on the TV: from the home screen press
   **Home 3×, Up 2×, Right, Left, Right, Left, Right**. Follow the on-screen
   prompts to set a developer password and note the IP address.
2. From a computer on the same network, browse to `http://<roku-ip>` and log
   in with username `rokudev` and the password you just set.
3. Click **Upload**, choose `roku-slideshow.zip`, then click **Install**. The
   channel launches automatically.

## First-run setup

The first time the channel runs it shows an on-screen keyboard. Type the URL
of the folder on your website that holds the slides, for example:

```
https://example.com/slides/
```

Press **Save**. The URL is stored on the TV, so subsequent launches go
straight to the slideshow.

To change the URL later, press **\*** (the Star/Options button) on the
remote.

## Hosting your slides

The channel looks for content in two ways. You only need to do **one** of
them:

### Option A — `manifest.json` (recommended)

Put a file called `manifest.json` in the slides folder that lists the files
to play, in order:

```json
{
  "duration": 6,
  "images": [
    "slide1.jpg",
    "slide2.jpg",
    "slide3.png"
  ],
  "audio": [
    "song1.mp3",
    "song2.mp3"
  ]
}
```

- `duration` (optional) is how many seconds each slide is shown. Default `6`.
- `images` and `audio` paths can be either relative to the slideshow URL, or
  absolute (`https://...`).

A copy of this file is included as `manifest.example.json`.

### Option B — Directory listing

If your web server has directory listing enabled (Apache `Options +Indexes`
or Nginx `autoindex on;`), the channel will parse the HTML index page and
play every image and audio file it finds. No `manifest.json` required.

## Supported formats

- **Images:** `.jpg`, `.jpeg`, `.png`, `.bmp`, `.gif`, `.webp`
- **Audio:** `.mp3`, `.m4a`, `.aac`, `.wav`, `.flac`

## Server requirements

- **HTTPS recommended.** Roku ships with a CA bundle and the channel uses it,
  so any normal certificate (Let's Encrypt, etc.) works. Plain HTTP is also
  fine.
- **CORS is not required** — Roku's HTTP client is not a browser.
- Files must be reachable by direct GET. Auth-walled content (cookies,
  redirects to login pages) won't work.

## Remote control

| Button       | Action                       |
| ------------ | ---------------------------- |
| OK / Play    | Skip to the next slide       |
| Right / FF   | Skip to the next slide       |
| Left / Rew   | Go back one slide            |
| **\*** (Star)| Re-enter the source URL      |
| Back         | Exit the channel             |

## Rebuilding the zip

If you edit the code and need a fresh `roku-slideshow.zip`:

```bash
./build.sh
```

This produces `roku-slideshow.zip` at the repo root, ready to sideload.
