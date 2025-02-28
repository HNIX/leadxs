# Swayed LDX Development Guide

## Project Vision
Swayed LDX is transforming the lead generation industry through a strategic approach that addresses FTC's 1:1 consent requirements while creating a more transparent, efficient ecosystem. The platform combines immediate compliance solutions with a long-term vision for industry evolution.

Our dual-phase strategy includes:
1. **Pre-Qualification Exchange**: Providing immediate regulatory compliance while maintaining familiar economics
2. **Programmatic Form Platform**: Shifting the industry toward direct publisher-buyer relationships

At the core of our solution is:
- **UnityHub**: A universal integration layer coordinating between publishers and multiple service providers
- **AuthentIQ**: A robust compliance management system ensuring every lead meets regulatory standards with immutable documentation

## Development Environment

### Setup & Commands
* Install dependencies: `bin/setup`
* Run the development server: `bin/dev`
* Run model tests: `bin/rails test:models`
* Run controller tests: `bin/rails test:controllers`
* Generate ERD diagram: `bin/rails jumpstart:erd`

### Technical Stack
* Ruby 3.4.2
* Rails 8.0
* PostgreSQL
* Hotwire (Turbo & Stimulus)
* Tailwind CSS
* Sidekiq for background processing

## Architecture Principles

### Core Components
1. **Campaign Management**
   - Structured for different campaign types (ping-post, direct, calls)
   - Field-based data collection and validation
   - Filter systems for lead quality control

2. **Pre-Qualification System**
   - Anonymous data collection and real-time bidding
   - Dynamic consent management
   - Compliance documentation

3. **Distribution System**
   - Buyer integration and response handling
   - Field mapping between campaigns and buyers
   - Multiple distribution methods (highest bid, round robin, etc.)

4. **Compliance Framework**
   - Consent verification and documentation
   - Audit trails for all data transactions
   - Regulatory requirement enforcement

### Data Flow
1. Publishers collect initial data
2. System solicits bids based on pre-qualification
3. Winner is selected based on campaign distribution method
4. User provides explicit consent for the specific buyer
5. Full lead data is collected and transmitted
6. Compliance documentation is generated and stored

## Code Style Guidelines

### General Principles
* Follow Ruby Style Guide (https://rubystyle.guide/)
* Use snake_case for variables, methods, file names
* Use CamelCase for classes and modules
* Use descriptive variable and method names
* Prefer double quotes for strings unless single quotes have a specific advantage
* Use proper indentation (2 spaces)
* Follow RESTful routing conventions

### Model Structure
* Define clear relationships between entities
* Implement validations at the model level
* Use concerns for shared behaviors
* Keep models focused on their domain
* Utilize callbacks judiciously and with clear purpose

### Controller Structure
* Follow RESTful patterns
* Use strong parameters for data security
* Keep controllers thin, move business logic to service objects
* Handle errors gracefully with appropriate status codes and messages

### Service Objects
* Use service objects for complex business logic
* Focus on a single responsibility
* Return result objects that include success/failure status and relevant data
* Implement clear error handling

### View Structure
* Use partials for reusable components
* Keep views focused on presentation logic
* Use Turbo Frames and Streams for dynamic updates
* Implement responsive design with Tailwind CSS

### Testing
* Write comprehensive tests for models, controllers, and services
* Follow TDD/BDD practices when possible
* Test both happy paths and edge cases
* Use factories for test data generation

## Performance Considerations
* Use database indexing effectively
* Implement caching strategies (fragment caching, Russian Doll caching)
* Use eager loading to avoid N+1 queries
* Optimize database queries using includes, joins, or select
* Use background jobs (Sidekiq) for time-consuming tasks

## Security Best Practices
* Implement proper authentication and authorization
* Use strong parameters in controllers
* Protect against common web vulnerabilities (XSS, CSRF, SQL injection)
* Store sensitive information securely
* Implement proper audit trails for compliance

## Deployment and Operations
* Use continuous integration and deployment
* Implement health checks and monitoring
* Set up proper logging and error tracking
* Create backup and disaster recovery procedures
* Document operational procedures

## Product Roadmap Integration
When implementing new features, consider where they fall within our phased approach:

## Documentation Standards
* Document public APIs using standard formats
* Keep README and other documentation up to date
* Document complex business logic and decisions
* Use meaningful commit messages
* Include context for future developers

## Additional Resources
* [Jumpstart Documentation](https://jumpstartrails.com/docs)
* [Ruby Style Guide](https://rubystyle.guide/)
* [Rails Guides](https://guides.rubyonrails.org/)
* [Hotwire Documentation](https://hotwired.dev/)
* [Tailwind CSS Documentation](https://tailwindcss.com/docs)