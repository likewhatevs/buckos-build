#!/usr/bin/env python3
"""
BuckOS Specification Validator

Validates BuckOS specification files for correct format, metadata, and structure.

Usage:
    ./scripts/validate-spec.py specs/core/SPEC-001-package-manager-integration.md
    ./scripts/validate-spec.py specs/**/*.md
    ./scripts/validate-spec.py --all
"""

import argparse
import glob
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import List, Optional, Dict, Any

try:
    import yaml
except ImportError:
    print("Error: PyYAML not installed. Install with: pip install PyYAML", file=sys.stderr)
    sys.exit(1)


# ============================================================================
# Constants
# ============================================================================

VALID_STATUSES = {"draft", "rfc", "approved", "rejected", "deprecated"}
VALID_CATEGORIES = {"core", "integration", "features", "bootstrap", "tooling"}
VALID_IMPL_STATUSES = {"not-started", "in-progress", "partial", "complete"}
VALID_REVIEW_STATUSES = {"approved", "changes-requested", "rejected"}

REQUIRED_FIELDS = {
    "id", "title", "status", "version", "created", "updated",
    "category", "authors"
}

REQUIRED_SECTIONS = {
    "Abstract", "Overview", "Motivation", "Specification",
    "Examples", "Implementation", "Security Considerations",
    "Alternatives Considered", "References"
}

SPEC_ID_PATTERN = re.compile(r'^SPEC-(\d{3})$')
VERSION_PATTERN = re.compile(r'^\d+\.\d+\.\d+$')
EMAIL_PATTERN = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
DATE_PATTERN = re.compile(r'^\d{4}-\d{2}-\d{2}$')
TAG_PATTERN = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')

SPEC_ID_RANGES = {
    "core": (1, 99),
    "bootstrap": (100, 199),
    "integration": (200, 299),
    "features": (300, 399),
    "tooling": (400, 499),
}


# ============================================================================
# Data Classes
# ============================================================================

@dataclass
class ValidationError:
    """Represents a validation error"""
    severity: str  # ERROR or WARNING
    message: str
    location: Optional[str] = None

    def __str__(self):
        loc = f" [{self.location}]" if self.location else ""
        return f"{self.severity}: {self.message}{loc}"


@dataclass
class ValidationResult:
    """Result of validating a specification"""
    spec_file: Path
    spec_id: Optional[str] = None
    is_valid: bool = True
    errors: List[ValidationError] = field(default_factory=list)
    warnings: List[ValidationError] = field(default_factory=list)

    def add_error(self, message: str, location: Optional[str] = None):
        """Add an error"""
        self.errors.append(ValidationError("ERROR", message, location))
        self.is_valid = False

    def add_warning(self, message: str, location: Optional[str] = None):
        """Add a warning"""
        self.warnings.append(ValidationError("WARNING", message, location))

    def print_summary(self):
        """Print validation summary"""
        if self.is_valid and not self.warnings:
            print(f"✓ {self.spec_file.name}: Valid")
            if self.spec_id:
                print(f"  Spec ID: {self.spec_id}")
        else:
            status = "✗" if not self.is_valid else "⚠"
            print(f"{status} {self.spec_file.name}:")
            if self.spec_id:
                print(f"  Spec ID: {self.spec_id}")

            for error in self.errors:
                print(f"  {error}")

            for warning in self.warnings:
                print(f"  {warning}")


# ============================================================================
# Validator Class
# ============================================================================

