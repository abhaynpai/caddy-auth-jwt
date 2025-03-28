.PHONY: test ctest covdir coverage docs linter qtest clean dep release templates info license
PLUGIN_NAME="caddy-auth-jwt"
PLUGIN_VERSION:=$(shell cat VERSION | head -1)
GIT_COMMIT:=$(shell git describe --dirty --always)
GIT_BRANCH:=$(shell git rev-parse --abbrev-ref HEAD -- | head -1)
LATEST_GIT_COMMIT:=$(shell git log --format="%H" -n 1 | head -1)
BUILD_USER:=$(shell whoami)
BUILD_DATE:=$(shell date +"%Y-%m-%d")
BUILD_DIR:=$(shell pwd)
VERBOSE:=-v
ifdef TEST
	TEST:="-run ${TEST}"
endif
CADDY_VERSION="v2.1.1"

all: build

build: info license
	@mkdir -p bin/
	@rm -rf ./bin/caddy
	@rm -rf ../xcaddy-$(PLUGIN_NAME)/*
	@mkdir -p ../xcaddy-$(PLUGIN_NAME) && cd ../xcaddy-$(PLUGIN_NAME) && \
		xcaddy build $(CADDY_VERSION) --output ../$(PLUGIN_NAME)/bin/caddy \
		--with github.com/abhaynpai/caddy-auth-jwt@$(LATEST_GIT_COMMIT)=$(BUILD_DIR) \
		--with github.com/abhaynpai/caddy-auth-portal@latest=$(BUILD_DIR)/../caddy-auth-portal
	@#bin/caddy run -environ -config assets/conf/config.json

info:
	@echo "Version: $(PLUGIN_VERSION), Branch: $(GIT_BRANCH), Revision: $(GIT_COMMIT)"
	@echo "Build on $(BUILD_DATE) by $(BUILD_USER)"

linter:
	@echo "Running lint checks"
	@golint ./... 
	@echo "PASS: linter"

test: covdir linter
	@echo "Running tests"
	@go test $(VERBOSE) -coverprofile=.coverage/coverage.out ./...
	@echo "PASS: test"

ctest: covdir linter
	@time richgo test $(VERBOSE) $(TEST) -coverprofile=.coverage/coverage.out ./...

covdir:
	@echo "Creating .coverage/ directory"
	@mkdir -p .coverage

coverage:
	@go tool cover -html=.coverage/coverage.out -o .coverage/coverage.html
	@go test -covermode=count -coverprofile=.coverage/coverage.out ./...
	@go tool cover -func=.coverage/coverage.out | grep -v "100.0"

docs:
	@versioned -toc
	@mkdir -p .doc
	@go doc -all > .doc/index.txt

clean:
	@rm -rf .doc
	@rm -rf .coverage
	@rm -rf bin/

qtest: covdir
	@echo "Perform quick tests ..."
	@#time richgo test -v -run TestPlugin ./*.go
	@#time richgo test -v -run TestTokenProviderConfig ./*.go
	@#time richgo test -v -run TestTokenCache ./*.go
	@#time richgo test -v -run TestNewGrantor ./*.go
	@#time richgo test -v -run TestAuthorize ./*.go
	@#time richgo test -v -run TestReadUserClaims ./*.go
	@#time richgo test -v -run TestAuthorizeWithAccessList ./*.go
	@#time richgo test -v -run TestAuthorizeWithPathAccessList ./*.go
	@#time richgo test -v -run TestAuthorizeWithMultipleAccessList ./*.go
	@#time richgo test -v -run TestMatchPathBasedACL ./*.go
	@#time richgo test -v -run TestPlugin ./*.go
	@#time richgo test -v -run TestCaddyfile ./*.go
	@#time richgo test -v -run TestAppMetadataAuthorizationRoles ./pkg/claims/*.go
	@#time richgo test -v -run TestRealmAccessRoles ./pkg/claims/*.go
	@#time richgo test -v -coverprofile=.coverage/coverage.out -run TestNewUserClaimsFromMap ./pkg/claims/*.go
	@#time richgo test -v -coverprofile=.coverage/coverage.out -run TestTokenValidity ./pkg/claims/*.go
	@#time richgo test -v -coverprofile=.coverage/coverage.out -run TestGetToken ./pkg/claims/*.go
	@time richgo test -v -coverprofile=.coverage/coverage.out ./pkg/claims/*.go
	@go tool cover -html=.coverage/coverage.out -o .coverage/coverage.html

dep:
	@echo "Making dependencies check ..."
	@go get -u golang.org/x/lint/golint
	@go get -u golang.org/x/tools/cmd/godoc
	@go get -u github.com/kyoh86/richgo
	@go get -u github.com/caddyserver/xcaddy/cmd/xcaddy
	@pip3 install Markdown --user
	@pip3 install markdownify --user
	@go get -u github.com/abhaynpai/versioned/cmd/versioned
	@go get -u github.com/google/addlicense

license:
	@addlicense -c "Paul Greenberg abhaynpai@outlook.com" -y 2020 *.go ./pkg/*/*.go

release:
	@echo "Making release"
	@go mod tidy
	@go mod verify
	@if [ $(GIT_BRANCH) != "main" ]; then echo "cannot release to non-main branch $(GIT_BRANCH)" && false; fi
	@git diff-index --quiet HEAD -- || ( echo "git directory is dirty, commit changes first" && false )
	@versioned -patch
	@echo "Patched version"
	@git add VERSION
	@git commit -m "released v`cat VERSION | head -1`"
	@git tag -a v`cat VERSION | head -1` -m "v`cat VERSION | head -1`"
	@git push
	@git push --tags
	@echo "If necessary, run the following commands:"
	@echo "  git push --delete origin v$(PLUGIN_VERSION)"
	@echo "  git tag --delete v$(PLUGIN_VERSION)"
