node {
   //   Mark the code checkout 'stage'....
   stage 'checkout'

   // Get some code from a GitHub repository
   git url: 'https://github.com/kesselborn/jenkinsfile'
   sh 'git clean -fdx; sleep 4;'

   stage('verify-docker-installed') {
       docker.build("test:1.0", "--no-cache .")
   }
}
