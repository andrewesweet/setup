# Security Design Guidelines

## 1. STRIDE Threat Analysis

### 1.1 STRIDE Methodology Application
1.1.1 You MUST use the STRIDE methodology to systematically identify security threats in your system design.
1.1.2 You MUST analyze each system component for Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, and Elevation of Privilege threats.
1.1.3 You MUST document identified threats and their potential impact.
1.1.4 You MUST use STRIDE as a checklist when reviewing system designs.
1.1.5 You MAY use the Elevation of Privilege card game to facilitate collaborative threat identification.

### 1.2 Spoofing Threat Analysis
1.2.1 You MUST identify and mitigate threats where attackers pretend to be something or someone they are not.
1.2.2 You MUST implement strong authentication mechanisms for all system components.
1.2.3 You MUST verify the identity of external entities before granting access.
1.2.4 You MUST use cryptographic signatures to prevent impersonation.
1.2.5 You MAY implement multi-factor authentication for high-value operations.

### 1.3 Tampering Threat Analysis
1.3.1 You MUST identify opportunities for unauthorized modification of data, processes, or communications.
1.3.2 You MUST implement data integrity controls using cryptographic hashes or digital signatures.
1.3.3 You MUST protect data in transit using secure communication protocols.
1.3.4 You MUST secure data at rest using appropriate encryption methods.
1.3.5 You MUST validate all input data to prevent injection attacks.

### 1.4 Repudiation Threat Analysis
1.4.1 You MUST identify scenarios where users can deny performing actions they actually performed.
1.4.2 You MUST implement comprehensive logging for all security-relevant events.
1.4.3 You MUST ensure logs are tamper-evident and stored securely.
1.4.4 You MUST implement digital signatures for critical transactions.
1.4.5 You MUST design audit trails that provide non-repudiation evidence.

### 1.5 Information Disclosure Threat Analysis
1.5.1 You MUST identify ways unauthorized users could access confidential information.
1.5.2 You MUST implement access controls based on the principle of least privilege.
1.5.3 You MUST encrypt sensitive data both in transit and at rest.
1.5.4 You MUST minimize the attack surface by exposing only necessary functionality.
1.5.5 You MUST implement proper session management to prevent information leakage.

### 1.6 Denial of Service Threat Analysis
1.6.1 You MUST identify ways attackers could disrupt system availability.
1.6.2 You MUST implement rate limiting and resource quotas.
1.6.3 You MUST design systems to gracefully handle resource exhaustion.
1.6.4 You MUST implement monitoring and alerting for availability threats.
1.6.5 You MUST plan incident response procedures for service disruptions.

### 1.7 Elevation of Privilege Threat Analysis
1.7.1 You MUST identify ways attackers could gain higher privileges than intended.
1.7.2 You MUST implement principle of least privilege throughout the system.
1.7.3 You MUST validate all authorization decisions at enforcement points.
1.7.4 You MUST implement proper role-based access controls.
1.7.5 You MUST regularly audit and review privilege assignments.

## 2. Early Security Integration

### 2.1 Security by Design
2.1.1 You MUST integrate security considerations into the initial design phase.
2.1.2 You MUST identify security requirements alongside functional requirements.
2.1.3 You MUST design security controls as integral parts of the system architecture.
2.1.4 You MUST consider security implications of all design decisions.
2.1.5 You MUST validate security design through threat modeling exercises.

### 2.2 Threat Modeling Process
2.2.1 You MUST conduct threat modeling during the design phase of development.
2.2.2 You MUST create system models that identify assets, threats, and vulnerabilities.
2.2.3 You MUST prioritize threats based on likelihood and impact.
2.2.4 You MUST design mitigations for identified high-priority threats.
2.2.5 You MUST update threat models when system design changes.

### 2.3 Security Requirements Derivation
2.3.1 You MUST derive specific security requirements from identified threats.
2.3.2 You MUST translate security requirements into concrete implementation guidance.
2.3.3 You MUST ensure security requirements are testable and verifiable.
2.3.4 You MUST trace security requirements to their threat sources.
2.3.5 You MUST validate that implemented controls address identified threats.

## 3. Attack Surface Analysis

### 3.1 Attack Surface Identification
3.1.1 You MUST identify all entry points where attackers could interact with the system.
3.1.2 You MUST catalog all external interfaces, APIs, and user interaction points.
3.1.3 You MUST identify all data inputs and their validation requirements.
3.1.4 You MUST map all trust boundaries in the system architecture.
3.1.5 You MUST document all privilege levels and access controls.

### 3.2 Attack Surface Minimization
3.2.1 You MUST minimize the attack surface by reducing unnecessary functionality.
3.2.2 You MUST disable or remove unused features and interfaces.
3.2.3 You MUST implement least privilege access for all system components.
3.2.4 You MUST isolate high-risk components using appropriate boundaries.
3.2.5 You MUST regularly review and reduce exposed attack surfaces.

