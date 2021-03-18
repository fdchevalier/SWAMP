# SWAMP: Single Worm Analysis of Movement Pipeline

This project aims to quantify movement of single worms in 96-well plates. Other programs exist to perform this task but have often limitations like:
* Not being open source,
* Not working on GNU/Linux,
* Not being supported anymore,
* Not allowing analysis automation,
* Not working with special plates. For instance, plates with inserts have pear-like shape wells which are usually not recognized.

We developed a simple and efficient pipeline to overcome these limitations. This pipeline analyzes videos of plate recorded from below. The analysis involves several steps:
* Individual frames from the video are extracted at a user-defined interval.
* Wells are isolated from each frame using a [CellProfiler](https://cellprofiler.org/) pipeline.
* Wells from consecutive frames are compared to quantify differences and thus estimate worm movement.
* A table of average movement per well is output.
* An analysis is performed by an R script given a plate layout.


## Prerequisites

The pipeline relies on few software dependencies:
* [FFmpeg](https://ffmpeg.org/)
* [ImageMagick](https://imagemagick.org/index.php)
* [Hugin](http://hugin.sourceforge.net/)
* [CellProfiler](https://cellprofiler.org/)
* [R](https://www.r-project.org/)

The R script relies on specific package dependencies:
* [optparse](https://cran.r-project.org/web/packages/optparse/index.html)
* [ggplot2](https://cran.r-project.org/web/packages/ggplot2/index.html)
* [platetools](https://cran.r-project.org/web/packages/platetools/index.html)
* [magrittr](https://cran.r-project.org/web/packages/magrittr/index.html)

These dependencies can be installed manually using your favorite package manager or through a conda environment (recommended but this requires a [conda](https://docs.conda.io/en/latest/) distribution, like [miniconda](https://docs.conda.io/en/latest/miniconda.html)). See the [installation section](#installation) for details about setting up the conda environment.

**Note regarding ImageMagick version**: the version to be installed must be the **version 7** and not the version 6 (or anterior). Algorithm used to compute the fuzz factor has been modified between the two versions. This fuzz factor is used to remove small differences when comparing well images, differences caused by video compression for instance. The change in algorithm makes the movement values slightly different, preventing full reproducibility.


## Files

The files available are:
* `cellprofiler_pipelines`: This folder contains the CellProfiler pipelines.
* `diff_image.sh`: This script computes well image differences to evaluate movement (or noise). This is a dependency of the `script.sh`.
* `quant_mvt.R`: This R script processes the data generated from the per-well comparison. This is a dependency of the `script.sh`.
* `swamp`: The main script which runs the complete pipeline. This script must be used to perform the analysis.

<!-- Details about usage are available in the [documentation](Documentation/xxx.pdf). -->

## Installation

To download the latest version of the files:
```
git clone https://github.com/fdchevalier/swamp
```

A conda environment ensures optimal functionality and reproducibility by installing specific versions of software. If you want to set up the conda environment for this pipeline, execute the following command:
```
conda create env -f .env/env.yml
```

For convenience, the script should be accessible system-wide by either including the folder in your `$PATH` or by moving the swamp folder content in a folder present in your path (e.g. `$HOME/.local/bin/`).

<!-- Details about usage are available in the [documentation](Documentation/xxx.pdf). -->

## Usage

If the conda environment is set up, the environment must be activated using the following command: `conda activate swamp`.

A summary of available options can be displayed using `./swamp -h`.

<!-- Details about usage are available in the [documentation](Documentation/xxx.pdf). -->


## Known bugs and workaround

When using conda environment, two bugs may interfere. An easy fix exists.

If there is a need to run CellProfiler with its graphical interface, you may encounter this error: `ImportError: libwebkitgtk-1.0.so.0: cannot open shared object file: No such file or directory`. This is due to wxPython which was built against the version 1 of libwebkitgtk which is progressively replaced by the version 3 in a lot of distributions. The yaml conda file contains the version 1 of the library (`webkitgtk-cos6-x86_64`, note this is the 64-bit version) but path to it must be included in the `LD_LIBRARY_PATH` environment variable.

Running the swamp pipeline on a HPCC may lead Java to issue an error of execution. This is due to `JAVA_HOME` not being correct. However adding `$JAVA_LD_LIBRARY_PATH` to `LD_LIBRARY_PATH` solves this.

A workaround for solving both problems at the same time is to create a script that will run upon activation of the conda environment to add the necessary paths to the `LD_LIBRARY_PATH` variable. To create the script, execute the code below in a terminal:
```bash
conda activate swamp

cat > $CONDA_PREFIX/etc/conda/activate.d/zz-ld_path.sh <<EOF
#!/bin/bash

export LD_LIBRARY_PATH=\$CONDA_PREFIX/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64/:\${JAVA_LD_LIBRARY_PATH}\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
EOF
```


## License

This project is licensed under the [GPLv3](LICENSE).
