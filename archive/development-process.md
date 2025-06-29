# Development Process Guidelines

## 1. Estimation and Planning

### 1.1 Estimation vs. Commitment Distinction
1.1.1 You MUST distinguish clearly between estimates and commitments, as they have fundamentally different implications.
1.1.2 Estimates MUST be presented as distributions with confidence intervals and probability ranges.
1.1.3 You MUST communicate the uncertainty inherent in estimates.
1.1.4 You MAY revise estimates as new information becomes available.
1.1.5 Commitments MUST be promises you will fulfill.
1.1.6 You MUST only make commitments when you have high certainty of success.
1.1.7 You MUST be prepared to work extra hours if necessary to meet commitments.
1.1.8 You MUST decline commitments that require compromising quality.

### 1.2 Team-Based Estimation
1.2.1 You MUST involve relevant stakeholders in estimation activities for better accuracy and context.
1.2.2 You MUST ensure all technical considerations are understood during estimation.
1.2.3 You MUST use multiple perspectives to improve estimate quality.
1.2.4 You MUST resolve significant estimation differences through analysis.
1.2.5 You MUST document assumptions made during estimation.

## 2. Code Integration and Quality

### 2.1 Code Review Standards
2.1.1 You MUST apply thorough code review principles for all changes.
2.1.2 You MUST review code for correctness, clarity, and adherence to standards.
2.1.3 You MUST ensure code meets quality criteria before acceptance.
2.1.4 You MUST validate that code follows established patterns and conventions.
2.1.5 You MUST verify that code changes address requirements appropriately.
2.1.6 You MUST ensure code meets security and performance standards.

### 2.2 Code Ownership Principles
2.2.1 You MUST apply consistent quality standards across all codebase areas.
2.2.2 You MUST maintain familiarity with codebase patterns and conventions.
2.2.3 You MUST respect existing architectural patterns when making changes.
2.2.4 You MUST collaborate with domain knowledge when working in specialized areas.
2.2.5 You MUST improve code quality in any area you modify.

### 2.3 Technical Communication Standards
2.3.1 You MUST document technical decisions and their rationale clearly.
2.3.2 You MUST communicate technical constraints and limitations accurately.
2.3.3 You MUST use precise technical language in all documentation.
2.3.4 You MUST document architectural decisions and trade-offs.
2.3.5 You MUST maintain clear technical specifications and requirements.

## 3. Technical Debt Management

### 3.1 Systematic Technical Debt Management
3.1.1 You MUST track and actively manage technical debt to prevent it from crippling development.
3.1.2 You MUST identify and document technical debt as you encounter it.
3.1.3 You MUST include technical debt paydown in sprint planning.
3.1.4 You MUST prioritize debt that impacts current development velocity.
3.1.5 You MAY establish team guidelines for acceptable debt levels.

### 3.2 Refactoring as Debt Prevention
3.2.1 You MUST use continuous refactoring to prevent technical debt from accumulating.
3.2.2 You MUST refactor aggressively when you have good test coverage.
3.2.3 You MUST balance refactoring with feature delivery based on business needs.
3.2.4 You MUST measure and communicate the impact of technical debt on velocity.
3.2.5 You MAY use code quality metrics to track debt levels over time.

## 4. Development Methodologies

### 4.1 Iterative Development
4.1.1 You MUST develop software iteratively with frequent feedback cycles.
4.1.2 You MUST deliver working software in short iterations (1-4 weeks).
4.1.3 You MUST gather feedback from stakeholders after each iteration.
4.1.4 You MUST adjust plans based on what you learn from each iteration.
4.1.5 You MAY use timeboxing to maintain consistent delivery rhythm.

### 4.2 Continuous Integration
4.2.1 You MUST integrate code changes frequently to prevent integration problems.
4.2.2 You MUST integrate your changes at least daily.
4.2.3 You MUST ensure all tests pass before committing changes.
4.2.4 You MUST use automated build and test processes.
4.2.5 You MAY use feature flags to integrate incomplete features safely.

### 4.3 Continuous Delivery
4.3.1 You MUST maintain software in a deployable state at all times.
4.3.2 You MUST automate deployment processes to reduce risk and effort.
4.3.3 You MUST implement deployment pipelines that verify quality gates.
4.3.4 You MUST enable rapid rollback capabilities for production issues.

## 5. Continuous Integration and Improvement

### 5.1 Code Quality Evolution
5.1.1 You MUST continuously improve code quality through systematic enhancement.
5.1.2 You MUST apply new technical knowledge to improve existing implementations.
5.1.3 You MUST stay current with relevant technical standards and best practices.
5.1.4 You MUST integrate improved patterns and practices into ongoing development.
5.1.5 You MUST evolve technical approaches based on proven methodologies.

### 5.2 Technical Knowledge Application
5.2.1 You MUST apply established design patterns and architectural principles.
5.2.2 You MUST experiment with proven techniques in appropriate contexts.
5.2.3 You MUST validate technical approaches through testing and measurement.
5.2.4 You MUST incorporate feedback from code analysis and performance metrics.
5.2.5 You MUST adapt technical approaches based on evidence and best practices.

### 5.3 Knowledge Integration
5.3.1 You MUST apply domain-specific knowledge to technical implementations.
5.3.2 You MUST integrate business requirements with technical solutions effectively.
5.3.3 You MUST document technical solutions for complex problems.
5.3.4 You MUST share technical knowledge through clear code and documentation.
5.3.5 You MUST remain receptive to alternative technical approaches and improvements.

## 6. Quality Assurance Integration

### 6.1 Quality Gates
6.1.1 You MUST implement quality gates that prevent poor-quality code from advancing.
6.1.2 You MUST require code review approval before merging changes.
6.1.3 You MUST require passing automated tests before deployment.
6.1.4 You MUST require security scans for production releases.
6.1.5 You MAY implement additional quality checks based on project needs.

### 6.2 Defect Prevention
6.2.1 You MUST focus on preventing defects rather than finding them after creation.
6.2.2 You MUST use practices like TDD and systematic testing to reduce defect injection.
6.2.3 You MUST implement process improvements based on defect analysis.
6.2.4 You MUST apply lessons learned from incident analysis to prevent recurrence.

## 7. Cross-Reference Integration

7.1 For professional practices that support development processes, reference sections 1-6 in @professional-conduct.md
7.2 For code quality practices within development processes, reference sections 1-9 in @code-quality.md
7.3 For testing practices that integrate with development processes, reference sections 1-7 in @testing-quality.md
7.4 For requirements practices that drive development processes, reference sections 1-8 in @requirements-gathering.md
7.5 For security considerations in development processes, reference sections 1-9 in @security-design.md