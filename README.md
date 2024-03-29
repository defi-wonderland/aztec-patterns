# Aztec Patterns
This repository contains a collection of useful development patterns for Aztec developers to reference. All patterns are thoroughly documented and are accompanied with code examples showcasing their structure and implementation along with tests to ensure its correct functionality.
## Recommended Read Order
1. [Private-Public Mirroring](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/private-public-mirroring/README.md)
1. [Shared Nullifier Key](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/note-sharing/README.md)
1. [Note Sharing](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/note-sharing/README.md)
1. [Contracts as Note Owners](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/contracts-as-note-owners/README.md)
1. [Immediate Note Nullification](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/immediate-nullification/README.md)
1. [Callback](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/callback/README.md)
1. [Multiparty Note-Sharing](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/multiparty-note-sharing/README.md)
1. [Additive Homomorphic Encryption](https://github.com/defi-wonderland/aztec-patterns/blob/dev/patterns/add-homomorphic/README.md)
## Structure
The general structure of the repository is as follows:
- `patterns/<name_of_pattern>:` contains all relevant files related to that given pattern.
- `patterns/<name_of_pattern>/README.md:` contains a detailed explanation of the pattern.
- `patterns/<name_of_pattern>/src/main.nr:` contains the pattern's code.
- `patterns/<name_of_pattern>/src/test/e2e.test.ts:` contains the pattern's tests.
- `patterns/<name_of_pattern>/src/types/<note_name>.nr:` contains the implementation of notes used for that pattern

## Contributing
If you have been developing in Aztec and found interesting patterns we have not added to the book, pull requests are more than welcome. Before you open one, please:
- Match the structure of the other patterns
- Thoroughly explain the pattern in the simplest possible way
- Add isolated code to showcase the pattern
- Test the code to ensure it works
- Add real examples where the pattern is used in more complex code