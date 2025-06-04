# 🔮 Araise Package Manager

Araise is a cross-platform package manager designed to simplify the installation and management of software packages, applications, and development tools.

## ⚡️ Quick Installation

### Linux/macOS
```bash
curl -fsSL https://raw.githubusercontent.com/Araise25/Araise_PM/main/unix/install.sh | bash
```

### Windows Users
For Windows users, we recommend using Windows Subsystem for Linux (WSL) to run Araise. Follow these steps:

1. Install WSL by opening PowerShell as Administrator and running:
```powershell
wsl --install
```

2. After WSL installation and restart, open your WSL terminal and run the Linux installation command above.

## 🚀 Getting Started

After installation, either restart your terminal or:

### Linux/macOS/WSL
```bash
source ~/.bashrc    # For Bash
source ~/.zshrc     # For Zsh
```

## 📚 Basic Commands

```bash
# Show help
araise help

# Install a package
araise install <package-name>

# Uninstall a package
araise uninstall <package-name>

# List installed packages
araise list

# Search available packages
araise available

# Update package list
araise update

# Run an installed package
araise <package-name>
```

## 🛠 System Requirements

### Linux/macOS/WSL
- Bash or Zsh shell
- Git
- curl or wget
- Internet connection

## 🔄 Package Management

### Package Structure
```json
{
  "name": "package-name",
  "version": "1.0.0",
  "description": "Package description",
  "dependencies": {
    "required": ["git", "python3"],
    "optional": ["docker"]
  }
}
```

### Adding New Packages

1. Fork the repository
2. Add your package to `common/packages.json`
3. Submit a pull request

## 🔧 Troubleshooting

### Linux/macOS/WSL
```bash
# Fix permissions
chmod +x ~/.araise/bin/araise
chmod +x ~/.araise/bin/uninstall-araise

# Update PATH
echo 'export PATH="$PATH:$HOME/.araise/bin"' >> ~/.bashrc
source ~/.bashrc
```

## 🗑 Uninstallation

### Linux/macOS/WSL
```bash
uninstall-araise
```

## 🔒 Security

- All installation scripts are hosted on verified GitHub repositories
- Package signatures are verified before installation
- Dependencies are checked for known vulnerabilities

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Submit a pull request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Support

- Report issues on [GitHub Issues](https://github.com/Araise25/Araise_PM/issues)
- Join our [Discord Community](https://discord.gg/araise)
- Follow updates on [Twitter](https://twitter.com/araise)

## 🙏 Acknowledgments

- Contributors and maintainers
- Open source community
- Package maintainers

---

Made with ❤️ by the Araise Team
