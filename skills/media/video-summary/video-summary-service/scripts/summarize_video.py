#!/usr/bin/env python3
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request


def request_json(method, url, api_key, payload=None, timeout=30):
    data = None
    headers = {"x-api-key": api_key}
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"HTTP {error.code} from {url}: {body}") from error


def submit_job(base_url, api_key, video_url):
    return request_json("POST", f"{base_url}/api/v1/jobs", api_key, {"url": video_url})


def get_job(base_url, api_key, job_id):
    return request_json("GET", f"{base_url}/api/v1/jobs/{job_id}", api_key)


def poll_job(base_url, api_key, job_id, timeout_seconds, interval_seconds):
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        job = get_job(base_url, api_key, job_id)
        if job.get("status") in {"succeeded", "failed", "canceled"}:
            return job
        time.sleep(interval_seconds)
    raise SystemExit(f"Timed out waiting for job {job_id}")


def format_markdown(job):
    result = job.get("result") or {}
    video = result.get("video") or {}
    transcript = result.get("transcript") or []
    summary = result.get("summary") or {}
    lines = [
        f"Job: `{job.get('id', '')}`",
        f"Status: `{job.get('status', '')}`",
    ]
    if job.get("error"):
        lines.append(f"Error: {job['error']}")
    if video:
        lines.extend(
            [
                "",
                f"Title: {video.get('title', '')}",
                f"Author: {video.get('author', '')}",
                f"Resolved URL: {video.get('resolved_url', '')}",
                f"Transcript segments: {len(transcript)}",
            ]
        )
    if summary:
        lines.extend(["", "## Summary", "", summary.get("one_line", "")])
        for key, title in [
            ("outline", "Outline"),
            ("quotes", "Quotes"),
            ("viewpoints", "Viewpoints"),
        ]:
            values = summary.get(key) or []
            if values:
                lines.extend(["", f"## {title}"])
                lines.extend(f"- {value}" for value in values)
        if summary.get("analysis"):
            lines.extend(["", "## Analysis", "", summary["analysis"]])
    return "\n".join(lines).strip() + "\n"


def main():
    parser = argparse.ArgumentParser(description="Submit and poll a Video Summary service job.")
    parser.add_argument("url", help="Video URL or share text to summarize.")
    parser.add_argument("--base-url", default=os.environ.get("VIDEO_SUMMARY_BASE_URL", "http://localhost:13000"))
    parser.add_argument("--api-key", default=os.environ.get("VIDEO_SUMMARY_API_KEY", ""))
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--interval", type=float, default=5.0)
    parser.add_argument("--json", action="store_true", help="Print raw job JSON instead of Markdown.")
    args = parser.parse_args()

    api_key = args.api_key.strip()
    if not api_key:
        raise SystemExit("VIDEO_SUMMARY_API_KEY or --api-key is required")
    base_url = args.base_url.rstrip("/")

    created = submit_job(base_url, api_key, args.url)
    job = created.get("job") or created
    job_id = job.get("id")
    if not job_id:
        raise SystemExit(f"Create job response did not include job id: {created}")
    final_job = poll_job(base_url, api_key, job_id, args.timeout, args.interval)
    if args.json:
        print(json.dumps(final_job, ensure_ascii=False, indent=2))
    else:
        print(format_markdown(final_job), end="")
    if final_job.get("status") != "succeeded":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
