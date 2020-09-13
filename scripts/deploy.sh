#!/bin/sh

set -e

if [[ -z "${AWS_S3_BUCKET}" ]]; then
  echo "Error: please set AWS_S3_BUCKET"
  exit 1
fi

if [[ -z "${AWS_DISTRIBUTION_ID}" ]]; then
  echo "Error: please set AWS_DISTRIBUTION_ID"
  exit 1
fi

aws s3 sync build/ s3://$AWS_S3_BUCKET \
  --delete

aws cloudfront create-invalidation --distribution-id $AWS_DISTRIBUTION_ID --paths "/*"
