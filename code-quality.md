# Code Quality Guidelines

## 1. Meaningful Naming

### 1.1 Descriptive Names
1.1.1 You MUST choose names that reveal intent clearly and unambiguously.
1.1.2 Names MUST explain what a variable contains, what a function does, or why something exists.
1.1.3 You MUST write code that reads like well-written prose.
1.1.4 You MUST avoid names that require readers to decode abbreviations or mental mapping.

### 1.2 Specific Naming Standards
1.2.1 You MUST use intention-revealing names for all variables, functions, and classes.
1.2.2 You MUST avoid disinformation in names.
1.2.3 You MUST make meaningful distinctions between similar concepts.
1.2.4 You MUST use pronounceable names for better communication.
1.2.5 You MUST use searchable names for important concepts.
1.2.6 You MUST avoid encodings and prefixes in names.
1.2.7 You MUST avoid mental mapping requirements.

### 1.3 Context and Scope
1.3.1 You MUST add meaningful context to names when necessary.
1.3.2 You MUST use shorter names for smaller scopes and longer names for larger scopes.
1.3.3 Names MUST be precise at the appropriate level of abstraction.

## 2. Function Design

### 2.1 Function Size and Responsibility
2.1.1 You MUST write functions that do one thing well.
2.1.2 Functions MUST be small, typically 20 lines or fewer.
2.1.3 You MUST extract larger functions into multiple focused functions.
2.1.4 Each function MUST operate at a single level of abstraction.

### 2.2 Function Arguments
2.2.1 You MUST minimize the number of function arguments.
2.2.2 Functions SHOULD have zero to three arguments.
2.2.3 You MUST avoid flag arguments that control function behavior.
2.2.4 You MUST group related arguments into parameter objects.

### 2.3 Function Naming and Structure
2.3.1 Function names MUST clearly describe what the function does.
2.3.2 You MUST use verbs for function names and nouns for classes.
2.3.3 You MUST structure functions with clear inputs and outputs.
2.3.4 You MUST eliminate side effects from functions.

## 3. Class Design Principles

### 3.1 Single Responsibility Principle
3.1.1 Every class MUST have only one reason to change.
3.1.2 Classes MUST be cohesive with all methods working toward the class's single purpose.
3.1.3 You MUST extract classes when responsibilities diverge.

### 3.2 Class Size and Organization
3.2.1 Classes MUST be small enough to understand completely.
3.2.2 You MUST organize class members logically with public methods first.
3.2.3 Instance variables MUST remain private unless absolutely necessary.

## 4. Domain Object Design

### 4.1 Entity Design
4.1.1 You MUST model domain objects that have identity and lifecycle as entities.
4.1.2 Entities MUST contain identity and business methods that operate on their data.
4.1.3 You MUST implement entities as objects with behavior, not data structures.
4.1.4 You MUST ensure entity invariants are maintained throughout the lifecycle.

4.1.5 Entity implementation requirements:
   4.1.5.1 Entities MUST have unique identity
   4.1.5.2 Entities MUST encapsulate business rules
   4.1.5.3 Entities MUST control access to their data
   4.1.5.4 Entities MUST maintain their invariants

### 4.2 Value Object Design
4.2.1 You MUST model domain concepts without identity as immutable value objects.
4.2.2 Value objects MUST be immutable after construction.
4.2.3 You MUST implement equality based on all attributes.
4.2.4 You MUST validate value object constraints during construction.

4.2.5 Value object implementation requirements:
   4.2.5.1 Value objects MUST be immutable
   4.2.5.2 Value objects MUST implement value-based equality
   4.2.5.3 Value objects MUST validate their constraints
   4.2.5.4 Value objects MUST represent whole concepts

### 4.3 Domain Service Design
4.3.1 You MUST implement domain operations that coordinate multiple objects as stateless domain services.
4.3.2 Domain services MUST be stateless.
4.3.3 You MUST define service interfaces using domain language.
4.3.4 Services MUST operate on domain objects without replacing their behavior.

## 5. Test-Driven Development as Design

### 5.1 Red-Green-Refactor Cycle
5.1.1 You MUST use the red-green-refactor cycle as a fundamental code design technique.
5.1.2 You MUST write a failing test that describes the desired behavior before writing implementation code.
5.1.3 You MUST write the simplest code possible to make the test pass.
5.1.4 You MUST improve the design while keeping all tests green.
5.1.5 You MUST maintain the rhythm and complete each step.

