# 0008-Setup efficient CICD Pipeline Jenkins to build binary and push docker image on Kubernetes cluster

# Overview
This section outlines how to set up an efficient CI/CD pipeline in Jenkins, running on a Kubernetes cluster. The pipeline is designed to build Docker images that can be deployed in containers. In this section, I didn’t include the deploy image on Kubernetes cluster

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725561587363_devops-Jenkins+Deployment.drawio+1.png)


# Objective
In a microservice architecture, it is crucial to focus on scalability, performance, security, and maintainability throughout the CI/CD process in the software development life cycle. Based on my analysis and the challenges identified, this document highlights key design considerations to achieve a reliable and efficient CI/CD implementation. 

The following points are considered in this design:
- **Dynamic Agents on Kubernetes:** Utilise dynamic agents running on the Kubernetes cluster, allowing for quick start and termination. This approach optimises memory and resource utilisation within the cluster and enhances scalability.
- **Local Dependency Caching:** Implement local caching of dependencies to reduce build times.
- **Isolation of DevOps Resources:** Isolate DevOps resources and ensure security to protect sensitive information and maintain a secure CI/CD environment.
- **Centralised DevOps Resources:** Use centralised DevOps resources to run the CI/CD process, enabling deployment across different environments.
- **Reliable Build Process:** Ensure a reliable build process that includes verifying dependencies, compiling code, executing tests, and packaging the application.
- **Maintain the Artifactory in development**: Ensue we have install the Artifactory in our infrastructure to store the application dependencies, application libraries to get the following benefits
    - Get the control and secure the dependencies of application
    - Get the cache the application dependencies to avoid the download time, we know the Kubernetes cluster running on multiple nodes
    - Use the same dependencies and libraries by the team and CICD Pipeline
    - We can add the retention policy to delete the unused dependencies and reduce the storage cost
    - We can use JFrog Artifactory as proxy server  to connect the build tools for downloading the dependencies for our applications instead of directly downloading from maven central repository

