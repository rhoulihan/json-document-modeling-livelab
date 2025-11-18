# Lintchecker - Vale Configuration

This directory contains Vale linting configuration for maintaining LiveLabs content quality standards.

## What is Vale?

Vale is a command-line tool that brings code-like linting to prose. It checks markdown files against Oracle's style guide and grammar rules.

## Installation

### macOS (Homebrew)
```bash
brew install vale
```

### Linux
```bash
# Download latest release
wget https://github.com/errata-ai/vale/releases/download/v2.29.0/vale_2.29.0_Linux_64-bit.tar.gz
tar -xvzf vale_2.29.0_Linux_64-bit.tar.gz
sudo mv vale /usr/local/bin/
```

### Windows
```bash
# Using Chocolatey
choco install vale

# Or download from: https://github.com/errata-ai/vale/releases
```

## Usage

### Lint a single file
```bash
vale labs/01-setup/setup.md
```

### Lint all markdown files
```bash
vale labs/**/*.md
```

### Lint entire directory
```bash
vale labs/
```

### Lint introduction
```bash
vale introduction/introduction.md
```

## Configuration

The `.vale.ini` file configures:

**Enabled Styles:**
- **Oracle** - Oracle-specific style rules
- **Markup** - Markdown/markup rules

**Disabled Rules:**
- `Oracle.Tutorial_HeadingCasing` - Allow flexible heading case
- `Oracle.GUI_ActionWords` - Allow UI action words
- `Oracle.Terminology_GenderBias` - Gender-neutral language (enabled elsewhere)
- `Oracle.Grammar_PassiveVoice` - Allow passive voice when needed
- `Markup.SentSpacing` - Allow single space after sentences

## Style Rules

The `styles/` directory contains:
- **Oracle/** - Oracle LiveLabs specific rules
- **Markup/** - General markup rules
- **Other styles** - Additional style guides (Microsoft, Google, etc.)

## Common Issues and Fixes

### Issue: Heading capitalization
```
Oracle.Tutorial_HeadingCasing
```
**Fix:** Use title case for headings
- ❌ "Setup the database"
- ✅ "Set Up the Database"

### Issue: Passive voice
```
Oracle.Grammar_PassiveVoice
```
**Fix:** Use active voice when possible
- ❌ "The database is configured by..."
- ✅ "You configure the database..."

### Issue: Wordiness
```
Oracle.Grammar_Wordiness
```
**Fix:** Use concise language
- ❌ "in order to"
- ✅ "to"

### Issue: Sentence spacing
```
Markup.SentSpacing
```
**Fix:** Use single space after sentences
- ❌ "First sentence.  Second sentence."
- ✅ "First sentence. Second sentence."

## CI/CD Integration

### GitHub Actions
```yaml
name: Vale Linting

on: [push, pull_request]

jobs:
  vale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: errata-ai/vale-action@v2
        with:
          files: '**/*.md'
```

### Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Get staged .md files
files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.md$')

if [ -n "$files" ]; then
    echo "Running Vale linting..."
    vale $files
    if [ $? -ne 0 ]; then
        echo "Vale linting failed. Please fix the issues above."
        exit 1
    fi
fi
```

## Ignoring Rules

### In-line
```markdown
<!-- vale off -->
This text won't be checked.
<!-- vale on -->
```

### Specific rules
```markdown
<!-- vale Oracle.Terminology_GenderBias = NO -->
chairman
<!-- vale Oracle.Terminology_GenderBias = YES -->
```

### For a file
Add at top of file:
```markdown
<!--
vale-ignore
-->
```

## Best Practices

1. **Run Vale before committing**
   ```bash
   vale labs/**/*.md
   ```

2. **Fix errors, review warnings**
   - Errors must be fixed
   - Warnings should be reviewed
   - Suggestions are optional

3. **Don't disable rules without reason**
   - Rules exist for consistency
   - If you must disable, document why

4. **Keep .vale.ini in sync**
   - Use oracle-livelabs/common as source of truth
   - Update periodically

## Resources

- [Vale Documentation](https://vale.sh/)
- [Oracle Style Guide](https://docs.oracle.com/en/style-guide/)
- [LiveLabs Content Guidelines](https://oracle-livelabs.github.io/common/sample-livelabs-templates/create-labs/labs/workshops/tenancy/index.html)

## Troubleshooting

**Vale not found:**
```bash
which vale
# If not found, install using instructions above
```

**No styles found:**
```bash
# Verify styles directory exists
ls -la lintchecker/styles/
```

**Permission denied:**
```bash
chmod +x /path/to/vale
```

**Rules not working:**
```bash
# Verify .vale.ini location
vale --config=lintchecker/.vale.ini labs/
```
