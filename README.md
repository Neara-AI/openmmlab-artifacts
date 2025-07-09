# OpenMMLab Artifacts

## Quickstart

### Build Wheel Files

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
