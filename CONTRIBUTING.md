# Contributing to NexusShield

Thank you for your interest in contributing! NexusShield is an open-source scam-detection platform for India.

## How to contribute

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run checks:
   - Backend: `cd backend && python -m py_compile main.py app/*.py`
   - Frontend: `flutter analyze` and `flutter test`
5. Commit with a clear message: `git commit -m "Add: your feature"`
6. Push and open a Pull Request

## Code style

- **Python:** Follow PEP 8. Use type hints where possible.
- **Dart/Flutter:** Follow the official Dart style guide. Run `flutter analyze` before committing.
- Keep commits focused — one feature or fix per commit.

## Reporting issues

Open an issue on GitHub with:
- Steps to reproduce
- Expected vs. actual behavior
- Screenshots if applicable

## Security

Do **not** open public issues for security vulnerabilities. See [SECURITY.md](SECURITY.md) for responsible disclosure.
