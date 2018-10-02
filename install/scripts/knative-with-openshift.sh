#!/usr/bin/env bash

# Turn colors in this script off by setting the NO_COLOR variable in your
# environment to any value:
#
# $ NO_COLOR=1 test.sh
NO_COLOR=${NO_COLOR:-""}
if [ -z "$NO_COLOR" ]; then
  header=$'\e[1;33m'
  reset=$'\e[0m'
else
  header=''
  reset=''
fi

function header_text {
  echo "$header$*$reset"
}

header_text "Starting Knative test-drive on OpenShift!"

echo "Using oc version:"
oc version

header_text "Writing config"
oc cluster up --write-config
sed -i -e 's/"admissionConfig":{"pluginConfig":null}/"admissionConfig": {\
    "pluginConfig": {\
        "ValidatingAdmissionWebhook": {\
            "configuration": {\
                "apiVersion": "v1",\
                "kind": "DefaultAdmissionConfig",\
                "disable": false\
            }\
        },\
        "MutatingAdmissionWebhook": {\
            "configuration": {\
                "apiVersion": "v1",\
                "kind": "DefaultAdmissionConfig",\
                "disable": false\
            }\
        }\
    }\
}/' openshift.local.clusterup/kube-apiserver/master-config.yaml

header_text "Starting OpenShift with 'oc cluster up'"
oc cluster up --server-loglevel=5

header_text "Logging in as system:admin and setting up default namespace"
oc login -u system:admin
oc project myproject
oc adm policy add-scc-to-user privileged -z default -n myproject
oc label namespace myproject istio-injection=enabled

header_text "Setting up security policy for istio"
oc adm policy add-scc-to-user anyuid -z istio-ingress-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z default -n istio-system
oc adm policy add-scc-to-user anyuid -z prometheus -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-egressgateway-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-citadel-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-ingressgateway-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-cleanup-old-ca-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-mixer-post-install-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-mixer-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-pilot-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-sidecar-injector-service-account -n istio-system
oc adm policy add-cluster-role-to-user cluster-admin -z istio-galley-service-account -n istio-system

header_text "Installing istio"
curl -L https://storage.googleapis.com/knative-releases/serving/latest/istio.yaml \
  | sed 's/LoadBalancer/NodePort/' \
  | oc apply -f -

header_text "Waiting for istio to become ready"
sleep 5; while echo && oc get pods -n istio-system | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Updating sidecar injector priviledged to true"
oc get cm istio-sidecar-injector -n istio-system -oyaml  \
| sed -e 's/securityContext:/securityContext:\\n      privileged: true/' \
| oc replace -f -

header_text "Check if SELinux is enabled in order to restart the sidecar-injector pod"
os="$(uname -s)"
if [ "$os" = "Linux" ]
then
    sel="$(getenforce | grep Disabled | wc -l)"
    if [ "$sel" = "1" ]
    then
        header_text "SELinux is disabled, no need to restart the pod"
    else
        header_text "SELinux is enabled, restarting sidecar-injector pod"
        oc delete pod -n istio-system -l istio=sidecar-injector
    fi
fi

header_text "Setting up security policy for knative"
oc adm policy add-scc-to-user anyuid -z build-controller -n knative-build
oc adm policy add-scc-to-user anyuid -z controller -n knative-serving
oc adm policy add-scc-to-user anyuid -z autoscaler -n knative-serving
oc adm policy add-scc-to-user anyuid -z kube-state-metrics -n monitoring
oc adm policy add-scc-to-user anyuid -z node-exporter -n monitoring
oc adm policy add-scc-to-user anyuid -z prometheus-system -n monitoring
oc adm policy add-cluster-role-to-user cluster-admin -z build-controller -n knative-build
oc adm policy add-cluster-role-to-user cluster-admin -z controller -n knative-serving
oc adm policy add-scc-to-user anyuid -z eventing-controller -n knative-eventing
oc adm policy add-cluster-role-to-user cluster-admin -z eventing-controller -n knative-eventing

header_text "Installing Knative-serving and Knative-build components"
curl -L https://github.com/knative/serving/releases/download/v0.1.1/release.yaml \
  | sed 's/LoadBalancer/NodePort/' \
  | oc apply -f -

header_text "Waiting for Knative-serving to become ready"
sleep 5; while echo && oc get pods -n knative-serving | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Waiting for Knative-build to become ready"
sleep 5; while echo && oc get pods -n knative-build | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Installing Knative-eventing"
curl -L https://storage.googleapis.com/knative-releases/eventing/latest/release.yaml \
  | sed 's/default-cluster-bus: stub/default-cluster-bus: kafka/' \
  | oc apply -f -

header_text "Waiting for Knative-eventing to become ready"
sleep 5; while echo && oc get pods -n knative-eventing | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Setting up Strimzi for Openshift"
wget https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.7.0/strimzi-0.7.0.tar.gz
tar xfvz strimzi-0.7.0.tar.gz
cd strimzi-0.7.0

oc apply -f examples/install/cluster-operator -n myproject
oc apply -f examples/templates/cluster-operator -n myproject

header_text "Waiting for Strimzi Cluster Operator to become ready"
sleep 5; while echo && oc get pods -n myproject | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

oc apply -f examples/kafka/kafka-ephemeral.yaml

cd ..


### plguin the bus

## k8s event source

## app for stuff
