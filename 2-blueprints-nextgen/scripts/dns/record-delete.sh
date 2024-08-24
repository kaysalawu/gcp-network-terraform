
%{~ for k,v in RECORDS }
gcloud beta dns record-sets delete ${k} \
--project=${PROJECT} \
--type=${v.type} \
--zone=${v.zone}
%{~ endfor }
