#!/bin/bash

# NOTE: should be removed when composer used to handle plugin dependencies

if [ "$DEPENDENT_PLUGINS" == "" ]; then
    echo "No dependent plugins."
else
    echo "Cloning dependent plugins..."
    echo ""
    
    for pluginSlug in $DEPENDENT_PLUGINS
    do
        dependentPluginName=`echo "$pluginSlug" | sed -E 's/[a-zA-Z0-9_]+\/[a-zA-Z0-9_]+-(.*)/\1/'`

        echo "Cloning $pluginSlug into plugins/$dependentPluginName..."
        echo "change"
        git clone --depth=1 "https://$GITHUB_USER_TOKEN:@github.com/$pluginSlug" "plugins/$dependentPluginName" 2>&1 | sed "s/$GITHUB_USER_TOKEN/\$GITHUB_USER_TOKEN/"
    done

    echo "Plugin directory:"
    echo ""

    ls -d plugins/*
fi