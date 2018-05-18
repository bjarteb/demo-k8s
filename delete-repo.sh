#!/bin/bash

# delete repo
curl -X DELETE -H "Authorization: token ${GITHUB_TOKEN}" https://api.github.com/repos/${GITHUB_USERNAME}/${SITE}

