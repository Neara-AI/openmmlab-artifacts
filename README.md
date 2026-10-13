# OpenMMLab Artifacts

## Quickstart

### Build Wheel Files

Prerequisites: CUDA toolkit 12.8 or newer 12.x on `PATH` with `CUDA_HOME` set (torch 2.7.1+cu128
refuses to build extensions with CUDA 13), and `libsparsehash-dev` for torchsparse.

To build the wheel files:

```sh
# Outputs are stored as wheelhouse/*whl
./tools/build_wheels.sh wheelhouse
```

### Add Wheel Files to Release

See the following guide.

https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository

## Torchsparse

The torchsparse module was cloned from https://github.com/mit-han-lab/torchsparse/tree/v1.4.0

And the patch `external/torchsparse.patch` is applied.
