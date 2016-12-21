#!/bin/bash
set -xe

DIR="$( cd $( dirname ${BASH_SOURCE[0]} )  && pwd )"
cd $DIR

# Build the project
$DIR/build.sh

# Install dist_test locally
SCRIPTS="dist_test"

if [[ -d $SCRIPTS ]]; then
    echo "Cleaning up remnants from a previous run"
    rm -rf $SCRIPTS
fi

git clone --depth 1 https://github.com/cloudera/$SCRIPTS.git $SCRIPTS || true

# Fetch the right branch
cd "$DIR/$SCRIPTS"
git fetch --depth 1 origin
git checkout -f origin/master
git ls-tree -r HEAD
./setup.sh
export PATH=`pwd`/bin/:$PATH
which grind

if [[ -z $DIST_TEST_USER || -z $DIST_TEST_PASSWORD ]]; then
    # Fetch dist test credentials and add them to the environment
    wget http://staging.jenkins.cloudera.com/gerrit-artifacts/misc/hadoop/dist_test_cred.sh
    source dist_test_cred.sh
fi

# Go to project root
cd "$DIR/.."

# Populate the per-project grind cfg file
cat > .grind_project.cfg << EOF
[grind]
empty_dirs = ["test/data", "test-dir", "log"]
file_globs = []
file_patterns = ["*.so"]
artifact_archive_globs = ["**/surefire-reports/TEST-*.xml"]
EOF

# Invoke grind to run tests
grind -c ${DIR}/$SCRIPTS/env/grind.cfg config
grind -c ${DIR}/$SCRIPTS/env/grind.cfg pconfig
grind -c ${DIR}/$SCRIPTS/env/grind.cfg test --artifacts -r 3 -e TestRM -e TestWorkPreservingRMRestart -e TestRMRestart -e TestContainerAllocation -e TestMRJobClient -e TestCapacityScheduler -e TestDelegatingInputFormat -e TestMRCJCFileInputFormat -e TestJobHistoryEventHandler -e TestCombineFileInputFormat -e TestAMRMRPCResponseId -e TestSystemMetricsPublisher -e TestNodesListManager -e TestRMContainerImpl -e TestApplicationMasterLauncher -e TestRMWebApp -e TestContainerManagerSecurity -e TestResourceManager -e TestParameterParser -e TestNativeCodeLoader -e TestRMContainerAllocator -e TestMRIntermediateDataEncryption -e TestWebApp -e TestCryptoStreamsWithOpensslAesCtrCryptoCodec -e TestDNS -e TestClientRMTokens -e TestAMAuthorization -e TestContinuousScheduling
# TestDNS fails only on supertest. CDH-37451
# TestClientRMTokens and TestAMAuthorization to be fixed in 5.8 (CDH-39590)
# TestContinuousScheduling has been failing consistently, to be fixed in 5.8 (CDH-38830)

# Cleanup the grind folder
if [[ -d "$DIR/$SCRIPTS" ]]; then
    rm -rf "$DIR/$SCRIPTS"
fi
