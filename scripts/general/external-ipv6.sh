#!/bin/bash

external_ip=$(curl -6 ifconfig.co)
echo {\"ip\":\"$external_ip\"}
