import groovy.json.JsonSlurperClassic

node {
    def ARTIFACTS_PATH = 'targets'
    def strBuilds = env.JENKINS_SELECT_BUILDS
    def atBuilds = new JsonSlurperClassic().parseText(strBuilds)

    atBuilds.each { atEntry ->
        stage("${atEntry[0]} ${atEntry[1]} ${atEntry[2]}"){
            docker.image("${atEntry[3]}").inside('-u root') {
                /* Clean before the build. */
                sh 'rm -rf .[^.] .??* *'

                checkout([$class: 'GitSCM',
                    branches: [[name: env.GIT_BRANCH_SPECIFIER]],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [
                        [$class: 'SubmoduleOption',
                            disableSubmodules: false,
                            recursiveSubmodules: true,
                            reference: '',
                            trackingSubmodules: false
                        ]
                    ],
                    submoduleCfg: [],
                    userRemoteConfigs: [[url: 'https://github.com/muhkuh-sys/org.muhkuh.tools-webui.git']]
                ])

                /* Install the build requirements. */
                sh "./.install_build_requirements"

                /* Build the javascript part. */
                sh "npm install"
                sh "npm run release"

                /* Build the project. */
                sh "python2.7 build_artifact.py ${atEntry[0]} ${atEntry[1]} ${atEntry[2]}"

                /* Archive all artifacts. */
                archiveArtifacts artifacts: "${ARTIFACTS_PATH}/*.tar.gz,${ARTIFACTS_PATH}/*.zip"

                /* Clean up after the build. */
                sh 'rm -rf .[^.] .??* *'
            }
        }
    }
}
