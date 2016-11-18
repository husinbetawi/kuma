#!/bin/bash -xe
GIT_COMMIT=${GIT_COMMIT:-$(git rev-parse HEAD)}
BASE_URL=${1:-${BASE_URL}}
DRIVER=Remote
docker build -f Dockerfile-integration-tests -t kuma_integration_tests:${GIT_COMMIT} --pull=true .


if [ -z "${BASE_URL}" ]; then
  # start bedrock
    echo BASE_URL required
    exit 1
fi

if [ "${DRIVER}" = "Remote" ]; then
  # Start Selenium hub and NUMBER_OF_NODES (default 5) firefox nodes.
  # Waits until all nodes are ready and then runs tests against BASE_URL

  SELENIUM_VERSION=${SELENIUM_VERSION:-2.48.2}

  docker pull selenium/hub:${SELENIUM_VERSION}
  docker pull selenium/node-firefox:${SELENIUM_VERSION}

  # start selenium grid hub
  docker run -d \
    --name selenium-hub-${BUILD_NUMBER} \
    selenium/hub:${SELENIUM_VERSION}
  DOCKER_LINKS=(${DOCKER_LINKS[@]} --link selenium-hub-${BUILD_NUMBER}:hub)
  SELENIUM_HOST="hub"

  # start selenium grid nodes
  for NODE_NUMBER in `seq ${NUMBER_OF_NODES:-5}`; do
    docker run -d \
      --name selenium-node-${NODE_NUMBER}-${BUILD_NUMBER} \
      ${DOCKER_LINKS[@]} \
      selenium/node-firefox:${SELENIUM_VERSION}
    while ! ${SELENIUM_READY}; do
      IP=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' selenium-node-${NODE_NUMBER}-${BUILD_NUMBER}`
      CMD="docker run --link selenium-hub-${BUILD_NUMBER}:hub tutum/curl curl http://hub:4444/grid/api/proxy/?id=http://${IP}:5555 | grep 'proxy found'"
      if eval ${CMD}; then SELENIUM_READY=true; fi
    done
  done
fi

docker run -v `pwd`/results:/app/results \
  ${DOCKER_LINKS[@]} \
  -e BASE_URL=${BASE_URL} \
  -e DRIVER=${DRIVER} \
  -e SAUCELABS_USERNAME=${SAUCELABS_USERNAME} \
  -e SAUCELABS_API_KEY=${SAUCELABS_API_KEY} \
  -e BROWSER_NAME="${BROWSER_NAME}" \
  -e BROWSER_VERSION=${BROWSER_VERSION} \
  -e PLATFORM="${PLATFORM}" \
  -e SELENIUM_HOST=${SELENIUM_HOST} \
  -e SELENIUM_PORT=${SELENIUM_PORT} \
  -e SELENIUM_VERSION=${SELENIUM_VERSION} \
  -e BUILD_TAG=${BUILD_TAG} \
  -e SCREEN_RESOLUTION=${SCREEN_RESOLUTION} \
  -e MARK_EXPRESSION="${MARK_EXPRESSION}" \
  -e TESTS_PATH="${TESTS_PATH}" \
  kuma_integration_tests:${GIT_COMMIT}
