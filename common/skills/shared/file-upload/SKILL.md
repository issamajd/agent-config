---
name: file-upload
description: Attach a screenshot or screen recording to a pull request, or stage it for sharing. Use when the user asks to upload or attach a file, or when a PR description needs media.

---

# File upload

Pick the destination, first match wins:

1. `FILE_HOST_URL` and `FILE_HOST_TOKEN` are both set: upload to the file host.
2. Otherwise stage the file locally. Until we have a host, every repo lands here.

Never upload files to Azure DevOps. Do not use its PR attachments API, even when the PR lives
there; stage locally and let the user attach by hand.

Always pass only the file's basename, such as `login-flow.mp4`. Never guess a token or a URL;
if something required is missing, say what, and fall back to local staging.

## File host

```bash
curl -sS --fail-with-body -X PUT -T <path-to-file> \
  -H "X-Upload-Token: <value of FILE_HOST_TOKEN>" "$FILE_HOST_URL/<filename>"
```

The response body is the permanent public URL. On HTTP 401 report that the token is wrong and
stop; do not retry. Embed images (`png`, `jpg`, `gif`) as `![description](URL)`. Link videos
(`mp4`, `mov`, `webm`) as `[🎬 screen recording](URL)`; PR descriptions do not play video inline.

## Local staging

```bash
DROP="${FILE_DROP_DIR:-$HOME/agent-uploads}"; mkdir -p "$DROP"
STEM="$(printf '%s' '<stem>' | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')"
cp <path-to-file> "$DROP/$STEM-$(date +%Y%m%d-%H%M%S).<ext>"
```

The slug step mirrors what a file host would do, so names stay the same when one arrives.

Report the absolute path in the OS's native form (`cygpath -w` on Windows). The user drags the
file into the PR in the browser. GitHub takes png, jpg, gif, mp4, mov and webm by drag and drop;
video is capped at 10 MB on free plans and 100 MB on paid ones. Azure DevOps takes images and
GIFs the same way. Put a visible placeholder in
the PR body where the media goes, and tell the user:

```
Screen recording: attach `login-flow.mp4` from <path>
```

## GIF preview

For a clip under about 30 seconds, a GIF plays inline on both GitHub and Azure DevOps and
survives the size caps better than the video:

```bash
ffmpeg -i recording.mp4 -vf "fps=10,scale=800:-1" -loop 0 preview.gif
```

Embed the GIF and link the full-quality video below it. Check `ffmpeg -version` first; if it
is missing, tell the user (`winget install Gyan.FFmpeg`, `brew install ffmpeg`) and skip the
preview rather than failing the upload.
