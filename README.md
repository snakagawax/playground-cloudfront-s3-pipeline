# はじめに

OAC を利用した CloudFront + S3 の Web サイトとデプロイパイプラインを Terarform で構築する。
コンテンツには React アプリケーションを利用する。

# 構成図

<img src="/img/cloudfront_s3_pipeline.png">

# 設定方法

`git clone`でクローン後、`terraform.tfvars`ファイルまたは、`provider.tf`で`prefix`を入力してください。
入力しない場合、`terraform`コマンド時にプロンプトで入力を求められます。

## 手順

- Terraform 実行

```bash
terraform init
terraform apply
```

- git-remote-codecommit をインストール

```bash
python3 -m venv .env
source .env/bin/activate
pip install git-remote-codecommit
```

- React アプリケーションを作成

```bash
npx create-react-app hello-world
cd hello-world
```

- CodeCommit へプッシュ ※ your-prefix の書き換えが必要

```bash
git init
git remote add origin codecommit::ap-northeast-1://<<your-prefix>>-static-hosting-repo
git add .
git commit -m "Initial commit"
git branch -M main
git push -u origin main
```

- CloudFront ディストリビューションのドメイン名に接続して React の画面が出れば OK

## 削除
```bash
# terraformの実行
terraform destroy
```

## 参考

- https://github.com/takakuni-classmethod/s3-pipeline-terraform/tree/main