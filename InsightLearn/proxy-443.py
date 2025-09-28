#!/usr/bin/env python3
import socket
import threading
import ssl

def handle_client(client_socket, target_host, target_port):
    try:
        # Connect to target server
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        # Wrap with SSL for HTTPS proxy
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        target_socket = context.wrap_socket(target_socket)

        target_socket.connect((target_host, target_port))

        def forward(source, destination):
            try:
                while True:
                    data = source.recv(4096)
                    if not data:
                        break
                    destination.send(data)
            except:
                pass
            finally:
                source.close()
                destination.close()

        # Start forwarding threads
        threading.Thread(target=forward, args=(client_socket, target_socket), daemon=True).start()
        threading.Thread(target=forward, args=(target_socket, client_socket), daemon=True).start()

    except Exception as e:
        print(f"Error: {e}")
        client_socket.close()

def start_proxy(listen_ip, listen_port, target_host, target_port):
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((listen_ip, listen_port))
    server_socket.listen(5)

    print(f"HTTPS Proxy listening on {listen_ip}:{listen_port} -> {target_host}:{target_port}")

    try:
        while True:
            client_socket, addr = server_socket.accept()
            print(f"Connection from {addr}")
            threading.Thread(target=handle_client, args=(client_socket, target_host, target_port), daemon=True).start()
    except KeyboardInterrupt:
        print("Proxy stopping...")
    finally:
        server_socket.close()

if __name__ == "__main__":
    start_proxy("192.168.1.103", 443, "127.0.0.1", 8443)