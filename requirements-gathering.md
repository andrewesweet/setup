# Requirements Gathering Guidelines

## 1. Gherkin Scenario Structure

### 1.1 Given-When-Then Format
1.1.1 You MUST structure scenarios using the Given-When-Then format for clarity and consistency.
1.1.2 Given statements MUST describe the initial context and preconditions.
1.1.3 When statements MUST describe the action or event that triggers the scenario.
1.1.4 Then statements MUST describe the expected outcome or result.
1.1.5 You MAY use And/But statements to extend any of the three main clauses.

### 1.2 Scenario Design Principles
1.2.1 Each scenario MUST focus on a single behavior or business rule.
1.2.2 Scenarios MUST be written in business language that stakeholders can understand.
1.2.3 You MUST avoid technical implementation details in scenario descriptions.
1.2.4 Scenarios MUST be independent and executable in any order.
1.2.5 You MUST use concrete examples with specific data rather than abstract descriptions.

### 1.3 Background and Scenario Outlines
1.3.1 You MUST use Background sections for common preconditions shared across multiple scenarios.
1.3.2 You MUST use Scenario Outlines for scenarios with multiple similar examples.
1.3.3 Examples tables MUST contain meaningful data that represents realistic business cases.
1.3.4 You MUST ensure all example combinations are valid and testable.

## 2. Use Case Development

### 2.1 Use Case Structure
2.1.1 You MUST define use cases with clear actors, triggers, and outcomes.
2.1.2 Each use case MUST have a primary actor who initiates the interaction.
2.1.3 You MUST specify the trigger that starts the use case.
2.1.4 You MUST describe the main success scenario in numbered steps.
2.1.5 You MUST identify and document alternative and exception scenarios.

### 2.2 Use Case Writing Standards
2.2.1 You MUST write use cases from the actor's perspective, not the system's perspective.
2.2.2 You MUST use active voice and actor-focused language.
2.2.3 Each step MUST represent a meaningful interaction between actor and system.
2.2.4 You MUST maintain consistent formatting across all use cases.
2.2.5 You MUST avoid implementation details in use case descriptions.

### 2.3 Business Value Connection
2.3.1 You MUST connect each use case to clear business value and strategic objectives.
2.3.2 You MUST identify the business value delivered by each use case.
2.3.3 You MUST validate that use cases support business strategy and user needs.
2.3.4 You MUST prioritize use cases based on business impact and frequency of use.
2.3.5 You MAY trace use cases to business requirements and success metrics.

## 3. User Story Development

### 3.1 INVEST Criteria
3.1.1 You MUST write user stories that follow the INVEST criteria: Independent, Negotiable, Valuable, Estimable, Small, Testable.
3.1.2 Stories MUST be Independent and able to be developed in any order.
3.1.3 Stories MUST be Negotiable and describe intent, not detailed specifications.
3.1.4 Stories MUST be Valuable and deliver value to users or the business.
3.1.5 Stories MUST be Estimable with enough detail for development estimation.
3.1.6 Stories MUST be Small enough to be completable within a single iteration.
3.1.7 Stories MUST be Testable with clear acceptance criteria.

### 3.2 Persona-Based Stories
3.2.1 You MUST write user stories from the perspective of specific personas with clear motivations.
3.2.2 You MUST identify specific user types and their characteristics.
3.2.3 You MUST use personas consistently across related stories.
3.2.4 You MUST include the motivation (so that) in addition to the capability (I want).
3.2.5 You MAY develop personas through user research and domain expert input.

### 3.3 Acceptance Criteria Definition
3.3.1 You MUST define clear acceptance criteria for each user story that specify when the story is complete.
3.3.2 You MUST write acceptance criteria in Given-When-Then format when appropriate.
3.3.3 You MUST include both functional and non-functional acceptance criteria.
3.3.4 You MUST involve stakeholders in defining acceptance criteria.
3.3.5 You MAY use acceptance criteria as the basis for automated tests.

## 4. Collaborative Requirements Workshops

### 4.1 Specification Development Process
4.1.1 You MUST analyze and refine requirements through systematic examination with relevant stakeholders.
4.1.2 You MUST include domain experts, developers, testers, and designers in requirements analysis.
4.1.3 You MUST use systematic analysis to explore examples, edge cases, and acceptance criteria.
4.1.4 You MUST facilitate knowledge integration and common vocabulary development.
4.1.5 You MAY use different analysis approaches based on system complexity.

### 4.2 Shared Understanding Development
4.2.1 You MUST ensure comprehensive understanding of requirements through systematic analysis.
4.2.2 You MUST identify and resolve hidden assumptions and constraints.
4.2.3 You MUST use examples to clarify abstract requirements and business rules.
4.2.4 You MUST resolve conflicts and ambiguities through systematic evaluation.
4.2.5 You MUST document decisions and rationale for future reference.

