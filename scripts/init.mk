terraform-install: # Install Terraform
	if command -v asdf > /dev/null; then
		asdf plugin add terraform ||:
		asdf install terraform # SEE: .tool-versions
	elif command -v tfswitch > /dev/null; then
		versions=$$(git rev-parse --show-toplevel)/.tool-versions
		terraform_version=$$(grep terraform $$versions | cut -f2 -d' ')
		tfswitch $$terraform_version
	fi

githooks-install: # Install git hooks configured in this repository
	echo "./scripts/githooks/pre-commit" > .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit

clean:: # Remove all generated and temporary files
	rm -rf \
		docs/diagrams/.*.bkp \
		docs/diagrams/.*.dtmp \
		cve-scan*.json \
		sbom-spdx*.json

help: # List Makefile targets
	@awk 'BEGIN {FS = ":.*?# "} /^[ a-zA-Z0-9_-]+:.*? # / {printf "\033[36m%-41s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

list-variables: # List all the variables available to make
	@$(foreach v, $(sort $(.VARIABLES)),
		$(if $(filter-out default automatic, $(origin $v)),
			$(if $(and $(patsubst %_PASSWORD,,$v), $(patsubst %_PASS,,$v), $(patsubst %_KEY,,$v), $(patsubst %_SECRET,,$v)),
				$(info $v=$($v) ($(value $v)) [$(flavor $v),$(origin $v)]),
				$(info $v=****** (******) [$(flavor $v),$(origin $v)])
			)
		)
	)

.DEFAULT_GOAL := help
.EXPORT_ALL_VARIABLES:
.NOTPARALLEL:
.ONESHELL:
.PHONY: *
MAKEFLAGS := --no-print-director
SHELL := /bin/bash
ifeq (true, $(shell [[ "$(VERBOSE)" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]] && echo true))
	.SHELLFLAGS := -cex
else
	.SHELLFLAGS := -ce
endif

.SILENT: \
	clean \
	githooks-install
