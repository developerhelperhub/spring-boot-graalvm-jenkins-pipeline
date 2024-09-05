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

  kube_prometheus_stack_enable = true
  prometheus_service_port      = 9090
  prometheus_domain_name       = var.prometheus_domain_name

  grafana_service_port   = 80
  grafana_domain_name    = var.grafana_domain_name
  grafana_admin_password = module.common.random_password_16

  prometheus_alertmanager_enabled      = true
  prometheus_persistent_volume_enabled = true
  prometheus_persistent_volume_size    = "1Gi"
}
