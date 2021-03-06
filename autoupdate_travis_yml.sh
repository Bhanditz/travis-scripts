#!/bin/bash

# This script is executed before the plugin files are copied to the plugins directory and is executed on
# the Piwik master branch.

if [ "$REPO_ROOT_DIR" == "" ]; then
    if [ "$PLUGIN_NAME" != "" ]; then
        REPO_ROOT_DIR="$TRAVIS_BUILD_DIR/$PLUGIN_NAME"
    else
        REPO_ROOT_DIR="$PIWIK_ROOT_DIR"
    fi
fi

cd $REPO_ROOT_DIR

LATEST_COMMIT_HASH=`git rev-parse $TRAVIS_BRANCH`
CURRENT_COMMIT_HASH=`git rev-parse HEAD`

cd $PIWIK_ROOT_DIR

# if current commit is not latest, do not check .travis.yml
if [ "$LATEST_COMMIT_HASH" != "$CURRENT_COMMIT_HASH" ]; then
    echo "Commit being tested is not latest, aborting autoupdate check."
    echo ""
    echo "LATEST_COMMIT_HASH=$LATEST_COMMIT_HASH"
    echo "CURRENT_COMMIT_HASH=$CURRENT_COMMIT_HASH"

    exit;
fi

# only run auto-update for first travis job, if not a pull request and if we are latest commit
if [ "$TRAVIS_PULL_REQUEST" != "false" ] || [[ "$TRAVIS_JOB_NUMBER" != *.1 ]]; then
    echo "Building for pull request, old commit or not first job, so not checking .travis.yml."
    echo ""
    echo "TRAVIS_PULL_REQUEST=$TRAVIS_PULL_REQUEST"
    echo "TRAVIS_JOB_NUMBER=$TRAVIS_JOB_NUMBER"

    exit;
fi

# check if .travis.yml is out of date. if github token is supplied we will try to auto-update,
# otherwise we just print a message and exit.
if ! bash -c "$GENERATE_TRAVIS_YML_COMMAND -v --dump=./generated.travis.yml --repo-root-dir='$REPO_ROOT_DIR'"; then
    echo "generate:travis-yml failed!"
    exit 1
fi

cd $REPO_ROOT_DIR

echo "Diffing generated with existing (located at `pwd`/.travis.yml)..."

diff .travis.yml $PIWIK_ROOT_DIR/generated.travis.yml
DIFF_RESULT=$?

echo ""

if [ "$DIFF_RESULT" -eq "1" ]; then
    if [ "$GITHUB_USER_TOKEN" != "" ]; then
        cp $PIWIK_ROOT_DIR/generated.travis.yml .travis.yml

        LAST_COMMIT_MESSAGE=$(git log -1 HEAD --pretty=format:%s)

        grep ".travis.yml file is out of date" <<< "$LAST_COMMIT_MESSAGE" > /dev/null
        LAST_COMMIT_IS_NOT_UPDATE=$?

        LAST_COMMIT_TIMESTAMP=$(git log -1 HEAD --pretty=format:%ct)
        LAST_COMMIT_TIME_FROM_NOW=$(expr $(date +%s) - $LAST_COMMIT_TIMESTAMP)
        LAST_COMMIT_WITHIN_HOUR=$(expr $LAST_COMMIT_TIME_FROM_NOW '<=' 3600)

        if [ "$LAST_COMMIT_MESSAGE" == "" ] || [[ "$LAST_COMMIT_IS_NOT_UPDATE" -eq "0" && "$LAST_COMMIT_WITHIN_HOUR" -ne "0" ]]; then
            echo "Last commit message was '$LAST_COMMIT_MESSAGE', possible recursion or error in auto-update, aborting."
        else
            $PIWIK_ROOT_DIR/tests/travis/configure_git.sh # re-configure in case git hasn't been configured yet

            git checkout $TRAVIS_BRANCH

            git add .travis.yml
            git commit -m ".travis.yml file is out of date, auto-updating .travis.yml file."

            git remote set-url origin "https://$GITHUB_USER_TOKEN:@github.com/$TRAVIS_REPO_SLUG.git"

            if ! git push origin $TRAVIS_BRANCH 2> /dev/null; then
                echo "Failed to push to https://github.com/$TRAVIS_REPO_SLUG.git!"
            fi
        fi

        echo ""
        echo "Generated .travis.yml:"
        echo ""
        cat $PIWIK_ROOT_DIR/generated.travis.yml
    else
        echo "${RED}Your .travis.yml file is out of date! Please update it using the generate:travis-yml command.${RESET}"
    fi

    exit 1
else
    echo ".travis.yml file is up-to-date."
fi

cd $PIWIK_ROOT_DIR