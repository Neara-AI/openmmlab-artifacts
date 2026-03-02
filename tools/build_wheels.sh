#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <wheel-dir>"
    exit 1
fi

WHEEL_DIR="$1"

export FORCE_CUDA=1
export TORCH_CUDA_ARCH_LIST="6.0 6.1 7.0 7.5 8.0 8.6+PTX 9.0"
export TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
export MMCV_WITH_OPS=1

export UV_HTTP_TIMEOUT=300

export venvdir=".venv_$(date +%Y.%m.%d_%H.%M.%S)"

uv venv $venvdir --python=3.12
source $venvdir/bin/activate

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# These pip dependencies need to be adjusted to match polez, especially pytorch.
# Pin setuptools<70 because mmcv's setup.py imports pkg_resources which was
# removed in setuptools 70+. We also use --no-build-isolation below so that
# the build picks up this pinned version.
uv pip install pip 'setuptools<70' wheel openmim 'numpy<2.0.0'

# Install Pytorch with pip because uv pip install does not work well.
python -m pip install 'torch==2.5.1' torchaudio torchvision --index-url=https://pypi.org/simple --extra-index-url=https://download.pytorch.org/whl/cu124

# Build openmmlab wheels.
# --no-build-isolation: use the venv's pinned setuptools (with pkg_resources)
# instead of letting pip install the latest setuptools in an isolated env.
python -m pip wheel --no-deps --no-binary=:all: --no-build-isolation --wheel-dir="$WHEEL_DIR" \
    'git+https://github.com/open-mmlab/mmcv.git@v2.1.0#egg=mmcv' \
    'git+https://github.com/open-mmlab/mmengine.git@v0.10.7#egg=mmengine' \
    'git+https://github.com/open-mmlab/mmdetection.git@v3.2.0#egg=mmdet' \
    'git+https://github.com/open-mmlab/mmdetection3d.git@v1.4.0#egg=mmdet3d' \
    --no-cache-dir

# Build torchsparse wheel
python -m pip wheel --no-deps --wheel-dir="$WHEEL_DIR" ${script_dir}/../external/torchsparse/ --no-cache-dir

# Rename all wheels to match the expected file names
python ${script_dir}/modify_wheels.py "$WHEEL_DIR"
