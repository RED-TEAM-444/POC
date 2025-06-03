# Save this as mock-c2.py
from http.server import BaseHTTPRequestHandler, HTTPServer

class C2Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        print("[+] Data Received:")
        print(post_data.decode())
        self.send_response(200)
        self.end_headers()

server = HTTPServer(('0.0.0.0', 80), C2Handler)
print("[*] Listening on port 80...")
server.serve_forever()
