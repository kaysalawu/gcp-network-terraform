#!/bin/bash

gcloud auth configure-docker

echo "Please select a GCP project:"
gcloud projects list --format="value(projectId)" | nl
read -p "Enter the number of the project you wish to use: " project_number
project_id=$(gcloud projects list --format="value(projectId)" | sed "${project_number}q;d")

echo "Please select a GKE cluster:"
gcloud container clusters list --format=json --project=$project_id | jq -r '.[] | "\(.name) (\(.location))"' | nl
read -p "Enter the number of the cluster you wish to use: " cluster_number

cluster_name=$(gcloud container clusters list --format=json --project=$project_id | jq -r ".[$((cluster_number - 1))].name")
location=$(gcloud container clusters list --format=json --project=$project_id | jq -r ".[$((cluster_number - 1))].location" | cut -d'/' -f4)

gcloud container clusters get-credentials $cluster_name --region $location --project=$project_id
