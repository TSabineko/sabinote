# AGENTS.md

This file documents repository-specific instructions for working in `sabinote`.

## Hugo execution policy

- Do not use the locally installed `hugo` binary for this repository.
- Always run Hugo commands via Docker because the local Hugo version may be older than the version required by the theme.
- Use `ghcr.io/gohugoio/hugo:v0.158.0`.
- Run commands from the repository root: `/home/sabineko/project/sabinote`.

## Commit workflow

- After making code or content edits, do not commit immediately.
- First, let the user review and verify the changes locally.
- Only create a commit after the user explicitly says to proceed.

## Standard Docker wrapper

Use this pattern for Hugo commands:

```bash
docker run --rm -it \
  -u "$(id -u):$(id -g)" \
  -v "$PWD":/src \
  -w /src \
  ghcr.io/gohugoio/hugo:v0.158.0 <hugo-command>
```

## Examples

Create a new post:

```bash
docker run --rm -it \
  -u "$(id -u):$(id -g)" \
  -v "$PWD":/src \
  -w /src \
  ghcr.io/gohugoio/hugo:v0.158.0 new content posts/first-post.md
```

Build the site:

```bash
docker run --rm -it \
  -u "$(id -u):$(id -g)" \
  -v "$PWD":/src \
  -w /src \
  ghcr.io/gohugoio/hugo:v0.158.0 --minify
```

Run the local server:

```bash
docker run --rm -it \
  -u "$(id -u):$(id -g)" \
  -p 1313:1313 \
  -v "$PWD":/src \
  -w /src \
  ghcr.io/gohugoio/hugo:v0.158.0 server --bind 0.0.0.0
```
