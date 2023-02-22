#!/usr/bin/env bash

AWS_ACCESS_KEY_ID=$(op item get "github-terraform-pipelines GithubActions User credentials" --vault b2b-cloud-infra --fields AWS_ACCESS_KEY_ID)
AWS_SECRET_ACCESS_KEY=$(op item get "github-terraform-pipelines GithubActions User credentials" --vault b2b-cloud-infra --fields AWS_SECRET_ACCESS_KEY)

gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"

echo '{ "build_type": "workflow" }' | gh api -X POST /repos/SandsB2B/$(basename $PWD)/pages --input  -
cat - <<EOF | gh api -X PUT /repos/SandsB2B/$(basename $PWD)/pages --input  -
{ "cname":"$(basename $PWD).docs.infra-area2.com", "https_enforced": true }
EOF
gh api --method POST -H "Accept: application/vnd.github+json" /repos/SandsB2B/$(basename $PWD)/environments/github-pages/deployment-branch-policies -f name='master'
gh api --method POST -H "Accept: application/vnd.github+json" /repos/SandsB2B/$(basename $PWD)/environments/github-pages/deployment-branch-policies -f name='main'
gh api --method POST -H "Accept: application/vnd.github+json" /repos/SandsB2B/$(basename $PWD)/environments/github-pages/deployment-branch-policies -f name='develop'

aws sts get-caller-identity --profile=cloud-services-prod

cp -f bin/change-rr-set.tpl.json bin/change-rr-set.json
sed -i .backup -e "s/REPO_NAME/$(basename $PWD)/g" bin/change-rr-set.json

[ ! -z "$(aws route53 list-resource-record-sets --hosted-zone-id=Z0827901K2W3PZV3XWL1  --profile=cloud-services-prod  --query="@.ResourceRecordSets[?Name == \`$(basename $PWD).docs.infra-area2.com.\`]" --output text)" ] || {
  aws route53 change-resource-record-sets --profile=cloud-services-prod --cli-input-json file://bin/change-rr-set.json;
}
