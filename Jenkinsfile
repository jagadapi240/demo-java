pipeline {
  agent none   // we will use different agents per stage

  environment {
    SONARQUBE_ENV = 'sonarqube'

    // Nexus (inside Docker network)
    NEXUS_URL        = 'http://nexus:8081'
    NEXUS_REPO       = 'maven-releases'
    NEXUS_GROUP_ID   = 'com.example.demo'
    NEXUS_GROUP_PATH = 'com/example/demo'
    NEXUS_ARTIFACT   = 'demo'

    // Docker Hub repo (auto-created on first push)
    DOCKER_REPO      = 'jagadapi240/demo-java'
  }

  options {
    timestamps()
  }

  stages {

    stage('Checkout') {
      agent any
      steps {
        checkout scm
        script {
          env.GIT_COMMIT_SHORT = sh(
            script: 'git rev-parse --short HEAD',
            returnStdout: true
          ).trim()
          env.APP_VERSION = "1.0.0-${env.GIT_COMMIT_SHORT}"
          echo "Commit: ${env.GIT_COMMIT}, Version: ${env.APP_VERSION}"
        }
      }
    }

    stage('SonarQube Analyze + Maven Build') {
      // Maven runs in its own Docker container (separate from Jenkins)
      agent {
        docker {
          image 'maven:3.9-eclipse-temurin-17'
          args '-v $HOME/.m2:/root/.m2'
        }
      }
      environment {
        MAVEN_OPTS = "-Dmaven.test.failure.ignore=false"
      }
      steps {
        withSonarQubeEnv("${SONARQUBE_ENV}") {
          sh """
            mvn clean verify sonar:sonar \
              -Dsonar.projectKey=demo-java \
              -Dsonar.projectName=demo-java \
              -Dsonar.projectVersion=${APP_VERSION}
          """
        }
      }
      post {
        success {
          archiveArtifacts artifacts: 'target/*.war', fingerprint: true
        }
      }
    }

    stage('Quality Gate') {
      agent any
      steps {
        script {
          timeout(time: 10, unit: 'MINUTES') {
            def qg = waitForQualityGate()
            if (qg.status != 'OK') {
              error "Pipeline aborted due to Quality Gate failure: ${qg.status}"
            }
          }
        }
      }
    }

    stage('Upload WAR to Nexus') {
      agent any
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'nexus-creds',
          usernameVariable: 'NEXUS_USER',
          passwordVariable: 'NEXUS_PASS'
        )]) {
          sh """
            WAR_PATH=\$(ls target/*.war | head -n 1)
            echo "Uploading \$WAR_PATH to Nexus as version ${APP_VERSION}"

            curl -v -u $NEXUS_USER:$NEXUS_PASS \
              --upload-file \$WAR_PATH \
              "$NEXUS_URL/repository/$NEXUS_REPO/$NEXUS_GROUP_PATH/$NEXUS_ARTIFACT/${APP_VERSION}/$NEXUS_ARTIFACT-${APP_VERSION}.war"
          """
        }
      }
    }

    stage('Build Docker Image (Tomcat + WAR from Nexus)') {
      // Runs on Jenkins container, uses docker CLI via /var/run/docker.sock
      agent any
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'nexus-creds',
          usernameVariable: 'NEXUS_USER',
          passwordVariable: 'NEXUS_PASS'
        )]) {
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

    stage('Push Docker Image to Docker Hub') {
      agent any
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-creds',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh """
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push $DOCKER_REPO:${APP_VERSION}
            docker logout
          """
        }
      }
    }

    stage('Notifications') {
      agent any
      steps {
        echo "Build ${env.BUILD_NUMBER} for ${env.GIT_COMMIT} completed. Image: $DOCKER_REPO:${APP_VERSION}"
      }
    }
  }

  post {
    success {
      echo "SUCCESS: Image $DOCKER_REPO:${APP_VERSION} pushed to Docker Hub."
    }
    failure {
      echo "FAILURE: Check Jenkins logs at ${env.BUILD_URL}"
    }
  }
}

