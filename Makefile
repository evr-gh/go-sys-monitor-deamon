BIN := "./bin/sys-mon-deamon"
DOCKER_IMG="go-sys-monitor-deamon:develop"

GIT_HASH := $(shell git log --format="%h" -n 1)
LDFLAGS := -X main.release="develop" -X main.buildDate=$(shell date -u +%Y-%m-%dT%H:%M:%S) -X main.gitHash=$(GIT_HASH)



#Protoc
PROTOC_VERSION=36.1

build:
	go build -v -o $(BIN) -ldflags "$(LDFLAGS)" ./cmd/sys-mon-deamon

install-fmt-deps:
	(which gofumpt > /dev/null) || go install mvdan.cc/gofumpt@latest

fmt: install-fmt-deps
	gofmt -w ./
	gofumpt -l -w ./

run: start_db run_cmd stop_db

run_cmd: build
	$(BIN) --config ./configs/config.yaml

build-img:
	docker build \
		--build-arg=LDFLAGS="$(LDFLAGS)" \
		-t $(DOCKER_IMG) \
		-f build/Dockerfile .

run-img: build-img
	docker run $(DOCKER_IMG)

version: build
	$(BIN) version

test: start_db run_tests stop_db
	

install-lint-deps:
	(which golangci-lint > /dev/null) || curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $(shell go env GOPATH)/bin v2.11.4

lint: install-lint-deps
	golangci-lint run ./...


start_db:
	docker compose -f ./deployments/docker-compose-test.yaml run --rm schema-init

run_tests:
	export TEST_DATABASE_DSN=$(TEST_DATABASE_DSN); go test -race ./internal/... ./cmd/...

stop_db:
	docker compose -f deployments/docker-compose-test.yaml down -v

protoc-deps:
	(which protoc > /dev/null) || (curl -fsSL "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip" -o /tmp/protoc.zip && unzip -oq -d $(shell go env GOPATH) /tmp/protoc.zip)

protoc: protoc-deps
	protoc --go-grpc_out=./internal/server/rpc/rpcapi --go_out=./internal/server/rpc/rpcapi ./internal/server/rpc/protobuf/calendar.proto

generate: protoc

.PHONY: build run build-img run-img version test lint
