# Aztec Patterns
This repository contains a collection of useful development patterns for Aztec developers to reference. All patterns are thoroughly documented and are accompanied with code examples showcasing their structure and implementation along with tests to ensure its correct functionality.
## Recommended Read Order
1. [Shared Nullifier Key](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/note-sharing/README.md)
1. [Note Sharing](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/note-sharing/README.md)
1. [Contracts as Note Owners](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/contracts-as-note-owners/README.md)
1. [Immediate Note Nullification](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/immediate-nullification/README.md)
1. [Multiparty Note-Sharing](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/multiparty-note-sharing/README.md)
## Structure
The general structure of the repository is as follows:
- `patterns/<name_of_pattern>:` contains all relevant files related to that given pattern.
- `patterns/<name_of_pattern>/README.md:` contains a detailed explanation of the pattern.
- `patterns/<name_of_pattern>/src/main.nr:` contains the pattern's code.
- `patterns/<name_of_pattern>/src/test/e2e.test.ts:` contains the pattern's tests.
- `patterns/<name_of_pattern>/src/types/<note_name>.nr:` contains the implementation of notes used for that pattern