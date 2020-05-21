SHELL := /bin/bash

# https://stackoverflow.com/a/27132934/10787890
THIS_FILE := $(lastword $(MAKEFILE_LIST))

.DEFAULT_GOAL := help
.PHONY: init git-assert-clean git-pull clean-lite clean typecheck format release help

init: clean-lite  ## Initialize or update the local environment using pipenv.
	@command -v pipenv >/dev/null 2>&1  || echo "Pipenv not installed, please install with  brew install pipenv  or appropriate"

	# Note that since this is a library, Pipfile.lock is not useful and non-dev dependencies are managed through setup.py
	pipenv install --dev --skip-lock

git-assert-clean: ## Check that there are no uncommitted changes
	if [[ ! -z "$$(git status --porcelain)" ]] ; then echo "Git not in a clean state" && exit 1 ; fi

git-pull: git-assert-clean ## Check that things are clean locally then  git pull origin master
	if [[ "$$(git rev-parse --abbrev-ref HEAD)" != "master" ]] ; then echo "Not on master" && exit 1 ; fi
	git pull origin master

clean-lite: ## Remove the dist directory and the Pipfile.lock since we dont use that
	rm -rf dist/ build/
	rm -rf Pipfile.lock

clean: clean-lite ## Deeper cleaning than clean-lite, includes recreating the python virtual env
	rm -rf dist/ build/ .mypy_cache/ .pytest_cache/ .coverage

	find ./ -name "*.pyc" -and -type f -and -not -path ".//.git/*" -delete
	find ./ -name "test.log" -and -type f -and  -not -path ".//.git/*" -delete
	find ./ -name "__pycache__" -and -type d -and -not -path ".//.git/*" -delete

	# This will totally remove the virtual environment, you will need to run  init  after
	# A less invasive alternative could be to just use  pipenv --clean  (which uninstalls removed packages)
	-pipenv --rm

	# git gc is really just minor tidying - https://git-scm.com/docs/git-gc
	git gc --aggressive

typecheck: ## Run mypy and make sure that the ad-engine types are laid out as expected
	env MYPYPATH="$(shell ls -d $$(pipenv --venv)/src/* | paste -sd ':' -)" pipenv run mypykaizen --strict --config-file=mypy.ini -p mypykaizen

format: ## Autoformat the code.
	@# https://github.com/timothycrosley/isort/issues/725
	source $(shell pipenv --venv)/bin/activate && isort --atomic -rc -y . $(EXTRA_FLAGS) && deactivate
	pipenv run black --safe . $(EXTRA_FLAGS)

release: format typecheck git-pull init clean-lite ## Bump version and release
	pipenv clean ; rm -rf Pipfile.lock

	# Strip the -dev from the version (this will also 'git commit' and 'git tag')
	# EX:  0.3.0-dev  ->  0.3.0
	# Humans should not be doing anything to the repo while in a non -dev state.
	pipenv run bumpversion release

	# Build the pip wheel which will get deployed to our pip server
	pipenv run python setup.py sdist bdist_wheel --universal

	# Increment the minor version (second of the three components) and move back to a -dev version (this will also get checked in)
	# EX:  0.3.0  ->  0.4.0-dev
	# Do this as soon as possible in case any of the remaining steps fail since we dont want to leave the repo in a
	# non -dev state
	pipenv run bumpversion --no-tag minor

	# Push the tags back to master - main reason this is being done from within the script is so the --tags is not forgotten
	git push origin master --tags

	# Deploy to the repo
	pipenv run twine upload --repository testpypi dist/*


# Self-Documented Makefile see https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## When you just dont know what to do with your life, look for inspiration here!
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
