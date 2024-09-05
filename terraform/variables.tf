#This is variable arguments while running the terraform scripts
variable "kind_cluster_name" {
    type = string
    description = "Kind cluster name"
}
variable "jenkins_domain_name" {
    type = string
    description = "Jenkins domain name"
    default = "jenkins.devops.com"
}
variable "jenkins_admin_username" {
    type = string
    description = "Jenkins admin username"
    default = "test_admin"
}
variable "jfrog_domain_name" {
    type = string
    description = "JFrog domain name"
    default = "jfrog.devops.com"
}

variable "prometheus_domain_name" {
    type = string
    description = "Prometheus domain name"
    default = "prometheus.devops.com"
}

variable "grafana_domain_name" {
    type = string
    description = "Grafana domain name"
    default = "grafana.devops.com"
}

