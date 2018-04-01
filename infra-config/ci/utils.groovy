import hudson.model.Result
import jenkins.model.CauseOfInterruption.UserInterruption

release_regex = /(?i)\d{2}q[1-4]s[1-8]w[1-2](\.\d+)?$/

def killOldBuilds() {
  while(currentBuild.rawBuild.getPreviousBuildInProgress() != null) {
    currentBuild.rawBuild.getPreviousBuildInProgress().doKill()
  }
}

def setup() {
  killOldBuilds()
  stash name: "${getCommit()}", includes: ""
}

def matcher(text, regex) {
  def matcher = text =~ regex
  matcher ? matcher[0][1] : null
}

def getVersion() {
  return matcher(sh (script: "cat VERSION.json", returnStdout: true), '"version":\\s*"(.+)"')
}

def getCommit(def step=null) {
  if (step == null) {
    step = 0
  }

  return sh (script: "git rev-parse --short HEAD~${step}", returnStdout: true).replaceAll('\n', '')
}

def releaseTag() {
  return sh(script: "git tag --sort committerdate | tail -1", returnStdout: true).trim()
}

def releaseChangelog() {
  currentTag = releaseTag()
  previousTag = sh(script: "git tag --sort committerdate | tail -2 | head -1", returnStdout: true).trim()

  return sh(script: "git shortlog -w0 -n --no-merges --perl-regexp --author='^((?!Jenkins-Instabug).*)\$' ${previousTag}..${currentTag}", returnStdout: true).trim()
}

def releaseURL() {
  return "https://github.com/Instabug/${getRepoName()}/releases/${releaseTag()}"
}

