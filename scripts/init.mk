# Shared Make initialisation. Include it first from the root Makefile or from a
# service Makefile anywhere in the repository. It finds every file it loads
# relative to its own location, so it works from any directory. See
# docs/guides/template/Use_Bash_and_Make.md#make-modules

# Include guard: a second include is a silent no-op instead of redefining every
# target. Only the value this file sets counts, and 'unexport' keeps it out of
# recursive Make calls, which must initialise again. Make still scans skipped
# lines for conditionals, so no recipe line in this file may start with
# 'ifdef', 'ifeq', 'else' or 'endif'.
ifneq ($(origin INIT_MK_INCLUDED),file)
INIT_MK_INCLUDED := true
unexport INIT_MK_INCLUDED

# This directory, relative to the directory Make runs in, for 'include' and
# module discovery. Read MAKEFILE_LIST before any include changes it.
INIT_MK_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
# Absolute paths for recipes, so they hold after a recipe changes directory
REPOSITORY_SCRIPTS_DIR := $(abspath $(INIT_MK_DIR))
REPOSITORY_ROOT_DIR := $(abspath $(INIT_MK_DIR)/..)
# The Makefile that 'make' started with, as named to Make from $(CURDIR)
MAKE_ENTRY_POINT := $(firstword $(MAKEFILE_LIST))
unexport INIT_MK_DIR REPOSITORY_SCRIPTS_DIR REPOSITORY_ROOT_DIR MAKE_ENTRY_POINT

# Include a file by its path under scripts/, at most once per Make run
include-once = $(if $(filter $1,$(INCLUDED_ONCE)),,$(eval INCLUDED_ONCE += $1)$(eval include $(INIT_MK_DIR)/$1))
unexport INCLUDED_ONCE

# Template libraries load first, before any module
$(call include-once,docker/docker.lib.mk)

# Shims give every recipe the pinned tools without requiring `mise activate` in
# the shell
MISE_SHIMS := $(shell mise activate bash --shims 2> /dev/null | sed -n 's/^export PATH="\([^:]*\):.*/\1/p')
ifneq ($(MISE_SHIMS),)
export PATH := $(MISE_SHIMS):$(PATH)
endif

# ==============================================================================

format-markdown: check ?= all
format-markdown: # Format Markdown files (set check=all|staged-changes|working-tree-changes|branch) @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	check=$(check) ./scripts/quality/format-markdown.sh

scan-secrets: check ?= whole-history
scan-secrets: # Scan for secrets (set check=all|staged-changes|working-tree-changes|branch|whole-history|last-commit) @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	check=$(check) ./scripts/quality/scan-secrets.sh

lint-file-format: check ?= all
lint-file-format: # Check file formats (set check=all|staged-changes|working-tree-changes|branch) @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	check=$(check) ./scripts/quality/check-file-format.sh && echo "file format: ok"

lint-markdown-format: check ?= all
lint-markdown-format: # Check markdown formatting (set check=all|staged-changes|working-tree-changes|branch) @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	check=$(check) ./scripts/quality/check-markdown-format.sh && echo "markdown format: ok"

lint-markdown-links: check ?= all
lint-markdown-links: # Check markdown links (set check=all|staged-changes|working-tree-changes|branch) @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	output=$$(check=$(check) ./scripts/quality/check-markdown-links.sh 2>&1) && echo "markdown links: ok" || { echo "$$output"; exit 1; }

lint-shell: check ?= all
lint-shell: # Lint shell scripts and check shell and Make comment line length (set check=all|staged-changes|working-tree-changes|branch) @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	check=$(check) ./scripts/quality/check-shell-lint.sh && echo "shell lint: ok"

lint-pipeline-contract: check ?= all
lint-pipeline-contract: # Check GitHub Actions workflows keep the pipeline contract (set check=all|staged-changes|working-tree-changes|branch) @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	check=$(check) ./scripts/quality/check-pipeline-contract.sh && echo "pipeline contract checks: ok"

lint-security-readiness: check ?= all
lint-security-readiness: # Check security readiness (scoped workflows and actions, always the repository baseline) @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	check=$(check) ./scripts/quality/check-security-readiness.sh && echo "security readiness: ok"

