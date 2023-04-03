githooks-install: 
	echo "./scripts/githooks/pre-commit" > .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
