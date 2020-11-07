# SWAMP: Single Worm Analysis of Movement Pipeline

This project aims to quantify movement of single worms in 96-well plates. Other programs exist to perform this task but have often limitations like:
* Not being open source,
* Not working on GNU/Linux,
* Not being supported anymore,
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

These dependencies can be installed manually. Alternatively, they can be installed through a conda environment (recommended but requiring a [conda](https://docs.conda.io/en/latest/) distribution, like [miniconda](https://docs.conda.io/en/latest/miniconda.html)) using the following command:
```
conda create env -f .env/env.yml
```

**N.B.**: The conda yml file installs only CellProfiler and ffmpeg for now. This will be improved in a near future.


## Files

The files available are:
* `cellprofiler_pipelines`: This folder contains the CellProfiler pipelines.
* `best-grid.sh`: This script performs tests to find the best threshold to draw the expected grid. This script can be used if the default settings of the main script does not work.
* `diff_image.sh`: This script computes well image differences to evaluate movement (or noise). This is a dependency of the `script.sh`.
* `quant_mvt.R`: This R script processes the data generated from the per-well comparison. This is a dependency of the `script.sh`.
* `script.sh`: The main script which runs the complete pipeline. This script must be used to perform the analysis.

<!-- Details about usage are available in the [documentation](Documentation/xxx.pdf). -->

## Installation

To download the latest version of the files:
```
git clone https://github.com/fdchevalier/swamp
```

For convenience, the script should be accessible system-wide by either including the folder in your `$PATH` or by moving the swamp folder content in a folder present in your path (e.g. `$HOME/.local/bin/`).

<!-- Details about usage are available in the [documentation](Documentation/xxx.pdf). -->

## Usage

A summary of available options can be displayed using `./script.sh -h`.

<!-- Details about usage are available in the [documentation](Documentation/xxx.pdf). -->

## License

This project is licensed under the [GPLv3](LICENSE).
