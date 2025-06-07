# S3バケットを作成します
resource "aws_s3_bucket" "public_bucket" {
  bucket = "${var.infra-basic-settings.name}-public-bucket"

  force_destroy = true
}


# バケットのバージョニング設定
resource "aws_s3_bucket_versioning" "public_bucket_versioning" {
  bucket = aws_s3_bucket.public_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# バケットの暗号化設定
resource "aws_s3_bucket_server_side_encryption_configuration" "public_bucket_encryption" {
  bucket = aws_s3_bucket.public_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# S3バケットのパブリックアクセスブロック設定を無効化します
# これにより、バケットポリシーによるパブリックアクセスが可能になります
# TODO: CF追加後はfalseにする
resource "aws_s3_bucket_public_access_block" "public_bucket_access" {
  bucket = aws_s3_bucket.public_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# バケットポリシーをアタッチして、公開読み取りを許可します
# TODO: CF追加後はPrincipalをCFに限定すること
resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.public_bucket.id

  # public_access_block の設定が完了してからポリシーを適用するように依存関係を設定します
  depends_on = [aws_s3_bucket_public_access_block.public_bucket_access]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*", # すべてのユーザー（任意の人）からのアクセスを許可
        Action    = "s3:GetObject", # オブジェクトの読み取りアクションを許可
        Resource  = "${aws_s3_bucket.public_bucket.arn}/*" # バケット内のすべてのオブジェクトが対象
      }
    ]
  })
}