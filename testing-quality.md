# Testing & Quality Assurance Guidelines

## 1. Unit Testing Principles

### 1.1 Focused Unit Tests
1.1.1 You MUST write unit tests that focus on testing one specific behavior or logical concept.
1.1.2 You MUST test one logical concept per test method.
1.1.3 You MAY have multiple assertions in a test if they verify the same concept.
1.1.4 You MUST split tests that verify different behaviors.
1.1.5 You MUST give tests names that clearly describe what they verify.

### 1.2 Dependency Isolation
1.2.1 You MUST use test doubles (mocks, stubs, fakes) to isolate the unit under test from its dependencies.
1.2.2 You MUST test all public methods of a class.
1.2.3 You MUST use test doubles to isolate dependencies.
1.2.4 You MUST achieve high code coverage while focusing on behavior coverage.
1.2.5 You MUST test both happy path and error conditions.

### 1.3 Build-Operate-Check Pattern
1.3.1 You MUST structure tests using the clear Build-Operate-Check pattern.
1.3.2 Build phase MUST set up the test data and configure the system under test.
1.3.3 Operate phase MUST execute the behavior being tested.
1.3.4 Check phase MUST verify that the expected outcome occurred.
1.3.5 You MUST clearly separate these phases in your test code.

## 2. Integration Testing

### 2.1 Component Integration Testing
2.1.1 You MUST write integration tests to verify that components work correctly together.
2.1.2 You MUST test critical integration points between components.
2.1.3 You MAY use in-memory databases for testing data access layers.
2.1.4 You MUST test with realistic test doubles for external services.
2.1.5 You MUST keep integration tests separate from unit tests.

### 2.2 Contract Testing
2.2.1 You MUST use contract testing to verify interfaces between different services or components.
2.2.2 You MUST define contracts for service interfaces.
2.2.3 You MUST verify that both providers and consumers adhere to contracts.
2.2.4 You MUST automate contract validation in your build pipeline.
2.2.5 You MAY use tools like Pact for consumer-driven contract testing.

### 2.3 System Integration Testing
2.3.1 You MUST test system-level integration points with external services.
2.3.2 You MUST verify data flow through multiple system boundaries.
2.3.3 You MUST test error handling across system boundaries.
2.3.4 You MUST validate system behavior under realistic load conditions.

## 3. Test Quality and Maintainability

### 3.1 Test Code Quality Standards
3.1.1 Test code MUST be held to the same quality standards as production code.
3.1.2 You MUST apply the same naming conventions to test code as production code.
3.1.3 You MUST keep test functions short and focused.
3.1.4 You MUST extract helper methods to reduce duplication in tests.
3.1.5 You MUST maintain test code as carefully as production code.

### 3.2 Domain-Specific Testing Language
3.2.1 You MUST create domain-specific helper methods to make tests more readable and maintainable.
3.2.2 You MUST extract common test setup into well-named helper methods.
3.2.3 You MUST create assertion helpers for domain-specific validations.
3.2.4 You MUST use the Builder pattern for complex test data creation.
3.2.5 You MAY create test-specific DSLs for complex scenarios.

### 3.3 Test Data Management
3.3.1 You MUST manage test data carefully to ensure reliable and maintainable tests.
3.3.2 You MUST use the minimal data necessary for each test.
3.3.3 You MUST create test data builders for complex objects.
3.3.4 You MUST eliminate shared mutable test state between tests.
3.3.5 You MAY use test data generators for property-based testing.

### 3.4 Test Environment Consistency
3.4.1 You MUST ensure test environments are consistent and repeatable.
3.4.2 You MUST use isolated test environments that can be reset between test runs.
3.4.3 You MUST ensure test data is consistent and predictable.
3.4.4 You MUST use test doubles for external dependencies where possible.
3.4.5 You MAY use containerization to ensure consistent test environments.

## 4. Acceptance Testing

