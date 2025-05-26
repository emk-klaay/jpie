# Publishing JPie

This guide explains how to publish new versions of the JPie gem to RubyGems.org.

## Prerequisites

1. Ensure you have a RubyGems.org account
2. Ensure you have ownership/publishing rights to the gem
3. Configure your local credentials:
   ```bash
   gem signin
   ```

## Publishing Process

### 1. Update Version

Update the version number in `lib/jpie/version.rb`:

```ruby
module JPie
  VERSION = "x.y.z"  # Use semantic versioning
end
```

### 2. Update Changelog

Update `CHANGELOG.md` with the changes in the new version:

```markdown
## [x.y.z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes
```

### 3. Build the Gem

```bash
gem build jpie.gemspec
```

This will create a file named `jpie-x.y.z.gem`.

### 4. Test the Gem Locally (Optional)

```bash
# In a test project
gem install ../path/to/jpie-x.y.z.gem
```

### 5. Push to RubyGems

```bash
gem push jpie-x.y.z.gem
```

### 6. Tag the Release

```bash
git add lib/jpie/version.rb CHANGELOG.md
git commit -m "Release version x.y.z"
git tag -a vx.y.z -m "Version x.y.z"
git push origin main --tags
```

## Versioning Guidelines

Follow [Semantic Versioning](https://semver.org/):

- MAJOR version (x) - incompatible API changes
- MINOR version (y) - add functionality in a backward compatible manner
- PATCH version (z) - backward compatible bug fixes

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   ```bash
   gem signin  # Re-authenticate with RubyGems
   ```

2. **Gem Name Conflict**
   - Ensure the version number is unique
   - Check if the gem name is available on RubyGems.org

3. **Build Errors**
   - Ensure all dependencies are correctly specified in the gemspec
   - Verify the gem builds locally before pushing

### Getting Help

- [RubyGems Guides](https://guides.rubygems.org/)
- [Semantic Versioning](https://semver.org/)
- Open an issue in the JPie repository 