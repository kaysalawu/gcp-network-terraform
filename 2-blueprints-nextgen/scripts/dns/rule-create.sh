
%{~ for k,v in RULES }
gcloud beta dns response-policies rules create ${k} \
--project=${PROJECT} \
--response-policy=${RP_NAME} \
--dns-name=${v.dns_name} \
--local-data='${v.local_data}'
%{~ endfor }
