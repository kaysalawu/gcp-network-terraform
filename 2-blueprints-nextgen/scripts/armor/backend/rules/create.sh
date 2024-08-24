#!/bin/bash

%{~ if ENABLE }
gcloud beta compute security-policies rules update 2147483647 \
--project ${PROJECT_ID} \
--security-policy ${POLICY_NAME} \
--action "deny-403"

%{~ for k,v in RULES }
echo -e "\n Create: ${k}\n"
gcloud beta compute security-policies rules create ${v.priority} \
--project ${PROJECT_ID} \
--security-policy=${POLICY_NAME}  \
--description=${k} \
%{~ if !v.ip }
--expression="${v.expression}" \
%{~ endif }
%{~ if v.ip }
--src-ip-ranges=${v.src_ip_ranges} \
%{~ endif }
--action ${v.action}
%{ endfor }

%{~ for b in BACKENDS }
gcloud beta compute backend-services update ${b} \
--project ${PROJECT_ID} \
--security-policy=${POLICY_NAME} \
--global
%{ endfor }
%{ endif }

:
