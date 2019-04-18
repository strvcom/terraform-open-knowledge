# infra

This directory holds folders with various infrastructure definitions. To actually do anything with the infrastructure here, you will need to `cd` into one of the directories here and run Terraform from there. Each folder is an isolated set of resources.

This allows developers to manage various "things" separately (ie. one folder to hold some development resources like CodeBuild, CodePipeline or Elastic Container Registry and the other folder to hold everything related to a backend API service, like Elastic Container Service, CloudWatch logs, alarms, SNS topics etc.).
