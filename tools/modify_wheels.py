"""Modify all wheel files in a directory to include the current date.

This script renames all wheel files in the specified directory to include
the current date in the format YYYYMMDD. It also appends the PyTorch and
NumPy versions to the wheel file name.

To keep the wheel files valid, it modifies the content of the wheel
files in place, updating the .dist-info directory and the METADATA file.

Example:

    # Before: mmcv-2.1.0-cp310-cp310-linux_x86_64.whl
    # After: mmcv-2.1.0.20250709-0torch2.4.1numpy1.26.4-cp310-cp310-linux_x86_64.whl
    # etc.
    $ python tools/modify_wheels.py wheelhouse

"""

import argparse
import datetime
import logging
import os
import pathlib
import shutil
import tempfile
import zipfile

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


def get_pytorch_and_numpy_version() -> tuple[str, str]:
    """Gets the PyTorch and NumPy versions.

    Returns:
        (pytorch_version, numpy_version)
    """
    import numpy
    import torch

    pytorch_version = torch.__version__.split("+")[0]
    numpy_version = numpy.__version__

    return pytorch_version, numpy_version


def modify_wheel_content_inplace(wheel_path: str | pathlib.Path, version: str) -> None:
    """Modifies the content of a wheel file in place.

    There are two main modifications:
      - Rename the .dist-info/ directory to include the version.
      - Modify the METADATA file in the .dist-info/ directory to update the
        Version field.

    Args:
        wheel_path: Path to the wheel file.
        version: The version to set in the wheel file.

    Returns:
        None. The wheel file is modified in place.
    """

    wheel_path = pathlib.Path(wheel_path)

    with tempfile.TemporaryDirectory() as temp_dir:
        # copy the wheel file to a temporary directory
        temp_dir = pathlib.Path(temp_dir)
        temp_wheel = temp_dir / wheel_path.name

        parts = wheel_path.name.split("-")

        shutil.copy(wheel_path, temp_wheel)

        with zipfile.ZipFile(temp_wheel, "r") as zip_ref:
            zip_ref.extractall(temp_wheel.parent)

        dist_info_dir = list(temp_dir.glob("*.dist-info"))[0]

        # Rename dist-info directory.
        new_dist_info_dir = temp_dir / f"{parts[0]}-{version}.dist-info"
        dist_info_dir.rename(new_dist_info_dir)
        dist_info_dir = new_dist_info_dir

        # Modify METADATA file.
        metadata_file = dist_info_dir / "METADATA"
        new_metadata_content = []
        with metadata_file.open("r") as f:
            metadata_content = f.read()
            for line in metadata_content.splitlines():
                if line.startswith("Version:"):
                    line = f"Version: {version}"
                new_metadata_content.append(line)
        with metadata_file.open("w") as f:
            f.write("\n".join(new_metadata_content))

        # zip temp_dir as wheel_path.name
        new_wheel_path = temp_wheel
        with zipfile.ZipFile(new_wheel_path, "w") as zip_ref:
            for foldername, subfolders, filenames in os.walk(temp_dir):
                # skip if self
                for filename in filenames:
                    if foldername == str(temp_dir) and filename == new_wheel_path.name:
                        continue
                    file_path = pathlib.Path(foldername) / filename
                    zip_ref.write(file_path, file_path.relative_to(temp_dir))

        # move the new wheel file to the original wheel_path
        shutil.move(new_wheel_path, wheel_path)


def modify_wheels(directory: str | pathlib.Path) -> None:
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

        # Rename
        wheel.rename(new_wheel_path)

        # Modify content
        modify_wheel_content_inplace(new_wheel_path, version)

        logger.info(f"Modified {wheel.name} to {new_name}")


def main():
    args = parse_args()
    modify_wheels(args.directory)


if __name__ == "__main__":
    main()
