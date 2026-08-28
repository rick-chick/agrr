#!/usr/bin/env python3
"""Minimal reCAPTCHA siteverify mock for R4 contract tests."""

from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs

HOST = "127.0.0.1"
PORT = 9191
INVALID_TOKEN = "invalid-token-for-contract-test"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        token = parse_qs(raw.decode()).get("response", [""])[0]
        if token == INVALID_TOKEN:
            payload = {"success": False, "error-codes": ["invalid-input-response"]}
        else:
            payload = {"success": True}
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        pass


def main() -> None:
    HTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
