terraform {
  required_version = "~> 0.11.13"
}

# Make sure you have a "playground" profile set up in your ~/.aws/credentials file.
# See AWS docs for details about profiles:
#
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html
provider "aws" {
  version = "~> 2.6"
  profile = "playground"
  region  = "eu-west-1"
}