def dockerRegistry(closure) {
  withCredentials([usernamePassword(credentialsId: 'e9e0c27d-207e-4294-b7a1-8c1b006056d5', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
    sh "docker login --username $USERNAME --password $PASSWORD"
    closure()
  }
}

def notifySlack(channels, message) {
  for(channel in channels) {
    slackSend channel: channel, teamDomain: 'instabugteam', color: '#00CC00', message: message, failOnError: false
  }
}

def pushImage(app, tags, deployableBranches) {
  if(deployableBranches == null || BRANCH_NAME in deployableBranches || BRANCH_NAME =~ release_regex) {
    dockerRegistry {
      for(tag in tags) app.push(tag)
      if(BRANCH_NAME == 'master') app.push("latest")
    }
  }
}

def sanitize(string) {
  return string.replaceAll('/', '-').toLowerCase()
}

def deployKubernetes(deploymentName, imageName, deployableBranches) {
  BRANCH_NAME = sanitize(BRANCH_NAME)
  if(BRANCH_NAME in deployableBranches || BRANCH_NAME =~ release_regex) {
    NAMESPACE = BRANCH_NAME
    if(NAMESPACE =~ release_regex) NAMESPACE = 'production'
    if(NAMESPACE == "master") NAMESPACE = 'staging'
    wrap([$class: 'KubectlBuildWrapper', credentialsId: '3c02c61a-ba20-495c-b462-2e3d805e08e6', serverUrl: 'https://api.kube.instabug.com']) {
      TAG = "$BRANCH_NAME-${getVersion()}"
      sh "kubectl --namespace=$NAMESPACE set image deployment $deploymentName $deploymentName=$imageName:$TAG --record"
    }
  }
}

def parallelize(app, agents, commit, command, serviceName, closure) {
  def nodes = [:]
  for(int i = 0; i < agents; i++) {
    def index = i
    nodes["Slave ${i}"] = {
      withEnv(["CI_NODE_INDEX=${index}", "TEST_ENV_NUMBER=$index", "CI_NODE_TOTAL=$agents"]) {
        node('jenkins-slaves') {
          deleteDir()
          unstash "$commit"
          dockerRegistry {
            app.pull() // pull test image
            sh "$command" // command for tests init (a.k.a infra-config/ci/prep-test-env.sh)
          }
          // bundleHash file comes from infra-config/ci/prep-test-env.sh
          bundleHash = sh(script: "cat bundleHash", returnStdout: true).replaceAll('\n', '')
          withAWS(credentials:'AWS-CREDS') {
            s3Upload(file:"$bundleHash", bucket:'public-bundles', path:"$bundleHash")
          }
          app.inside("-e 'RAILS_ENV=test' -e 'RACK_ENV=test' --network isolated_nw -v /report_$serviceName:/var/app/knapsack") {
            closure()
          }
          // upload updated knapsack reports
          sh "mv /report_$serviceName/knapsack_rspec_report.json ./$serviceName-slave$index-knapsack_rspec_report.json"
          withAWS(credentials:'AWS-CREDS') {
            s3Upload(file:"$serviceName-slave$index-knapsack_rspec_report.json", bucket: 'ibg-knapsack-reports', path: "$serviceName-slave$index-knapsack_rspec_report.json")
          }
        }
      }
    }
  }
  return nodes;
}

def getRepoName() {
  return matcher(sh (script: "git remote show -n origin | grep Fetch", returnStdout: true), '/([^/]*).git$')
}

def bumpVersion() {
  retVal = false
  withCredentials([usernamePassword(credentialsId: 'Github', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
    // Set https origin
    origin = "https://${URLEncoder.encode(USERNAME, "UTF-8")}:${URLEncoder.encode(PASSWORD, "UTF-8")}@github.com/Instabug/${getRepoName()}.git"

    // Sync branch to get refs
    sh "git fetch $origin $BRANCH_NAME"
    sh "git checkout $BRANCH_NAME"

    // Get last commit message
    commitMsg = sh(script: 'git log -1 --pretty=%B $(git rev-parse HEAD)', returnStdout: true).trim()

    // If it's a version message stop and return that it was already bumped
    if (commitMsg =~ /^Version [0-9.]+$/) {
      println 'Commit is version commit, building'
      retVal = true
      return true
    }

    println 'Bumping version based on commit message'

    bumpMode = 'patch'
    version = getVersion()

    // Parse major, minor and patch version
    major = sh(script: "echo $version | cut -d'.' -f1 | sed 's/\"// '", returnStdout: true).toInteger()
    minor = sh(script: "echo $version | cut -d'.' -f2 | sed 's/\"// '", returnStdout: true).toInteger()
    patch = sh(script: "echo $version | cut -d'.' -f3 | sed 's/\"// '", returnStdout: true).toInteger()

    // Increment version based on commit tags [PATCH] [MINOR] and [MAJOR]
    if(commitMsg =~ /\[PATCH\]/) {
      patch++
      bumpMode = 'patch'
    } else if (commitMsg =~ /\[MINOR\]/) {
      patch = 0
      minor++
      bumpMode = 'minor'
    } else if (commitMsg =~ /\[MAJOR\]/) {
      patch = 0
      minor = 0
      major++
      bumpMode = 'major'
    } else {
      patch++
    }

    nextVersion = "$major" + "." + "$minor" + "." + "$patch"

    println "Bumping $bumpMode version"

    // Write new version into VERSION.json file
    sh "echo '{ \"version\": \"$nextVersion\" }' > VERSION.json"

    // Set version committer to Jeknins user
    jenkinsGitUsername = 'Jenkins-Instabug'
    jenkinsGitEmail = 'jenkins@instabug.com'

    // Set committer and author to jenkins
    committerVars = "GIT_COMMITTER_NAME='$jenkinsGitUsername' GIT_COMMITTER_EMAIL='$jenkinsGitEmail'"
    authorArg = "--author='$jenkinsGitUsername <$jenkinsGitEmail>'"
    sh "$committerVars git commit -m 'Version $nextVersion' $authorArg -- VERSION.json"

    // Tag with new version
    sh "git tag '$nextVersion' -m 'Version $nextVersion' | cat" // Disregard failure to tag for duplicate tags

    println "Pushing version $nextVersion"

    ref = "HEAD"
    sh "git push $origin $ref"
  }
  return retVal
}

return this