### 3.3 Trust Boundary Definition
3.3.1 You MUST explicitly define all trust boundaries in the system.
3.3.2 You MUST implement security controls at every trust boundary crossing.
3.3.3 You MUST validate all data crossing trust boundaries.
3.3.4 You MUST authenticate and authorize all interactions across trust boundaries.
3.3.5 You MUST monitor and log all trust boundary crossings.

## 4. Defense in Depth

### 4.1 Layered Security Controls
4.1.1 You MUST implement multiple layers of security controls.
4.1.2 You MUST ensure that failure of one control does not compromise the entire system.
4.1.3 You MUST implement controls at network, host, application, and data layers.
4.1.4 You MUST design controls to detect, prevent, and respond to attacks.
4.1.5 You MUST regularly test the effectiveness of security controls.

### 4.2 Fail-Safe Defaults
4.2.1 You MUST design systems to fail securely when security controls fail.
4.2.2 You MUST implement default-deny access control policies.
4.2.3 You MUST ensure system failures result in more restrictive security postures.
4.2.4 You MUST validate that error conditions maintain security properties.
4.2.5 You MUST implement graceful degradation that preserves security.

### 4.3 Complete Mediation
4.3.1 You MUST check authorization for every access to protected resources.
4.3.2 You MUST implement access controls that cannot be bypassed.
4.3.3 You MUST ensure all security-relevant decisions go through central enforcement points.
4.3.4 You MUST validate that cached authorization decisions remain valid.
4.3.5 You MUST implement consistent security enforcement across all access paths.

## 5. Secure Communication Design

### 5.1 Encryption Requirements
5.1.1 You MUST encrypt all sensitive data in transit using approved cryptographic protocols.
5.1.2 You MUST encrypt sensitive data at rest using appropriate encryption standards.
5.1.3 You MUST use industry-standard cryptographic algorithms and key sizes.
5.1.4 You MUST implement proper key management and rotation procedures.
5.1.5 You MUST validate encryption implementation through security testing.

### 5.2 Authentication and Authorization
5.2.1 You MUST implement strong authentication for all user and system interactions.
5.2.2 You MUST use secure protocols for authentication credential transmission.
5.2.3 You MUST implement fine-grained authorization controls.
5.2.4 You MUST regularly review and update authentication and authorization policies.
5.2.5 You MUST implement session management that prevents hijacking and fixation.

## 6. Secure Development Practices

### 6.1 Secure Coding Standards
6.1.1 You MUST follow secure coding practices that prevent common vulnerabilities.
6.1.2 You MUST validate all input data to prevent injection attacks.
6.1.3 You MUST implement proper error handling that prevents information disclosure.
6.1.4 You MUST use safe APIs and avoid dangerous functions.
6.1.5 You MUST implement proper memory management to prevent buffer overflows.

### 6.2 Security Testing Integration
6.2.1 You MUST integrate security testing into the development lifecycle.
6.2.2 You MUST perform static analysis to identify security vulnerabilities.
6.2.3 You MUST conduct dynamic testing to validate security controls.
6.2.4 You MUST perform penetration testing of critical system components.
6.2.5 You MUST implement automated security testing in continuous integration.

## 7. Incident Response Planning

### 7.1 Security Monitoring
7.1.1 You MUST implement comprehensive security monitoring and logging.
7.1.2 You MUST monitor all security-relevant events and anomalies.
7.1.3 You MUST implement real-time alerting for security incidents.
7.1.4 You MUST maintain audit logs for forensic analysis.
7.1.5 You MUST protect logging infrastructure from tampering.

### 7.2 Incident Response Procedures
7.2.1 You MUST develop and maintain incident response procedures.
7.2.2 You MUST train team members on incident response processes.
7.2.3 You MUST test incident response procedures through regular exercises.
7.2.4 You MUST establish communication procedures for security incidents.
7.2.5 You MUST implement procedures for evidence preservation and forensics.

## 8. Security Governance

### 8.1 Security Requirements Management
8.1.1 You MUST establish security requirements for all system components.
8.1.2 You MUST trace security requirements to threat sources and business needs.
8.1.3 You MUST validate that implemented controls meet security requirements.
8.1.4 You MUST update security requirements when threats or business needs change.
8.1.5 You MUST maintain documentation of security decisions and their rationale.

### 8.2 Security Review Process
8.2.1 You MUST conduct security reviews at key development milestones.
8.2.2 You MUST involve security experts in architecture and design reviews.
8.2.3 You MUST perform security code reviews for all changes.
8.2.4 You MUST validate security controls through testing and verification.
8.2.5 You MUST document security review findings and remediation actions.

## 9. Cross-Reference Integration

9.1 For architectural security patterns, reference sections 6.1-6.2 in @architecture-design.md
9.2 For secure coding practices, reference sections 1-9 in @code-quality.md
9.3 For security testing methodologies, reference sections 5.3 in @testing-quality.md
9.4 For security requirements gathering, reference sections 6.1-6.3 in @requirements-gathering.md
9.5 For professional responsibility in security, reference sections 1.2 in @professional-conduct.md