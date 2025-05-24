# mdai-labs
A repository full of reference solutions for getting started with MDAI.
```

### Makefile Usage

There is a Makefile for deploying MDAI stack with Kind, Helm, and K8s configs.

Run `make` and all the pre-requisites will be installed.

You can optionally run individual steps to perform more targeted actions:
* Create cluster - `make cluster`
* Deploy MDAI Hub - `make mdai-deploy`
* Clean the environment - `make clean`

