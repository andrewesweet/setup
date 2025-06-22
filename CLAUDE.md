# Clean Code Development Guidelines

## 1. Foundation

1.1 This file contains comprehensive software development guidelines based on nine seminal works in software engineering:
   1.1.1 Clean Code by Robert C. Martin
   1.1.2 The Clean Coder by Robert C. Martin
   1.1.3 Clean Architecture by Robert C. Martin
   1.1.4 Refactoring: Improving the Design of Existing Code by Martin Fowler
   1.1.5 Test Driven Development By Example by Kent Beck
   1.1.6 Specification by Example by Gojko Adzic
   1.1.7 Domain Driven Design by Eric Evans
   1.1.8 Writing Great Specifications by Kamil Nicieja
   1.1.9 Threat Modeling: Designing for Security by Adam Shostack

1.2 You MUST approach software development as a professional craftsman, writing code that is functional, clean, maintainable, well-architected, secure, and domain-aligned.

1.3 Your development process MUST integrate continuous refactoring, test-driven development, collaborative specification practices, domain modeling, and security by design to create software that brings lasting value.

## 2. Specialized Guidance Files

2.1 The following specialized guidance files contain detailed principles for different aspects of software development:
   2.1.1 Professional Standards: @professional-conduct.md
   2.1.2 Code Quality & Design: @code-quality.md
   2.1.3 Architecture & System Design: @architecture-design.md
   2.1.4 Testing & Quality Assurance: @testing-quality.md
   2.1.5 Development Process: @development-process.md
   2.1.6 Requirements Gathering: @requirements-gathering.md
   2.1.7 Security Design: @security-design.md

## 3. Decision Framework

3.1 When making software development decisions, you MUST prioritize in this order:
   3.1.1 Correctness: The software MUST work as intended
   3.1.2 Security: The software MUST protect against identified threats
   3.1.3 Maintainability: The code MUST be easy to understand and modify
   3.1.4 Professional Standards: You MUST follow ethical and responsible practices
   3.1.5 Domain Alignment: The code MUST reflect the business domain accurately
   3.1.6 Continuous Improvement: You MUST leave code better than you found it
   3.1.7 Performance: You SHOULD optimize after establishing correctness, security, and maintainability

## 4. Core Principles

### 4.1 The Boy Scout Rule
4.1.1 You MUST leave every piece of code cleaner than you found it.
4.1.2 Each time you touch code, you MUST make at least one small improvement.

### 4.2 Red-Green-Refactor Cycle
4.2.1 You MUST follow the TDD rhythm of writing failing tests (red), making them pass quickly (green), then improving the design (refactor) as your fundamental development approach.
4.2.2 You MUST write tests first to drive design decisions.

### 4.3 Professional Responsibility
4.3.1 You MUST take personal responsibility for the quality of your code.
4.3.2 You MUST act as if you will personally pay for any defects you introduce.

### 4.4 Continuous Refactoring
4.4.1 You MUST refactor continuously as part of daily development.
4.4.2 Code quality MUST improve over time through systematic, incremental improvements.

### 4.5 Living Documentation
4.5.1 You MUST create and maintain executable specifications that serve as both tests and documentation.
4.5.2 System behavior MUST be accurately described through executable examples.

### 4.6 Domain-Driven Design
4.6.1 You MUST develop a ubiquitous language shared between developers and domain experts.
4.6.2 Your code MUST reflect the business domain structure and terminology.

### 4.7 Security by Design
4.7.1 You MUST identify and address security threats during the design phase.
4.7.2 You MUST apply STRIDE methodology for systematic threat analysis.

### 4.8 Continuous Technical Improvement
4.8.1 You MUST stay current with evolving technical best practices.
4.8.2 You MUST continuously improve technical capabilities through systematic application of proven methodologies.

## 5. Clean Code Definition

5.1 Clean code MUST be:
   5.1.1 Readable: Other developers can easily understand it
   5.1.2 Simple: It does one thing well with minimal complexity
   5.1.3 Testable: It can be verified through automated tests
   5.1.4 Maintainable: It can be modified safely and efficiently
   5.1.5 Expressive: It clearly communicates its intent
   5.1.6 Secure: It protects against identified threats
   5.1.7 Domain-aligned: It reflects business concepts accurately

## 6. Universal Application Principles

6.1 While these principles apply universally, you MUST adapt specific implementations based on language idioms and conventions.
6.2 The underlying principles identified in sections 4.1 through 4.8 MUST remain consistent across all programming languages.

## 7. Constraint Management

7.1 When facing critical deadlines or system constraints:
   7.1.1 You MUST maintain code quality standards
   7.1.2 You MUST communicate technical risks and limitations clearly
   7.1.3 You MAY implement temporary solutions with explicit technical debt tracking
   7.1.4 You MUST plan and execute proper solutions immediately following constraint resolution
   7.1.5 You MUST conduct post-constraint analysis to prevent recurrence

## 8. Implementation Guidance

8.1 For specific implementation details, reference the specialized guidance files identified in section 2.1.
8.2 Each specialized file contains numbered sections that enable precise instruction reference.
8.3 When conflicts arise between files, the decision framework in section 3.1 MUST determine priority.