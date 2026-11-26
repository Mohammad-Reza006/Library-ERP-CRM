# Library ERP – CRM Microservice

**A multi-tenant Customer Relationship Management (CRM) microservice built with C# and .NET for a global Library Management ERP platform.**

## 📖 About the Project

This project is part of a larger Library ERP system designed to support libraries of different sizes and locations around the world.

The long-term vision is to create a connected library ecosystem where multiple libraries can independently manage their operations while participating in a shared global network.

My responsibility in this team project is the **CRM microservice**, which focuses on managing customer relationships, employee profiles, customer communication, and service requests.

The system is being designed with a microservice-oriented architecture to allow independent development, deployment, maintenance, and integration with other ERP services.

## 🎯 CRM Objectives

The CRM microservice aims to provide:

- **Customer Management:** Registration, profiles, contact information, search, categorization, and customer history.
- **Staff Management:** Employee profiles, departments, job titles, and branch assignments.
- **Customer 360°:** A centralized view of customer interactions and relevant information from other services.
- **Real-Time Messaging:** Communication between customers and employees without requiring page refreshes.
- **Service Request Management:** Handling customer requests, complaints, facility assistance, and employee assignments.
- **Audit Logging:** Tracking important customer and employee actions.
- **Multi-Tenancy:** Supporting multiple independent library organizations and their branches.
- **Integration:** Communicating with other ERP microservices through defined APIs and events.

## 🗄️ Database Design

The initial database design focuses on customer relationships, conversations, service requests, staff profiles, and audit history.

Planned core entities include:

- CustomerProfiles
- CustomerContacts
- CustomerAddresses
- CustomerTags
- CustomerTagAssignments
- CustomerNotes
- CustomerInteractions
- CustomerConsentEvents
- StaffProfiles
- Conversations
- ConversationParticipants
- Messages
- MessageAttachments
- ServiceRequests
- ServiceRequestCategories
- ServiceRequestEvents
- ServiceRequestComments
- ConversationAssignmentHistory
- CrmAuditEntries

The database is designed around tenant isolation, relational integrity, data consistency, and future integration with other services.

The repository structure will evolve as backend development, database implementation, testing, and application integration progress.

## 🔗 Integration with Other Microservices

The CRM is intended to communicate with other services within the Library ERP ecosystem:

- **Identity & Access:** Authentication, user accounts, roles, and permissions.
- **Accounting:** Payment and financial status information.
- **Membership:** Subscription status and membership information.
- **Device Manager:** Facility-related service request workflows.
- **Ordering:** Coffee shop orders and fulfillment status.
- **Library Registry:** Library organizations and branch information.

Each microservice is responsible for its own data. Integration will use defined APIs and asynchronous events where appropriate.

## 🌍 Long-Term Vision

The ultimate goal is to contribute to a globally connected library platform where libraries can manage their operations independently while allowing customers to discover libraries, explore book collections, and access available services across participating locations.

## 🚧 Development Status

**Current stage: Initial CRM database design and architecture.**

Development is progressing incrementally, beginning with database design and moving toward backend implementation, customer management, authentication integration, real-time communication, testing, and ERP integration.

This is an evolving project. Requirements, architecture, and implementation decisions may change as the team reviews and develops the system.

## 👨‍💻 Development & Collaboration

This project is being developed collaboratively by a beginner development team, with each developer responsible for an assigned microservice.

The CRM repository follows an independent development workflow, with GitHub used for version control, code reviews, documentation, and progress presentations.

**Primary focus:** Learning, implementing, and delivering a maintainable, secure, and scalable CRM microservice using the .NET ecosystem.
