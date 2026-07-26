#!/usr/bin/env python3
"""Local static server for public/research with VitePress base-path aliases."""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class ResearchHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, public_root: Path, **kwargs):
        self.public_root = public_root
        super().__init__(*args, directory=str(public_root), **kwargs)

    def translate_path(self, path: str) -> str:
        clean = path.split('?', 1)[0].split('#', 1)[0]
        if clean.startswith('/research_reports/') or clean.startswith('/en/research_reports/'):
            path = '/research' + clean
        return super().translate_path(path)


class ReusableHTTPServer(ThreadingHTTPServer):
    allow_reuse_address = True


def main() -> None:
    parser = argparse.ArgumentParser(description='Serve public/ with /research_reports aliases')
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument(
        '--directory',
        type=Path,
        default=Path(__file__).resolve().parents[4] / 'public',
    )
    args = parser.parse_args()
    public_root = args.directory.resolve()
    handler = partial(ResearchHandler, public_root=public_root)
    server = ReusableHTTPServer(('127.0.0.1', args.port), handler)
    print(f'[serve-research-local] http://127.0.0.1:{args.port}/research/ (root={public_root})')
    server.serve_forever()


if __name__ == '__main__':
    main()
