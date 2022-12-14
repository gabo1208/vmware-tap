#!/usr/bin/env bash

# Aux function to poke tap controller
poke_tap() {
  kubectl label pkgi tap poke=yes -n tap-install
}

tanzu_network_info() { # args: info template pkg name
  echo -e "Starting $1 installation (Linus, WSL 2, Mac OS only)\n"
  echo "Remember to config and set the proper K8s Cluster context with: kubectl config set-context \${YOUR_CLUSTER_CONTEXT}"
  echo "Make sure you have a https://network.tanzu.vmware.com/ account"
  echo "First accept the EULAs https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install-tanzu-cli.html"
  echo -e "Please visit https://network.pivotal.io/products/tanzu-application-platform#/releases/1205491 to check all the available resources for Tanzu\n"
}

# Install Tanzu CLI
install_tanzu_cli() {
  echo -e "DIY instructions for installing Tanzu CLI: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install-tanzu-cli.html#install-or-update-the-tanzu-cli-and-plugins-3
Download the Tanzu CLI binaries from:
  https://network.pivotal.io/products/tanzu-application-platform#/releases/1205491/file_groups/10484
Rename it to 'tanzu-cli.tar' and save it to this directory.
Press any key to continue.
"
  read null
  echo -e "Extracting and installing...\n"
  mkdir -p $HOME/tanzu
  tar -xvf tanzu-cli.tar -C $HOME/tanzu
  sudo install $HOME/tanzu/cli/core/v*/tanzu-core-* /usr/local/bin/tanzu
  echo -e "\nTanzu CLI successfully installed. Version:"
  tanzu version
}

# Install Cluster Essentials
install_cluster_essentials() {
  # tanzu_network_info "Tanzu Cluster Essentials"
  echo -e "DIY instructions for installing Cluster Essentials: https://docs.vmware.com/en/Cluster-Essentials-for-VMware-Tanzu/1.3/cluster-essentials/GUID-deploy.html
Download the Cluster Essentials binaries from:
	https://network.tanzu.vmware.com/products/tanzu-cluster-essentials/
Rename it to 'tanzu-cluster-essentials.tar' and save it to this directory.
Press any key to continue.
"
  read null
  echo -e "Installing Cluster Essentials into the \$HOME/tanzu-cluster-essentials directory...\n"
  mkdir -p $HOME/tanzu-cluster-essentials
  tar -xvf tanzu-cluster-essentials.tar -C $HOME/tanzu-cluster-essentials
  sleep 1
  echo "Deploying Tanzu Cluster Essentials to Cluster"
  echo -e "To advanced configurations (private registries, certificates, etc) visit:\n https://docs.vmware.com/en/Cluster-Essentials-for-VMware-Tanzu/1.3/cluster-essentials/GUID-deploy.html\n"
  echo "Creating kapp-controller namespace..."
  kubectl create namespace kapp-controller

  echo "If you already have the required env vars set then proceed, this are the required env vars:"
  echo "INSTALL_BUNDLE: cluster essentials img url and sha to use"
  echo "INSTALL_REGISTRY_HOSTNAME: registry url to be used"
  echo "INSTALL_REGISTRY_USERNAME: registry username"
  echo "INSTALL_REGISTRY_PASSWORD: registry password"
  echo "Or do you want to set env vars? [y,N]"
  read set_env_vars
  if [ "$set_env_vars" = "y" ] || [ "$set_env_vars" = "Y" ]; then
    echo -e "Input the install bundle img url, leave blank for the default\n(registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:54bf611711923dccd7c7f10603c846782b90644d48f1cb570b43a082d18e23b9):"
    read install_bundle
    if [ -z "$install_bundle" ]; then
      echo "here"
      install_bundle="registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:54bf611711923dccd7c7f10603c846782b90644d48f1cb570b43a082d18e23b9"
    fi
    echo "$install_bundle"
    export INSTALL_BUNDLE=$install_bundle
    echo -e "\nInput the registry hostname, leave blank for the default\n(registry.tanzu.vmware.com):"
    read registry_hostname
    if [ -z "$registry_hostname" ]; then
      registry_hostname="registry.tanzu.vmware.com"
    fi
    export INSTALL_REGISTRY_HOSTNAME=$registry_hostname
    echo "Input your registry username:"
    read registry_username
    echo "Input your registry password:"
    read -s registry_password
    export INSTALL_REGISTRY_USERNAME=$registry_username
    export INSTALL_REGISTRY_PASSWORD=$registry_password
  fi

  current_dir=$(pwd)
  cd $HOME/tanzu-cluster-essentials
  ./install.sh --yes
  cd $current_dir
  echo "Do you wish to add the Cluster Essentials CLI to your \$PATH?[y/N]"
  read add_cli_to_path
  if [ "$add_cli_to_path" = "y" ] || [ "$add_cli_to_path" = "Y" ]; then
    echo "Copying kapp and imgpkg to \$PATH (/usr/local/bin)"
    sudo cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp
    sudo cp $HOME/tanzu-cluster-essentials/imgpkg /usr/local/bin/imgpkg
  fi
  echo -e "\nTanzu Cluster Essentials deployed successfully and CLI installed successfully\n"
}

