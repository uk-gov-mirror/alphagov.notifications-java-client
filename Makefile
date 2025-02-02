.DEFAULT_GOAL := help
SHELL := /bin/bash

DOCKER_BUILDER_IMAGE_NAME = govuk/notify-java-client-builder

BUILD_TAG ?= notifications-java-client-manual

DOCKER_CONTAINER_PREFIX = ${USER}-${BUILD_TAG}

.PHONY: help
help:
	@cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: dependencies
dependencies: ## Install build dependencies
	mvn --batch-mode clean initialize

.PHONY: build
build: dependencies ## Build project

.PHONY: test
test: ## Run tests
	mvn --batch-mode clean test

.PHONY: integration-test
integration-test: ## Run integration tests
	mvn --batch-mode clean verify

.PHONY: generate-env-file
generate-env-file: ## Generate the environment file for running the tests inside a Docker container
	script/generate_docker_env.sh

.PHONY: prepare-docker-runner-image
prepare-docker-runner-image: ## Prepare the Docker builder image
	docker build -t ${DOCKER_BUILDER_IMAGE_NAME} .

.PHONY: build-with-docker
build-with-docker: prepare-docker-runner-image ## Build inside a Docker container
	docker run -i --rm \
		--name "${DOCKER_CONTAINER_PREFIX}-build" \
		-v "`pwd`:/var/project" \
		-v `pwd`/.m2:/root/.m2 \
		${DOCKER_BUILDER_IMAGE_NAME} \
		make build

.PHONY: test-with-docker
test-with-docker: prepare-docker-runner-image generate-env-file ## Run tests inside a Docker container
	docker run -i --rm \
		--name "${DOCKER_CONTAINER_PREFIX}-test" \
		-v "`pwd`:/var/project" \
		-v `pwd`/.m2:/root/.m2 \
		--env-file docker.env \
		${DOCKER_BUILDER_IMAGE_NAME} \
		make test

.PHONY: integration-test-with-docker
integration-test-with-docker: prepare-docker-runner-image generate-env-file ## Run integration tests inside a Docker container
	docker run -i --rm \
		--name "${DOCKER_CONTAINER_PREFIX}-integration-test" \
		-v "`pwd`:/var/project" \
		-v `pwd`/.m2:/root/.m2 \
		--env-file docker.env \
		${DOCKER_BUILDER_IMAGE_NAME} \
		make integration-test

.PHONY: clean-docker-containers
clean-docker-containers: ## Clean up any remaining docker containers
	docker rm -f $(shell docker ps -q -f "name=${DOCKER_CONTAINER_PREFIX}") 2> /dev/null || true

clean:
	rm -rf .m2


.PHONY: get-client-version
get-client-version: ## Retrieve client version number from source code (https://stackoverflow.com/a/26514030)
	@mvn help:evaluate -Dexpression=project.version -q -DforceStdout
