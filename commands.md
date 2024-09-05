

### Terraform
* https://registry.terraform.io/providers/kyma-incubator/kind/latest/docs/resources/cluster
* https://devopscube.com/jenkins-build-agents-kubernetes/

### Jenkins
* https://www.jenkins.io/doc/book/installing/kubernetes/#setup-jenkins-on-kubernetes
* https://plugins.jenkins.io/kubernetes/
* https://www.jenkins.io/doc/book/platform-information/support-policy-java/
* https://www.jenkins.io/doc/book/managing/nodes/
* https://blog.thecloudside.com/docker-in-docker-with-jenkins-pod-on-kubernetes-f2b9877936f2

## Delete and get the pods different status
```shell
kubectl delete -n jenkins pods --field-selector status.phase=Failed
kubectl get -n jenkins pods --field-selector status.phase=Running
kubectl delete -n jenkins pods --field-selector status.phase!=Running
```
## Inspect the IP of docker engine
```shell
docker network inspect bridge
```
We have to use "Gateway": "172.17.0.1" as IP address of Docker Engine

## Create the presistance volumne and claim
```shell
kubectl apply -n devops -f maven-repo-pv-pvc.yaml
kubectl get -n devops pv
kubectl get -n devops pvc
```

## Configure the resoures maven config and secret
```shell
kubectl -n devops create configmap maven-settings --from-file=settings.xml
kubectl -n devops delete configmap maven-settings

kubectl -n devops create secret generic maven-credentials --from-file=settings-security.xml
kubectl -n devops delete secret maven-credentials
kubectl -n devops get secret
```

## Debug the Pod Template
```shell
kubectl apply -n devops -f graalvm-22-muslib-maven-jenkins-agent-template.yaml

kubectl -n devops exec -it graalvm-22-muslib-maven-jenkins-agent-template -c builder -- sh

du -sh /root/.m2

kubectl -n jenkins exec -it graalvm-22-muslib-maven-jenkins-agent-template -c docker -- sh

kubectl delete -n devops -f graalvm-22-muslib-maven-jenkins-agent-template.yaml
```