unninstall_cluster_essentials() {
  $HOME/tanzu-cluster-essentials/uninstall.sh --yes
}

# Install TAP
install_tap() { # args: --values-file for Tap install
  tanzu_network_info "TAP"
  echo "DIY instructions for installing TAP: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.2/tap/GUID-install.html\n"

  echo "If you already have the required env vars set then proceed, this are the required env vars:"
  echo "INSTALL_REGISTRY_HOSTNAME: registry url to be used"
  echo "INSTALL_REGISTRY_USERNAME: registry username"
  echo "INSTALL_REGISTRY_PASSWORD: registry password"
  echo "TAP_VERSION: tap version to install, ex. ex. 1.4.0-build.22"
  echo "INSTALL_REPO: Tap install repo url, ex. tanzu-application-platform/tap-packages"
  echo "Or do you want to set env vars? [y,N]"
  read set_env_vars
  if [ "$set_env_vars" = "y" ] || [ "$set_env_vars" = "Y" ]; then
    echo -e "\nInput the registry hostname, leave blank for the default\n(registry.tanzu.vmware.com):"
    read registry_hostname
    if [ -z "$registry_hostname" ]; then
      registry_hostname="registry.tanzu.vmware.com"
    fi
    export INSTALL_REGISTRY_HOSTNAME=$registry_hostname
    echo "Input your registry username:"
    read registry_username
    echo "Input your registry password:"
    read -s registry_password
    export INSTALL_REGISTRY_USERNAME=$registry_username
    export INSTALL_REGISTRY_PASSWORD=$registry_password
    echo "Check and choose the tap packages version, retrieving tap pkg versions..."
    imgpkg tag list -i registry.tanzu.vmware.com/tanzu-application-platform/tap-packages | grep -v sha | sort -V
    echo "Input the Tap version: (ex. 1.4.0-build.22)"
    read tap_version
    export TAP_VERSION=$tap_version
    echo -e "Input the Tap install repo, leave blank for the default\n(tanzu-application-platform/tap-packages)"
    read install_repo
    if [ -z "$install_repo" ]; then
      install_repo="tanzu-application-platform/tap-packages"
    fi
    export INSTALL_REPO=$install_repo
  fi

  echo "Creating tap-install namespace"
  kubectl create ns tap-install
  echo "Installing tanzu secret plugin"
  secret_installed=$(tanzu plugin list | grep secret | grep installed)
  if [ -z "$secret_installed" ]; then
    tanzu plugin install secret
  else
    echo "tanzu plugin secret already installed"
  fi
  echo "Creating registry secret for Tap to use:"
  tanzu secret registry add tap-registry \
    --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
    --server ${INSTALL_REGISTRY_HOSTNAME} \
    --export-to-all-namespaces --yes --namespace tap-install
  echo "Installing tanzu package plugin"
  package_installed=$(tanzu plugin list | grep package | grep installed)
  if [ -z "$package_installed" ]; then
    tanzu plugin install package
  else
    echo "tanzu plugin package already installed"
  fi
  tanzu package repository add tanzu-tap-repository \
    --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}:$TAP_VERSION \
    --namespace tap-install
  echo "Checking if TAP reconciled succesfully"
  tap_repo_succeeded=$(tanzu package repository get tanzu-tap-repository --namespace tap-install | grep succeeded)
  if [ -z "$tap_repo_succeeded" ]; then
    echo -e "Something went wrong during repo reconciliation\n"
    exit 1
  fi
  echo "Installing Tap pkg to cluster..."
  tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file $1 -n tap-install
  echo "Verifying Tap pkg installation"
  tanzu package installed get tap -n tap-install
  echo "Verify all the packages installed Reconciliation Succeeded"
  tanzu package installed list -A
  echo -e "\nTap deployed successfully\n"
  tap_cli_external_ip=$(kubectl get services --namespace tap-gui server --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo "To check Tap CLI visit: $tap_cli_external_ip:7000\n"
}

