create cjmark-nodes-historical  --schedule "*/5 * * * *"  --image=appdynamicscx/mark-nodes-historical --dry-run=client -o yaml > mark-nodes-historical.yaml 
create cm mark-nodes-historical-config --from-env-file=env.list $do > configmap.yaml 
k create secret generic mark-nodes-historical-secret --from-literal=jwt=blabal $do > secret.yaml 