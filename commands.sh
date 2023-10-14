crc start -c 6 -m 16384 -d 90 -p ~/.crc/pull_secret.json
crc console --credentials | grep admin | awk -F"'" '{print $2}'

oc new-project parca
oc apply -f https://github.com/parca-dev/parca/releases/download/v0.19.0/openshift-manifest.yaml
oc apply -f https://github.com/parca-dev/parca-agent/releases/download/v0.26.0/openshift-manifest.yaml

oc rollout status deploy/parca -n parca

oc -n parca port-forward svc/parca 7070:7070
oc -n parca port-forward pods/$(oc get pods -l app.kubernetes.io/name=parca-agent -o jsonpath='{.items[0].metadata.name}') 7071:7071

oc apply -f pvc.yaml -n parca

oc new-project argocd
oc apply -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml -n argocd
oc adm policy add-scc-to-user privileged -z argocd-redis -n argocd
