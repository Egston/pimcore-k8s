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

### 1. Generate .env file with env. variables and secrets

```shell
./scripts/generate-dotenv.py
```

Good idea is to keep the `.env` file in a secure location. You can use
Google Cloud Secrets Manager to store and retrieve the secrets securely.

```shell
gcloud secrets create your-env-secret-name --data-file=.env
```

You can add other env. variables used by Helmsman DSF to the `.env` file.

```shell
  echo 'GKE_KUBE_CONTEXT="..."' >> .env
```

#### Add custom env. variables to deployments

You can add custom env. variables to the `.env` file and use them in k8s Secret
included in deployments:

```shell
  echo 'GOOGLE_TRANSLATE_API_KEY="..."' >> .env
```

Edit your custom DSF file:

```yaml
apps:
  pimcore:
    set:
      pimcore.customEnvVars[0].name: "GOOGLE_TRANSLATE_API_KEY"
      pimcore.customEnvVars[0].value: "$GOOGLE_TRANSLATE_API_KEY"
      # ...
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

# or copy and edit the DSF file and invoke it instead the upstream one
# (don't forget to update paths in the DSF copy)
```

## Maintenance Shell

There is a maintenance shell deployment by default called
`pimcore-maintenance-shell` having 0 replicas initially. You can scale
it to 1 to run maintenance commands.

```shell
kubectl scale deployment/pimcore-maintenance-shell --replicas=1
kubectl exec -it deployment/pimcore-maintenance-shell -- bash

cd /var/www/pimcore
bin/console ...
logout

kubectl scale deployment/pimcore-maintenance-shell --replicas=0
```

### Maintenance Shell useful scripts

The pimcore-maintenance-shell deployment has some usefull scripts prefixed with `maint-` that you
can invoke directly:

- maint-shell - starts an interactive bash shell
- maint-cache-reset - resets Pimcore cache
- maint-graphql-cache-reset - resets Pimcore GraphQL cache
- maint-db-import - imports a database dump
- maint-help - shows detailed help about available scripts

Usage example:

```shell
kubectl exec -it deployment/pimcore-maintenance-shell -- maint-cache-reset
```

### Maintenance Shell wrapper script

There is a wrapper script `scripts/maintenance-shell.sh` that simplifies the usage of the
maintenance shell:

```shell
./scripts/maintenance-shell.sh --help

```

## Initialize data PVC form an existing Git repository instead of creating an empty Pimcore project skeleton

Instead of running `composer create-project` during the installation, you can initialize the data
PVC from an existing Git repository containing a Pimcore project.
This is useful if you have a pre-configured Pimcore project that you want to deploy.

Modify your DSF file to use the `pvc.data.initFromRepo`:

```yaml
apps:
  pimcore:
      pvc.data.initFromRepo.enabled: true
      pvc.data.initFromRepo.gitRepositoryUrl: "https://dev.azure.com/your-org/your-project/_git/your-repo" # or any other Git repository URL
      pvc.data.initFromRepo.gitUsername: "git" # does not matter when PAT is used, just cannot be empty
      pvc.data.initFromRepo.gitPersonalAccessToken: "$PIMCORE_INIT_REPO_GIT_TOKEN"
```
And put your Personal Access Token into the `.env` file:

```ini
PIMCORE_INIT_REPO_GIT_TOKEN="..."
```

If you don't specify `gitPersonalAccessToken`, the repository must be public.

## Setting up Minikube

```shell
# Set the CPUs and memory limits as desired.
minikube start --cni=flannel --driver=docker --cpus=no-limit --memory=no-limit
```
