/*
 * This file defines everything needed to auto-deploy Github commits through
 * CodePipeline + CodeBuild to an S3 + CloudFront hosting.
 */

# A CodePipeline service allows you to perform various tasks with code, and move it through various
# stages. We will use a relatively simple setup - fetch the code from GitHub and hand it over to
# CodeBuild to build & publish the site to S3.
resource "aws_codepipeline" "website" {
  name = "${var.project}-${terraform.workspace}"

  # A role is required to specifcy what this pipeline can do within our AWS account. By default it
  # cannot do anything. We are setting the role up below.
  role_arn = "${aws_iam_role.codepipeline.arn}"

  # CodePipeline requires an "artifact store" to move from one stage to another. In our case, it
  # needs it to hand off the GitHub repo to the build step. We will use an S3 bucket for that.
  artifact_store {
    type     = "S3"
    location = "${aws_s3_bucket.codepipeline.bucket}"
  }

  # This will hook up to the Github repository and fetch the contents on each commit.
  stage {
    name = "source"

    action {
      name             = "github-source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["repo"]

      configuration {
        Owner      = "${var.github_owner}"
        Repo       = "${var.github_repo}"
        Branch     = "${var.github_branch}"
        OAuthToken = "${var.github_token}"
      }
    }
  }

  # This section tells CodePipeline to hand off the repo to CodeBuild and let it build our site.
  stage {
    name = "build"

    action {
      name             = "build-and-deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["repo"]
      output_artifacts = ["bundle"]

      configuration {
        ProjectName = "${aws_codebuild_project.website.name}"
      }
    }
  }
}

resource "aws_s3_bucket" "codepipeline" {
  bucket        = "codepipeline-${var.project}-${terraform.workspace}"
  acl           = "private"
  force_destroy = true
}

# Create a role for CodePipeline so it can interact with other AWS services within our AWS account.
# By default it has no access to anything.
resource "aws_iam_role" "codepipeline" {
  assume_role_policy = "${file("${path.module}/codepipeline-role.json")}"
}

resource "aws_iam_role_policy_attachment" "codepipeline_s3" {
  role       = "${aws_iam_role.codepipeline.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "codepipeline_codebuild" {
  role       = "${aws_iam_role.codepipeline.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess"
}

# CodeBuild is a managed CI/CD service. Let's use it to build our static site and publish it to S3.
resource "aws_codebuild_project" "website" {
  name         = "${var.project}-${terraform.workspace}"
  service_role = "${aws_iam_role.codebuild.arn}"

  # The default timeout is quite long - if our build hangs, terminate it in 15 minutes to save some
  # money.
  build_timeout = "15"

  # The input (Github repo contents) will come from CodePipeline.
  source {
    type = "CODEPIPELINE"
  }

  # The build artifacts are also managed by CodePipeline.
  artifacts {
    type = "CODEPIPELINE"
  }

  # This is the runtime environment in which our build will execute.
  environment {
    type         = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/nodejs:10.14.1-1.7.0"

    # We can inject environment variables into the build container, so that we know where to publish
    # the static content and which CloudFront distribution to invalidate when we publish new
    # versions.
    environment_variable {
      name  = "S3_BUCKET"
      value = "${aws_s3_bucket.content.bucket}"
    }

    environment_variable {
      name  = "CLOUDFRONT_DISTRIBUTION"
      value = "${aws_cloudfront_distribution.content.id}"
    }
  }
}

# A CloudWatch log group to which CodeBuild will publish the build logs.
#
# CodeBuild creates a CloudWatch Log Group where it publishes build logs. This resource is created
# automatically by CodeBuild, but we still want to manage that resource through Terraform, so we
# create it manually.
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${aws_codebuild_project.website.name}"
  retention_in_days = 30
}

# And again, allow CodeBuild to interact with other AWS resources in our account by creating a role.
resource "aws_iam_role" "codebuild" {
  assume_role_policy = "${file("${path.module}/codebuild-role.json")}"
}

resource "aws_iam_role_policy_attachment" "codebuild_s3" {
  role       = "${aws_iam_role.codebuild.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_cloudfront" {
  role       = "${aws_iam_role.codebuild.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudFrontFullAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_cwlogs" {
  role       = "${aws_iam_role.codebuild.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
