#!/bin/bash
#
# Prereqs: a running ocp 4 cluster, logged in as kubeadmin
#

# Defaults
USERCOUNT=15
MODULE=m3
GOGS_PWD=r3dh4t1!

# get routing suffix
TMP_PROJ="dummy-$RANDOM"
oc new-project $TMP_PROJ
oc create route edge dummy --service=dummy --port=8080 -n $TMP_PROJ
ROUTE=$(oc get route dummy -o=go-template --template='{{ .spec.host }}' -n $TMP_PROJ)
HOSTNAME_SUFFIX=$(echo $ROUTE | sed 's/^dummy-'${TMP_PROJ}'\.//g')
MASTER_URL=$(oc whoami --show-server)
CONSOLE_URL=$(oc whoami --show-console)

echo -e "HOSTNAME_SUFFIX: $HOSTNAME_SUFFIX \n"

# deploy guides
for i in $(eval echo "{0..$USERCOUNT}") ; do
  MODULE_NO=$(echo $MODULE | cut -c 2)
  oc new-project user${i}-guides
  oc adm policy add-scc-to-user anyuid -z default -n user${i}-guides
  oc adm policy add-scc-to-user privileged -z default -n user${i}-guides 
  oc adm policy add-role-to-user admin user$i -n user${i}-guides

  oc -n user${i}-guides new-app quay.io/osevg/workshopper --name=user${i}-guides-${MODULE} \
      -e MASTER_URL=$MASTER_URL \
      -e CONSOLE_URL=$CONSOLE_URL \
      -e ECLIPSE_CHE_URL=http://codeready-labs-infra.$HOSTNAME_SUFFIX \
      -e KEYCLOAK_URL=http://keycloak-labs-infra.$HOSTNAME_SUFFIX \
      -e GIT_URL=http://gogs-labs-infra.$HOSTNAME_SUFFIX \
      -e ROUTE_SUBDOMAIN=$HOSTNAME_SUFFIX \
      -e CONTENT_URL_PREFIX="https://raw.githubusercontent.com/bmachado/cloud-native-workshop-v2$MODULE-guides/master" \
      -e WORKSHOPS_URLS="https://raw.githubusercontent.com/bmachado/cloud-native-workshop-v2$MODULE-guides/master/_cloud-native-workshop-module$MODULE_NO.yml" \
      -e CHE_USER_NAME=user${i} \
      -e CHE_USER_PASSWORD=${GOGS_PWD} \
      -e OPENSHIFT_USER_NAME=user${i} \
      -e OPENSHIFT_USER_PASSWORD=${GOGS_PWD} \
      -e RHAMT_URL=http://rhamt-web-console-labs-infra.$HOSTNAME_SUFFIX \
      -e LOG_TO_STDOUT=true
  oc -n user${i}-guides expose svc/user${i}-guides-${MODULE}
done

oc delete project $TMP_PROJ