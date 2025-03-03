#!/usr/bin/env python3
import socket
import os

PORT = 9000
hostname = socket.gethostname()

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server_socket:
    server_socket.bind(("0.0.0.0", PORT))
    server_socket.listen()

    print(f"Listening on port {PORT}...")

    while True:
        connection, client_address = server_socket.accept()
        with connection:
            print(f"Connection from {client_address}")
            message = f"Appy-TCP remote={client_address[0]}, hostname={hostname}\n"
            connection.sendall(message.encode())
            print(f"Sent: {message}")
