# bitbucket-auto-merge

## What is does 

Since there is no such feature for automatic branch merging in bitbucket cloud, i decided to script it myself.

The Script `auto-merge.sh` uses git and plain Shell commands and also the bitbucket cloud api.

In order to get it working, you need to create a OAuth Consumer see below.

## How it doese it

1. In the `bitbucket-pipelines.yml` Auto Merge Step definition, it defines to clone the full repo
2. Install `curl` and `jq` in order to work and starts the `auto-mege.sh` Script located int the repository itself
3. The `auto-mege.sh` Script checksout the main/master branch and gets all existing branches
4. Then it iterates over all branches
5. and checks with `git log` if the branch is ahead and behind at least one commit
6. then tries to merge main into the branch without commit and checks if there where any merge conflicts
7. if not it commits and pushes the changes
8. if yes 


# Links

- https://jswenski.medium.com/nearly-automatic-branch-merging-with-bitbucket-cloud-5d34f41b0311
- https://dev.to/clickpesa/automating-pull-request-creation-from-one-branch-to-another-using-javascript-bitbucket-pipelines-and-bitbucket-api-3ijh
- https://jira.atlassian.com/browse/BCLOUD-14286

