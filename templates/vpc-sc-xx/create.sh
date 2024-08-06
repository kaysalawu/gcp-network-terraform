#!/bin/bash

# policy
#------------------------------------

gcloud access-context-manager policies create \
--organization ${ORGANIZATION_ID} \
--title ${POLICY_TITLE}
echo ""

POLICY_NAME=$(gcloud access-context-manager policies list \
--organization ${ORGANIZATION_ID} \
--format="value(name)")
echo ""

gcloud config set access_context_manager/policy $POLICY_NAME

# access levels
#------------------------------------

%{~ for x in ACCESS_LEVELS ~}
gcloud access-context-manager levels create ${x.name} \
--title=${x.title} \
--basic-level-spec=<(echo '
- ipSubnetworks:
%{ for p in x.prefixes ~}
  - ${p}
%{ endfor ~}
')
echo ""
%{ endfor ~}

%{ for k,v in PERIMETERS ~}
# perimeter - ${k}
#------------------------------------

gcloud beta access-context-manager perimeters create ${k} \
--title=${k} \
--perimeter-type=${v.type} \
--resources=projects/${v.project_numbers} \
--restricted-services=${v.restricted_services} \
--vpc-allowed-services=RESTRICTED-SERVICES \
--enable-vpc-accessible-services
echo ""

# egress

%{ if length(v.egress) != 0 ~}
gcloud beta access-context-manager perimeters update ${k} \
--set-egress-policies=<(echo '
%{ for rule in v.egress ~}
- egressFrom:
    identities:
%{ for i in rule.from.identities ~}
    - ${i}
%{ endfor ~}
  egressTo:
    resources:
    - projects/${rule.to.project}
%{ for s in rule.to.services ~}
    operations:
    - serviceName: ${s}
      methodSelectors:
%{ for m in rule.to.methods ~}
      - method: ${m}
%{ endfor ~}
%{ endfor ~}
%{ endfor ~}
')
echo ""
%{ endif ~}

# ingress

%{~ if length(v.ingress) != 0 ~}

gcloud beta access-context-manager perimeters update ${k} \
--set-ingress-policies=<(echo '
%{ for rule in v.ingress ~}
- ingressFrom:
    identities:
%{ for i in rule.from.identities ~}
    - ${i}
%{ endfor ~}
%{ if rule.from.project != null ~}
    sources:
    - resource: projects/${rule.from.project}
%{ endif ~}
  ingressTo:
    resources:
    - projects/${rule.to.project}
%{ for s in rule.to.services ~}
    operations:
    - serviceName: ${s}
      methodSelectors:
%{ for m in rule.to.methods ~}
      - method: ${m}
%{ endfor ~}
%{ endfor ~}
%{ endfor ~}
')
echo ""
%{ endif ~}
%{ endfor ~}