### 5.2 TDD Design Benefits
5.2.1 You MUST use TDD to drive better code design decisions at the function and class level.
5.2.2 You MUST use TDD to design function interfaces that are easy to test and understand.
5.2.3 You MUST let test requirements drive the emergence of necessary abstractions.
5.2.4 You MUST use test pain as a signal that your design needs improvement.

### 5.3 Implementation Strategies
5.3.1 You MUST choose the appropriate TDD implementation strategy based on confidence and complexity.
5.3.2 You MAY use Obvious Implementation when confident about the solution.
5.3.3 You MUST use Fake Implementation when the solution is complex or uncertain.
5.3.4 You MUST use Triangulation when you need multiple examples to understand patterns.

## 6. Clean Architecture Implementation Patterns

### 6.1 Entity and Use Case Implementation
6.1.1 You MUST implement entities and use cases following Clean Architecture principles.
6.1.2 Entities MUST contain Critical Business Rules that apply across multiple applications.
6.1.3 You MUST keep entity classes free of dependencies on frameworks, databases, or UI concerns.
6.1.4 Use cases MUST orchestrate the flow of data to and from entities.
6.1.5 You MUST keep use case classes independent of UI and database implementation details.

### 6.2 Dependency Management
6.2.1 Use cases MAY depend on entities, but entities MUST remain independent of use cases.
6.2.2 You MUST accept simple request objects and return simple response objects.
6.2.3 Entity classes MUST work independently of any application framework.

## 7. Code Smells and Refactoring

### 7.1 Identifying Code Smells
7.1.1 You MUST actively look for code smells as indicators that refactoring is needed.
7.1.2 You MUST rename variables, functions, and classes when their purpose is unclear.
7.1.3 You MUST eliminate identical or nearly identical code through extraction.
7.1.4 Functions exceeding 20-30 lines MUST be broken down into smaller, focused functions.
7.1.5 Functions with more than 3-4 parameters MUST be refactored using parameter objects.
7.1.6 You MUST encapsulate global variables within appropriate boundaries.
7.1.7 You MUST minimize mutable data and encapsulate it when necessary.

### 7.2 Safe Refactoring Practices
7.2.1 You MUST refactor systematically to preserve behavior while improving design.
7.2.2 You MUST have comprehensive tests before refactoring.
7.2.3 You MUST make small, incremental changes.
7.2.4 You MUST run tests after each refactoring step.
7.2.5 You MUST use automated refactoring tools when available.
7.2.6 You MUST commit frequently during refactoring sessions.

### 7.3 Refactoring Techniques
7.3.1 You MUST extract methods when functions become too long.
7.3.2 You MUST extract classes when responsibilities diverge.
7.3.3 You MUST move methods to appropriate classes based on data usage.
7.3.4 You MUST replace conditional logic with polymorphism when appropriate.

## 8. Comments and Documentation

### 8.1 Code as Documentation
8.1.1 You MUST write code that is self-documenting through clear naming and structure.
8.1.2 Well-written code MUST eliminate the need for most comments.
8.1.3 You MUST express intent through code structure rather than comments.

### 8.2 Necessary Comments
8.2.1 You MAY write comments to explain why, not what.
8.2.2 You MUST document complex business rules that cannot be expressed clearly in code.
8.2.3 You MUST warn about consequences when necessary.
8.2.4 You MUST keep comments synchronized with code changes.

### 8.3 Comment Quality
8.3.1 Comments MUST add value that cannot be expressed through better code.
8.3.2 You MUST remove obsolete or misleading comments immediately.
8.3.3 You MUST write clear, concise comments when they are necessary.

## 9. Cross-Reference Integration

9.1 For architectural design principles that complement code quality, reference sections 1-8 in @architecture-design.md
9.2 For testing practices that support code quality, reference sections 1-6 in @testing-quality.md  
9.3 For professional practices in code quality, reference sections 1-6 in @professional-conduct.md
9.4 For development processes that support code quality, reference sections 1-5 in @development-process.md
9.5 For security considerations in code design, reference sections 1-8 in @security-design.md