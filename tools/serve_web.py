"""Web export'unu yerelde test etmek için basit HTTP sunucusu.

Kullanım:
    python tools/serve_web.py            # build/web klasörünü http://localhost:8060 adresinde sunar
    python tools/serve_web.py 9000       # farklı port

Godot web export'u file:// ile açılamaz; bir HTTP sunucusu gerekir.
COOP/COEP başlıkları da eklenir (thread desteği açılırsa diye).
"""

import http.server
import os
import sys
from functools import partial

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "application/javascript",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
    if not os.path.isfile(os.path.join(ROOT, "index.html")):
        sys.exit("build/web/index.html bulunamadı. Önce Web export'u al.")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=ROOT))
    print(f"Fener web sürümü: http://localhost:{port}  (durdurmak için Ctrl+C)")
    server.serve_forever()


if __name__ == "__main__":
    main()
