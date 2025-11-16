pipeline {
    agent none

    environment {
        SONARQUBE_ENV = 'sonarqube'

        // Nexus
        NEXUS_URL       = 'http://nexus:8081'
        NEXUS_REPO      = 'maven-releases'
        NEXUS_GROUP_ID  = 'com.example.demo'
        NEXUS_GROUP_PATH= 'com/example/demo'
        NEXUS_ARTIFACT  = 'demo'

        // Docker Hub
        DOCKER_REPO     = 'jagadapi240/demo-java'
    }

    options {
        timestamps()
    }

    stages {

        /* -------------------------------
           CHECKOUT
        --------------------------------*/
        stage('Checkout') {
            agent any
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    env.APP_VERSION = "1.0.0-${env.GIT_COMMIT_SHORT}"

                    echo "Commit: ${env.GIT_COMMIT}"
                    echo "Version: ${env.APP_VERSION}"
                }
            }
        }

        /* -------------------------------
           BUILD + SONARQUBE ANALYSIS
        --------------------------------*/
        stage('Build & SonarQube Analysis') {
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-17'
                    args '-v $HOME/.m2:/root/.m2'
                }
            }
            steps {
                checkout scm

                withSonarQubeEnv("${SONARQUBE_ENV}") {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh """
                            mvn clean verify sonar:sonar \
                              -Dsonar.projectKey=demo-java \
                              -Dsonar.projectName=demo-java \
                              -Dsonar.projectVersion=${APP_VERSION} \
                              -Dsonar.host.url=http://sonarqube:9000 \
                              -Dsonar.login=$SONAR_TOKEN
                        """
                    }
                }
            }

            post {
                success {
                    archiveArtifacts artifacts: 'target/*.war', fingerprint: true
                }
            }
        }

        /* -------------------------------
           WAIT FOR QUALITY GATE
        --------------------------------*/
        stage('Quality Gate') {
            agent any
            steps {
                script {
                    timeout(time: 10, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "Quality Gate FAILED: ${qg.status}"
                        }
                    }
                }
            }
        }

        /* -------------------------------
           UPLOAD WAR -> NEXUS
        --------------------------------*/
        stage('Upload WAR to Nexus') {
            agent any
            steps {
                checkout scm

                withCredentials([
                    usernamePassword(
                        credentialsId: 'nexus-creds',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )
                ]) {
                    script {
                        env.WAR_PATH = sh(
                            script: "ls target/*.war | head -n 1",
                            returnStdout: true
                        ).trim()

                        echo "WAR File = ${WAR_PATH}"
                        echo "Uploading to Nexus…"
                    }

                    sh """
                        curl -v -u $NEXUS_USER:$NEXUS_PASS \
                          --upload-file ${WAR_PATH} \
                          "$NEXUS_URL/repository/$NEXUS_REPO/$NEXUS_GROUP_PATH/$NEXUS_ARTIFACT/${APP_VERSION}/$NEXUS_ARTIFACT-${APP_VERSION}.war"
                    """
                }
            }
        }

        /* -------------------------------
           BUILD DOCKER IMAGE (pull WAR from Nexus)
        --------------------------------*/
        stage('Build Docker Image (Tomcat + WAR)') {
            agent any
            steps {
                checkout scm

                withCredentials([
                    usernamePassword(
                        credentialsId: 'nexus-creds',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )
                ]) {
                    sh """
                        docker build \
                          --build-arg NEXUS_URL=$NEXUS_URL \
                          --build-arg NEXUS_REPO=$NEXUS_REPO \
                          --build-arg NEXUS_GROUP_PATH=$NEXUS_GROUP_PATH \
                          --build-arg NEXUS_ARTIFACT=$NEXUS_ARTIFACT \
                          --build-arg NEXUS_VERSION=${APP_VERSION} \
                          --build-arg NEXUS_USERNAME=$NEXUS_USER \
                          --build-arg NEXUS_PASSWORD=$NEXUS_PASS \
                          -t $DOCKER_REPO:${APP_VERSION} .
                    """
                }
            }
        }

        /* -------------------------------
           PUSH DOCKER IMAGE TO DOCKER HUB
        --------------------------------*/
        stage('Push Docker Image to Docker Hub') {
            agent any
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push $DOCKER_REPO:${APP_VERSION}
                        docker logout
                    """
                }
            }
        }

        /* -------------------------------
           NOTIFICATION
        --------------------------------*/
        stage('Notifications') {
            agent any
            steps {
                echo "Build Complete. Image pushed: $DOCKER_REPO:${APP_VERSION}"
            }
        }
    }

    post {
        success {
            echo "SUCCESS: CI/CD Completed."
        }
        failure {
            echo "FAILED: See logs at ${env.BUILD_URL}"
        }
    }
}

