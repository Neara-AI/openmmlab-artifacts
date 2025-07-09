"""Rename all wheel files in a directory to include the current date.

Example:

    # Before: mmcv-2.1.0-cp310-cp310-linux_x86_64.whl
    # After: mmcv-2.1.0.2025.07.09-cp310-cp310-linux_x86_64.whl
    # etc.
    $ python tools/rename_wheels.py wheelhouse

"""

import argparse
import datetime
import pathlib
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "directory", type=str, help="Directory containing the wheel files."
    )
    return parser.parse_args()


def get_pytorch_and_numpy_version():
    import torch
    import numpy

    pytorch_version = torch.__version__.split("+")[0]
    numpy_version = numpy.__version__

    return pytorch_version, numpy_version


def rename_wheels(directory: str | pathlib.Path):
    directory = pathlib.Path(directory)
    if not directory.is_dir():
        raise ValueError(f"{directory} is not a valid directory.")

    today = datetime.date.today().strftime("%Y%m%d")
    for wheel in directory.glob("*.whl"):
        parts = wheel.name.split("-")
        if len(parts) < 2:
            continue

        version = parts[1]
        version = f"{version}.{today}"

        try:
            pytorch_version, numpy_version = get_pytorch_and_numpy_version()

            # Note: Build tag needs to start with a number.
            build_tag = [f"0torch{pytorch_version}numpy{numpy_version}"]
        except ImportError:
            build_tag = []

        new_name = "-".join([parts[0], version] + build_tag + parts[2:])
        new_wheel_path = directory / new_name
        wheel.rename(new_wheel_path)
        logger.info(f"Renamed {wheel.name} to {new_name}")


def main():
    args = parse_args()
    rename_wheels(args.directory)


if __name__ == "__main__":
    main()
