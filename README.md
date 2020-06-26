This project aims to quantify movement of single worms in 96-well plates. Other programs exist to perform this task but have often limitations like:
* Not being open source,
* Not working on GNU/Linux,
* Not being supported anymore,
* Not working with special plates. For instance, plates with inserts have pear-like shape wells which are usually not recognize.

Plates are analyzed by two [CellProfiler](https://cellprofiler.org/) pipelines:
* Single Worm Output: This pipeline identifies wells and isolate worms in them for a given video frame
* Single Worm RandIndex: This pipeline analyzes the change in pixel for each isolated worms between two frames.

The input needed for the first pipeline is a series of frame extracted at regular interval from a video recording of a plate. Frames can be extracted with a tool like `ffmpeg`. The second pipeline will then use the output of the first pipeline to generate a data table of quantified movement.
