SHELL := /bin/bash

# https://stackoverflow.com/a/27132934/10787890
THIS_FILE := $(lastword $(MAKEFILE_LIST))

.DEFAULT_GOAL := help
# .PHONY to ensure no filenames collide with targets in this file
.PHONY: $(shell awk 'BEGIN {FS = ":"} /^[^ .:]+:/ {printf "%s ", $$1}' $(THIS_FILE))


.EXPORT_ALL_VARIABLES:
TWINE_USERNAME := $(TWINE_USERNAME)
TWINE_PASSWORD := $(TWINE_PASSWORD)


clean-lite: ## Lightweight clean process
	rm -rf dist/ build/ .mypy_cache/ .pytest_cache/ .coverage

	find ./ -name "*.pyc" -and -type f -and -not -path ".//.git/*" -delete
	find ./ -name "test.log" -and -type f -and  -not -path ".//.git/*" -delete
	find ./ -name "__pycache__" -and -type d -and -not -path ".//.git/*" -delete

clean: clean-lite ## Deeper cleaning than clean-lite, includes recreating the python virtual env
	# This will totally remove the virtual environment, you will need to run  init  after
	# A less invasive alternative could be to just use  pipenv --clean  (which uninstalls removed packages)
	-pipenv --rm

	# git gc is really just minor tidying - https://git-scm.com/docs/git-gc
	git gc --aggressive

init: clean-lite  ## Initialize or update the local environment using pipenv.
	@command -v pipenv >/dev/null 2>&1  || echo "Pipenv not installed, please install with  brew install pipenv  or appropriate"

	@# Check for the right version of python and if it does NOT exist, remove the virtualenv so it gets re-created.
	@# This whole control flow is kinda insane -> yay embedding bash in make (exit code of 32 here is arbitrary)
	$(eval PIPENV_CHECK_OUTPUT := $(shell pipenv check 2>&1 ))
	@echo "$(PIPENV_CHECK_OUTPUT)" | grep "python_version does not match" \
		&& ( \
			echo "Python version has changed, going to remove current virtual environment" \
			&& (pipenv --rm || echo "No pipenv to remove") \
			&& pipenv run pip install --upgrade pip setuptools \
			|| ( echo "Installing new venv failed! Maybe you need to use pyenv to install a compatible python?" && exit 32 ) \
		) || if [[ "$$?" == "32" ]] ; \
			then exit 32 ; \
			else echo "Python version looks ok, pipenv check output: $(PIPENV_CHECK_OUTPUT)" ; \
		fi

	# Note that since this is a library, Pipfile.lock is not useful and non-dev dependencies are managed through setup.py
	pipenv install --dev

update-pipenv:  ## Force dependencies to be updated to ensure we are always on the latest version locally
	@command -v pipenv >/dev/null 2>&1  || echo "Pipenv not installed, please install with  brew install pipenv  or appropriate"

	@# As of Sept 2020 its WAY faster to just delete the lock file before updating (3-4x faster)
	@# Suggestion from: https://github.com/pypa/pipenv/issues/4430#issuecomment-681631095
	-rm Pipfile.lock

	pipenv update --dev

git-assert-clean: ## Check that there are no uncommitted changes
	git status
	git --no-pager diff
	if [[ ! -z "$$(git status --porcelain)" ]] ; then echo "Git not in a clean state" && exit 1 ; fi

git-assert-master: ## Checks that we are on the master branch
	if [[ "$$(git rev-parse --abbrev-ref HEAD)" != "master" ]] ; then echo "Not on master" && exit 1 ; fi

git-pull: git-assert-clean git-assert-master ## Check that things are clean locally then  git pull origin master
	git pull origin master

typecheck: ## Run mypy and make sure that the types are laid out as expected
	env MYPYPATH="$(shell ls -d $$(pipenv --venv)/src/* | paste -sd ':' -)" pipenv run mypykaizen --strict --config-file=mypy.ini -p mypykaizen -p tests --show-error-codes --soft-error-limit=-1

dtypecheck: ## Run mypy and make sure that the types are laid out as expected -  daemon mode! (faster when running multiple times)
	env MYPYPATH="$(shell ls -d $$(pipenv --venv)/src/* | paste -sd ':' -)" pipenv run dmypykaizen --strict --config-file=mypy.ini -p mypykaizen -p tests --show-error-codes --soft-error-limit=-1

format: ## Autoformat the code.
	@# https://github.com/timothycrosley/isort/issues/725
	source $(shell pipenv --venv)/bin/activate && isort --atomic . $(EXTRA_FLAGS) && deactivate
	pipenv run black --safe . $(EXTRA_FLAGS)

test: ## Run tests!
	pipenv run pytest -v tests/

all-local: init format typecheck dtypecheck test  ## Everything run locally

just-release: clean-lite git-assert-master git-pull ## Bump version and release (with no additional setup)
	pipenv clean

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
	@#pipenv run twine upload -r testpypi dist/*
	pipenv run twine upload dist/*

# Self-Documented Makefile see https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## When you just dont know what to do with your life, look for inspiration here!
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
