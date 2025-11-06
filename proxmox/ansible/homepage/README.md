# Homepage Ansible Playbook

This playbook installs and configures [homepage.dev](https://gethomepage.dev/) on a target machine.

## Prerequisites

- An LXC container running a Debian-based OS (e.g., Ubuntu).
- Ansible installed on the control machine.
- SSH access to the target machine.

## Usage

1.  **Update Inventory**: Ensure the `inventory/hosts` file contains the correct IP address and SSH credentials for the target machine.

2.  **Run the Playbook**:
    ```bash
    ansible-playbook -i inventory/hosts linux_setup_homepage.yml
## Accessing Homepage

Once the playbook has run successfully, you can access the Homepage dashboard by navigating to `http://10.0.0.48:3000` in your web browser.