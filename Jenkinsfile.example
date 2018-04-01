node('main-agent') {
  ansiColor('xterm') {
      stage('verify-docker-installed') {
          docker.build("test:1.0", "--no-cache .")
      }
  }
}
