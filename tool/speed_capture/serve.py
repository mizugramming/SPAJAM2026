"""Receive two labelled accelerometer takes from Android Chrome over adb reverse."""
import argparse
import csv
import json
import math
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from tempfile import TemporaryDirectory

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
parser.add_argument("--port", type=int, default=18773)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
page = Path(__file__).with_name("phone.html").read_bytes()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/":
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(page)

    def do_POST(self):
        local_origins = (f"http://localhost:{args.port}", f"http://127.0.0.1:{args.port}")
        if self.path != "/save" or self.headers.get("Origin") not in local_origins:
            self.send_error(403)
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            if not 0 < length <= 2_000_000:
                raise ValueError()
            request = json.loads(self.rfile.read(length))
            ident, rows = request["id"], request["rows"]
            if not re.fullmatch(r"[a-f0-9-]{36}", ident) or not isinstance(rows, list):
                raise ValueError()
            last = -1
            takes = [[], []]
            for row in rows:
                if len(row) != 4 or not all(type(v) in (float, int) and math.isfinite(v) for v in row):
                    raise ValueError()
                t, x, y, z = row
                if not last < t < 26 or t < 0:
                    raise ValueError()
                last = t
                group = int(t >= 13)
                takes[group].append((t - group * 13, x, y, z))
            if any(len(take) < 100 or take[0][0] > 1 or take[-1][0] < 12.5 for take in takes):
                raise ValueError()
        except (ValueError, TypeError, KeyError, OverflowError):
            self.send_error(400)
            return
        dest = args.output / ident
        if not dest.exists():
            with TemporaryDirectory(dir=args.output) as tmp:
                batch = Path(tmp) / "take"
                batch.mkdir()
                for label, take in zip(("slow", "fast"), takes):
                    with (batch / f"{label}.csv").open("w", newline="") as fp:
                        writer = csv.writer(fp)
                        writer.writerow(("t_s","x_m_s2","y_m_s2","z_m_s2"))
                        writer.writerows(take)
                batch.rename(dest)
            print(f"Saved {dest}, slow={len(takes[0])} fast={len(takes[1])}", flush=True)
        self.send_response(204)
        self.end_headers()

HTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
