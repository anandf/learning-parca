# learning-parca

## Run profiling for ArgoCD components

### Openshift Local (CRC) based setup


#### Steps

- Create a local CRC setup and initialize it
```
crc setup
crc start -c 6 -m 16384 -d 90 -p ~/.crc/pull_secret.json
crc console --credentials | grep admin | awk -F"'" '{print $2}'
```

- Create a project/namespace for deploying the parca components.
```
oc new-project parca
# Install parca-server component
oc apply -f https://github.com/parca-dev/parca/releases/download/v0.19.0/openshift-manifest.yaml
oc rollout status deploy/parca -n parca
# Install parca-agent component
oc apply -f https://github.com/parca-dev/parca-agent/releases/download/v0.26.0/openshift-manifest.yaml
oc rollout status daemonset/parca-agent -n parca
```

- Create a port-forwarding session for both the server and agent components.
```
oc -n parca port-forward svc/parca 7070:7070
oc -n parca port-forward pods/$(oc get pods -l app.kubernetes.io/name=parca-agent -o jsonpath='{.items[0].metadata.name}') 7071:7071
```

- Create a PVC with default storage as storing ArgoCD profiles requires lot of disk space
```
oc apply -f pvc.yaml -n parca
```

- Modify the `data` volume in parca server component to use the disk space from pvc instead of `emptyDir`
```
oc patch deployment parca --type json -p='[{"op": "replace", "path": "/spec/template/spec/volumes/1", "value": {"name": "data", "persistentVolumeClaim":{"claimName": "parca-data"}}}]'
```

- Create the scraping config for pulling net/pprof profile data from ArgoCD components
```
oc apply -f parca_cm.yaml -n parca
```

- Redeploy the parca-server component to reload the config map changes
```
oc scale deploy/parca -n parca --replicas=0
oc scale deploy/parca -n parca --replicas=1
oc rollout status deploy/parca -n parca
```

- Deploy the ArgoCD components in `argocd` namespace
```
oc new-project argocd
oc apply -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml -n argocd
oc adm policy add-scc-to-user privileged -z argocd-redis -n argocd
```

- Restart the port-forward session after the redeployment
```
oc -n parca port-forward svc/parca 7070:7070
```

- Access the Web UI at http://localhost:7070 in a web brower (chrome, firefox)

- Start seeing the profile data. You can filter for all pods running in `argocd` namespace by setting filter criteria to `namespace="argocd"`

