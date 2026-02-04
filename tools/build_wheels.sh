#!/bin/bash

set -e

if [ $# -ne 4 ]; then
    echo "Usage: $0 <wheel-dir> <python-version> <torch-version> <cuda-version>"
    exit 1
fi

WHEEL_DIR="$1"
PYTHON_VERSION="$2"
TORCH_VERSION="$3"
CUDA_VERSION="$4"

export FORCE_CUDA=1
export TORCH_CUDA_ARCH_LIST="8.6+PTX 9.0"
# export TORCH_CUDA_ARCH_LIST="6.0 6.1 7.0 7.5 8.0 8.6+PTX 9.0"
export TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
export MMCV_WITH_OPS=1

export UV_HTTP_TIMEOUT=300

export venvdir=".venv_cp${PYTHON_VERSION}_torch${TORCH_VERSION}_cu${CUDA_VERSION}"
# export venvdir=".venv_$(date +%Y.%m.%d_%H.%M.%S)"

uv venv $venvdir --python=${PYTHON_VERSION} --allow-existing
source $venvdir/bin/activate

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# These pip dependencies need to be adjusted to match polez, especially pytorch.
uv pip install pip setuptools wheel openmim numpy change-wheel-version

uv pip install "torch==${TORCH_VERSION}" torchaudio torchvision --index-url=https://pypi.org/simple --extra-index-url=https://download.pytorch.org/whl/cu${CUDA_VERSION} --index-strategy unsafe-best-match

# Build openmmlab wheels
packages=(
    'git+https://github.com/open-mmlab/mmcv.git@v2.1.0#egg=mmcv'
    'git+https://github.com/open-mmlab/mmengine.git@v0.10.7#egg=mmengine'
    'git+https://github.com/open-mmlab/mmdetection.git@v3.2.0#egg=mmdet'
    'git+https://github.com/open-mmlab/mmdetection3d.git@v1.4.0#egg=mmdet3d'
)

for package in "${packages[@]}";  do
  JOBS=$(nproc) MAX_CONCURRENCY=$(nproc) uv run python -m pip wheel --no-deps --no-build-isolation --no-binary=:all: --wheel-dir="$WHEEL_DIR" "${package}"
done

# Build torchsparse wheel
# uv run python -m pip wheel --no-deps --wheel-dir="$WHEEL_DIR" ${script_dir}/../external/torchsparse/ --no-cache-dir

# Change local version
TAG="cp${PYTHON_VERSION/[.]/}"
for wheel in dist/*none-any.whl; do
  echo "Versioning ${wheel}"
  uv run change_wheel_version --delete-old-wheel --local-version "cu${CUDA_VERSION}.torch${TORCH_VERSION}" "$wheel"
done

for wheel in dist/*none-any.whl; do
  echo "Tagging ${wheel}"
  uv run python -m wheel tags --remove --platform-tag linux_x86_64 --abi-tag $TAG --python-tag $TAG "$wheel"
done
