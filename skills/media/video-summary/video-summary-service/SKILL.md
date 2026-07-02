---
name: video-summary-service
description: Use the deployed Video Summary service to summarize Douyin or short-video links via its public API. Trigger when users ask to summarize a video through the video-summary service, submit a video URL for asynchronous summarization, poll a video summary job, or diagnose basic service/API-key usage.
---

# Video Summary Service

## Purpose

Use the deployed Video Summary API to turn a Douyin or short-video share link into a transcript-backed summary.

## Inputs

Require:

- A video URL or full share text.
- Service base URL, defaulting to `VIDEO_SUMMARY_BASE_URL` or `http://localhost:13000`.
- API key from `VIDEO_SUMMARY_API_KEY`; send it as `x-api-key`.

Do not ask the user to paste secrets into repository files. Prefer environment variables.

## Workflow

1. Confirm the user wants to use the deployed service rather than local manual processing.
2. Ensure `VIDEO_SUMMARY_API_KEY` is available. If missing, ask the user to set it.
3. Submit the URL with `POST /api/v1/jobs`.
4. Poll `GET /api/v1/jobs/{job_id}` until `succeeded` or `failed`.
5. Return the title, author, resolved URL, transcript segment count, and structured summary.
6. If the job fails, report the job id and error exactly enough for operations follow-up.

## Script

Use `scripts/summarize_video.py` for deterministic API calls:

```bash
VIDEO_SUMMARY_BASE_URL=https://video.example.com \
VIDEO_SUMMARY_API_KEY=... \
python skills/media/video-summary/video-summary-service/scripts/summarize_video.py "https://v.douyin.com/..."
```

The script prints a concise Markdown summary by default. Use `--json` to print the raw job JSON.

## Output Requirements

When reporting to the user, include:

- Job id and final status.
- Video title/author when available.
- One-line summary.
- Outline, representative quotes, viewpoints, and analysis when available.
- A short note if the summary came from a failed or incomplete job.

## Checks

- Never expose or echo the API key.
- Verify HTTP status codes and job status before claiming success.
- Keep `/healthz` and `/readyz` checks separate from protected summary APIs.
- If the service returns `401`, tell the user to check `VIDEO_SUMMARY_API_KEY`.

## Boundaries

- Do not modify production deployment, rotate cookies, restart containers, or change secrets unless the user explicitly asks.
- Do not bypass access controls.
- Do not store API keys, cookies, tokens, or downloaded video content in the skill repository.
