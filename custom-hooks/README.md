# Helmsman lifecycle hooks

Into this directory you can add custom Helmsman hooks. The directory is in the
`.gitignore` file, so you can add your custom hooks without worrying about
pushing them to the repository.

See examples in the [examples](examples) directory.

You can add custom hooks to the following directories:
`./_common/<LIFECYCLE_EVENT>`
`./<CLOUD_PROVIDER>-<LIFECYCLE_EVENT>`

Where:

- `CLOUD_PROVIDER` depends on the Helmsman DSF you used. For examples:

  - `gke` for `helmsman apply -f helmsman/dsf/gke.yaml`
  - `minikube` for `helmsman apply -f helmsman/dsf/minikube.yaml`

- `LIFECYCLE_EVENT` is the helmsman lifecycle event you want to hook into (e.g. 
  pre-install, post-install, etc).

Currently gke and minikbe DSF exists, so you can add hooks to the following
directories:

- `./custom-hooks/_common/pre-install`
- `./custom-hooks/_common/post-install`
- `./custom-hooks/_common/pre-upgrade`
- `./custom-hooks/_common/post-upgrade`
- `./custom-hooks/_common/pre-delete`
- `./custom-hooks/_common/post-delete`

- `./custom-hooks/gke-pre-install`
- `./custom-hooks/gke-post-install`
- `./custom-hooks/gke-pre-upgrade`
- `./custom-hooks/gke-post-upgrade`
- `./custom-hooks/gke-pre-delete`
- `./custom-hooks/gke-post-delete`

- `./custom-hooks/minikube-pre-install`
- `./custom-hooks/minikube-post-install`
- `./custom-hooks/minikube-pre-upgrade`
- `./custom-hooks/minikube-post-upgrade`
- `./custom-hooks/minikube-pre-delete`
- `./custom-hooks/minikube-post-delete`

The scripts are executed by run-parts, which runs all the scripts in the
directory in lexicographical order.

Additionally, the scripts must conform to the following rules:

- The scripts must be executable.
- The name must consist entirely of ASCII upper- and lower-case letters, 
  ASCII digits, ASCII underscores, and ASCII minus-hyphens.

## Example pre-install hook installing k8s resources

Hooks with CWD set to the running hook directory.

`custom-hooks/gke-pre-install/01-install-k8s-resources.sh`
```bash
#!/bin/bash

kubectl apply -f ./k8s-resources
```

`custom-hooks/gke-pre-install/k8s-resources/pv.yaml`
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv0001
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/tmp/data"
```
