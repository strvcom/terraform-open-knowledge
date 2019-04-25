variable "project" {
  default     = "website"
  description = "A unique name for your project. This will be used for the resources created on AWS to identify this deployment."
}

variable "github_owner" {
  description = "Owner of the Github repository where the source code is hosted"
}

variable "github_repo" {
  description = "Repository where the source code is hosted"
}

variable "github_branch" {
  description = "Branch from which to deploy changes"
  default     = "master"
}

variable "github_token" {
  description = "Github token used to authenticate with Github"
}
