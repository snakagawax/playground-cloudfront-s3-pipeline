####################################
# CodeCommit Repository
####################################
resource "aws_codecommit_repository" "static_hosting" {
  repository_name = "${var.prefix}-static-hosting-repo"
  default_branch  = "main"
}

####################################
# CodePipeline
####################################
data "aws_iam_policy_document" "assume_codepipeline" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "policy_codepipeline" {
  version = "2012-10-17"

  statement {
    sid    = "CodeCommit"
    effect = "Allow"
    actions = [
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetRepository",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive"
    ]
    resources = [aws_codecommit_repository.static_hosting.arn]
  }

  # S3への読み書き
  # https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/reference_policies_examples_s3_rw-bucket.html
  statement {
    sid     = "ListObjectsInBucket"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.static_hosting.arn,
      aws_s3_bucket.static_hosting_artifact.arn,
    ]
  }

  statement {
    sid     = "AllObjectActions"
    effect  = "Allow"
    actions = ["s3:*Object"]
    resources = [
      "${aws_s3_bucket.static_hosting.arn}/*",
      "${aws_s3_bucket.static_hosting_artifact.arn}/*",
    ]
  }

  statement {
    sid    = "KMS"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    resources = [
      aws_kms_key.static_hosting.arn,
      aws_kms_key.static_hosting_artifact.arn,
    ]
  }

  # CodeBuildのStartBuildアクションを許可
  statement {
    sid    = "CodeBuild"
    effect = "Allow"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds"
    ]
    resources = [
      aws_codebuild_project.static_hosting.arn
    ]
  }

  # CloudWatchを許可
  statement {
    sid    = "CloudWatch"
    effect = "Allow"
    actions = [
      "cloudwatch:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "codepipeline_static_hosting" {
  name               = "${var.prefix}-codepipeline-static-hosting"
  assume_role_policy = data.aws_iam_policy_document.assume_codepipeline.json
}

resource "aws_iam_policy" "codepipeline_static_hosting" {
  name   = "${var.prefix}-codepipeline-static-hosting"
  policy = data.aws_iam_policy_document.policy_codepipeline.json
}

resource "aws_iam_role_policy_attachment" "codepipeline_static_hosting" {
  role       = aws_iam_role.codepipeline_static_hosting.name
  policy_arn = aws_iam_policy.codepipeline_static_hosting.arn
}

####################################
# CodeBuild Project
####################################
data "local_file" "buildspec" {
  filename = "${path.module}/codebuild/buildspec.yml"
}

resource "aws_codebuild_project" "static_hosting" {
  name          = "${var.prefix}-static-hosting-build"
  description   = "Build project for static hosting"
  build_timeout = "5"

  source {
    type      = "CODEPIPELINE"
    buildspec = data.local_file.buildspec.content
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_MEDIUM"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "ENV"
      value = "dev"
    }
  }

  service_role = aws_iam_role.codebuild_static_hosting.arn
}

####################################
# CodeBuild Role
####################################
data "aws_iam_policy_document" "assume_codebuild" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "policy_codebuild" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "codebuild_static_hosting" {
  name               = "${var.prefix}-codebuild-static-hosting"
  assume_role_policy = data.aws_iam_policy_document.assume_codebuild.json
}

resource "aws_iam_policy" "codebuild_static_hosting" {
  name   = "${var.prefix}-codebuild-static-hosting"
  policy = data.aws_iam_policy_document.policy_codebuild.json
}

resource "aws_iam_role_policy_attachment" "codebuild_static_hosting" {
  role       = aws_iam_role.codebuild_static_hosting.name
  policy_arn = aws_iam_policy.codebuild_static_hosting.arn
}

####################################
# CodePipeline
####################################
resource "aws_codepipeline" "static_hosting" {
  name     = "${var.prefix}-static-hosting"
  role_arn = aws_iam_role.codepipeline_static_hosting.arn

  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.static_hosting_artifact.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = 1
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName       = aws_codecommit_repository.static_hosting.repository_name
        BranchName           = aws_codecommit_repository.static_hosting.default_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
      run_order = 1
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = 1
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.static_hosting.name
      }
      run_order = 1
    }
  }

  stage {
    name = "Deploy"
    action {
      name     = "Deploy"
      category = "Deploy"
      owner    = "AWS"
      provider = "S3"
      version  = 1
      configuration = {
        BucketName = aws_s3_bucket.static_hosting.bucket
        Extract    = "true"
      }
      input_artifacts = ["build_output"]
      run_order       = 1
    }
  }
}
