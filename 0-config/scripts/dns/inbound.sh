#!/bin/bash

eval "$(jq -r '@sh "PROJECT=\(.project) REGION=\(.region)"')"

gcloud config set project $PROJECT
IP=$(gcloud compute addresses list --filter="name:dns AND region:$REGION" --format="json" |jq -r '.[0].address')
gcloud config unset project

function output() {
  jq -n --arg ip $IP '{"ip":$ip}'
}

output
