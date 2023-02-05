#!/bin/bash

POLICY_NAME=$(gcloud access-context-manager policies list --organization ${ORGANIZATION_ID} --format="value(name)")

%{ for x in PERIMETERS ~}
gcloud -q access-context-manager perimeters delete ${x} --policy=$POLICY_NAME && echo ""
%{ endfor ~}
