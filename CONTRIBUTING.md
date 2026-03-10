# Contributing to MI-SOAR-NGFW

Thank you for your interest in contributing to MI-SOAR-NGFW! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

We are committed to fostering a welcoming and inclusive community. Please:
- Be respectful and constructive in all communications
- Focus on the technical merits of ideas
- Accept constructive criticism gracefully
- Show empathy towards other community members

## Getting Started

### Prerequisites
- Docker and Docker Compose installed
- Basic understanding of security concepts
- Familiarity with Git and GitHub workflow

### Development Environment Setup

1. Fork the repository
2. Clone your fork:
```bash
git clone https://github.com/your-username/mi-soar-ngfw.git
cd mi-soar-ngfw
```

3. Set up development environment:
```bash
cp .env.example .env
docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

4. Run tests to verify setup:
```bash
./scripts/monitoring/health-checks.sh
```

## Development Workflow

### Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch for features
- `feature/*`: New features or enhancements
- `bugfix/*`: Bug fixes
- `hotfix/*`: Critical production fixes

### Pull Request Process

1. **Create a feature branch** from `develop`:
```bash
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name
```

2. **Make your changes** with comprehensive tests

3. **Run tests locally**:
```bash
# Validate configurations
suricata -T -c configs/suricata/suricata.yaml
nft --check -f configs/nftables/main.nft

# Run health checks
./scripts/monitoring/health-checks.sh

# Test Docker Compose
docker-compose config
```

4. **Update documentation** if needed

5. **Commit your changes** with descriptive commit messages:
```bash
git add .
git commit -m "feat: add new Suricata rule for SSH brute force detection

- Add threshold-based SSH brute force detection
- Update documentation with new rule details
- Test with sample attack traffic"
```

6. **Push to your fork**:
```bash
git push origin feature/your-feature-name
```

7. **Create a Pull Request** to the `develop` branch

### Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code restructuring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples**:
```
feat(suricata): add HTTP-based malware detection rules
fix(wireguard): resolve peer connection timeout issue
docs(deployment): update GCP Cloud Run deployment guide
```

## Contribution Areas

### High Priority Areas
1. **Security Rules**: New detection rules for Suricata
2. **Integration Modules**: New n8n custom nodes
3. **Deployment Scripts**: Support for additional cloud providers
4. **Documentation**: Tutorials, guides, and examples
5. **Testing**: Additional test cases and scenarios

### Guidelines for Specific Contributions

#### Adding New Suricata Rules
1. Add rules to `configs/suricata/suricata.rules`
2. Include appropriate SID (1000000+ for custom rules)
3. Add classification in `configs/suricata/classification.config`
4. Test with sample traffic
5. Document the rule in `docs/rules/`

#### Creating n8n Custom Nodes
1. Create node in `configs/n8n/custom-nodes/`
2. Include comprehensive documentation
3. Add error handling and validation
4. Test with sample workflows
5. Update `configs/n8n/config.json`

#### Adding Cloud Provider Support
1. Create deployment scripts in `scripts/deploy/`
2. Add GitHub Actions workflow in `.github/workflows/`
3. Include documentation in `docs/deployment.md`
4. Test in target environment
5. Add to CI/CD pipeline

## Testing Requirements

### Unit Tests
- Configuration validation tests
- Script syntax checking
- Docker Compose validation

### Integration Tests
- Service communication tests
- End-to-end workflow tests
- Performance and load tests

### Security Tests
- Vulnerability scanning
- Secret detection
- Compliance checking

### Test Commands
```bash
# Run all tests
./scripts/test/all.sh

# Run specific test suites
./scripts/test/unit.sh
./scripts/test/integration.sh
./scripts/test/security.sh
```

## Documentation Standards

### Code Documentation
- Include comments for complex logic
- Document function parameters and return values
- Update README for user-facing changes
- Maintain changelog for significant updates

### User Documentation
- Clear installation and setup instructions
- Examples and tutorials
- Troubleshooting guides
- API documentation where applicable

## Review Process

### Pull Request Review Criteria
1. **Code Quality**: Clean, maintainable code
2. **Functionality**: Works as described
3. **Tests**: Comprehensive test coverage
4. **Documentation**: Updated documentation
5. **Security**: No security vulnerabilities
6. **Performance**: No performance regressions

### Review Timeline
- Initial review within 48 hours
- Feedback and iteration
- Merge when all criteria are met

## Community

### Getting Help
- GitHub Issues for bug reports and feature requests
- Discussions for questions and ideas
- Regular community meetings (schedule TBD)

### Recognition
Contributors will be acknowledged in:
- README.md contributors section
- Release notes
- Project documentation

## Security Considerations

### Responsible Disclosure
If you discover a security vulnerability:
1. **DO NOT** create a public issue
2. Email security@scryptocybershield.eu with details
3. Include steps to reproduce
4. We will acknowledge within 48 hours
5. Fix will be coordinated with you

### Security Review Process
All contributions undergo security review:
- Code security analysis
- Dependency vulnerability check
- Configuration security assessment
- Permission and access control review

## License

By contributing to MI-SOAR-NGFW, you agree that your contributions will be licensed under the MIT License.