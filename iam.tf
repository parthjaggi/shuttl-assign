/*=== DATA ===*/

data "aws_iam_policy_document" "ec2_instance" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    actions   = ["s3:*"]
    resources = ["*"]
  }
}


/*=== IAM RESOURCES ===*/

resource "aws_iam_role" "ec2_s3_access" {
  name               = "ec2_s3_access"
  assume_role_policy = "${data.aws_iam_policy_document.ec2_instance.json}"
}

resource "aws_iam_policy" "s3_access" {
  name        = "s3_access"
  description = "S3 Access"
  policy = "${data.aws_iam_policy_document.s3_access.json}"
}

resource "aws_iam_policy_attachment" "ec2_s3_access" {
  name       = "ec2_s3_access"
  roles      = ["${aws_iam_role.ec2_s3_access.name}"]
  policy_arn = "${aws_iam_policy.s3_access.arn}"
}

resource "aws_iam_instance_profile" "ec2_s3_access" {
  name  = "ec2_s3_access"
  role  = "${aws_iam_role.ec2_s3_access.name}"
}