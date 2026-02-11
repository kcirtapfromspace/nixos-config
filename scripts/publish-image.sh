#!/usr/bin/env bash
set -euo pipefail

REGISTRY_PUSH="${REGISTRY_PUSH:-localhost:5001}"
IMAGE_NAME=""
IMAGE_TAG=""
PLATFORM="${PLATFORM:-linux/arm64}"
DOCKERFILE="Dockerfile"
CONTEXT="."
PUSH_IMAGES=true
PUBLISH_LATEST=false

usage() {
  cat <<USAGE
Usage: ./scripts/publish-image.sh [options]

Options:
  --image <repo/name>      Image name under registry (required)
  --tag <tag>              Tag to publish (default: git short sha or timestamp)
  --registry <host:port>   Registry endpoint (default: REGISTRY_PUSH or localhost:5001)
  --platform <platform>    Build platform (default: linux/arm64)
  --dockerfile <path>      Dockerfile path (default: Dockerfile)
  --context <path>         Build context (default: .)
  --no-push                Build locally with --load (no registry push)
  --latest                 Publish an extra :latest tag
  --help                   Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      IMAGE_NAME="${2:?missing value for --image}"
      shift 2
      ;;
    --tag)
      IMAGE_TAG="${2:?missing value for --tag}"
      shift 2
      ;;
    --registry)
      REGISTRY_PUSH="${2:?missing value for --registry}"
      shift 2
      ;;
    --platform)
      PLATFORM="${2:?missing value for --platform}"
      shift 2
      ;;
    --dockerfile)
      DOCKERFILE="${2:?missing value for --dockerfile}"
      shift 2
      ;;
    --context)
      CONTEXT="${2:?missing value for --context}"
      shift 2
      ;;
    --no-push)
      PUSH_IMAGES=false
      shift
      ;;
    --latest)
      PUBLISH_LATEST=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$IMAGE_NAME" ]]; then
  echo "--image is required" >&2
  usage
  exit 1
fi

if [[ -z "$IMAGE_TAG" ]]; then
  if git rev-parse --git-dir >/dev/null 2>&1; then
    IMAGE_TAG="$(git rev-parse --short HEAD)"
  else
    IMAGE_TAG="$(date +%Y%m%d%H%M%S)"
  fi
fi

primary_ref="${REGISTRY_PUSH}/${IMAGE_NAME}:${IMAGE_TAG}"
tags=("-t" "$primary_ref")

if [[ "$PUBLISH_LATEST" == "true" ]]; then
  tags+=("-t" "${REGISTRY_PUSH}/${IMAGE_NAME}:latest")
fi

echo "registry: ${REGISTRY_PUSH}"
echo "image:    ${IMAGE_NAME}"
echo "tag:      ${IMAGE_TAG}"
echo "platform: ${PLATFORM}"
echo "push:     ${PUSH_IMAGES}"
echo "context:  ${CONTEXT}"
echo "file:     ${DOCKERFILE}"

if [[ "$PUSH_IMAGES" == "true" ]]; then
  docker buildx build \
    --platform "$PLATFORM" \
    -f "$DOCKERFILE" \
    "${tags[@]}" \
    --push \
    "$CONTEXT"
else
  docker buildx build \
    --platform "$PLATFORM" \
    -f "$DOCKERFILE" \
    "${tags[@]}" \
    --load \
    "$CONTEXT"
fi

echo "published: ${primary_ref}"
if [[ "$PUBLISH_LATEST" == "true" ]]; then
  echo "published: ${REGISTRY_PUSH}/${IMAGE_NAME}:latest"
fi
