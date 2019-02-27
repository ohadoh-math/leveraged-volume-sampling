# leveraged-volume-sampling

Leveraged volume sampling university project (submission).

## Purpose
A reproduction of the results set in the [paper](https://arxiv.org/abs/1802.06749) introducing the concept of "*Leveraged Volume Sampling for Linear Regression*".

## Setup
Run [setup.sh](setup.sh) to fetch the datasets and pre-process them for loading.
```bash
$ ./setup.sh
```
The processed datasets are placed in a `downloaded-datasets/` directory and are CSVs where the first column is the expected result and the rest of the columns are the features.

The project was developed on Octave 4.4.1 and, sadly, it seems it's the minimum requirement.
The standard Ubuntu 16.04 repository holds Octave 4.0.0 which is definetly not good enough.
To install Octave 5.0.9 on Ubuntu 16.04, you can run:
```bash
$ ./install-flatpak-octave.sh
```
Though note that this script is untested so it may fail.

## Running the Project
If you have Octave installed then you can just simply run:
```bash
$ ./run.sh
```

Or for extra debug prints (no use hoping that the traces will be too informative but they give a sense of what's going on):
```bash
$ ./run.sh -t
```
[run.sh](run.sh) runs [setup.sh](setup.sh) to download the required data sets and then processes them individually
to produce a graph which will be placed in the `graphs` directory at the root of the project.

## Running the Project Manually on a Dataset
You can run the project manually (perhaps through matlab) by running the file [src/main.m](src/main.m) with the following arguments:
* The first argument is the dataset to process (e.g. `downloaded-datasets/bodyfat`). These can be found in the `downloaded-datasets` directory after running `setup.sh`.
* The second argument is the name of the output graph file (e.g. `graphs/bodyfat.png`).
* The third argument is a comma separated list that describes the sample counts (e.g. `20,30,40,50,60,70`).

To run this with Octave, if you have a pre-installed Octave on your machine, the command sequence would look like this:
```bash
$ # change into the project directory
$ cd leveraged-volume-sampling/
$
$ # download the datasets
$ ./setup.sh
$
$ # create an output directory for the graphs
$ mkdir graphs/
$
$ # run octave-cli which is the command-line Octave interface
$ TRACE_INFO="1" octave-cli -p src/ src/main.m downloaded-datasets/bodyfat graphs/bodyfat.png 20,30,40,50,60,70
```

If you have installed Octave with the [install-flatpak-octave.sh](install-flatpak-octave.sh) script the commands are a little more convoluted:
```bash
$ # change into the project directory
$ cd leveraged-volume-sampling/
$
$ # download the datasets
$ ./setup.sh
$
$ # create an output directory for the graphs
$ mkdir graphs/
$
$ # run octave-cli which is the command-line Octave interface
$ TRACE_INFO="1" flatpak run --branch=stable \
                             --arch=x86_64 \
                             --command=/app/bin/octave-cli \
                             --filesystem=host \
                             org.octave.Octave -p src/ src/main.m downloaded-datasets/bodyfat graphs/bodyfat.png 20,30,40,50,60,70
```

