/* 
* Policy restricted to zone created in the code 
* if want to manage all zones via external-dns
* Use policy in ../policies/external_dns_policy.json
*/

data "aws_iam_policy_document" "external_dns" {
  statement {
    sid    = "externalDnsChange"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = [
      "${aws_route53_zone.internet_alb.arn}",
    ]
  }

  statement {
    sid    = "externalDnsList"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
    ]

    resources = [
      "${aws_route53_zone.internet_alb.arn}",
    ]
  }
}

# ALB Policy JSON
resource "aws_iam_policy" "external_dns" {
  name   = "${local.tags["github_repo"]}-eks-external-dns"
  path   = "/"
  policy = data.aws_iam_policy_document.external_dns.json
}

#####################################
# IRSA IAM policy for ALB ingress controller
#####################################

data "aws_iam_policy_document" "irsa_external_dns_trust_policy_doc" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type = "Federated"
      identifiers = [
        data.aws_iam_openid_connect_provider.alb_example.arn
      ]
    }
    condition {
      test = "StringEquals"
      # this needs to be obtained automatically
      variable = "${data.aws_iam_openid_connect_provider.alb_example.url}:sub"
      ## service account location in kubernetes terminology. "system:serviceaccount:<namespace>:<service_account_name>
      values = [
        "system:serviceaccount:default:external-dns"
      ]
    }
    condition {
      test = "StringEquals"
      # this needs to be obtained automatically
      variable = "${data.aws_iam_openid_connect_provider.alb_example.url}:aud"
      values = [
        "sts.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${local.tags["github_repo"]}-external-dns-ServiceAccount-Role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.irsa_external_dns_trust_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}
