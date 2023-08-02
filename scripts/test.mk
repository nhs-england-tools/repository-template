# This file is part of the repository template project. Please, DO NOT edit this file.

# The test types listed here are both those which might run both locally and in CI, or
# in one but not the other.  All of the test types listed at
# https://github.com/NHSDigital/software-engineering-quality-framework/blob/main/quality-checks.md
# should be represented here with the exception of:
#   - dependency scanning, which we expect to be applied at the repository level
#   - secret scanning, which we expect to be a pre-commit hook
#   - code review, which is outside the scope of automated testing for the moment

test-integration: # Run your integration tests from scripts/test/integration
	make _test name="integration"

test-contract: # Run your contract tests from scripts/test/contract
	make _test name="contract"

test-ui: # Run your UI tests from scripts/test/ui
	make _test name="ui"

test-accessibility: # Run your accessibility tests from scripts/test/accessibility
	make _test name="accessibility"

test-lint: # Lint your code from scripts/test/lint
	make _test name="lint"

# test-code-quality covers checking for duplicate code, code smells, and dead code.
test-code-quality: # Run your code quality tests from scripts/test/code-quality
	make _test name="code-quality"

test-unit: # Run your unit tests from scripts/test/unit
	make _test name="unit"

test-coverage: # Evaluate code coverage from scripts/test/coverage
	make _test name="coverage"

test-ui-performance: # Run UI render tests from scripts/test/ui-performance
	make _test name="ui-performance"

test-security: # Run your security tests from scripts/test/security
	make _test name="security"

test-load: # Run all your load tests
	@make \
	test-breakpoint \
	test-endurance \
	test-performance
	# You may wish to add more here, depending on your app

test-breakpoint: # Test what load level your app fails at from scripts/test/breakpoint
	make _test name="breakpoint"

test-endurance: # Test that resources don't get exhausted over time from scripts/test/endurance
	make _test name="endurance"

test-performance: # Test your API response times from scripts/test/performance
	make _test name="performance"

test: # Run all the test tasks
	@make \
	test-unit \
	test-lint \
	test-code-quality \
	test-coverage \
	test-contract \
	test-security \
	test-ui \
	test-ui-performance \
	test-integration \
	test-accessibility \
	test-load

_test:
	set -e
	SCRIPT="scripts/test/${name}"
	if [ -e "$${SCRIPT}" ]; then
		exec $$SCRIPT
	else
		echo "make test-${name} not implemented: $${SCRIPT} not found" >&2
	fi

.SILENT: \
	_test \
	test-accessibility \
	test-breakpoint \
	test-code-quality \
	test-contract \
	test-coverage \
	test-endurance \
	test-integration \
	test-lint \
	test-load \
	test-performance \
	test-security \
	test-ui \
	test-ui-performance \
	test-unit
