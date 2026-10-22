# Experimenting Securely and Efficiently Using an SSH Bastion Host

This artifact sets up a group of bare metal worker nodes on Chameleon that share a single public IP address. A small VM acts as the bastion host: it holds the only floating IP, and every SSH connection to the workers is routed through it. The workers have no floating IP, so they can't be reached from the internet.

Using a VM as the bastion host leaves every reserved bare metal node free for the experiment itself, and the VM boots in a minute or two.

The steps of the artifact are:
1. Reserve the bare metal workers, a VM flavor for the bastion host, and one floating IP
2. Launch Ubuntu 24.04 on the workers, without waiting for them to boot
3. Launch the bastion VM, attach the floating IP, and add an SSH security group
4. Wait for the workers, then connect to each one through the bastion host, used as an SSH jump host
5. Clean up the resources

The notebook runs at CHI@TACC, since the site must offer both VMs and bare metal nodes. All instances are on `sharednet1`, so the bastion host can reach the workers' private IPs. The bastion host only forwards connections, so your private key never leaves the notebook.

