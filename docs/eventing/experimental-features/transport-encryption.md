# Transport Encryption for Knative Eventing

**Flag name**: `transport-encryption`

**Stage**: Alpha, disabled by default

**Tracking issue**: [#5957](https://github.com/knative/eventing/issues/5957)

## Overview

By default, event delivery within the cluster is unencrypted. This limits the types of events which
can be transmitted to those of low compliance value (or a relaxed compliance posture)
or, alternatively, forces administrators to use a service mesh or encrypted CNI to encrypt the
traffic, which poses many challenges to Knative Eventing adopters.

Knative Brokers and Channels provides HTTPS endpoints to receive events. Given that these
endpoints typically do not have public DNS names (e.g. svc.cluster.local or the like), these need to
be signed by a non-public CA (cluster or organization specific CA).

Event producers are be able to connect to HTTPS endpoints with cluster-internal CA certificates.

## Prerequisites

In order to enable the transport encryption feature, you will need to install cert-manager operator
by
following [the cert-manager operator installation instructions](https://cert-manager.io/docs/installation/).

## Transport Encryption configuration

The `transport-encryption` feature flag is an enum configuration that configures how Addressables (
Broker, Channel, Sink) should accept events.

The possible values for `transport-encryption` are:

- `disabled` (this is equivalent to the current behavior)
    - Addressables may accept events to HTTPS endpoints
    - Producers may send events to HTTPS endpoints
- `permissive`
    - Addressables should accept events on both HTTP and HTTPS endpoints
    - Addressables should advertise both HTTP and HTTPS endpoints
    - Producers should prefer sending events to HTTPS endpoints, if available
- `strict`
    - Addressables must not accept events to non-HTTPS endpoints
    - Addressables must only advertise HTTPS endpoints

For example, to enable `strict` transport encryption, the `config-features` ConfigMap will look like
the following:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-features
  namespace: knative-eventing
data:
  transport-encryption: "strict"
```

## Verifying that the feature is working

In case of the `strict` mode the components should have only a single `HTTPS` endpoint. The status of the object does reflect this and also lists the certificate for it. Take a look at this broker status:

```yaml
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  name: my-broker
  namespace: default
spec:
  ...
status:
  address:
    name: http
    url: http://broker-ingress.knative-eventing.svc.cluster.local/default/my-broker
  addresses:
  - CACerts: |
      -----BEGIN CERTIFICATE-----
      MIIBbzCCARegAwIBAgIRAOpna3gP62fPHc12q2TOJycwCgYIKoZIzj0EAwIwGDEW
      MBQGA1UEAxMNc2VsZnNpZ25lZC1jYTAeFw0yMzA4MDMwODE2NTNaFw0yMzExMDEw
      ODE2NTNaMBgxFjAUBgNVBAMTDXNlbGZzaWduZWQtY2EwWTATBgcqhkjOPQIBBggq
      hkjOPQMBBwNCAASapRiZRn5pHR3O84qgwMMQaBW4cfBliHDli9fZ/s29/SpLcZgC
      mr71ZsvyzRqCGYwgvptatRu2nEn1KTA+htQAo0IwQDAOBgNVHQ8BAf8EBAMCAqQw
      DwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUFSVkHQF/rK7qTrfykuNCI0lp/Vcw
      CgYIKoZIzj0EAwIDRgAwQwIfSM38+OVtvdC9gaoEd6wUf9r5dWLaKA4MWyH+0zGk
      IgIgFdCi7IMaXoxDKFil55E8taEO2lom2NT0Z7yldeyMe4I=
      -----END CERTIFICATE-----
    name: https
    url: https://broker-ingress.knative-eventing.svc.cluster.local/default/my-broker
  - name: http
    url: http://broker-ingress.knative-eventing.svc.cluster.local/default/my-broker
  annotations:
    knative.dev/channelCACerts: |
      -----BEGIN CERTIFICATE-----
      MIIBbzCCARegAwIBAgIRAOpna3gP62fPHc12q2TOJycwCgYIKoZIzj0EAwIwGDEW
      MBQGA1UEAxMNc2VsZnNpZ25lZC1jYTAeFw0yMzA4MDMwODE2NTNaFw0yMzExMDEw
      ODE2NTNaMBgxFjAUBgNVBAMTDXNlbGZzaWduZWQtY2EwWTATBgcqhkjOPQIBBggq
      hkjOPQMBBwNCAASapRiZRn5pHR3O84qgwMMQaBW4cfBliHDli9fZ/s29/SpLcZgC
      mr71ZsvyzRqCGYwgvptatRu2nEn1KTA+htQAo0IwQDAOBgNVHQ8BAf8EBAMCAqQw
      DwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUFSVkHQF/rK7qTrfykuNCI0lp/Vcw
      CgYIKoZIzj0EAwIDRgAwQwIfSM38+OVtvdC9gaoEd6wUf9r5dWLaKA4MWyH+0zGk
      IgIgFdCi7IMaXoxDKFil55E8taEO2lom2NT0Z7yldeyMe4I=
      -----END CERTIFICATE-----
...
```

In the case of the `permissive` there will be two endpoints, since the `Addressable` should accept events on both HTTP and HTTPS protocols. For the **HTTPS** endpoint there is same information about the certifcate in the status as well.
