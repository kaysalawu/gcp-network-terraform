
%{~ for k,v in RULES }
gcloud beta -q dns response-policies rules delete ${k} \
--project=${PROJECT} \
--response-policy=${RP_NAME}
%{~ endfor }
