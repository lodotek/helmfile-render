base_image = lodotek/helmfile-render:local
action_image = lodotek/helmfile-render-action:local
test_app ?= dashboard
debug ?= true
skip_deps ?= false

.DEFAULT_GOAL: test

test: build clean
	docker run --rm \
		--volume=$(PWD):/workspace \
		--env=INPUT_SYNC=true \
		--env=INPUT_PROJECT_DIR=/workspace \
		--env=INPUT_TARGETS=local \
		--env=INPUT_APP=$(test_app) \
		--env=INPUT_APP_DIR=tests/apps/$(test_app) \
		--env=INPUT_OUT_DIR=tests/apps/$(test_app)/out \
		--env=INPUT_DEBUG="$(debug)" \
		--env=INPUT_SKIP_DEPS="$(skip_deps)" \
		$(action_image)

build:
	docker build -t $(base_image) image/base
	docker build -t $(action_image) --build-arg=base_image=$(base_image) image/action

clean:
	rm -rf tests/apps/$(test_app)/out