class SpecValidator:
    """Validates BuckOS specifications"""

    def __init__(self, specs_dir: Path):
        self.specs_dir = specs_dir
        self.all_spec_ids: Dict[str, Path] = {}  # For checking uniqueness

    def validate_file(self, spec_file: Path) -> ValidationResult:
        """Validate a single specification file"""
        result = ValidationResult(spec_file=spec_file)

        try:
            content = spec_file.read_text(encoding='utf-8')
        except Exception as e:
            result.add_error(f"Failed to read file: {e}")
            return result

        # Extract and validate YAML frontmatter
        frontmatter, markdown = self._extract_frontmatter(content)

        if frontmatter is None:
            result.add_error("No YAML frontmatter found")
            return result

        # Validate frontmatter fields
        self._validate_frontmatter(frontmatter, result)

        if "id" in frontmatter:
            result.spec_id = frontmatter["id"]

        # Validate markdown content
        self._validate_markdown(markdown, frontmatter, result)

        # Validate filename matches spec ID
        if "id" in frontmatter:
            self._validate_filename(spec_file, frontmatter["id"], result)

        return result

    def _extract_frontmatter(self, content: str) -> tuple[Optional[Dict], str]:
        """Extract YAML frontmatter and markdown content"""
        # Check for YAML frontmatter delimiters
        if not content.startswith('---\n'):
            return None, content

        # Find end of frontmatter
        end_match = re.search(r'\n---\n', content[4:])
        if not end_match:
            return None, content

        frontmatter_text = content[4:4 + end_match.start()]
        markdown = content[4 + end_match.end():]

        try:
            frontmatter = yaml.safe_load(frontmatter_text)
            return frontmatter, markdown
        except yaml.YAMLError as e:
            return None, content

    def _validate_frontmatter(self, frontmatter: Dict, result: ValidationResult):
        """Validate YAML frontmatter"""
        # Check required fields
        for field in REQUIRED_FIELDS:
            if field not in frontmatter:
                result.add_error(f"Missing required field: {field}", "frontmatter")

        # Validate spec ID
        if "id" in frontmatter:
            self._validate_spec_id(frontmatter["id"], frontmatter.get("category"), result)

        # Validate status
        if "status" in frontmatter:
            if frontmatter["status"] not in VALID_STATUSES:
                result.add_error(
                    f"Invalid status: {frontmatter['status']}. "
                    f"Must be one of: {', '.join(VALID_STATUSES)}",
                    "frontmatter.status"
                )

        # Validate category
        if "category" in frontmatter:
            if frontmatter["category"] not in VALID_CATEGORIES:
                result.add_error(
                    f"Invalid category: {frontmatter['category']}. "
                    f"Must be one of: {', '.join(VALID_CATEGORIES)}",
                    "frontmatter.category"
                )

        # Validate version
        if "version" in frontmatter:
            self._validate_version(frontmatter["version"], frontmatter.get("status"), result)

        # Validate dates
        for date_field in ["created", "updated"]:
            if date_field in frontmatter:
                self._validate_date(frontmatter[date_field], date_field, result)

        # Validate created <= updated
        if "created" in frontmatter and "updated" in frontmatter:
            try:
                created = datetime.strptime(frontmatter["created"], "%Y-%m-%d")
                updated = datetime.strptime(frontmatter["updated"], "%Y-%m-%d")
                if created > updated:
                    result.add_error(
                        "Created date is after updated date",
                        "frontmatter.dates"
                    )
            except ValueError:
                pass  # Already reported by _validate_date

        # Validate authors
        if "authors" in frontmatter:
            self._validate_authors(frontmatter["authors"], result)

        # Validate tags
        if "tags" in frontmatter:
            self._validate_tags(frontmatter["tags"], result)

        # Validate implementation status
        if "implementation" in frontmatter:
            self._validate_implementation(frontmatter["implementation"], result)

        # Validate lifecycle dates
        if "lifecycle" in frontmatter:
            self._validate_lifecycle(frontmatter["lifecycle"], frontmatter.get("status"), result)

        # Validate changelog
        if "changelog" in frontmatter:
            self._validate_changelog(frontmatter["changelog"], frontmatter.get("version"), result)

    def _validate_spec_id(self, spec_id: str, category: Optional[str], result: ValidationResult):
        """Validate spec ID format and uniqueness"""
        # Check format
        match = SPEC_ID_PATTERN.match(spec_id)
        if not match:
            result.add_error(
                f"Invalid spec ID format: {spec_id}. Must be SPEC-NNN (3 digits)",
                "frontmatter.id"
            )
            return

        # Extract number
        spec_num = int(match.group(1))

        # Check range for category
        if category and category in SPEC_ID_RANGES:
            min_id, max_id = SPEC_ID_RANGES[category]
            if not (min_id <= spec_num <= max_id):
                result.add_warning(
                    f"Spec ID {spec_id} (number {spec_num}) is outside recommended range "
                    f"for category '{category}' ({min_id:03d}-{max_id:03d})",
                    "frontmatter.id"
                )

        # Check uniqueness
        if spec_id in self.all_spec_ids:
            other_file = self.all_spec_ids[spec_id]
            if other_file != result.spec_file:
                result.add_error(
                    f"Duplicate spec ID: {spec_id} already used in {other_file}",
                    "frontmatter.id"
                )
        else:
            self.all_spec_ids[spec_id] = result.spec_file

    def _validate_version(self, version: str, status: Optional[str], result: ValidationResult):
        """Validate semantic version"""
        if not VERSION_PATTERN.match(version):
            result.add_error(
                f"Invalid version format: {version}. Must be MAJOR.MINOR.PATCH",
                "frontmatter.version"
            )
            return

        # Parse version
        major, minor, patch = map(int, version.split('.'))

        # Check version matches status
        if status == "draft" and major != 0:
            result.add_warning(
                f"Draft spec should have version 0.x.x, got {version}",
                "frontmatter.version"
            )
        elif status == "rfc" and (major != 0 or minor != 9):
            result.add_warning(
                f"RFC spec should have version 0.9.x, got {version}",
                "frontmatter.version"
            )
        elif status == "approved" and major == 0:
            result.add_warning(
                f"Approved spec should have version 1.0.0+, got {version}",
                "frontmatter.version"
            )

    def _validate_date(self, date_str: str, field_name: str, result: ValidationResult):
        """Validate ISO 8601 date"""
        if not DATE_PATTERN.match(date_str):
            result.add_error(
                f"Invalid date format in {field_name}: {date_str}. Must be YYYY-MM-DD",
                f"frontmatter.{field_name}"
            )
            return

        try:
            datetime.strptime(date_str, "%Y-%m-%d")
        except ValueError as e:
            result.add_error(
                f"Invalid date in {field_name}: {date_str} ({e})",
                f"frontmatter.{field_name}"
            )

    def _validate_authors(self, authors: Any, result: ValidationResult):
        """Validate authors list"""
        if not isinstance(authors, list):
            result.add_error("Authors must be a list", "frontmatter.authors")
            return

        if len(authors) == 0:
            result.add_error("At least one author required", "frontmatter.authors")
            return

        for i, author in enumerate(authors):
            if not isinstance(author, dict):
                result.add_error(
                    f"Author {i+1} must be a dictionary with 'name' and 'email'",
                    f"frontmatter.authors[{i}]"
                )
                continue

            if "name" not in author:
                result.add_error(
                    f"Author {i+1} missing 'name' field",
                    f"frontmatter.authors[{i}]"
                )

            if "email" not in author:
                result.add_error(
                    f"Author {i+1} missing 'email' field",
                    f"frontmatter.authors[{i}]"
                )
            elif not EMAIL_PATTERN.match(author["email"]):
                result.add_error(
                    f"Author {i+1} has invalid email: {author['email']}",
                    f"frontmatter.authors[{i}].email"
                )

    def _validate_tags(self, tags: Any, result: ValidationResult):
        """Validate tags"""
        if not isinstance(tags, list):
            result.add_error("Tags must be a list", "frontmatter.tags")
            return

        for i, tag in enumerate(tags):
            if not isinstance(tag, str):
                result.add_error(
                    f"Tag {i+1} must be a string",
                    f"frontmatter.tags[{i}]"
                )
                continue

            if not TAG_PATTERN.match(tag):
                result.add_error(
                    f"Invalid tag format: {tag}. Must be lowercase with hyphens",
                    f"frontmatter.tags[{i}]"
                )

    def _validate_implementation(self, impl: Any, result: ValidationResult):
        """Validate implementation metadata"""
        if not isinstance(impl, dict):
            result.add_error(
                "Implementation must be a dictionary",
                "frontmatter.implementation"
            )
            return

        if "status" in impl and impl["status"] not in VALID_IMPL_STATUSES:
            result.add_error(
                f"Invalid implementation status: {impl['status']}. "
                f"Must be one of: {', '.join(VALID_IMPL_STATUSES)}",
                "frontmatter.implementation.status"
            )

        if "completeness" in impl:
            comp = impl["completeness"]
            if not isinstance(comp, (int, float)) or not (0 <= comp <= 100):
                result.add_error(
                    f"Implementation completeness must be 0-100, got {comp}",
                    "frontmatter.implementation.completeness"
                )

    def _validate_lifecycle(self, lifecycle: Any, status: Optional[str], result: ValidationResult):
        """Validate lifecycle metadata"""
        if not isinstance(lifecycle, dict):
            result.add_error(
                "Lifecycle must be a dictionary",
                "frontmatter.lifecycle"
            )
            return

        # Validate dates if present
        date_fields = ["rfc_date", "approved_date", "deprecated_date", "sunset_date"]
        for field in date_fields:
            if field in lifecycle and lifecycle[field] is not None:
                self._validate_date(lifecycle[field], f"lifecycle.{field}", result)

        # Check lifecycle dates match status
        if status == "rfc" and "rfc_date" in lifecycle and lifecycle["rfc_date"] is None:
            result.add_warning(
                "RFC spec should have rfc_date set",
                "frontmatter.lifecycle.rfc_date"
            )

        if status == "approved" and "approved_date" in lifecycle and lifecycle["approved_date"] is None:
            result.add_warning(
                "Approved spec should have approved_date set",
                "frontmatter.lifecycle.approved_date"
            )

        if status == "deprecated":
            if "deprecated_date" in lifecycle and lifecycle["deprecated_date"] is None:
                result.add_warning(
                    "Deprecated spec should have deprecated_date set",
                    "frontmatter.lifecycle.deprecated_date"
                )
            if "deprecation_reason" in lifecycle and not lifecycle["deprecation_reason"]:
                result.add_warning(
                    "Deprecated spec should have deprecation_reason",
                    "frontmatter.lifecycle.deprecation_reason"
                )

    def _validate_changelog(self, changelog: Any, version: Optional[str], result: ValidationResult):
        """Validate changelog"""
        if not isinstance(changelog, list):
            result.add_error(
                "Changelog must be a list",
                "frontmatter.changelog"
            )
            return

        if len(changelog) == 0:
            result.add_warning(
                "Changelog is empty",
                "frontmatter.changelog"
            )
            return

        # Check changelog entries
        for i, entry in enumerate(changelog):
            if not isinstance(entry, dict):
                result.add_error(
                    f"Changelog entry {i+1} must be a dictionary",
                    f"frontmatter.changelog[{i}]"
                )
                continue

            if "version" not in entry:
                result.add_error(
                    f"Changelog entry {i+1} missing 'version'",
                    f"frontmatter.changelog[{i}]"
                )

            if "date" not in entry:
                result.add_error(
                    f"Changelog entry {i+1} missing 'date'",
                    f"frontmatter.changelog[{i}]"
                )
            else:
                self._validate_date(entry["date"], f"changelog[{i}].date", result)

            if "changes" not in entry:
                result.add_error(
                    f"Changelog entry {i+1} missing 'changes'",
                    f"frontmatter.changelog[{i}]"
                )

        # Check most recent version matches frontmatter version
        if version and changelog and "version" in changelog[0]:
            if changelog[0]["version"] != version:
                result.add_warning(
                    f"Most recent changelog version ({changelog[0]['version']}) "
                    f"doesn't match frontmatter version ({version})",
                    "frontmatter.changelog"
                )

    def _validate_markdown(self, markdown: str, frontmatter: Dict, result: ValidationResult):
        """Validate markdown content"""
        # Extract all headers
        headers = re.findall(r'^##\s+(.+)$', markdown, re.MULTILINE)

        # Check for required sections
        for section in REQUIRED_SECTIONS:
            if section not in headers:
                result.add_warning(
                    f"Missing recommended section: {section}",
                    "markdown"
                )

        # Validate Abstract section exists and is brief
        abstract_match = re.search(r'##\s+Abstract\s*\n\n(.+?)(?=\n##|\Z)', markdown, re.DOTALL)
        if not abstract_match:
            result.add_warning("Abstract section not found or empty", "markdown")
        else:
            abstract = abstract_match.group(1).strip()
            if len(abstract) > 500:
                result.add_warning(
                    f"Abstract is too long ({len(abstract)} chars). Should be 2-3 sentences.",
                    "markdown.abstract"
                )

        # Check for status badge
        title = frontmatter.get("title", "")
        status = frontmatter.get("status", "")
        version = frontmatter.get("version", "")
        updated = frontmatter.get("updated", "")

        expected_badge = f"**Status**: {status} | **Version**: {version} | **Last Updated**: {updated}"
        if expected_badge not in markdown:
            result.add_warning(
                "Status badge not found or incorrect format. Expected: " + expected_badge,
                "markdown"
            )

    def _validate_filename(self, spec_file: Path, spec_id: str, result: ValidationResult):
        """Validate filename matches spec ID"""
        expected_prefix = spec_id.lower()
        actual_name = spec_file.stem

        if not actual_name.startswith(expected_prefix):
            result.add_warning(
                f"Filename should start with spec ID: expected {expected_prefix}-*, got {actual_name}",
                "filename"
            )


