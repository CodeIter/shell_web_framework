# Bash Web Framework

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Bash](https://img.shields.io/badge/Made%20with-Bash-4EAA25.svg)

**A minimalistic, Bash web server and framework.**

A lightweight web framework built entirely in Bash for serving HTML and JSON,
routing requests by path and method, handling middleware, parsing query
strings, form bodies, cookies, and sessions, and serving both dynamic scripts
and static files from the `web/` tree. It supports signed session cookies,
simple redirects, MIME-type detection, and embedded Bash execution inside
HTML files for fast, scriptable pages.

Perfect for embedded devices, IoT, quick prototypes, CTFs, or when you
want to flex your shell skills.

## Features

- Middleware loading from `middleware.d/`
- Method-based routing with file conventions under `router.d/`
- Static file serving from `web/`
- Dynamic Bash page handlers via `.bash` / `.sh` files
- HTML templates with embedded `<? ... ?>` Bash execution
- JSON and HTML response helpers
- Query, form-body, and cookie parsing
- Signed session cookies with file-backed sessions
- Proxy-aware client IP / host / protocol handling
- Security headers middleware
- Redirect helpers
- MIME type detection for common assets

## Requirements

- Bash 4+
- `socat` **or** `ncat` (netcat with `--sh-exec`)
- `openssl` (for session signing)
- `perl` (for `<? ?>` template processing)
- `jq` (for `json_get` request body helper)

- `nginx` (for the provided container setup)
- Docker + Compose

All dependencies are pre-installed in the official Docker image.

## Quick Start

### 1. Clone & Setup

```bash
git clone https://github.com/CodeIter/shell_web_framework.git
cd shell_web_framework
cp .env.example .env
```

### 2. Run locally

```bash
chmod +x *.bash
./server.bash
```

Server will listen on `http://127.0.0.1:8080` (configurable in `.env`).

### 3. Or with Docker

```bash
docker compose up --build -d
```

App available at `http://127.0.0.1:8000`

## Project Structure

```bash
.
├── web/             # Static files + dynamic pages (index.bash, .html, etc.)
├── router.d/        # API routes (e.g. router.d/api/login/post.bash)
├── middleware.d/    # Global middleware (executed in lexical order)
├── handler.bash     # Core request processor
├── server.bash      # Starts socat/ncat
├── core.bash        # Response helpers
├── session.bash     # Session management
├── internal.bash    # Internal functions
├── config.bash      # Loads .env
└── Dockerfile / docker-compose.yml
```

## License

[MIT License](LICENSE).

