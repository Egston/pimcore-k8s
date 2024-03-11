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

## Usage

### 1. Generate .env file with secrets

```shell
./scripts/generate-dotenv.py
```

### 2. Optional: Create custom Helmsman hooks

See [custom-hooks/README.md](custom-hooks/README.md)

Tip: Use pre-install hooks to create Kubernetes resources such as Ingresses,
load balancers or custom PV, PVCs or StorageClasses.

### 3. Run Helmsman with selected DSF

```shell
helmsman -apply -f helmsman/dsf/minikube.yaml
# or
helmsman -apply -f helmsman/dsf/gke.yaml
```
