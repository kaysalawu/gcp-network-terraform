#!/bin/sh

while true; do
  nc -l -p 7687 -c "/usr/local/bin/handle_connection.py"
done
