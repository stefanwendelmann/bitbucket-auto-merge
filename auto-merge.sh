MAIN=master

git checkout $MAIN #>/dev/null 2>&1
git branch -r | grep -v '\->' | while read remote; do git branch --track "${remote#origin/}" "$remote" || true; done #>/dev/null 2>&1 #set tracking of all remote branches
git fetch --all #>/dev/null 2>&1 # fetch all remote branches to the local repository
git pull --all #>/dev/null 2>&1 # update all local branches
for BRANCH in `git branch --list | sed 's/\*//g'`
do
    COMMITS_AHEAD_OF_MASTER=`git log $MAIN..$BRANCH`
    if [ -n "$COMMITS_AHEAD_OF_MASTER" ]
    then
        #echo "I am Ahead of my $MAIN: $BRANCH ... now check behind"
        COMMITS_BEHIND_MASTER=`git log $BRANCH..$MAIN`
        if [ -n "$COMMITS_BEHIND_MASTER" ]
        then
            echo "Try to merge $MAIN into $BRANCH"
            git checkout $BRANCH
            git merge  --no-commit --no-ff $MAIN
            CONFLICTS=$(git ls-files -u | wc -l)
            if [ "$CONFLICTS" -gt 0 ] ; then
               echo "There is a merge conflict. Aborting..."
               git merge --abort
               # in pipeline Sicherstellen das curl und jq installiert sind
               # apt-get update
               # apt-get -y install curl jq
               export BB_TOKEN=$(curl -s -S -f -X POST -u "${BB_AUTH_STRING}" \
                https://bitbucket.org/site/oauth2/access_token \
                -d grant_type=client_credentials -d scopes="repository" | jq --raw-output '.access_token')
               #echo "$BB_TOKEN"

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
                    "title": "merge-resolver-bot/'$BRANCH'",
                    "description": "Der Merge-Resolver Bot hat bei dem automatischen mergen von '$MAIN' nach '$BRANCH' merge-conflicts erkannt. \n \n Bitte löse diese",
                    "source": {
                      "branch": {
                        "name": "'$MAIN'"
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

                  # For Testing only one PR
                  # TODO: GGf. Rate Limit je Repo / global einbauen, damit nicht zu viele PR's pro tag / stunde gespammt werden.
                  #exit 0

            else
               # No Merge Conflict Then commit and push
               git commit -m "merge from $MAIN"
               git push
            fi
        fi
    fi
done
