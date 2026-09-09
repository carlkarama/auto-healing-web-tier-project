# Publish the container image

The web tier pulls an already published image. This separate Terraform configuration is only needed to create and manage a publishing repository in your own AWS account. It has its own local state; keep that state and the provider lock file, and do not copy the web-tier state here.

ECR Public is managed in `us-east-1`. Configure your usual AWS credentials with permission to create a public repository and push images, then run from the project root:

```sh
terraform -chdir=registry init
terraform -chdir=registry plan -out=publish-repository.tfplan
terraform -chdir=registry apply publish-repository.tfplan

IMAGE_REPOSITORY=$(terraform -chdir=registry output -raw repository_url)
IMAGE_TAG=nginx-1.30.4-arm64-v1

docker buildx build --platform linux/arm64 --load -t "$IMAGE_REPOSITORY:$IMAGE_TAG" .
tests/container-smoke.sh "$IMAGE_REPOSITORY:$IMAGE_TAG"

aws ecr-public get-login-password --region us-east-1 |
  docker login --username AWS --password-stdin ecr-public.aws.com
docker push "$IMAGE_REPOSITORY:$IMAGE_TAG"
```

Use a new tag for each image revision. Copy the digest printed by `docker push` into the root `container_image` value as `ecr-public.aws.com/<alias>/auto-healing-web-tier@sha256:<digest>`, then run the root Terraform plan. Use the dual-stack `ecr-public.aws.com` endpoint because the VMs have IPv6 internet access.

The default image in the root configuration is already public. Consumers do not need AWS permissions or a Docker login to pull it. Removing a public image still referenced by a deployment would prevent replacement VMs from bootstrapping, so retain versions while any launch template uses them.