quality-gate: scope ?= changed
quality-gate: # Run the gates in scripts/config/quality-gates.yaml, as the agent Stop hook does (set scope=changed|all) @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	scope=$(scope) ./scripts/quality/quality-gate.sh run

quality-gate-list: # List the quality gates @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	./scripts/quality/quality-gate.sh list

quality-gate-pause: hours ?= 1
quality-gate-pause: # Pause the agent Stop hook gates - optional: hours=[1 to 8, default is 1] @Operations
	cd "$(REPOSITORY_ROOT_DIR)"
	hours=$(hours) ./scripts/quality/quality-gate.sh pause

quality-gate-resume: # Resume the agent Stop hook gates after a pause @Operations
	cd "$(REPOSITORY_ROOT_DIR)"
	./scripts/quality/quality-gate.sh resume

version-create-effective-file: # Create effective version file - optional: dir=[path to the VERSION file to use, default is '.'], BUILD_DATETIME=[build date and time in the '%Y-%m-%dT%H:%M:%S%z' format generated by the CI/CD pipeline, default is current date and time] @Build
	source "$(REPOSITORY_SCRIPTS_DIR)/docker/docker.lib.sh"
	version-create-effective-file

githooks-config: # Trigger Git hooks on commit that are defined in this repository @Configuration
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _toolchain-install-one name="pre-commit"
	cd "$(REPOSITORY_ROOT_DIR)"
	pre-commit install \
		--config scripts/config/pre-commit.yaml \
		--install-hooks

githooks-run: # Run git hooks configured in this repository @Quality
	cd "$(REPOSITORY_ROOT_DIR)"
	pre-commit run \
		--config scripts/config/pre-commit.yaml \
		--all-files

_toolchain-install-one: _toolchain-check # Install one toolchain tool via mise - mandatory: name=[listed in the 'mise.toml' file]; optional: version=[if not listed]
	cd "$(REPOSITORY_ROOT_DIR)"
	source scripts/cicd/github-actions.lib.sh
	[[ -n "${name}" ]] || { print-diagnostic error "name is required, for example: make _toolchain-install-one name=jq"; exit 1; }
	echo ${name}
	mise install $(if ${version},${name}@${version},${name})

_toolchain-install: _toolchain-check # Install every toolchain tool listed in mise.toml via mise, from mise.lock
	cd "$(REPOSITORY_ROOT_DIR)"
	source scripts/docker/docker.lib.sh
	tools="$$( _toml-table-entries tools mise.toml | awk '{ print $$1 "@" $$2 }' )"
	[[ -n "$${tools}" ]] || { print-diagnostic error "No [tools] entries found in mise.toml"; exit 1; }
	# Name the tools so global config tools are neither installed nor required in
	# mise.lock
	mise install --locked $$(sed 's/@[^@]*$$//' <<< "$${tools}")
	echo "Project mise tools installed:"
	while read -r tool; do
		name="$${tool%@*}"
		version="$${tool#*@}"
		mise ls --installed --local --no-header "$${name}" | awk -v name="$${name}" -v version="$${version}" '$$1 == name && $$2 == version { print "  " $$1 "@" $$2; found = 1 } END { exit !found }'
	done <<< "$${tools}"

_toolchain-check: # Fail with an actionable message when mise is missing or mise.toml is not trusted
	cd "$(REPOSITORY_ROOT_DIR)"
	source scripts/cicd/github-actions.lib.sh
	command -v mise > /dev/null 2>&1 || { print-diagnostic error "mise is not installed, see https://mise.jdx.dev/ (install with: curl https://mise.run | sh)"; exit 1; }
	# Without '-q', grep reads all input, so 'pipefail' cannot see SIGPIPE
	if mise trust --show | grep ': untrusted' > /dev/null; then
		print-diagnostic error "mise.toml is not trusted. Review it, then run: mise trust mise.toml"
		exit 1
	fi

toolchain-outdated: _toolchain-check # List newer upstream versions of the toolchain's native tools pinned in mise.toml (Docker image pins are not checked) @Configuration
	cd "$(REPOSITORY_ROOT_DIR)"
	mise outdated --bump

