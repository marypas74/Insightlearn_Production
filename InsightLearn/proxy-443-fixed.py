#!/usr/bin/env python3
import socket
import threading
import ssl

def handle_client(client_socket, target_host, target_port):
    try:
        # Connect to target server WITHOUT SSL (localhost:8443 already handles SSL)
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
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
                try:
                    source.close()
                except:
                    pass
                try:
                    destination.close()
                except:
                    pass

        # Start forwarding threads
        t1 = threading.Thread(target=forward, args=(client_socket, target_socket), daemon=True)
        t2 = threading.Thread(target=forward, args=(target_socket, client_socket), daemon=True)
        t1.start()
        t2.start()

        t1.join()
        t2.join()

    except Exception as e:
        print(f"Error handling client: {e}")
        try:
            client_socket.close()
        except:
            pass

def start_proxy(listen_ip, listen_port, target_host, target_port):
    # Create SSL context for the listening socket
    context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    context.load_cert_chain('/tmp/192-168-1-103.crt', '/tmp/192-168-1-103.key')

    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((listen_ip, listen_port))
    server_socket.listen(5)

    # Wrap server socket with SSL
    ssl_server_socket = context.wrap_socket(server_socket, server_side=True)

    print(f"HTTPS Proxy listening on {listen_ip}:{listen_port} -> {target_host}:{target_port}")

    try:
        while True:
            client_socket, addr = ssl_server_socket.accept()
            print(f"HTTPS Connection from {addr}")
            threading.Thread(target=handle_client, args=(client_socket, target_host, target_port), daemon=True).start()
    except KeyboardInterrupt:
        print("HTTPS Proxy stopping...")
    finally:
        ssl_server_socket.close()

if __name__ == "__main__":
    start_proxy("192.168.1.103", 443, "127.0.0.1", 8443)