### 4.1 Specification by Example Implementation
4.1.1 You MUST use concrete examples to specify and validate system behavior through collaborative analysis.
4.1.2 You MUST develop concrete examples of desired behavior based on requirements.
4.1.3 You MUST automate the verification of these examples.
4.1.4 You MUST use examples as the basis for acceptance tests.
4.1.5 You MAY use tools like Cucumber or SpecFlow to make examples executable.

### 4.2 End-to-End Testing Strategy
4.2.1 You MUST implement end-to-end tests judiciously to verify critical business scenarios.
4.2.2 You MUST focus end-to-end tests on the most critical user journeys.
4.2.3 You MUST design end-to-end tests to be reliable and maintainable.
4.2.4 You MUST keep end-to-end tests separate from faster test suites.
4.2.5 You MUST ensure end-to-end tests provide value that justifies their maintenance cost.

### 4.3 User Acceptance Testing
4.3.1 You MUST involve stakeholders in defining acceptance criteria.
4.3.2 Acceptance tests MUST verify business value delivery.
4.3.3 You MUST ensure acceptance tests are business-readable.
4.3.4 You MUST automate acceptance tests where feasible.

## 5. Testing Tools and Automation

### 5.1 Test Automation Architecture
5.1.1 You MUST design your test automation to be maintainable and reliable.
5.1.2 You MUST create layers of abstraction that separate test logic from implementation details.
5.1.3 You MUST make test failures easy to diagnose and fix.
5.1.4 You MUST design tests to be resilient to minor changes in implementation.
5.1.5 You MAY use page object patterns for UI tests to reduce coupling.

### 5.2 Performance Testing
5.2.1 You MUST include performance testing as part of your quality assurance strategy.
5.2.2 You MUST establish performance baselines for critical operations.
5.2.3 You MUST test performance under realistic load conditions.
5.2.4 You MUST automate performance tests to catch regressions.
5.2.5 You MAY use performance testing to identify bottlenecks and optimization opportunities.

### 5.3 Security Testing
5.3.1 You MUST include security testing in your quality assurance process.
5.3.2 You MUST test authentication and authorization mechanisms.
5.3.3 You MUST test input validation and sanitization.
5.3.4 You MUST test for common security vulnerabilities.
5.3.5 You MUST automate security tests where possible.

## 6. Testing Strategy and Planning

### 6.1 Test Pyramid Implementation
6.1.1 You MUST implement a test pyramid with more unit tests than integration tests, and more integration tests than end-to-end tests.
6.1.2 Unit tests MUST provide fast feedback and high coverage.
6.1.3 Integration tests MUST verify component interactions.
6.1.4 End-to-end tests MUST verify critical business workflows.
6.1.5 You MUST balance test coverage with execution speed and maintenance cost.

### 6.2 Continuous Testing Integration
6.2.1 You MUST integrate testing into your continuous integration pipeline.
6.2.2 You MUST run fast tests on every code change.
6.2.3 You MUST run comprehensive test suites before production deployment.
6.2.4 You MUST fail builds when tests fail.
6.2.5 You MUST provide rapid feedback on test failures.

### 6.3 Test Maintenance Strategy
6.3.1 You MUST maintain tests alongside production code.
6.3.2 You MUST update tests when requirements change.
6.3.3 You MUST remove obsolete tests to prevent maintenance burden.
6.3.4 You MUST refactor test code to maintain quality.
6.3.5 You MUST monitor test execution time and optimize slow tests.

## 7. Cross-Reference Integration

7.1 For TDD design practices that drive testing, reference sections 5.1-5.3 in @code-quality.md
7.2 For requirements that drive testing approaches, reference sections 1-7 in @requirements-gathering.md
7.3 For security testing considerations, reference sections 1-8 in @security-design.md
7.4 For development processes that support testing, reference sections 1-5 in @development-process.md
7.5 For professional practices in testing, reference sections 1-6 in @professional-conduct.md