### 4.3 Example Analysis Sessions
4.3.1 You MUST conduct systematic example analysis to explore user stories and acceptance criteria.
4.3.2 You MUST identify rules, examples, and questions for each user story.
4.3.3 You MUST use examples to validate understanding of business rules.
4.3.4 You MUST capture questions and uncertainties for follow-up investigation.
4.3.5 You MUST ensure appropriate stakeholders can provide domain expertise.

## 5. Specification by Example Techniques

### 5.1 Concrete Examples Implementation
5.1.1 You MUST use concrete examples to specify and validate system behavior through systematic analysis.
5.1.2 You MUST develop concrete examples of desired behavior based on comprehensive requirements analysis.
5.1.3 You MUST use realistic data in examples that represents actual business scenarios.
5.1.4 You MUST ensure examples cover both normal and edge cases.
5.1.5 You MUST validate examples with domain knowledge before implementation.

### 5.2 Living Documentation
5.2.1 You MUST create and maintain executable specifications that serve as both tests and documentation.
5.2.2 You MUST automate the verification of specification examples.
5.2.3 You MUST use examples as the basis for acceptance tests.
5.2.4 You MUST keep specifications synchronized with system behavior.
5.2.5 You MUST update specifications when requirements change.

### 5.3 Collaborative Specification Development
5.3.1 You MUST integrate business stakeholder input in specification development.
5.3.2 You MUST use business-readable language in all specifications.
5.3.3 You MUST ensure specifications can be understood by non-technical stakeholders.
5.3.4 You MUST validate specifications with business expertise before implementation.
5.3.5 You MAY use tools like Cucumber or SpecFlow to make examples executable.

## 6. Requirements Elicitation Techniques

### 6.1 Stakeholder Analysis
6.1.1 You MUST identify and analyze all relevant stakeholders in requirements gathering.
6.1.2 You MUST understand stakeholder needs, constraints, and success criteria.
6.1.3 You MUST analyze communication requirements between different stakeholder groups.
6.1.4 You MUST manage conflicting requirements through systematic evaluation.
6.1.5 You MUST ensure stakeholder input is captured and addressed appropriately.

### 6.2 Requirements Discovery Methods
6.2.1 You MUST use multiple elicitation techniques to gather comprehensive requirements.
6.2.2 You MAY use interviews, observations, surveys, and document analysis.
6.2.3 You MUST validate requirements through multiple sources and methods.
6.2.4 You MUST identify both explicit and implicit requirements.
6.2.5 You MUST capture assumptions and constraints that affect requirements.

### 6.3 Domain Knowledge Analysis
6.3.1 You MUST analyze domain knowledge and business rules from subject matter experts.
6.3.2 You MUST understand the business context and environment thoroughly.
6.3.3 You MUST identify business processes and workflows that affect requirements.
6.3.4 You MUST document domain terminology and definitions systematically.
6.3.5 You MUST validate domain understanding with business expertise.

## 7. Requirements Management and Traceability

### 7.1 Requirements Documentation
7.1.1 You MUST document requirements in a format that supports development and testing.
7.1.2 You MUST maintain requirements at an appropriate level of detail.
7.1.3 You MUST organize requirements to support understanding and navigation.
7.1.4 You MUST ensure requirements are testable and verifiable.
7.1.5 You MUST keep requirements documentation current with system changes.

### 7.2 Requirements Traceability
7.2.1 You MUST establish traceability between business objectives and detailed requirements.
7.2.2 You MUST trace requirements to design decisions and implementation.
7.2.3 You MUST trace requirements to test cases and acceptance criteria.
7.2.4 You MUST maintain traceability throughout the development lifecycle.
7.2.5 You MAY use tools to support requirements traceability management.

### 7.3 Change Management
7.3.1 You MUST establish processes for managing requirements changes.
7.3.2 You MUST assess the impact of requirements changes on design and implementation.
7.3.3 You MUST communicate requirements changes to all affected stakeholders.
7.3.4 You MUST update all related artifacts when requirements change.
7.3.5 You MUST maintain a history of requirements changes and their rationale.

## 8. Cross-Reference Integration

8.1 For architectural decisions driven by requirements, reference sections 1-8 in @architecture-design.md
8.2 For testing approaches that verify requirements, reference sections 4.1-4.3 in @testing-quality.md
8.3 For development processes that support requirements gathering, reference sections 1-8 in @development-process.md
8.4 For code quality practices that implement requirements, reference sections 1-9 in @code-quality.md
8.5 For security requirements considerations, reference sections 1-8 in @security-design.md