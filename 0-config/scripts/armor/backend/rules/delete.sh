#!/bin/bash

%{~ if ENABLE }
%{~ for k,v in RULES }
echo -e "\n Delete: ${k}\n"
gcloud beta -q compute security-policies rules delete ${v.priority} \
--project ${PROJECT_ID} \
--security-policy=${POLICY_NAME}
%{ endfor }

%{~ for b in BACKENDS }
gcloud beta compute backend-services update ${b} \
--project ${PROJECT_ID} \
--security-policy='' \
--global
%{ endfor }
%{ endif }

:
