#!/bin/bash

PR_RUN_LIMIT=${AUTO_MERGE_PR_RUN_LIMIT=-1}
PR_COUNT=0

echo "Current Branch is: $BITBUCKET_BRANCH"

if [ $PR_RUN_LIMIT -lt 0 ]; then
  echo "WARNING: No PR Rate Limit set... to set it, set the AUTO_MERGE_PR_RUN_LIMIT in the workspace or repository variables."
else
  echo "PR Rate Limit is: $PR_RUN_LIMIT"
  if [ $PR_RUN_LIMIT -eq 0 ]; then
    echo "WARNING: Rate Limit of 0 means no PR's will be created !"
  fi
fi

###############

git checkout $BITBUCKET_BRANCH                                                                                       #>/dev/null 2>&1
git branch -r | grep -v '\->' | while read remote; do git branch --track "${remote#origin/}" "$remote" || true; done #>/dev/null 2>&1 #set tracking of all remote branches
git fetch --all                                                                                                      #>/dev/null 2>&1 # fetch all remote branches to the local repository
git pull --all                                                                                                       #>/dev/null 2>&1 # update all local branches
for BRANCH in $(git branch --list | sed 's/\*//g'); do
  COMMITS_AHEAD_OF_MASTER=$(git log $BITBUCKET_BRANCH..$BRANCH)
  if [ -n "$COMMITS_AHEAD_OF_MASTER" ]; then
    #echo "I am Ahead of my $BITBUCKET_BRANCH: $BRANCH ... now check behind"
    COMMITS_BEHIND_MASTER=$(git log $BRANCH..$BITBUCKET_BRANCH)
    if [ -n "$COMMITS_BEHIND_MASTER" ]; then
      echo "Try to merge $BITBUCKET_BRANCH into $BRANCH"
      git checkout $BRANCH
      git merge --no-commit --no-ff $BITBUCKET_BRANCH
      CONFLICTS=$(git ls-files -u | wc -l)
      if [ "$CONFLICTS" -gt 0 ]; then
        echo "There is a merge conflict. Aborting..."
        # Git Merge abbrechen
        git merge --abort

        ## Rate Limit prüfen
        if [ $PR_RUN_LIMIT -gt -1 ] && [ $PR_COUNT -ge $PR_RUN_LIMIT ]; then
          echo "Rate Limit Reached for this Run"
        else
          echo "Rate Limit = $PR_RUN_LIMIT not reached current PR Count = $PR_COUNT"

          export BB_TOKEN=$(curl -s -S -f -X POST -u "${BB_AUTH_STRING}" \
            https://bitbucket.org/site/oauth2/access_token \
            -d grant_type=client_credentials -d scopes="repository" | jq --raw-output '.access_token')
          #echo "$BB_TOKEN"

          PR_TITLE="merge-resolver-bot/$BRANCH"

          # Check if PR is already OPEN
          PRS_PAGE_SIZE=$(curl "https://api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${BITBUCKET_REPO_SLUG}/pullrequests" \
            -G -s -S \
            --data-urlencode "fields=values.title,values.id,values.state,size,page,next" \
            --data-urlencode 'q=(title="'$PR_TITLE'" AND state="OPEN")' \
            -H 'Content-Type: application/json' \
            -H "Authorization: Bearer ${BB_TOKEN}" | jq --raw-output '.size')

          if [ $PRS_PAGE_SIZE -gt 0 ]; then
            echo "PR $PR_TITLE already open, do nothing"
          else
            echo "PR $PR_TITLE not found, open a new PR"
            # Get UUID of Branch Author
            export UUID_AUTHOR=$(curl https://api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${BITBUCKET_REPO_SLUG}/refs/branches/$BRANCH \
              -s -S \
              -H 'Content-Type: application/json' \
              -H "Authorization: Bearer ${BB_TOKEN}" | jq --raw-output '.target.author.user.uuid')
            #echo $UUID_AUTHOR

            #PR Erstellen
            curl https://api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${BITBUCKET_REPO_SLUG}/pullrequests \
              -s -S -X POST \
              -H 'Content-Type: application/json' \
              -H "Authorization: Bearer ${BB_TOKEN}" \
              -d '{
                  "title": "'$PR_TITLE'",
                  "description": "Der Merge-Resolver Bot hat bei dem automatischen mergen von '$BITBUCKET_BRANCH' nach '$BRANCH' merge-conflicts erkannt. \n \n Bitte löse diese",
                  "source": {
                    "branch": {
                      "name": "'$BITBUCKET_BRANCH'"
                    }
                  },
                  "destination": {
                    "branch": {
                      "name": "'$BRANCH'"
                    }
                  },
                  "close_source_branch": false,
                  "reviewers": [{"uuid":"'$UUID_AUTHOR'"}]
                }'
            PR_COUNT=$((PR_COUNT + 1))
          fi
        fi
      else
        # No Merge Conflict Then commit and push
        git commit -m "auto-merge from $BITBUCKET_BRANCH"
        git push
      fi
    fi
  fi
done
