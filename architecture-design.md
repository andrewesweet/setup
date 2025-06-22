# Architecture & Design Guidelines

## 1. Clean Architecture Principles

### 1.1 The Dependency Rule
1.1.1 Source code dependencies MUST point inward toward higher-level policies.
1.1.2 Inner circles MUST remain independent of outer circles.
1.1.3 Entities MUST know nothing about use cases, and use cases MUST know nothing about frameworks.
1.1.4 Dependencies MUST be inverted at architectural boundaries using interfaces and dependency injection.

### 1.2 System Independence Principles
1.2.1 The architecture MUST enable independent development of different system components.
1.2.2 The architecture MUST enable independent deployment of system components.
1.2.3 The architecture MUST enable independent testing of business logic without frameworks.
1.2.4 Business rules MUST operate independently of external agencies and mechanisms.

### 1.3 Entity Layer Design
1.3.1 Entities MUST contain enterprise-wide Critical Business Rules.
1.3.2 Entities MUST be usable by multiple applications in the enterprise.
1.3.3 Entities MUST remain stable when external elements change.
1.3.4 Entities MUST contain business rules that are fundamental to the enterprise's operation.

### 1.4 Use Case Layer Design
1.4.1 Use cases MUST contain application-specific business rules.
1.4.2 Use cases MUST orchestrate the flow of data to and from entities.
1.4.3 Use cases MUST remain independent of database, UI, and framework concerns.
1.4.4 Use cases MUST define application behavior in terms of business operations.

### 1.5 Dependency Inversion at Architecture Level
1.5.1 High-level business policies and low-level implementation details MUST depend on business abstractions.
1.5.2 You MUST define business interfaces that represent domain concepts.
1.5.3 You MUST implement technical infrastructure as plugins to business capabilities.
1.5.4 Business logic MUST remain independent of databases, frameworks, and external services.
1.5.5 You MUST use ports and adapters patterns to isolate business logic from technical implementations.

## 2. Domain-Driven Architecture

### 2.1 Ubiquitous Language Development
2.1.1 You MUST develop and maintain a shared vocabulary that bridges business and technical domains across your entire system architecture.
2.1.2 You MUST establish domain vocabulary through systematic analysis with business stakeholders.
2.1.3 Architectural components MUST use consistent terminology in their interfaces.
2.1.4 You MUST create system-wide glossaries that define business concepts and their relationships.
2.1.5 You MUST evolve language consistently across all system boundaries when domain understanding deepens.

### 2.2 Bounded Context Design
2.2.1 You MUST identify and explicitly design bounded contexts that encapsulate distinct business domains with clear integration patterns.
2.2.2 You MUST map bounded contexts based on business capabilities, team organization, and conceptual boundaries.
2.2.3 Each bounded context MUST maintain internal consistency and autonomy.
2.2.4 You MUST design explicit integration patterns between contexts using defined patterns.
2.2.5 Business concepts MUST remain within their appropriate context boundaries.

2.2.6 Integration patterns between bounded contexts MUST use one of:
   2.2.6.1 Shared Kernel for closely aligned contexts
   2.2.6.2 Customer-Supplier for dependent contexts
   2.2.6.3 Conformist pattern for external system integration
   2.2.6.4 Anti-corruption Layer for legacy system integration

### 2.3 Strategic Domain Model Design
2.3.1 You MUST identify core domains, supporting subdomains, and generic subdomains to focus architectural investment appropriately.
2.3.2 You MUST identify which domains provide core business value and competitive advantage.
2.3.3 You MUST invest in custom, sophisticated solutions for core domains.
2.3.4 You MUST use off-the-shelf solutions for generic subdomains.
2.3.5 You MAY build supporting subdomains in-house but with simpler architectural approaches.

## 3. Component Architecture

### 3.1 Component Cohesion Principles
3.1.1 You MUST group related business capabilities that change together into the same architectural component.
3.1.2 You MUST follow the Common Closure Principle: group elements that change for the same business reasons.
3.1.3 You MUST follow the Common Reuse Principle: group elements that are used together.
3.1.4 Components MUST have high internal cohesion and low coupling with other components.

