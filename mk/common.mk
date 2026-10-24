REPO=	ghcr.io/ddf89/docker-opnsense
SED=	sed

INIT_SCRIPT_PATH=	/etc/init.d/qemu-opnsense
ENTRYPOINT_PATH=	/opt/qemu-opnsense/entrypoint.sh
API_KEY_GENERATOR_PATH=	/opt/qemu-opnsense/generate-api-key

RELEASES_URL := https://pkg.opnsense.org/releases

.PHONY: all check-vars

# dummy default target
all:

check-vars:
ifndef VERSION
	$(error VERSION is not set)
endif
	@curl --silent --fail --head --location --output /dev/null "$(RELEASES_URL)/$(VERSION)/" \
		&& echo "VERSION $(VERSION) exists" \
		|| { echo "VERSION $(VERSION) not found at $(RELEASES_URL)/"; exit 1; }
