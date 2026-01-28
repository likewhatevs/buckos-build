# BuckOS Specifications Index

**Generated:** 2025-12-27 13:31:23

## Summary

**Total Specifications:** 5

**By Status:**
- ✅ approved: 5
- 🔄 rfc: 0
- 📝 draft: 0
- ⚠️ deprecated: 0
- ⛔ rejected: 0

**By Category:**
- core: 5
- bootstrap: 0
- integration: 0
- features: 0
- tooling: 0

## Status Legend

| Status | Badge | Description |
|--------|-------|-------------|
| approved | ✅ | Canonical specification, ready for implementation |
| rfc | 🔄 | Request for Comments, under review |
| draft | 📝 | Work in progress, not ready for review |
| rejected | ⛔ | Not accepted, kept for historical reference |
| deprecated | ⚠️ | Replaced or outdated, scheduled for removal |

## Specifications

### Core Specifications

| ID | Title | Status | Version | Updated |
|--- |-------|--------|---------|---------|
| [SPEC-001](core/SPEC-001-package-manager-integration.md) | Package Manager Integration | ✅ approved | 1.0.0 | 2025-12-27 |
| [SPEC-002](core/SPEC-002-use-flags.md) | USE Flag System | ✅ approved | 1.0.0 | 2025-11-27 |
| [SPEC-003](core/SPEC-003-versioning.md) | Package Versioning and Slot System | ✅ approved | 1.0.0 | 2025-11-19 |
| [SPEC-004](core/SPEC-004-package-sets.md) | Package Sets and System Profiles | ✅ approved | 1.0.0 | 2025-11-20 |
| [SPEC-005](core/SPEC-005-patches.md) | Patch System | ✅ approved | 1.0.0 | 2025-11-20 |

## Quick Links

### Core System Specifications (Approved)

- [SPEC-001: Package Manager Integration](core/SPEC-001-package-manager-integration.md): This specification defines how package managers should interact with the BuckOS Buck2 build system. It provides a complete specification for implementing package manager tooling that integrates wit...
- [SPEC-002: USE Flag System](core/SPEC-002-use-flags.md): The USE flag system provides fine-grained control over package features, dependencies, and build configuration in BuckOS. Similar to Gentoo's USE flags but implemented for Buck2, this system enable...
- [SPEC-003: Package Versioning and Slot System](core/SPEC-003-versioning.md): This specification defines the versioning, slot, and subslot system for BuckOS packages. It enables parallel installation of multiple versions, ABI compatibility tracking, and automated dependency ...
- [SPEC-004: Package Sets and System Profiles](core/SPEC-004-package-sets.md): This specification defines the package set system for BuckOS, which organizes packages into logical collections for different use cases. Package sets enable building complete systems (minimal, serv...
- [SPEC-005: Patch System](core/SPEC-005-patches.md): This specification defines the patch system for BuckOS, which allows users and distributions to customize package builds through multiple patch sources with clear precedence ordering. The system su...

## References

- [TEMPLATE.md](TEMPLATE.md) - Template for creating new specs
- [README.md](README.md) - Guide to the specification system
- [REGISTRY.json](REGISTRY.json) - Machine-readable spec registry

---

For questions or suggestions about the specification system, please file an issue in the project repository.