# Gcloud setup
gcloud_check() {
	echo "Please check the following gcloud properties are set correctly:"
  gcloud info | grep Account -A 8
  echo "Looks good? [Y,n]"
  read cli_yn
  if [ "$cli_yn" = "n" ] || [ "$cli_yn" = "N" ]; then
		exit
  fi
}

gcloud_create_cluster() {
	gcloud_check
	echo "Which zone do you want to deploy to? [us-central1-a]"
	read gcloud_zone
	if [ -z "$gcloud_zone" ]; then
		gcloud_zone="us-central1-a"
	fi

	echo "Creating a cluster named 'tap-auto-created' in zone $gcloud_zone with the following parameters:"
	echo 'gcloud beta container clusters create "tap-auto-created" --zone "$gcloud_zone" --no-enable-basic-auth  --machine-type "e2-standard-8" --num-nodes "6" --enable-autoscaling --min-nodes "0" --max-nodes "12" --enable-autoupgrade --enable-autorepair'
	gcloud beta container clusters create "tap-auto-created" --zone "$gcloud_zone" --no-enable-basic-auth  --machine-type "e2-standard-8" --num-nodes "6" --enable-autoscaling --min-nodes "0" --max-nodes "12" --enable-autoupgrade --enable-autorepair
}

####### Main CLI #######
# Basic input handling
echo "Checking for required binaries..."
if [ -z "$SKIP_GCLOUD" ]; then
	which gcloud > /dev/null || echo "`gcloud` cli not installed. Install `gcloud` for google cloud management https://cloud.google.com/sdk/docs/install.\nOr set SKIP_GCLOUD env var to true `SKIP_GCLOUD=1`"
fi
which kubectl > /dev/null || echo "`kubectl` cli not installed."
which tanzu > /dev/null || (echo "`tanzu` cli not installed." && install_tanzu_cli)

# default no params
if [ -z "$1" ]; then
	echo "The following operations will be performed:
	1. Create a GKE cluster
	2. Install of tanzu cluser essentials
	3. Install TAP
Continue? [Y,n]"
  read cli_yn
  if [ "$cli_yn" = "n" ] || [ "$cli_yn" = "N" ]; then
		exit
  fi

	gcloud_create_cluster
	install_cluster_essentials
	install_tap

elif [ "$1" = "tanzu-cli" ]; then
  install_tanzu_cli
  exit
elif [ "$1" = "gke-cluster" ]; then
  gcloud_create_cluster
  exit
elif [ "$1" = "cluster-essentials" ]; then
  install_cluster_essentials
  exit
elif [ "$1" = "tap" ]; then
  install_tap "./config-values/tap-values.yaml"
  exit
else
  echo "Invalid option. Valid options are:
  tanzu-cli 					- to install the tanzu cli
  gke-cluster					- to create a gke cluster named 'tap-auto-created'
  cluster-essentials	- to install the tanzu cluster essentials
  tap 								- to install tap"
fi
