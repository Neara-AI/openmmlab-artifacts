#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <wheel-dir>"
    exit 1
fi

WHEEL_DIR="$1"

# Requires CUDA toolkit 12.8+ (12.x; torch refuses a different major version) on PATH/CUDA_HOME,
# and libsparsehash-dev for torchsparse.
export FORCE_CUDA=1
# torch 2.7.1+cu128 supports sm_75..sm_120. 12.0 is Blackwell (RTX PRO 6000 / RTX 50xx).
export TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6 9.0 10.0 12.0+PTX"
export TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
export MMCV_WITH_OPS=1

export UV_HTTP_TIMEOUT=300

export venvdir=".venv_$(date +%Y.%m.%d_%H.%M.%S)"

uv venv $venvdir --python=3.10
source $venvdir/bin/activate

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# These pip dependencies need to be adjusted to match polez, especially pytorch.
# setuptools<82: mmcv's setup.py imports pkg_resources, removed in setuptools 82.
# ninja: without it torch compiles extension sources one at a time.
uv pip install pip 'setuptools<82' wheel openmim 'numpy<2.0.0' ninja

# Install Pytorch with pip because uv pip install does not work well.
python -m pip install 'torch==2.7.1' 'torchaudio==2.7.1' 'torchvision==0.22.1' --index-url=https://download.pytorch.org/whl/cu128

# --no-build-isolation: build against the torch installed above, not one pulled into an isolated
# build env (PyPI's default torch is a different CUDA build).
# Build openmmlab wheels
python -m pip wheel --no-deps --no-build-isolation --no-binary=:all: --wheel-dir="$WHEEL_DIR" \
    'git+https://github.com/open-mmlab/mmcv.git@v2.1.0#egg=mmcv' \
    'git+https://github.com/open-mmlab/mmengine.git@v0.10.7#egg=mmengine' \
    'git+https://github.com/open-mmlab/mmdetection.git@v3.2.0#egg=mmdet' \
    'git+https://github.com/open-mmlab/mmdetection3d.git@v1.4.0#egg=mmdet3d' \
    --no-cache-dir

# Build torchsparse wheel
python -m pip wheel --no-deps --no-build-isolation --wheel-dir="$WHEEL_DIR" ${script_dir}/../external/torchsparse/ --no-cache-dir

# Rename all wheels to match the expected file names
python ${script_dir}/modify_wheels.py "$WHEEL_DIR"
