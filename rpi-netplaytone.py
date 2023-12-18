#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime
from time import sleep
import subprocess
import argparse

def bigben_overlap_wait():
    overlap = [0, 15, 30, 45]
    for o in overlap:
        if datetime.now().minute == o:
            print('Waiting overlap with Big Ben...')
            sleep(40)

def playtone(script_file, gpio_pin, tone_file):
    bigben_overlap_wait()
    try:
        result = subprocess.run([
            script_file,
            "--gpio-pin",
            str(gpio_pin),
            "--filename",
            TONE_PATH + tone_file],
            capture_output=True,
            text=True
        )
        return result
    except subprocess.CalledProcessError as e:
        print("[ERROR]: code {}\nCommand: {}\nOutput: {}\n".format(
            e.returncode, e.cmd, e.output
        ))
        return e

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/play'):
            tone_file = self.path.split('/')[-1]
            play_process = playtone(PLAYTONE_SCRIPT, GPIO_PIN, tone_file)
            if not play_process.returncode:
                message = play_process.stdout + "\n"
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(bytes(message, "utf8"))
            else:
                message = "[ERROR]: code {}\nCommand: {}\nOutput: {}\nError Output: {}\n".format(
                    play_process.returncode, play_process.args, play_process.stdout, play_process.stderr
                )
                self.send_response(500)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(bytes(message, "utf8"))
        else:
            self.send_response(404)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(bytes("Not Found\n", "utf8"))

def run(bind_address, port, server_class=HTTPServer, handler_class=RequestHandler):
    server_address = (bind_address, port)
    httpd = server_class(server_address, handler_class)
    print("Starting server binding at {}:{}".format(bind_address, port))
    httpd.serve_forever()

# Main code
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='A web server for playing PC Speaker tones for BBS pagers')
    parser.add_argument('--gpio-pin', type=int, action='store', help='The GPIO pin to use in the Raspberry Pi, defaults to 13', default=13)
    parser.add_argument('--playtone-script', type=str, action='store', help='The script used to play .TON files.', default='/usr/local/bin/playtone.bash')
    parser.add_argument('--tone-path', type=str, action='store', help='The folder where the .TON files will be looked for.', default='/usr/local/share/sbbstone/')
    parser.add_argument('--bind-address', type=str, action='store', help='The interface address to bind.', default='0.0.0.0')
    parser.add_argument('--port', type=int, action='store', help='The TCP port where the server will listen.', default=8000)
    args = parser.parse_args()

    GPIO_PIN=args.gpio_pin
    PLAYTONE_SCRIPT=args.playtone_script
    TONE_PATH=args.tone_path
    if TONE_PATH[-1] != '/':
        TONE_PATH += '/'

    try:
        run(args.bind_address, args.port)
    except KeyboardInterrupt:
        print("\nServer stopped")
