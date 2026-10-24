include mk/common.mk

.PHONY: all build builder image docker-login src test-src push lint clean

all: build

docker-login: SHELL := /bin/bash
docker-login:
ifndef GH_TOKEN
	$(error GH_TOKEN is not set, can't login to image repo)
else
	@true
endif

ifndef USER
	$(error USER is not set, can't login to image repo)
else
	@true
endif

	@docker login ghcr.io -u ${USER} --password-stdin <<< ${GH_TOKEN}

builder:
	@make -C image-builder builder

image:
	@make -C image-builder image

test-src:
	@make -C src test

src:
	@make -C src

Dockerfile: Dockerfile.in
	@$(SED) -e 's|@INIT_SCRIPT_PATH@|$(INIT_SCRIPT_PATH)|g' \
		-e 's|@ENTRYPOINT_PATH@|$(ENTRYPOINT_PATH)|g' \
		-e 's|@API_KEY_GENERATOR_PATH@|$(API_KEY_GENERATOR_PATH)|g' \
		$< > $@

build: Dockerfile src check-vars
	@docker build . -t ${REPO}:${VERSION} --build-arg OPNSENSE_VERSION=${VERSION}

push: check-vars
	@docker push ${REPO}:${VERSION}

lint:
	@hadolint Dockerfile	

clean:
	@rm -f Dockerfile