# ============================================================================
# Main Function
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Validate BuckOS specification files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Validate single spec:
    %(prog)s specs/core/SPEC-001-package-manager-integration.md

  Validate all specs:
    %(prog)s --all
    %(prog)s specs/**/*.md

  Fail on warnings:
    %(prog)s --strict specs/core/SPEC-001-package-manager-integration.md
        """
    )
    parser.add_argument(
        "specs",
        nargs="*",
        help="Specification files to validate"
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Validate all specs in specs/ directory"
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as errors"
    )
    parser.add_argument(
        "--specs-dir",
        type=Path,
        default=Path("specs"),
        help="Path to specs directory (default: specs/)"
    )

    args = parser.parse_args()

    # Determine which specs to validate
    if args.all:
        spec_files = list(args.specs_dir.glob("**/SPEC-*.md"))
    elif args.specs:
        spec_files = []
        for spec_pattern in args.specs:
            matched = glob.glob(spec_pattern, recursive=True)
            spec_files.extend([Path(f) for f in matched])
    else:
        parser.print_help()
        sys.exit(1)

    if not spec_files:
        print("No specification files found")
        sys.exit(1)

    # Validate all specs
    validator = SpecValidator(args.specs_dir)
    results = []

    for spec_file in sorted(spec_files):
        result = validator.validate_file(spec_file)
        results.append(result)
        result.print_summary()
        print()

    # Print summary
    total = len(results)
    valid = sum(1 for r in results if r.is_valid)
    invalid = total - valid
    total_errors = sum(len(r.errors) for r in results)
    total_warnings = sum(len(r.warnings) for r in results)

    print("=" * 60)
    print(f"Validation Summary:")
    print(f"  Total specs: {total}")
    print(f"  Valid: {valid}")
    print(f"  Invalid: {invalid}")
    print(f"  Total errors: {total_errors}")
    print(f"  Total warnings: {total_warnings}")
    print("=" * 60)

    # Exit code
    if invalid > 0:
        sys.exit(1)
    elif args.strict and total_warnings > 0:
        print("\nFailing due to warnings (--strict mode)")
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
