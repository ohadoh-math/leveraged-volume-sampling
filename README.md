# leveraged-volume-sampling

Leveraged volume sampling university project (submission).

## Purpose
A reproduction of the results set in the [paper](https://arxiv.org/abs/1802.06749) introducing the concept of "*Leveraged Volume Sampling for Linear Regression*".

## Setup
Run [setup.sh](setup.sh) to fetch the datasets and pre-process them for loading.
```bash
./setup.sh
```

The processed datasets are placed in a `.data/` directory and are CSVs where the first column is the expected result and the rest of the columns are the features.

