# S3バケットへのPut/Deleteを許可するIAMポリシーを作成
resource "aws_iam_policy" "s3_put_delete_policy" {
  name        = "S3PutDeletePolicy-${var.infra-basic-settings.name}-public-bucket"
  description = "Allows Put and Delete access to a specific S3 bucket"

  # ポリシードキュメント
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        # ステートメント1: S3コンソールでバケットリストを表示するために必要
        Sid      = "AllowBucketListing",
        Effect   = "Allow",
        Action   = "s3:ListAllMyBuckets",
        Resource = "*" # このアクションは特定のリソースに限定できないため"*"を指定します
      },
      {
        # ステートメント2: 特定のバケットを開いてオブジェクト一覧を表示・場所を取得するために必要
        Sid      = "AllowBucketAccess",
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = "${var.s3-public-bucket-arn}" # 対象はバケットそのもの
      },  
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "${var.s3-public-bucket-arn}/*"
      }
    ]
  })
}

# 作成したポリシーを既存のIAMユーザーにアタッチ
resource "aws_iam_user_policy_attachment" "s3_put_delete_attachment" {
  user       = "s3-contents-maintenance"
  policy_arn = aws_iam_policy.s3_put_delete_policy.arn
}