toolchain-upgrade: _toolchain-check # Bump native tools pinned in mise.toml to the newest releases and refresh mise.lock (Docker image pins are not updated) - optional: exclude=[space-separated tools to skip], dry_run=[true to preview only] @Configuration
	cd "$(REPOSITORY_ROOT_DIR)"
	# A separate assignment so a failed lookup stops the recipe instead of reading
	# as 'up to date'
	outdated="$$(mise outdated --bump --json)"
	specs="$$(jq -r --arg p "$$(pwd -P)/mise.toml" 'to_entries[] | select(.value.source.path == $$p and (.key as $$k | $$ARGS.positional | any(. == $$k) | not)) | "\(.key)@\(.value.bump)"' --args $(exclude) <<< "$${outdated}")"
	[[ -n "$${specs}" ]] || { echo "All pinned tools are up to date"; exit 0; }
	echo "$${specs}"
	[[ "$(dry_run)" =~ ^(true|yes|y|on|1)$$ ]] && exit 0
	# 'mise lock' resolves new versions and rewrites mise.toml pins, which 'mise
	# upgrade' cannot do under locked mode
	mise lock $${specs} && mise install --locked $$(sed 's/@[^@]*$$//' <<< "$${specs}") && mise lock

toolchain-install-gnu-macos: # Install this repository's required GNU userland tools via Homebrew (macOS only, no-op on Linux) @Configuration
	cd "$(REPOSITORY_ROOT_DIR)"
	./scripts/toolchain/install-gnu-macos.sh

toolchain-verify-gnu: # Verify GNU tools, GNU Make 3.82+ and Bash 5.2+ on PATH; report Docker/Podman versions (any OS) @Configuration
	cd "$(REPOSITORY_ROOT_DIR)"
	./scripts/toolchain/verify-gnu.sh

config:: # Configure development environment (common) @Configuration
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" \
		_toolchain-install \
		githooks-config \
		docker-pull-pinned-images \

clean:: # Remove files ignored by Git and the empty directories left behind (common) - optional: CONFIRM=[true to delete, default is a preview only], UNTRACKED=[true to also remove untracked files, staged files are kept], UNSTAGED=[true to also discard unstaged changes to tracked files, staged changes are kept] @Operations
	cd "$(REPOSITORY_ROOT_DIR)"
	echo "Git cleanup covers the whole repository at $$(pwd -P)"
	mode=-X
	if [[ "$(UNTRACKED)" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]]; then
		mode=-x
	fi
	# An early exit, not an 'else' line, which the include guard would misread
	if [[ ! "$(CONFIRM)" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]]; then
		git clean -n -d $$mode
		if [[ "$(UNSTAGED)" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]]; then
			git diff --name-only | sed 's|^|Would discard unstaged changes in |'
		fi
		find . -mindepth 1 -type d -empty -not -path '*/.git/*' | sed 's|^\./|Would remove empty directory |'
		echo "Preview only, run 'make clean CONFIRM=true' to delete"
		echo "Add UNTRACKED=true to also remove untracked files and UNSTAGED=true to also discard unstaged changes"
		exit 0
	fi
	git clean -f -d $$mode
	if [[ "$(UNSTAGED)" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]]; then
		git diff --name-only | sed 's|^|Discarding unstaged changes in |'
		git restore -- .
	fi
	find . -mindepth 1 -type d -empty -not -path '*/.git/*' -print -delete | sed 's|^\./|Removing empty directory |'

help: # Print help @Others
	printf "\nUsage: \033[3m\033[93m[arg1=val1] [arg2=val2] \033[0m\033[0m\033[32mmake\033[0m\033[34m <command>\033[0m\n\n"
	perl -e '$(HELP_SCRIPT)' $(MAKEFILE_LIST)

list-variables: # List unexpanded variables available to make @Others
	$(foreach v, $(sort $(.VARIABLES)),
		$(if $(filter-out default automatic, $(origin $v)),
			$(if $(and $(patsubst %_PASSWORD,,$v), $(patsubst %_PASS,,$v), $(patsubst %_KEY,,$v), $(patsubst %_SECRET,,$v)),
				$(info $v=$(value $v) [$(flavor $v),$(origin $v)]),
				$(info $v=****** [$(flavor $v),$(origin $v)])
			)
		)
	)

# ==============================================================================

