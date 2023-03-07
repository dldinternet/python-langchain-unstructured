#!/usr/bin/env bash

if op item get "${ITEM} GithubActions User credentials" --vault ${VAULT} --fields AWS_ACCESS_KEY_ID ; then
  AWS_ACCESS_KEY_ID=$(op item get "${ITEM} GithubActions User credentials" --vault ${VAULT} --fields AWS_ACCESS_KEY_ID)
  AWS_SECRET_ACCESS_KEY=$(op item get "${ITEM} GithubActions User credentials" --vault ${VAULT} --fields AWS_SECRET_ACCESS_KEY)

  gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
  gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"

  echo '{ "build_type": "workflow" }' | gh api -X POST /repos/${ORGANIZATION}/$(basename $PWD)/pages --input  -
  cat - <<EOF | gh api -X PUT /repos/${ORGANIZATION}/$(basename $PWD)/pages --input  -
{ "cname":"$(basename $PWD).docs.dldinternet.com", "https_enforced": true }
EOF
  gh api --method POST -H "Accept: application/vnd.github+json" /repos/${ORGANIZATION}/$(basename $PWD)/environments/github-pages/deployment-branch-policies -f name='master'
  gh api --method POST -H "Accept: application/vnd.github+json" /repos/${ORGANIZATION}/$(basename $PWD)/environments/github-pages/deployment-branch-policies -f name='main'
  gh api --method POST -H "Accept: application/vnd.github+json" /repos/${ORGANIZATION}/$(basename $PWD)/environments/github-pages/deployment-branch-policies -f name='develop'

  aws sts get-caller-identity --profile=${AWS_PROFILE}

  cp -f bin/change-rr-set.tpl.json bin/change-rr-set.json
  sed -i .backup -e "s/REPO_NAME/$(basename $PWD)/g" bin/change-rr-set.json

  [ ! -z "$(aws route53 list-resource-record-sets --hosted-zone-id=${HOSTED_ZONE_ID}  --profile=${AWS_PROFILE}  --query="@.ResourceRecordSets[?Name == \`$(basename $PWD).docs.dldinternet.com.\`]" --output text)" ] || {
    aws route53 change-resource-record-sets --profile=${AWS_PROFILE} --cli-input-json file://bin/change-rr-set.json;
  }
else
  echo "You need to install the 1Password CLI and login to the ${VAULT} vault"
fi
