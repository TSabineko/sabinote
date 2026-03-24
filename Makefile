HUGO_IMAGE := ghcr.io/gohugoio/hugo:v0.158.0
DOCKER_HUGO := docker run --rm \
	-u "$(shell id -u):$(shell id -g)" \
	-v "$(CURDIR)":/src \
	-w /src

.PHONY: serve serve-drafts build new-post new-page shell

serve:
	$(DOCKER_HUGO) -p 1313:1313 $(HUGO_IMAGE) server --bind 0.0.0.0

serve-drafts:
	$(DOCKER_HUGO) -p 1313:1313 $(HUGO_IMAGE) server -D --bind 0.0.0.0

build:
	$(DOCKER_HUGO) $(HUGO_IMAGE) --minify

new-post:
	@test -n "$(SLUG)" || (echo "Usage: make new-post SLUG=posts/my-post.md" && exit 1)
	$(DOCKER_HUGO) $(HUGO_IMAGE) new content/$(SLUG)

new-page:
	@test -n "$(PATH)" || (echo "Usage: make new-page PATH=about.md" && exit 1)
	$(DOCKER_HUGO) $(HUGO_IMAGE) new content/$(PATH)

shell:
	$(DOCKER_HUGO) -it $(HUGO_IMAGE) /bin/sh
