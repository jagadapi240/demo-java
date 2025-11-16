pipeline {
    agent any

    environment {
        VERSION = "1.0.0-${env.GIT_COMMIT[0..6]}"
        DOCKERHUB_REPO = "jagadapi240/demo-java"
        SONARQUBE_SERVER = "sonarqube"
    }

    stages {

        /* ---------------------------------------------------------
         * 1) Clone and Build with Maven + SonarQube
         * --------------------------------------------------------- */
        stage('Build & SonarQube Analysis') {
            steps {
                checkout scm
                withSonarQubeEnv('sonarqube') {
                    sh """
                        mvn clean verify sonar:sonar \
                          -Dsonar.projectKey=demo-java \
                          -Dsonar.host.url=http://sonarqube:9000 \
                          -Dsonar.login=$SONAR_TOKEN
                    """
                }
            }
        }

        /* ---------------------------------------------------------
         * 2) Wait for Quality Gate
         * --------------------------------------------------------- */
        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        /* ---------------------------------------------------------
         * 3) Upload WAR to Nexus
         * --------------------------------------------------------- */
        stage('Upload WAR to Nexus') {
            environment {
                NEXUS_URL = "http://nexus:8081"
                NEXUS_REPO = "maven-releases"
                NEXUS_GROUP_PATH = "com/example/demo"
                NEXUS_ARTIFACT = "demo"
            }
            steps {
                checkout scm
                withCredentials([usernamePassword(credentialsId: 'nexus-creds',
                                                 usernameVariable: 'NEXUS_USER',
                                                 passwordVariable: 'NEXUS_PASS')]) {
                    sh """
                        set -e
                        echo "=== Locating WAR file ==="
                        WAR_PATH=\$(ls target/*.war | head -n 1)

                        echo "WAR located: \$WAR_PATH"
                        echo "=== Uploading WAR to Nexus ==="

                        curl -v -u "$NEXUS_USER:$NEXUS_PASS" \
                          --upload-file \$WAR_PATH \
                          $NEXUS_URL/repository/$NEXUS_REPO/$NEXUS_GROUP_PATH/$NEXUS_ARTIFACT/$VERSION/$NEXUS_ARTIFACT-$VERSION.war

                        echo "WAR uploaded successfully."
                    """
                }
            }
        }

        /* ---------------------------------------------------------
         * 4) Build Docker Image (Tomcat + WAR from Nexus)
         * --------------------------------------------------------- */
        stage('Build Docker Image (Tomcat + WAR from Nexus)') {
            environment {
                NEXUS_URL = "http://nexus:8081"
                NEXUS_REPO = "maven-releases"
                NEXUS_GROUP_PATH = "com/example/demo"
                NEXUS_ARTIFACT = "demo"
            }
            steps {
                checkout scm
                withCredentials([usernamePassword(credentialsId: 'nexus-creds',
                                                 usernameVariable: 'NEXUS_USER',
                                                 passwordVariable: 'NEXUS_PASS')]) {

                    sh """
                        docker build \
                          --network=cicd-net \
                          --build-arg NEXUS_URL=$NEXUS_URL \
                          --build-arg NEXUS_REPO=$NEXUS_REPO \
                          --build-arg NEXUS_GROUP_PATH=$NEXUS_GROUP_PATH \
                          --build-arg NEXUS_ARTIFACT=$NEXUS_ARTIFACT \
                          --build-arg NEXUS_VERSION=$VERSION \
                          --build-arg NEXUS_USERNAME=$NEXUS_USER \
                          --build-arg NEXUS_PASSWORD=$NEXUS_PASS \
                          -t $DOCKERHUB_REPO:$VERSION .
                    """
                }
            }
        }

        /* ---------------------------------------------------------
         * 5) Push Docker Image to Docker Hub
         * --------------------------------------------------------- */
        stage('Push Docker Image to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                 usernameVariable: 'D_USER',
                                                 passwordVariable: 'D_PASS')]) {

                    sh """
                        echo "$D_PASS" | docker login -u "$D_USER" --password-stdin
                        docker push $DOCKERHUB_REPO:$VERSION
                    """
                }
            }
        }

    }

    /* ---------------------------------------------------------
     * 6) Pipeline Notifications
     * --------------------------------------------------------- */
    post {
        success {
            echo "SUCCESS: Build completed and image pushed: $DOCKERHUB_REPO:$VERSION"
        }
        failure {
            echo "FAILURE: Check Jenkins logs at ${env.BUILD_URL}"
        }
    }
}

