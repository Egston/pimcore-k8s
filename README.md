# Pimcore Helm Chart and Helmsman DSF for minikube and GKE

## Acknowledgments

This project is in its early stages and might not yet be
production-ready. I needed a way to deploy Pimcore on Kubernetes and
didn't find any existing projects that suited my needs. This is the
result, enabling the deployment of Pimcore on Minikube or GKE.

Please be aware that prior to this project, I had no experience with
Kubernetes and Helm. Therefore, I strongly encourage you to review the
code and consider this context when making your decision to use this
project. Your insights and contributions to improve its reliability and
performance are highly welcome.

This project is heavily inspired by and based on
[DivanteLtd/pimcore-helm-chart][1] developed by Bruno Ramalho. I am
grateful for his contributions to the open-source community and his
work, which laid the groundwork for this fork.
  
  [1]: https://github.com/DivanteLtd/pimcore-helm-chart

## Basic usage

### 1. Generate .env file with secrets

```shell
./scripts/generate-dotenv.py
```

### 2. Optional: Create custom Helmsman hooks

See the [custom-hooks/README.md](custom-hooks/README.md) and examples
in the [custom-hooks/examples](custom-hooks/examples) directory.

Tip: Use pre-install hooks to create Kubernetes resources such as Ingresses,
load balancers or custom PV, PVCs or StorageClasses.

By default hooks are read from the `custom-hooks` directory. You can override
this by setting the `HELMSMAN_CUSTOM_HOOKS_DIR` environment variable.

### 3. Run Helmsman with selected DSF

```shell
helmsman -apply -f helmsman/dsf/minikube.yaml
# or
helmsman -apply -f helmsman/dsf/gke.yaml
```

## Using as a submodule in your private repository

You can use this repository as a submodule in your private repository.
You can set HELMSMAN_CUSTOM_HOOKS_DIR env. variable to absolute path of
you custom hooks directory.

Example for GKE:

```shell
git init .
git submodule add https://github.com/Egston/pimcore-k8s.git pimcore-k8s

cp -r pimcore-k8s/custom-hooks/examples/ custom-hooks/
# edit custom-hooks/gke-*/

./pimcore-k8s/scripts/generate-dotenv.py
echo 'GKE_KUBE_CONTEXT="..."' >> .env
gcloud secrets create your-env-secret-name --data-file=.env
# retrieve by: (umask 0077; gcloud secrets versions access latest --secret="your-env-secret-name" > .env)

export HELMSMAN_CUSTOM_HOOKS_DIR="$PWD/custom-hooks/"
helmsman -apply -f pimcore-k8s/helmsman/dsf/gke.yaml
```