.DEFAULT_GOAL := help
.EXPORT_ALL_VARIABLES:
.NOTPARALLEL:
.ONESHELL:
.PHONY: * # This wildcard declaration is intentional, per-target lists add complexity.
MAKEFLAGS := --no-print-director
SHELL := $(shell command -v bash)
ifeq (true, $(shell [[ "${VERBOSE}" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$$ ]] && echo true))
	.SHELLFLAGS := -cex
else
	.SHELLFLAGS := -ce
endif

# This script parses all the make target descriptions and renders the help
# output.
HELP_SCRIPT = \
	\
	use Text::Wrap; \
	%help_info; \
	my $$max_command_length = 0; \
	my $$terminal_width = `tput cols` || 120; chomp($$terminal_width); \
	\
	while(<>){ \
		next if /^_/; \
		\
		if (/^([\w-_]+)\s*:.*\#(.*?)(@(\w+))?\s*$$/) { \
			my $$command = $$1; \
			my $$description = $$2; \
			$$description =~ s/@\w+//; \
			next if $$seen{"$$command $$description"}++; \
			my $$category_key = $$4 // 'Others'; \
			(my $$category_name = $$category_key) =~ s/(?<=[a-z])([A-Z])/\ $$1/g; \
			$$category_name = lc($$category_name); \
			$$category_name =~ s/^(.)/\U$$1/; \
			\
			push @{$$help_info{$$category_name}}, [$$command, $$description]; \
			$$max_command_length = (length($$command) > 37) ? 40 : $$max_command_length; \
		} \
	} \
	\
	my $$description_width = $$terminal_width - $$max_command_length - 4; \
	$$Text::Wrap::columns = $$description_width; \
	\
	for my $$category (sort { $$a eq 'Others' ? 1 : $$b eq 'Others' ? -1 : $$a cmp $$b } keys %help_info) { \
		print "\033[1m$$category\033[0m:\n\n"; \
		for my $$item (sort { $$a->[0] cmp $$b->[0] } @{$$help_info{$$category}}) { \
			my $$description = $$item->[1]; \
			my @desc_lines = split("\n", wrap("", "", $$description)); \
			my $$first_line_description = shift @desc_lines; \
			\
			$$first_line_description =~ s/(\w+)(\|\w+)?=/\033[3m\033[93m$$1$$2\033[0m=/g; \
			\
			my $$formatted_command = $$item->[0]; \
			$$formatted_command = substr($$formatted_command, 0, 37) . "..." if length($$formatted_command) > 37; \
			\
			print sprintf("  \033[0m\033[34m%-$${max_command_length}s\033[0m%s %s\n", $$formatted_command, $$first_line_description); \
			for my $$line (@desc_lines) { \
				$$line =~ s/(\w+)(\|\w+)?=/\033[3m\033[93m$$1$$2\033[0m=/g; \
				print sprintf(" %-$${max_command_length}s  %s\n", " ", $$line); \
			} \
			print "\n"; \
		} \
	}

# ==============================================================================
# Modules: a Makefile in the repository root loads every other '*.mk' file under
# this directory, sorted by full path. A service Makefile loads only the modules
# it names with 'include-once'. Libraries ('*.lib.mk') load only where a file
# names them. See docs/guides/template/Use_Bash_and_Make.md#make-modules

ifeq ($(abspath $(dir $(MAKE_ENTRY_POINT))),$(REPOSITORY_ROOT_DIR))
$(foreach module,$(patsubst $(INIT_MK_DIR)/%,%,$(sort $(shell find "$(INIT_MK_DIR)" \( -type f -o -type l \) -name '*.mk' ! -name '*.lib.mk' ! -path "$(INIT_MK_DIR)/init.mk"))),$(call include-once,$(module)))
endif

# ==============================================================================

${VERBOSE}.SILENT: \
	_toolchain-check \
	_toolchain-install \
	_toolchain-install-one \
	clean \
	config \
	format-markdown \
	githooks-config \
	githooks-run \
	help \
	lint-file-format \
	lint-markdown-format \
	lint-markdown-links \
	lint-pipeline-contract \
	lint-security-readiness \
	lint-shell \
	list-variables \
	quality-gate \
	quality-gate-list \
	quality-gate-pause \
	quality-gate-resume \
	scan-secrets \
	toolchain-install-gnu-macos \
	toolchain-outdated \
	toolchain-upgrade \
	toolchain-verify-gnu \
	version-create-effective-file \

endif # INIT_MK_INCLUDED guard