### 3.2 Component Coupling Management
3.2.1 You MUST minimize dependencies between components.
3.2.2 You MUST eliminate circular dependencies between components.
3.2.3 Dependencies MUST follow the Stable Dependencies Principle: depend in the direction of stability.
3.2.4 You MUST design stable interfaces for components that other components depend on.

### 3.3 Plugin Architecture Design
3.3.1 You MUST design system boundaries as plugin interfaces.
3.3.2 Business rules MUST define interfaces that plugins implement.
3.3.3 Plugins MUST implement technical concerns without affecting business logic.
3.3.4 You MUST enable plugin replacement without business logic changes.

## 4. SOLID Principles at System Level

### 4.1 Single Responsibility Principle (SRP)
4.1.1 Each architectural component MUST have only one reason to change.
4.1.2 Components MUST serve a single business capability or technical concern.
4.1.3 You MUST separate components when they serve different stakeholders or change for different reasons.

### 4.2 Open-Closed Principle (OCP)
4.2.1 System architecture MUST be open for extension but closed for modification.
4.2.2 You MUST design extension points for anticipated changes.
4.2.3 Core business logic MUST remain unchanged when extending system functionality.

### 4.3 Liskov Substitution Principle (LSP)
4.3.1 Component implementations MUST be substitutable for their interfaces.
4.3.2 Substitutions MUST preserve system behavior and contracts.
4.3.3 Interface contracts MUST be honored by all implementations.

### 4.4 Interface Segregation Principle (ISP)
4.4.1 Components MUST provide focused interfaces for specific client needs.
4.4.2 Clients MUST depend only on interfaces they actually use.
4.4.3 You MUST segregate large interfaces into focused, cohesive contracts.

### 4.5 Dependency Inversion Principle (DIP)
4.5.1 High-level architectural components MUST depend on abstractions.
4.5.2 Low-level implementation components MUST depend on abstractions.
4.5.3 Abstractions MUST represent business concepts, not implementation details.

## 5. Layered Architecture Patterns

### 5.1 Domain Layer Isolation
5.1.1 The domain layer MUST contain pure business logic free of technical concerns.
5.1.2 Domain objects MUST operate independently of persistence, UI, and external services.
5.1.3 Domain layer MUST define interfaces for external dependencies.

### 5.2 Application Layer Design
5.2.1 The application layer MUST coordinate business operations and external interactions.
5.2.2 Application services MUST translate between external protocols and domain operations.
5.2.3 Application layer MUST manage transactions and cross-cutting concerns.

### 5.3 Infrastructure Layer Implementation
5.3.1 Infrastructure layer MUST implement domain interfaces using technical frameworks.
5.3.2 Infrastructure MUST handle persistence, messaging, and external service integration.
5.3.3 Infrastructure implementations MUST be substitutable through dependency injection.

## 6. System Boundary Design

### 6.1 Boundary Interface Definition
6.1.1 System boundaries MUST have clearly defined contracts.
6.1.2 Boundary interfaces MUST use domain-specific data structures.
6.1.3 You MUST design boundaries to minimize coupling between systems.

### 6.2 Cross-Boundary Communication
6.2.1 Systems MUST communicate through well-defined protocols.
6.2.2 You MUST translate between different domain models at boundaries.
6.2.3 Boundary crossings MUST preserve data integrity and business invariants.

## 7. Scalability and Performance Architecture

### 7.1 Scalability Design Patterns
7.1.1 You MUST design for horizontal scalability when growth is anticipated.
7.1.2 Stateless components MUST be preferred for scalability.
7.1.3 You MUST separate read and write operations when appropriate.

### 7.2 Performance Considerations
7.2.1 Performance optimizations MUST preserve architectural principles.
7.2.2 You MUST measure performance impact of architectural decisions.
7.2.3 Caching strategies MUST maintain data consistency requirements.

## 8. Cross-Reference Integration

8.1 For code-level implementation of architectural patterns, reference sections 4-6 in @code-quality.md
8.2 For testing architectural components, reference sections 4-5 in @testing-quality.md
8.3 For security considerations in architecture, reference sections 1-8 in @security-design.md
8.4 For requirements that drive architectural decisions, reference sections 1-7 in @requirements-gathering.md
8.5 For development processes that support architecture, reference sections 1-5 in @development-process.md