#!/bin/bash

ignore_errors=0
ruby_version=2.4.4
asset_version=${TAG:-local-build}
asset_filename=sensu-ruby-runtime_${asset_version}_ruby-${ruby_version}_${platform}_linux_aarch64.tar.gz
asset_image=ghcr.io/skbki/sensu-ruby-runtime-${ruby_version}-${platform}:${asset_version}


if [ "${asset_version}" = "local-build" ]; then
  echo "Local build"
  ignore_errors=1
fi

echo "Platform: ${platform}"
echo "Check for asset file: ${asset_filename}"
if [ -f "$PWD/dist/${asset_filename}" ]; then
  echo "File: "$PWD/dist/${asset_filename}" already exists!!!"
  [ $ignore_errors -eq 0 ] && exit 1  
else
  echo "Check for docker image: ${asset_image}"
  if [[ "$(docker images -q ${asset_image} 2> /dev/null)" == "" ]]; then
    echo "Docker image not found...we can build"
    echo "Building Docker Image: sensu-ruby-runtime:${ruby_version}-${platform}"
    DOCKER_CLI_EXPERIMENTAL=enabled docker buildx build --cache-from=type=gha --cache-to=type=gha --output=type=registry --platform "linux/arm64" --build-arg "RUBY_VERSION=$ruby_version" --build-arg "ASSET_VERSION=$asset_version" -t ${asset_image} -f Dockerfile.${platform} .
    echo "Making Asset: /assets/sensu-ruby-runtime_${asset_version}_ruby-${ruby_version}_${platform}_linux_aarch64.tar.gz"
    docker run -v "$PWD/dist:/dist" ${asset_image} cp /assets/${asset_filename} /dist/
  #    #rm $PWD/test/*
  #    #cp $PWD/dist/${asset_filename} $PWD/dist/${asset_filename}
  else
    echo "Image already exists!!!"
    [ $ignore_errors -eq 0 ] && exit 1  
  fi
fi

ls -lash /dist/

test_arr=($test_platforms)
for test_platform in "${test_arr[@]}"; do
  echo "Test: ${test_platform}"
  docker run -e platform -e test_platform=${test_platform} -e asset_filename=${asset_filename} -v "$PWD/scripts/:/scripts" -v "$PWD/dist:/dist" ${test_platform} /scripts/test.sh
  retval=$?
  if [ $retval -ne 0 ]; then
    echo "!!! Error testing ${asset_filename} on ${test_platform}"
    exit $retval
  fi
done
