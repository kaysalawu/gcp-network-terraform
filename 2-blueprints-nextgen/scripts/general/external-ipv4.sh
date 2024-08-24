#!/bin/bash

external_ip=$(curl -4 ifconfig.co)
echo {\"ip\":\"$external_ip\"}