In a separate article, I discussed essential design considerations for building scalable and high-performance applications, such as [creating native images from Spring Boot applications using the GraalVM builder](https://dev.to/binoy_59380e698d318/build-native-image-from-spring-boot-application-with-graalvm-builder-3b7l). The principles outlined in that article are also applied to setting up the CI/CD pipeline in Jenkins, running on a Kubernetes cluster.

# Setup the Jenkins and JFrog Artifactory locally in Kubernetes Cluster
I have created Terraform scripts to deploy Jenkins and JFrog Artifactory locally on a Kubernetes cluster. These scripts are explained in a separate [article](https://dev.to/binoy_59380e698d318/deploy-jenkins-frog-grafana-and-prometheus-applications-in-kubernetes-cluster-terraform-2ann). They make it easy to deploy applications within a Kubernetes cluster that runs on Docker on our local machine. The process of [deploying a Kubernetes cluster on Docke](https://dev.to/binoy_59380e698d318/setup-linux-box-on-local-with-docker-container-3k8)r is also detailed in another article.

**Setup working environment in Docker container**  
```shell
docker run -it --name working-envornment-box -v ~/.kube/config:/work/.kube/config -e KUBECONFIG=/work/.kube/config -v ${HOME}:/root/ -v ${PWD}:/work -w /work --net host developerhelperhub/kub-terr-work-env-box
```
**Download the Terraform Script in docker container and Deploy The service**
```shell
#Download the source codes
git clone https://github.com/developerhelperhub/kuberentes-help.git
cd kuberentes-help/kubenretes/tutorials/sections/0008/terraform

#Setup the cluster and deploy the application with terraform
terraform init
terraform plan -var="kind_cluster_name=devops-test-cluster"
terraform apply -var="kind_cluster_name=devops-test-cluster"
```
Add our domain to the bottom of the `/etc/hosts` file on your local machine. This configuration should not be inside our working Linux box “working-envornment-box”; it should be applied to your personal machine's `/etc/hosts` file.
(you will need administrator access):
```shell
127.0.0.1       jenkins.devops.com
127.0.0.1       jfrog.devops.com
```
- Jenkins Username and password will be available in the Terraform state file, URL “[http://jenkins.devops.com/”](http://jenkins.devops.com/%E2%80%9D)
- JFrog username and password are "admin" and "password", URL “[http://jfrog.devops.com/”](http://jfrog.devops.com/%E2%80%9D)

## Setup Repositories in JFrog Artifactory
We have to create the repository in the Artifactory for maintaining the central repository and application repository. I have explained another article, how to connect the spring boot application in [JFrog Artifactory](https://dev.to/binoy_59380e698d318/setup-jfrog-artifactory-on-kubernetes-and-connect-spring-boot-application-1n4c). Following repositories needs to be create in the “[http://jfrog.devops.com/”](http://jfrog.devops.com/%E2%80%9D) artifactory.

Navigate to “Artifactory → Artifacts → Manage Repositories → Create Repository” and create the following repositories:
- **Local**: This repository manages your application binaries. For example “my-app-snapshot”
    - Name: my-app-snapshot
    - Environments: DEV
- **Remote**: This repository stores all dependencies used in your application, which will be downloaded from central repositories and stored in repository. For example “my-app-central-snapshot”
    - Name: my-app-central-snapshot
    - Environments: DEV
- **Virtual**: This virtual repository provides a common endpoint that aggregates the “Local” and “Remote” repositories. This endpoint will be configured in your application. “my-app-virtual-snapshot”
    - Name: my-app-virtual-snapshot
    - Environments: DEV
    - Repositories: Added “my-app-snapshot” and “my-app-central-snapshot” repositories
    - Default Deployment Repository: Select “my-app-snapshot” repository

Finally you are able to view the repositories like this inside JFrog Artifactory:

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725221189981_image.png)


We use a common Maven configuration to connect to JFrog Artifactory for application builds. In the Jenkins agent pod on Kubernetes, the shared `.m2/settings.xml` is mounted to connect to the repository and mirror JFrog Artifactory. Additionally, the project's `pom.xml` is configured to publish application versions to the Artifactory repository.
```xml
<distributionManagement>
    <repository>
        <uniqueVersion>false</uniqueVersion>
        <id>my-app-virtual-snapshot</id>
        <name>my-app-virtual-snapshot</name>
        <url>http://jfrog-artifactory-oss.devops.svc.cluster.local:8081/artifactory/my-app-virtual-snapshot/</url>
        <layout>default</layout>
    </repository>
</distributionManagement>
```
# Setup maven configuration on Kubernetes cluster
We need to configure the Maven-related resources in the Kubernetes cluster. As I mentioned earlier, we're using Kubernetes to run the Jenkins Agent for building the application's native binary. In this scenario, we need to set up Maven repository caching and connect to JFrog Artifactory to download the necessary dependencies for building the application's binary.

## Setup Persistence Storage on Kubernetes Cluster to Cache the .m2/repository
We need to create persistent storage in the cluster to cache the `.m2/repository`. This persistent storage will be used to mount a volume to the Jenkins agent pod. Once dependencies are downloaded from Artifactory, this cache will be utilized for building applications, preventing the need to download dependencies each time a build is executed in the Jenkins agent pod.
Following configuration need to add in the `maven-repo-pv-pvc.yaml` file
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: maven-repo-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: "/mnt/data/maven-repo"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: maven-repo-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: manual
  resources:
    requests:
      storage: 10Gi
```
Execute the following command to create the resources and verify it
```shell
#Apply file in the Kubenertes cluster
kubectl apply -n devops -f maven-repo-pv-pvc.yaml

#Verif the Presistance Volume and Presistance Volume Claim
kubectl get -n devops pv
kubectl get -n devops pvc
```

## Configure the maven settings.xml for connecting JFrog Artifactory in .m2 folder
We need to create a Kubernetes ConfigMap to configure the `settings.xml` file in the `.m2` folder, which will be mounted in the Jenkins agent pod. In this example, I'm using the JFrog Artifactory admin username and password. However, it's best practice to create a separate user with the appropriate roles and permissions for the specific repositories. This approach ensures proper control over the repositories in accordance with security policies.

When managing or using the JFrog Artifactory password in Maven configuration, it's important to store it securely rather than in plain text. Maven offers functionality to encrypt the application's password using a master password. To achieve this, we need to set up a master password and store it in the `settings-security.xml` file.

You need to run the following Maven command to generate the encrypted master password. This command will prompt you to enter your master password.
```shell
mvn --encrypt-master-password
```
For example, after running the command, the encrypted string will be displayed in the console. This string should be added to the `settings-security.xml` file for configuration.
```shell
{HAEd11iX7PMHppeclHfsksksIjslalamajPs0tA+PA8d+oDgtWkclKRccu71N4UMGAB5B/GC155}
```
Create the `settings-security.xml` file and add the following configuration to it. This file will be stored in a Kubernetes secret and mounted in the Jenkins agent pod.
```xml
<settingsSecurity>
  <master>{HAEd11iX7PMHppeclHfsksksIjslalamajPs0tA+PA8d+oDgtWkclKRccu71N4UMGAB5B/GC155}</master>
</settingsSecurity>
```
We need to generate the encrypted password for JFrog Artifactory.
```shell
mvn --encrypt-password <jfrog-artifactory-admin-password>
```
For example, after running the command, the encrypted string will be displayed in the console. This string should be configured in the `password` attribute within the `settings.xml` file.
```shell
{jSMOWnoPFgsHVpMvz5VrIt5sKsldljdlskRbzGpI8u+9EF1iFQyJQ=}
```
Create the `settings.xml` file and configure the following configuration in the file
```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
    <servers>
        <server>
            <id>my-app-virtual-snapshot</id>
            <username>admin</username>
            <password>{jSMOWnoPFgsHVpMvz5VrIt5sKsldljdlskRbzGpI8u+9EF1iFQyJQ=}</password>
        </server>
        <server>
            <id>my-app-central-snapshot</id>
            <username>admin</username>
            <password>{jSMOWnoPFgsHVpMvz5VrIt5sKsldljdlskRbzGpI8u+9EF1iFQyJQ=}</password>
        </server>
    </servers>

    <profiles>
        <profile>
            <id>my-app</id>
            <repositories>
                <repository>
                    <id>my-app-virtual-snapshot</id>
                    <name>my-app-virtual-snapshot</name>
                    <url>http://jfrog-artifactory-oss.devops.svc.cluster.local:8081/artifactory/my-app-virtual-snapshot/</url>
                    <layout>default</layout>
                </repository>
            </repositories>
        </profile>
    </profiles>

    <activeProfiles>
        <activeProfile>my-app</activeProfile>
    </activeProfiles>

    <mirrors>
        <mirror>
            <id>my-app-central-snapshot</id>
            <mirrorOf>*</mirrorOf>
            <url>http://jfrog-artifactory-oss.devops.svc.cluster.local:8081/artifactory/my-app-central-snapshot</url>
            <name>Artifactory</name>
            <blocked>false</blocked>
        </mirror>
    </mirrors>
</settings>
```

Run the Kubernetes command to create the `Secret` named `maven-credentials` and the `ConfigMap` named `maven-settings`.
```shell
kubectl -n devops create secret generic maven-credentials --from-file=settings-security.xml
kubectl -n devops create configmap maven-settings --from-file=settings.xml
```

# Setup Jenkins Pipeline and Configuration
In this example, following CICD pipeline stage and steps to build and deploy our application on Kubernetes cluster.

- Download the spring boot source code from Github
- Run maven verify command to build the native image
- Compress the size of binary to reduce the size of native image
- Create the docker image 
- Login Docker Hub Repository
- Push the docker image to Docker Hub Repository
- Logout Docker Hub

Before explain the CICD pipeline script, we have to configure the relevant configurations in the Jenkins.

## Create the Secret in Jenkins to store the Docker Hub Repository

Go to “Mange Jenkins”→”Credential”→”Click Global domain”→”Add Credential”. I am using docker hub token to login the docker hub of my account. We can generate the token from Docker Hub and store in the Jenkins Secret. 

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725477079559_image.png)

- **Kind**: Secret Text
- **ID**: “docker-access-token”, this secret id is used in the pipeline scrip
- **Secret**: Docker hub access token
## Create Pod Template to build Jenkins agent pod

Go to “Mange Jenkins”→”Nodes”→”Clouds”→”kuberntes”→”Pod Templates”→”Click Add a pod template”

**Provide common configurations:**

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725507021995_image.png)

****- **Name**: “graalvm-22-muslib-maven-jenkins-agent-template”, this name is used to choose pod template in the Jenkins pipeline script
- **Namespace**: “devops”, namespace where agent will be running.
- **Labels**: “jenkins-jenkins-agent”

**Add container “jnlp”**
We can take these main container configuration from “default” pod template.

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725477323826_image.png)

- **Name**: “jnlp”
- **Docker image:** “jenkins/inbound-agent:3256.v88a_f6e922152-1”, this is the main container for configuring the Jenkins agent. 
- **Working directory**: “/home/jenkins/agent”
- **Command to run**: It should empty
- **Arguments to pass to the command**: ${computer.jnlpmac} ${computer.name}

**Add Environment of “jnlp”**

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725477361672_image.png)

- **Key**: JENKINS_URL
- **Value**: http://jenkins.devops.svc.cluster.local:8080/

**Configure the Pod Retention is “Never”**

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725477407963_image.png)


**Add the following Pod configuration in the “Raw YAML for the Pod”**

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725477485994_image.png)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: graalvm-22-muslib-maven-jenkins-agent-template
  labels:
    app: jenkins-agent
spec:
  containers:
    # This container is used to build the native image and maven related configuration
  - name: builder
    image: developerhelperhub/graalvm-22-muslib-maven:latest
    command:
    - cat
    tty: true
    volumeMounts:
    - name: maven-credentials
      mountPath: /root/.m2/settings-security.xml
      subPath: settings-security.xml
    - name: maven-settings
      mountPath: /root/.m2/settings.xml
      subPath: settings.xml
    - name: maven-repo
      mountPath: /root/.m2
  # This container is used to connect the docker engine to manage docker process. Here, local docker engine is connecting. We can use remote docker egine 
  - name: docker
    image: docker:latest
    env:
    - name: DOCKER_HOST
      value: "tcp://172.17.0.1:2375"
    command:
    - cat
    tty: true
    volumeMounts:
      - mountPath: /var/run/docker.sock
        name: docker-sock
  volumes:
  - name: maven-repo
    persistentVolumeClaim:
      claimName: maven-repo-pvc
  - name: maven-settings
    configMap:
      name: maven-settings
  - name: maven-credentials
    secret:
      secretName: maven-credentials
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock    
```

- “**builder**”: container is used to build the native image of application and maven configuration. This builder name is used to select the container name in the Jenkins steps
    - Configuring the maven settings volumes
        - maven-crendentials: mount the `settings-security.xml` file into `./m2/settings-security.xml`
        - maven-settings: mount the `settings.xml` file into `./m2/settings.xml`
        - maven-repo: mount the `.m2` folder into `./m2/`
- “**docker**”: container is used to connect the docker engine to build the image, push, login, logout etc. This builder name is used to select the container name in the Jenkins steps

We can click on save button after configuring above all configurations in the Pod Template

**Note**: Execute the following command to check the docker IP of local machine. 
```shell
docker network inspect bridge
```
We have to use “Gateway” IP in the following section
```yaml
- name: DOCKER_HOST
  value: "tcp://172.17.0.1:2375"
```

## Create Pipeline “my-api-graalvm-dev-pipeline” 

Goto “Desktop”→”New Item”→”Select Pipeline”. Enter the item name is “my-api-dev-pipeline”→”Click Ok”

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725478032071_image.png)

## In the pipeline section, we need to add following stage and steps

**Configure the agent**
```shell
agent {
  kubernetes {
    inheritFrom 'graalvm-22-muslib-maven-jenkins-agent-template'
  }
}
```
- Give the pod template name in the “inheritFrom” which we have created Kubernetes configuration

**Create stage to clone the source code from Git Repo**
```shell
stage('Clone Application Git Repo') {
  steps {
    container('builder') {
      git branch: 'main', changelog: false, poll: false, url: 'https://github.com/developerhelperhub/spring-boot-graalvm-jenkins-pipeline.git'
    }
  }
}  
```
- Branch name : “main”
- URL: Application git repository

**Create the binary of application and compress the size of binary**
```shell
stage('Build Native Image and Compress') {
  steps {
    container('builder') {
      sh '''
        cd spring-boot-rest-api-app
        mvn verify clean -Pnative native:compile
        upx -7 -k target/app-native-binary
      '''
    }
  }
}
```
- Container should be “builder”, this container contains the all build related tools are configured
- Change the directory of application if it required
- Configure the maven verify command and compile the native command
- Configure the compress the command of binary

**Note**: We can configure the all binary build command in the section depend on requirements

**Build the image of docker**
```shell
stage('Build Docker Image') {
  steps {
    container('docker') {
      sh '''
        cd spring-boot-rest-api-app
        ls
        docker build -t {your-docker-hub-account}/spring-boot-startup-performance:latest .
      '''
    }
  }
}
```
- Configure the docker command 
- Give the your docker hub account {your-docker-hub-account}

**Note**: Make sure the Docker file in the repository related requirement 

**Login into Docker account**
```shell
stage('Push Docker Image') {
  steps {
    withCredentials([string(credentialsId: 'docker-access-token', variable: 'password')]) {
      container('docker') {
        sh 'docker login -u {your-docker-hub-account} -p ${password}'
      }
    }
  }
}
```
- Configure the credential id and variable name
    - credential id : docker-access-token
    - variable name: password, this variable name used in the inside of step
- Configure the docker login command
- Give the your docker hub account {your-docker-hub-account}

**Push Docker image in the repository**
```shell
stage('Push-Images-Docker-to-DockerHub') {
    steps {
      container('docker') {
        sh 'docker push {your-docker-hub-account}/spring-boot-startup-performance:latest'
      }
    }
  }
}
```
- Configure the docker push command
- Give the your docker hub account {your-docker-hub-account}

**Note**: Create the docker repository in the docker hub account, this is the repository name ‘spring-boot-startup-performance’ in my docker hub account 

**Logout Docker Hub account**
```shell
post {
    always {
      container('docker') {
        sh 'docker logout'
      }
    }
}
```
- Configure the docker logout account
- This should be part of post steps execution of pipeline and it should be executed always make sure logout the account

**Note:** The Jenkins script file available in the GitRepo location `jenkins-pipeline/Jenkinsfile`
 
**Click “Save Button”→”Click Build Now”**

You can see first while building the maven, the dependencies downloaded from “JFrog Artifactory” 

![](https://paper-attachments.dropboxusercontent.com/s_BA3BAE44DD4083A7F8698A3B07D54D5F29C93AE9DF365B514CDB45DDC32FE257_1725478295295_image.png)


Second time when we build it, downloaded will not happen and just build the application

# Conclusion 

This section demonstrates an efficient Jenkins build cycle for creating native binary applications with GraalVM. Since the native build process can be time-consuming, we can skip building the native image when deploying to non-production environments like "development" or "QA/testing." Instead, deploying the Java application directly for functional testing allows for faster development and testing cycles.
For production deployment, it's important to consider strategies like "blue/green" deployment to minimize downtime during release certification. However, one risk with this approach is that QA is not testing the native image, which could lead to native binary issues at release time.


## Reference
- [Source Git Repo](https://github.com/developerhelperhub/kuberentes-help/tree/main/kubenretes/tutorials/sections/0008)
- [Deploy the Jenkins and JFrog Artifactory in Kubernetes Cluster locally](https://dev.to/binoy_59380e698d318/deploy-jenkins-frog-grafana-and-prometheus-applications-in-kubernetes-cluster-terraform-2ann) 
- [Spring Boot Application Connecting JFrog Artifactory](https://dev.to/binoy_59380e698d318/setup-jfrog-artifactory-on-kubernetes-and-connect-spring-boot-application-1n4c)
[](https://dev.to/binoy_59380e698d318/deploy-jenkins-frog-grafana-and-prometheus-applications-in-kubernetes-cluster-terraform-2ann)- [Spring Boot Applications using GraalVM builder](https://dev.to/binoy_59380e698d318/build-native-image-from-spring-boot-application-with-graalvm-builder-3b7l)
- [Deploy the Kubernetes Cluster on Docker container](https://dev.to/binoy_59380e698d318/setup-linux-box-on-local-with-docker-container-3k8)

