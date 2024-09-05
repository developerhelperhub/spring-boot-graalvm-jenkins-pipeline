# Development - Run DevOps Applications in Kubernetes Cluster locally
These Terraform scripts help set up DevOps applications necessary for application development. The module is hosted in a GitHub repository called ["DevOps Terraform Module."](https://github.com/developerhelperhub/devops-terraform-module).

The following applications will be deployed locally in a Kubernetes cluster.
* Jenkins
* JFrog
* Prometheus
* Grafana

**Root Main Terraform Script** `main.tf`
```shell
module "common" {
  source = "git::https://github.com/developerhelperhub/devops-terraform-module.git//modules/common?ref=v1.1.0"
}

module "devops" {
  source = "git::https://github.com/developerhelperhub/devops-terraform-module.git//devops?ref=v1.1.0"

  kind_cluster_name = var.kind_cluster_name
  kind_http_port    = 80
  kind_https_port   = 443

  kubernetes_namespace = "devops"

  jenkins_service_port   = 8080
  jenkins_enable         = true
  jenkins_domain_name    = var.jenkins_domain_name
  jenkins_admin_username = var.jenkins_admin_username
  jenkins_admin_password = module.common.random_password_16

  jfrog_service_port        = 8082
  jfrog_enable              = true
  jfrog_domain_name         = var.jfrog_domain_name
  jfrog_postgresql_password = module.common.random_password_16

  #Disabled the Grafana and Prometheus 
  kube_prometheus_stack_enable = false
  prometheus_service_port      = 9090
  prometheus_domain_name       = var.prometheus_domain_name

  grafana_service_port   = 80
  grafana_domain_name    = var.grafana_domain_name
  grafana_admin_password = module.common.random_password_16

  prometheus_alertmanager_enabled      = true
  prometheus_persistent_volume_enabled = true
  prometheus_persistent_volume_size    = "1Gi"
}
```

## Setup local environment to build DevOps resources
I use docker containers to set up work environments for multiple applications([Setup Environment](https://dev.to/binoy_59380e698d318/setup-linux-box-on-local-with-docker-container-3k8)). This approach ensures fully isolated and maintainable environments for application development, allowing us to easily start and terminate these environments. Below is the Docker command to create the environment.
```shell
docker run -it --name test-devops-module-envornment-box -v ~/.kube/config:/work/.kube/config -e KUBECONFIG=/work/.kube/config -v ${HOME}/root/ -v ${PWD}:/work -w /work --net host developerhelperhub/kub-terr-work-env-box
```
The container contains Docker, Kubectl, Helm, Terraform, Kind, Git

## Setup DevOps Applications on Kubernetes Cluster 
I have developed all the necessary Terraform scripts, which are available in a GitHub repository. You can download these scripts to set up various DevOps applications, which are deployed on a Kubernetes cluster running locally in a Docker container.

**Clone the repository** onto your local Linux machine to get started.
```shell
git clone https://github.com/developerhelperhub/kuberentes-help.git
cd kuberentes-help/terraform/dev/terraform-module-devops/
```
Run the following commands to install the resources
```shell
terraform init
terraform plan -var="kind_cluster_name=devops-test-cluster"
terraform apply -var="kind_cluster_name=devops-test-cluster"
```

**Note:** The Terraform state file should be kept secure and encrypted (using encryption at rest) because it contains sensitive information, such as usernames, passwords, and Kubernetes cluster details etc.

Add our domain to the bottom of the `/etc/hosts` file on your local machine. This configuration should not be inside our working Linux box “test-jenkins-module-envornment-box”; it should be applied to your personal machine's `/etc/hosts` file. 
(you will need administrator access):
```shell
127.0.0.1       jenkins.devops.com
127.0.0.1       jfrog.devops.com
127.0.0.1       prometheus.devops.com
127.0.0.1       grafana.devops.com
```
## Applications 
* Jenkins Username and password will be available in the Terraform state file, URL “http://jenkins.devops.com/”
* JFrog username and password are "admin" and "password", URL “http://jfrog.devops.com/”
* Prometheus URL “http://prometheus.devops.com/”
* Grafana Username is "admin", password will be available in the Terraform state file, URL “http://grafana.devops.com/”

## Reference
* [Maintain Module Version](https://github.com/developerhelperhub/kuberentes-help/tree/main/terraform/sections/00004)
* [Jfrog Deployment in Kubernetes](https://github.com/developerhelperhub/kuberentes-help/tree/main/terraform/sections/00005)
* [Module Design Jenkins Deployment in Kubernetes](https://github.com/developerhelperhub/kuberentes-help/tree/main/terraform/sections/00003)
* [Setup Terraform - Jenkins](https://github.com/developerhelperhub/kuberentes-help/tree/main/terraform/sections/00002)
* [Setup Kubernetes Cluster on Docker with help of Kind](https://github.com/developerhelperhub/kuberentes-help/tree/main/terraform/sections/00001)