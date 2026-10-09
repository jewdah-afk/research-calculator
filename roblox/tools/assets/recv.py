import base64, http.server, os, sys
OUT = os.path.expanduser('~/Downloads/rc-main/roblox/assets/' + (sys.argv[1] if len(sys.argv) > 1 else 'TreeAssets.rbxm'))
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers['Content-Length'])
        data = base64.b64decode(self.rfile.read(n))
        open(OUT, 'wb').write(data)
        self.send_response(200); self.end_headers(); self.wfile.write(b'saved %d' % len(data))
        print('saved', len(data), flush=True)
        sys.exit(0)
http.server.HTTPServer(('127.0.0.1', 8779), H).handle_request()
