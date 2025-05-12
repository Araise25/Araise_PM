# 🔮 Araise Package Manager

Araise is a cross-platform package manager designed to simplify the installation and management of software packages, applications, and development tools.

## ⚡️ Quick Installation

### Windows
```powershell
$script = Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/Araise25/Araise_PM/main/windows/install.ps1"
$script.Content | Out-File -FilePath "$env:TEMP\araise_install.ps1"
& "$env:TEMP\araise_install.ps1"
```

### Linux/macOS
```bash
curl -fsSL https://raw.githubusercontent.com/Araise25/Araise_PM/main/unix/install.sh | bash
```

## 🚀 Getting Started

After installation, either restart your terminal or:

### Windows
```powershell
. $PROFILE
```

### Linux/macOS
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

### Windows
- PowerShell 5.1 or later
- Git
- Internet connection

### Linux/macOS
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

### Windows
```powershell
# Fix execution policy issues
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

### Linux/macOS
```bash
# Fix permissions
chmod +x ~/.araise/bin/araise
chmod +x ~/.araise/bin/uninstall-araise

# Update PATH
echo 'export PATH="$PATH:$HOME/.araise/bin"' >> ~/.bashrc
source ~/.bashrc
```

## 🗑 Uninstallation

### Windows
```powershell
uninstall-araise
```

### Linux/macOS
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
