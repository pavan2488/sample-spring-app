#!/usr/bin/groovy

@Library('sharedlibs')

def pipeline = new io.bitwise.Pipeline()

podTemplate(label: 'jenkins-pipeline', containers: [
        containerTemplate(name: 'jnlp', image: 'lachlanevenson/jnlp-slave:3.10-1-alpine', args: '${computer.jnlpmac} ${computer.name}', workingDir: '/home/jenkins', resourceRequestCpu: '200m', resourceLimitCpu: '500m', resourceRequestMemory: '512Mi', resourceLimitMemory: '1024Mi'),
        containerTemplate(name: 'kaniko', image: 'gcr.io/kaniko-project/executor:debug', command: 'cat', ttyEnabled: true,   envVars: [
          secretEnvVar(key: 'GOOGLE_APPLICATION_CREDENTIALS', secretName: 'devops-gcr-key-key', secretKey: 'key.json') 
        ]),
        containerTemplate(name: 'maven', image: 'jenkinsxio/builder-maven', command: 'cat', ttyEnabled: true),
        containerTemplate(name: 'helm', image: 'lachlanevenson/k8s-helm:v2.8.2', command: 'cat', ttyEnabled: true),
        containerTemplate(name: 'kubectl', image: 'lachlanevenson/k8s-kubectl:v1.9.6', command: 'cat', ttyEnabled: true)
],
volumes:[
    hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock'),
    hostPathVolume(mountPath: '/root/.m2/', hostPath: '/tmp/jenkins/.m2'),
], nodeSelector: 'beta.kubernetes.io/os=linux') {
     
  node ('jenkins-pipeline') {


    checkout scm

    def pwd = pwd()
    def chart_dir = "${pwd}/charts/spring-demo"
     
    def target_dir =  "${pwd}/target"
      


    def inputFile = readFile('Jenkinsfile.json')
    def config = new groovy.json.JsonSlurperClassic().parseText(inputFile)

    println "pipeline config ==> ${config}"

    // continue only if pipeline enabled
    if (!config.pipeline.enabled) {
        println "pipeline disabled"
        return
    }

    // set additional git envvars for image tagging
    pipeline.gitEnvVars()


    def acct = pipeline.getContainerRepoAcct(config)

    // tag image with version, and branch-commit_id
    def image_tags_map = pipeline.getContainerTags(config)

    // compile tag list
    def image_tags_list = pipeline.getMapValues(image_tags_map)

   stage ('compile and test') {

      container('maven') {
            sh 'mvn  clean install'
           }
    }


   container(name: 'kaniko', shell: '/busybox/sh') {
              
             sh "/kaniko/executor --dockerfile `pwd`/Dockerfile --context `pwd` --destination=gcr.io/savvy-folio-279711/spring-demo"
    }

          /*
    stage ('publish container') {

      container('docker') {

        // build and publish container
        pipeline.containerBuildPub(
            dockerfile: config.container_repo.dockerfile,
            host      : config.container_repo.host,
            acct      : acct,
            repo      : config.container_repo.repo,
            tags      : image_tags_list,
            auth_id   : config.container_repo.jenkins_creds_id,
            target_dir : target_dir
        )

      }

    } */


    // deploy only the master branch
    if (env.BRANCH_NAME == 'master') {
      stage ('deploy to k8s') {
        container('helm') {
          // Deploy using Helm chart
          pipeline.helmDeploy(
            dry_run       : false,
            name          : config.app.name,
            namespace     : config.app.name,
            chart_dir     : chart_dir,
            set           : [
              "imageTag": image_tags_list.get(0),
              "replicas": config.app.replicas,
              "cpu": config.app.cpu,
              "memory": config.app.memory
            ]
          )
          
          //  Run helm tests
          if (config.app.test) {
            pipeline.helmTest(
              name          : config.app.name
            )
          }
        }
      }
    }
  }
  
}
