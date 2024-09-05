
docker login should before push

curl -u admin:<jenkins-secrete> -o agent.jar http://localhost/jnlpJars/agent.jar

docker run -d --name jenkins-agent -e JENKINS_SECRET=admin -e JENKINS_NAME=admin developerhelperhub/graalvm-jenkins-agent


docker run --rm -it --entrypoint /bin/bash developerhelperhub/graalvm-jenkins-agent

docker run --rm -it -e JENKINS_SECRET=<jenkins-secrete>  -e JENKINS_NAME=graalvm-jenkins-agent -e JENKINS_URL=http://10.96.102.61:8080/ developerhelperhub/graalvm-jenkins-agent


java -jar /usr/local/bin/jenkins-agent.jar -secret $(JENKINS_SECRET) -name $(JENKINS_NAME) -url http://jenkins:8080

java -jar /usr/local/bin/jenkins-agent.jar -secret <jenkins-secrete>  -name graalvm-jenkins-agent -url http://10.96.102.61:8080

