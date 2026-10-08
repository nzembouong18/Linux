#!/usr/bin/env python3
"""Application de démonstration « Tickets » (stdlib uniquement).
Écoute sur 127.0.0.1:$PORT (défaut 8000).
  /            page HTML          /health   200 « ok »
  /api/tickets liste JSON         /whoami   JSON {xff, host} (en-têtes reçus)
  /slow?ms=N   répond après N ms  /error    500
"""
import http.server
import json
import os
import time
import urllib.parse

PORT = int(os.environ.get("PORT", "8000"))
TICKETS = [{"id": i, "titre": f"Incident numéro {i}", "etat": "ouvert" if i % 3 else "clos"} for i in range(1, 61)]


class Handler(http.server.BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="text/plain; charset=utf-8"):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/health":
            return self._send(200, "ok\n")
        if url.path == "/api/tickets":
            return self._send(200, json.dumps(TICKETS), "application/json")
        if url.path == "/whoami":
            body = json.dumps({"xff": self.headers.get("X-Forwarded-For", "-"), "host": self.headers.get("Host", "-")})
            return self._send(200, body, "application/json")
        if url.path == "/slow":
            ms = int(urllib.parse.parse_qs(url.query).get("ms", ["500"])[0])
            time.sleep(ms / 1000)
            return self._send(200, "ok\n")
        if url.path == "/error":
            return self._send(500, "erreur\n")
        if url.path == "/":
            return self._send(200, "<h1>Tickets</h1>\n", "text/html; charset=utf-8")
        return self._send(404, "introuvable\n")

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.client_address[0], fmt % args), flush=True)


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
