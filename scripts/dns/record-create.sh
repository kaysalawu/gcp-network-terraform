
%{~ for k,v in RECORDS }
gcloud beta dns record-sets create ${k} \
--project=${PROJECT} \
--ttl=${v.ttl} \
--type=${v.type} \
--zone=${v.zone} \
--routing_policy_type=${v.policy_type} \
--routing_policy_data='${v.policy_data}'
%{~ endfor }
