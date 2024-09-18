detect_distro() {
    if [ -f /etc/os-release ]; then
        # Read the distro info
        . /etc/os-release
        DISTRO=$ID
    else
        DISTRO=$(uname -s)
    fi

    case $DISTRO in
        ubuntu|debian)
            PACKAGE_MANAGER="apt-get"
            INSTALL_CMD="sudo apt-get install -y"
            FIREWALL="ufw"
            REQUIRED_SOFTWARE=(docker docker-compose ufw openssl certbot)
            ;;
        centos|fedora|rhel|rocky|almalinux)
            PACKAGE_MANAGER="yum"
            INSTALL_CMD="sudo yum install -y"
            FIREWALL="firewalld"
            REQUIRED_SOFTWARE=(docker docker-compose firewalld openssl certbot)
            ;;
        amzn)
            PACKAGE_MANAGER="yum"
            INSTALL_CMD="sudo yum install -y"
            FIREWALL="firewalld"
            REQUIRED_SOFTWARE=(docker amazon-linux-extras firewalld openssl certbot)
            ;;
        arch|manjaro)
            PACKAGE_MANAGER="pacman"
            INSTALL_CMD="sudo pacman -S --noconfirm"
            FIREWALL="ufw"
            REQUIRED_SOFTWARE=(docker docker-compose ufw openssl certbot)
            ;;
        opensuse*)
            PACKAGE_MANAGER="zypper"
            INSTALL_CMD="sudo zypper install -y"
            FIREWALL="firewalld"
            REQUIRED_SOFTWARE=(docker docker-compose firewalld openssl certbot)
            ;;
        *)
            echo -e "${RED}Unsupported Linux distribution: $DISTRO${NC}"
            exit 1
            ;;
    esac
}
