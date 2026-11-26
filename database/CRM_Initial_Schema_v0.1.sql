SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'crm') IS NULL
    EXEC(N'CREATE SCHEMA crm AUTHORIZATION dbo;');
GO

/* ================================================================
   1. CUSTOMER PROFILES
   ================================================================ */
CREATE TABLE crm.CustomerProfiles
(
    CustomerId              uniqueidentifier NOT NULL,
    TenantId                uniqueidentifier NOT NULL,
    CustomerNumber          nvarchar(32) NOT NULL,
    IdentityUserId          uniqueidentifier NULL,
    HomeBranchId            uniqueidentifier NULL,
    RegisteredAtBranchId    uniqueidentifier NULL,
    FirstName               nvarchar(100) NOT NULL,
    LastName                nvarchar(100) NOT NULL,
    DateOfBirth             date NULL,
    PreferredLanguage       nvarchar(10) NOT NULL CONSTRAINT DF_CustomerProfiles_PreferredLanguage DEFAULT (N'en'),
    PreferredContactChannel nvarchar(20) NULL,
    Status                  tinyint NOT NULL CONSTRAINT DF_CustomerProfiles_Status DEFAULT (1),
    CreatedAtUtc            datetime2(3) NOT NULL CONSTRAINT DF_CustomerProfiles_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
    CreatedByIdentityUserId uniqueidentifier NULL,
    UpdatedAtUtc            datetime2(3) NULL,
    UpdatedByIdentityUserId uniqueidentifier NULL,
    ArchivedAtUtc           datetime2(3) NULL,
    ArchivedByIdentityUserId uniqueidentifier NULL,
    RowVersion              rowversion NOT NULL,

    CONSTRAINT PK_CustomerProfiles PRIMARY KEY (CustomerId),
    CONSTRAINT UQ_CustomerProfiles_Tenant_CustomerId UNIQUE (TenantId, CustomerId),
    CONSTRAINT UQ_CustomerProfiles_Tenant_CustomerNumber UNIQUE (TenantId, CustomerNumber),
    CONSTRAINT CK_CustomerProfiles_Status CHECK (Status IN (1, 2, 3, 4)),
    CONSTRAINT CK_CustomerProfiles_ArchivedState CHECK
    (
        (Status = 4 AND ArchivedAtUtc IS NOT NULL) OR
        (Status <> 4 AND ArchivedAtUtc IS NULL)
    ),
    CONSTRAINT CK_CustomerProfiles_Name CHECK
    (
        LEN(LTRIM(RTRIM(FirstName))) > 0 AND LEN(LTRIM(RTRIM(LastName))) > 0
    )
);
GO

CREATE UNIQUE INDEX UX_CustomerProfiles_Tenant_IdentityUserId
    ON crm.CustomerProfiles (TenantId, IdentityUserId)
    WHERE IdentityUserId IS NOT NULL;
GO

CREATE INDEX IX_CustomerProfiles_Tenant_Name
    ON crm.CustomerProfiles (TenantId, LastName, FirstName)
    INCLUDE (CustomerNumber, Status, HomeBranchId, CreatedAtUtc);
GO

CREATE INDEX IX_CustomerProfiles_Tenant_Status_Created
    ON crm.CustomerProfiles (TenantId, Status, CreatedAtUtc DESC);
GO

/* ================================================================
   2. CUSTOMER CONTACT METHODS AND ADDRESSES
   ================================================================ */
CREATE TABLE crm.CustomerContacts
(
    CustomerContactId uniqueidentifier NOT NULL,
    TenantId          uniqueidentifier NOT NULL,
    CustomerId        uniqueidentifier NOT NULL,
    ContactType       nvarchar(16) NOT NULL,
    ContactValue      nvarchar(320) NOT NULL,
    NormalizedValue   nvarchar(320) NOT NULL,
    IsPrimary         bit NOT NULL CONSTRAINT DF_CustomerContacts_IsPrimary DEFAULT (0),
    IsVerified        bit NOT NULL CONSTRAINT DF_CustomerContacts_IsVerified DEFAULT (0),
    VerifiedAtUtc     datetime2(3) NULL,
    IsActive          bit NOT NULL CONSTRAINT DF_CustomerContacts_IsActive DEFAULT (1),
    CreatedAtUtc      datetime2(3) NOT NULL CONSTRAINT DF_CustomerContacts_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_CustomerContacts PRIMARY KEY (CustomerContactId),
    CONSTRAINT UQ_CustomerContacts_Tenant_ContactId UNIQUE (TenantId, CustomerContactId),
    CONSTRAINT FK_CustomerContacts_CustomerProfiles FOREIGN KEY (TenantId, CustomerId)
        REFERENCES crm.CustomerProfiles (TenantId, CustomerId),
    CONSTRAINT CK_CustomerContacts_Type CHECK (ContactType IN (N'Phone', N'Email')),
    CONSTRAINT CK_CustomerContacts_Verification CHECK
    (
        (IsVerified = 0 AND VerifiedAtUtc IS NULL) OR
        (IsVerified = 1 AND VerifiedAtUtc IS NOT NULL)
    ),
    CONSTRAINT CK_CustomerContacts_Value CHECK
    (
        LEN(LTRIM(RTRIM(ContactValue))) > 0 AND LEN(LTRIM(RTRIM(NormalizedValue))) > 0
    )
);
GO

CREATE INDEX IX_CustomerContacts_Tenant_Type_Normalized
    ON crm.CustomerContacts (TenantId, ContactType, NormalizedValue)
    INCLUDE (CustomerId, IsVerified, IsActive);
GO

CREATE UNIQUE INDEX UX_CustomerContacts_OnePrimaryPerType
    ON crm.CustomerContacts (TenantId, CustomerId, ContactType)
    WHERE IsPrimary = 1 AND IsActive = 1;
GO

CREATE TABLE crm.CustomerAddresses
(
    CustomerAddressId uniqueidentifier NOT NULL,
    TenantId          uniqueidentifier NOT NULL,
    CustomerId        uniqueidentifier NOT NULL,
    AddressType       nvarchar(20) NOT NULL,
    CountryCode       char(2) NOT NULL,
    Region            nvarchar(100) NULL,
    City              nvarchar(100) NULL,
    PostalCode        nvarchar(32) NULL,
    AddressLine1      nvarchar(200) NOT NULL,
    AddressLine2      nvarchar(200) NULL,
    Latitude          decimal(9,6) NULL,
    Longitude         decimal(9,6) NULL,
    IsPrimary         bit NOT NULL CONSTRAINT DF_CustomerAddresses_IsPrimary DEFAULT (0),
    CreatedAtUtc      datetime2(3) NOT NULL CONSTRAINT DF_CustomerAddresses_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_CustomerAddresses PRIMARY KEY (CustomerAddressId),
    CONSTRAINT UQ_CustomerAddresses_Tenant_AddressId UNIQUE (TenantId, CustomerAddressId),
    CONSTRAINT FK_CustomerAddresses_CustomerProfiles FOREIGN KEY (TenantId, CustomerId)
        REFERENCES crm.CustomerProfiles (TenantId, CustomerId),
    CONSTRAINT CK_CustomerAddresses_Type CHECK (AddressType IN (N'Residential', N'Billing', N'Other')),
    CONSTRAINT CK_CustomerAddresses_CountryCode CHECK (CountryCode LIKE '[A-Z][A-Z]'),
    CONSTRAINT CK_CustomerAddresses_Latitude CHECK (Latitude IS NULL OR Latitude BETWEEN -90 AND 90),
    CONSTRAINT CK_CustomerAddresses_Longitude CHECK (Longitude IS NULL OR Longitude BETWEEN -180 AND 180)
);
GO

CREATE INDEX IX_CustomerAddresses_Tenant_Customer
    ON crm.CustomerAddresses (TenantId, CustomerId);
GO

CREATE UNIQUE INDEX UX_CustomerAddresses_OnePrimaryPerType
    ON crm.CustomerAddresses (TenantId, CustomerId, AddressType)
    WHERE IsPrimary = 1;
GO

/* ================================================================
   3. CUSTOMER TAGS, NOTES, INTERACTIONS, CONSENT
   ================================================================ */
CREATE TABLE crm.CustomerTags
(
    CustomerTagId uniqueidentifier NOT NULL,
    TenantId      uniqueidentifier NOT NULL,
    TagName       nvarchar(64) NOT NULL,
    NormalizedName nvarchar(64) NOT NULL,
    CreatedAtUtc  datetime2(3) NOT NULL CONSTRAINT DF_CustomerTags_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_CustomerTags PRIMARY KEY (CustomerTagId),
    CONSTRAINT UQ_CustomerTags_Tenant_TagId UNIQUE (TenantId, CustomerTagId),
    CONSTRAINT UQ_CustomerTags_Tenant_NormalizedName UNIQUE (TenantId, NormalizedName),
    CONSTRAINT CK_CustomerTags_Name CHECK
    (
        LEN(LTRIM(RTRIM(TagName))) > 0 AND LEN(LTRIM(RTRIM(NormalizedName))) > 0
    )
);
GO

CREATE TABLE crm.CustomerTagAssignments
(
    TenantId       uniqueidentifier NOT NULL,
    CustomerId     uniqueidentifier NOT NULL,
    CustomerTagId  uniqueidentifier NOT NULL,
    AssignedAtUtc  datetime2(3) NOT NULL CONSTRAINT DF_CustomerTagAssignments_AssignedAtUtc DEFAULT (SYSUTCDATETIME()),
    AssignedByIdentityUserId uniqueidentifier NULL,

    CONSTRAINT PK_CustomerTagAssignments PRIMARY KEY (TenantId, CustomerId, CustomerTagId),
    CONSTRAINT FK_CustomerTagAssignments_Customer FOREIGN KEY (TenantId, CustomerId)
        REFERENCES crm.CustomerProfiles (TenantId, CustomerId),
    CONSTRAINT FK_CustomerTagAssignments_Tag FOREIGN KEY (TenantId, CustomerTagId)
        REFERENCES crm.CustomerTags (TenantId, CustomerTagId)
);
GO

CREATE TABLE crm.CustomerNotes
(
    CustomerNoteId uniqueidentifier NOT NULL,
    TenantId       uniqueidentifier NOT NULL,
    CustomerId     uniqueidentifier NOT NULL,
    NoteText       nvarchar(2000) NOT NULL,
    Visibility     tinyint NOT NULL CONSTRAINT DF_CustomerNotes_Visibility DEFAULT (1),
    CreatedAtUtc   datetime2(3) NOT NULL CONSTRAINT DF_CustomerNotes_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
    CreatedByIdentityUserId uniqueidentifier NOT NULL,
    UpdatedAtUtc   datetime2(3) NULL,
    UpdatedByIdentityUserId uniqueidentifier NULL,
    IsArchived     bit NOT NULL CONSTRAINT DF_CustomerNotes_IsArchived DEFAULT (0),

    CONSTRAINT PK_CustomerNotes PRIMARY KEY (CustomerNoteId),
    CONSTRAINT UQ_CustomerNotes_Tenant_NoteId UNIQUE (TenantId, CustomerNoteId),
    CONSTRAINT FK_CustomerNotes_Customer FOREIGN KEY (TenantId, CustomerId)
        REFERENCES crm.CustomerProfiles (TenantId, CustomerId),
    CONSTRAINT CK_CustomerNotes_Visibility CHECK (Visibility IN (1, 2)),
    CONSTRAINT CK_CustomerNotes_Text CHECK (LEN(LTRIM(RTRIM(NoteText))) > 0)
);
GO

CREATE INDEX IX_CustomerNotes_Tenant_Customer_Created
    ON crm.CustomerNotes (TenantId, CustomerId, CreatedAtUtc DESC);
GO

CREATE TABLE crm.CustomerInteractions
(
    CustomerInteractionId uniqueidentifier NOT NULL,
    TenantId              uniqueidentifier NOT NULL,
    CustomerId            uniqueidentifier NOT NULL,
    BranchId              uniqueidentifier NULL,
    InteractionType       nvarchar(24) NOT NULL,
    Channel               nvarchar(24) NULL,
    Summary               nvarchar(1000) NOT NULL,
    OccurredAtUtc         datetime2(3) NOT NULL,
    RecordedAtUtc         datetime2(3) NOT NULL CONSTRAINT DF_CustomerInteractions_RecordedAtUtc DEFAULT (SYSUTCDATETIME()),
    RecordedByIdentityUserId uniqueidentifier NULL,

    CONSTRAINT PK_CustomerInteractions PRIMARY KEY (CustomerInteractionId),
    CONSTRAINT UQ_CustomerInteractions_Tenant_InteractionId UNIQUE (TenantId, CustomerInteractionId),
    CONSTRAINT FK_CustomerInteractions_Customer FOREIGN KEY (TenantId, CustomerId)
        REFERENCES crm.CustomerProfiles (TenantId, CustomerId),
    CONSTRAINT CK_CustomerInteractions_Type CHECK
    (
        InteractionType IN (N'Visit', N'PhoneCall', N'Email', N'Meeting', N'Other')
    ),
    CONSTRAINT CK_CustomerInteractions_Summary CHECK (LEN(LTRIM(RTRIM(Summary))) > 0)
);
GO

CREATE INDEX IX_CustomerInteractions_Tenant_Customer_Occurred
    ON crm.CustomerInteractions (TenantId, CustomerId, OccurredAtUtc DESC);
GO

/*
   Append-only consent history. This table records communication choices;
   it is not a substitute for a legal review of each country's consent rules.
*/
CREATE TABLE crm.CustomerConsentEvents
(
    CustomerConsentEventId uniqueidentifier NOT NULL,
    TenantId               uniqueidentifier NOT NULL,
    CustomerId             uniqueidentifier NOT NULL,
    Purpose                nvarchar(32) NOT NULL,
    Channel                nvarchar(20) NOT NULL,
    ConsentAction          nvarchar(12) NOT NULL,
    PolicyVersion          nvarchar(40) NULL,
    EvidenceReference      nvarchar(300) NULL,
    Source                 nvarchar(24) NOT NULL,
    RecordedAtUtc          datetime2(3) NOT NULL CONSTRAINT DF_CustomerConsentEvents_RecordedAtUtc DEFAULT (SYSUTCDATETIME()),
    RecordedByIdentityUserId uniqueidentifier NULL,

    CONSTRAINT PK_CustomerConsentEvents PRIMARY KEY (CustomerConsentEventId),
    CONSTRAINT UQ_CustomerConsentEvents_Tenant_EventId UNIQUE (TenantId, CustomerConsentEventId),
    CONSTRAINT FK_CustomerConsentEvents_Customer FOREIGN KEY (TenantId, CustomerId)
        REFERENCES crm.CustomerProfiles (TenantId, CustomerId),
    CONSTRAINT CK_CustomerConsentEvents_Purpose CHECK
    (
        Purpose IN (N'Marketing', N'ServiceUpdates', N'ProductUpdates', N'Other')
    ),
    CONSTRAINT CK_CustomerConsentEvents_Channel CHECK
    (
        Channel IN (N'Email', N'SMS', N'Phone', N'InApp')
    ),
    CONSTRAINT CK_CustomerConsentEvents_Action CHECK
    (
        ConsentAction IN (N'Granted', N'Withdrawn')
    )
);
GO

CREATE INDEX IX_CustomerConsentEvents_Tenant_Customer_Recorded
    ON crm.CustomerConsentEvents (TenantId, CustomerId, RecordedAtUtc DESC);
GO

/* ================================================================
   4. CRM STAFF DIRECTORY
   IdentityUserId points to the Identity service; credentials and roles
   are intentionally NOT stored here.
   ================================================================ */
CREATE TABLE crm.StaffProfiles
(
    StaffProfileId  uniqueidentifier NOT NULL,
    TenantId        uniqueidentifier NOT NULL,
    IdentityUserId  uniqueidentifier NOT NULL,
    EmployeeNumber  nvarchar(32) NOT NULL,
    PrimaryBranchId uniqueidentifier NULL,
    FirstName       nvarchar(100) NOT NULL,
    LastName        nvarchar(100) NOT NULL,
    JobTitle        nvarchar(100) NULL,
    Department      nvarchar(100) NULL,
    EmploymentStatus tinyint NOT NULL CONSTRAINT DF_StaffProfiles_EmploymentStatus DEFAULT (1),
    CreatedAtUtc    datetime2(3) NOT NULL CONSTRAINT DF_StaffProfiles_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
    UpdatedAtUtc    datetime2(3) NULL,
    RowVersion      rowversion NOT NULL,

    CONSTRAINT PK_StaffProfiles PRIMARY KEY (StaffProfileId),
    CONSTRAINT UQ_StaffProfiles_Tenant_StaffProfileId UNIQUE (TenantId, StaffProfileId),
    CONSTRAINT UQ_StaffProfiles_Tenant_EmployeeNumber UNIQUE (TenantId, EmployeeNumber),
    CONSTRAINT CK_StaffProfiles_EmploymentStatus CHECK (EmploymentStatus IN (1, 2, 3)),
    CONSTRAINT CK_StaffProfiles_Name CHECK
    (
        LEN(LTRIM(RTRIM(FirstName))) > 0 AND LEN(LTRIM(RTRIM(LastName))) > 0
    )
);
GO

CREATE UNIQUE INDEX UX_StaffProfiles_Tenant_IdentityUserId
    ON crm.StaffProfiles (TenantId, IdentityUserId);
GO

CREATE INDEX IX_StaffProfiles_Tenant_Branch_Status
    ON crm.StaffProfiles (TenantId, PrimaryBranchId, EmploymentStatus)
    INCLUDE (EmployeeNumber, FirstName, LastName, JobTitle);
GO

/* ================================================================
   5. CONVERSATIONS AND MESSAGES
   ================================================================ */
CREATE TABLE crm.Conversations
(
    ConversationId  uniqueidentifier NOT NULL,
    TenantId        uniqueidentifier NOT NULL,
    BranchId        uniqueidentifier NULL,
    ConversationType nvarchar(24) NOT NULL,
    Subject         nvarchar(160) NULL,
    CustomerId      uniqueidentifier NULL,
    Status          tinyint NOT NULL CONSTRAINT DF_Conversations_Status DEFAULT (1),
    CreatedByIdentityUserId uniqueidentifier NOT NULL,
    CreatedAtUtc    datetime2(3) NOT NULL CONSTRAINT DF_Conversations_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
    LastMessageAtUtc datetime2(3) NULL,
    ClosedAtUtc     datetime2(3) NULL,
    RowVersion      rowversion NOT NULL,

    CONSTRAINT PK_Conversations PRIMARY KEY (ConversationId),
    CONSTRAINT UQ_Conversations_Tenant_ConversationId UNIQUE (TenantId, ConversationId),
    CONSTRAINT FK_Conversations_Customer FOREIGN KEY (TenantId, CustomerId)
        REFERENCES crm.CustomerProfiles (TenantId, CustomerId),
    CONSTRAINT CK_Conversations_Type CHECK
    (
        ConversationType IN (N'CustomerSupport', N'EmployeeDirect', N'Group')
    ),
    CONSTRAINT CK_Conversations_Status CHECK (Status IN (1, 2, 3, 4)),
    CONSTRAINT CK_Conversations_CustomerSupport CHECK
    (
        ConversationType <> N'CustomerSupport' OR CustomerId IS NOT NULL
    )
);
GO

CREATE INDEX IX_Conversations_Tenant_Status_LastMessage
    ON crm.Conversations (TenantId, Status, LastMessageAtUtc DESC);
GO

CREATE INDEX IX_Conversations_Tenant_Customer_LastMessage
    ON crm.Conversations (TenantId, CustomerId, LastMessageAtUtc DESC)
    WHERE CustomerId IS NOT NULL;
GO

CREATE TABLE crm.ConversationParticipants
(
    ConversationParticipantId uniqueidentifier NOT NULL,
    TenantId                  uniqueidentifier NOT NULL,
    ConversationId            uniqueidentifier NOT NULL,
    ParticipantType           nvarchar(12) NOT NULL,
    CustomerId                uniqueidentifier NULL,
    StaffProfileId            uniqueidentifier NULL,
    IdentityUserId            uniqueidentifier NOT NULL,
    JoinedAtUtc               datetime2(3) NOT NULL CONSTRAINT DF_ConversationParticipants_JoinedAtUtc DEFAULT (SYSUTCDATETIME()),
    LeftAtUtc                 datetime2(3) NULL,
    LastReadAtUtc             datetime2(3) NULL,
    IsMuted                   bit NOT NULL CONSTRAINT DF_ConversationParticipants_IsMuted DEFAULT (0),

    CONSTRAINT PK_ConversationParticipants PRIMARY KEY (ConversationParticipantId),
    CONSTRAINT UQ_ConversationParticipants_Tenant_Conversation_Participant
        UNIQUE (TenantId, ConversationId, ConversationParticipantId),
    CONSTRAINT FK_ConversationParticipants_Conversation FOREIGN KEY (TenantId, ConversationId)
        REFERENCES crm.Conversations (TenantId, ConversationId),
    CONSTRAINT FK_ConversationParticipants_Customer FOREIGN KEY (TenantId, CustomerId)
        REFERENCES crm.CustomerProfiles (TenantId, CustomerId),
    CONSTRAINT FK_ConversationParticipants_Staff FOREIGN KEY (TenantId, StaffProfileId)
        REFERENCES crm.StaffProfiles (TenantId, StaffProfileId),
    CONSTRAINT CK_ConversationParticipants_Type CHECK
    (
        (ParticipantType = N'Customer' AND CustomerId IS NOT NULL AND StaffProfileId IS NULL) OR
        (ParticipantType = N'Staff' AND StaffProfileId IS NOT NULL AND CustomerId IS NULL)
    )
);
GO

CREATE UNIQUE INDEX UX_ConversationParticipants_Conversation_User
    ON crm.ConversationParticipants (TenantId, ConversationId, IdentityUserId);
GO

CREATE INDEX IX_ConversationParticipants_Tenant_User
    ON crm.ConversationParticipants (TenantId, IdentityUserId, ConversationId)
    INCLUDE (ParticipantType, CustomerId, StaffProfileId, LastReadAtUtc, LeftAtUtc);
GO

CREATE TABLE crm.Messages
(
    MessageId          uniqueidentifier NOT NULL,
    TenantId           uniqueidentifier NOT NULL,
    ConversationId     uniqueidentifier NOT NULL,
    SenderParticipantId uniqueidentifier NOT NULL,
    ClientMessageId   uniqueidentifier NULL,
    MessageType        nvarchar(12) NOT NULL,
    Body               nvarchar(max) NULL,
    SentAtUtc          datetime2(3) NOT NULL CONSTRAINT DF_Messages_SentAtUtc DEFAULT (SYSUTCDATETIME()),
    EditedAtUtc        datetime2(3) NULL,
    DeletedAtUtc       datetime2(3) NULL,

    CONSTRAINT PK_Messages PRIMARY KEY (MessageId),
    CONSTRAINT UQ_Messages_Tenant_MessageId UNIQUE (TenantId, MessageId),
    CONSTRAINT FK_Messages_SenderParticipant FOREIGN KEY
        (TenantId, ConversationId, SenderParticipantId)
        REFERENCES crm.ConversationParticipants
        (TenantId, ConversationId, ConversationParticipantId),
    CONSTRAINT CK_Messages_Type CHECK (MessageType IN (N'Text', N'File', N'System')),
    CONSTRAINT CK_Messages_Body CHECK
    (
        (MessageType IN (N'Text', N'System') AND Body IS NOT NULL AND LEN(LTRIM(RTRIM(Body))) > 0)
        OR MessageType = N'File'
    )
);
GO

CREATE INDEX IX_Messages_Tenant_Conversation_Sent
    ON crm.Messages (TenantId, ConversationId, SentAtUtc DESC, MessageId DESC);
GO

CREATE UNIQUE INDEX UX_Messages_ClientMessageId
    ON crm.Messages (TenantId, ConversationId, SenderParticipantId, ClientMessageId)
    WHERE ClientMessageId IS NOT NULL;
GO

CREATE TABLE crm.MessageAttachments
(
    MessageAttachmentId uniqueidentifier NOT NULL,
    TenantId            uniqueidentifier NOT NULL,
    MessageId           uniqueidentifier NOT NULL,
    StorageKey          nvarchar(500) NOT NULL,
    OriginalFileName    nvarchar(255) NOT NULL,
    ContentType         nvarchar(127) NOT NULL,
    SizeBytes           bigint NOT NULL,
    Sha256Hash          char(64) NULL,
    UploadedAtUtc       datetime2(3) NOT NULL CONSTRAINT DF_MessageAttachments_UploadedAtUtc DEFAULT (SYSUTCDATETIME()),
    MalwareScanStatus   tinyint NOT NULL CONSTRAINT DF_MessageAttachments_MalwareScanStatus DEFAULT (0),

    CONSTRAINT PK_MessageAttachments PRIMARY KEY (MessageAttachmentId),
    CONSTRAINT FK_MessageAttachments_Message FOREIGN KEY (TenantId, MessageId)
        REFERENCES crm.Messages (TenantId, MessageId),
    CONSTRAINT CK_MessageAttachments_Size CHECK (SizeBytes > 0),
    CONSTRAINT CK_MessageAttachments_ScanStatus CHECK (MalwareScanStatus IN (0, 1, 2, 3))
);
GO

CREATE INDEX IX_MessageAttachments_Tenant_Message
    ON crm.MessageAttachments (TenantId, MessageId);
GO

CREATE TABLE crm.ConversationAssignmentHistory
(
    ConversationAssignmentHistoryId uniqueidentifier NOT NULL,
    TenantId                       uniqueidentifier NOT NULL,
    ConversationId                 uniqueidentifier NOT NULL,
    AssignedToStaffProfileId       uniqueidentifier NULL,
    AssignedByIdentityUserId       uniqueidentifier NOT NULL,
    AssignmentNote                 nvarchar(500) NULL,
    AssignedAtUtc                  datetime2(3) NOT NULL CONSTRAINT DF_ConversationAssignmentHistory_AssignedAtUtc DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_ConversationAssignmentHistory PRIMARY KEY (ConversationAssignmentHistoryId),
    CONSTRAINT FK_ConversationAssignmentHistory_Conversation FOREIGN KEY (TenantId, ConversationId)
        REFERENCES crm.Conversations (TenantId, ConversationId),
    CONSTRAINT FK_ConversationAssignmentHistory_Staff FOREIGN KEY (TenantId, AssignedToStaffProfileId)
        REFERENCES crm.StaffProfiles (TenantId, StaffProfileId)
);
GO

CREATE INDEX IX_ConversationAssignmentHistory_Tenant_Conversation_Assigned
    ON crm.ConversationAssignmentHistory (TenantId, ConversationId, AssignedAtUtc DESC);
GO

/* ================================================================
   6. SERVICE REQUESTS
   ================================================================ */
CREATE TABLE crm.ServiceRequestCategories
(
    ServiceRequestCategoryId uniqueidentifier NOT NULL,
    TenantId                 uniqueidentifier NOT NULL,
    CategoryCode             nvarchar(32) NOT NULL,
    CategoryName             nvarchar(100) NOT NULL,
    DefaultPriority          tinyint NOT NULL CONSTRAINT DF_ServiceRequestCategories_DefaultPriority DEFAULT (2),
    IsActive                 bit NOT NULL CONSTRAINT DF_ServiceRequestCategories_IsActive DEFAULT (1),
    CreatedAtUtc             datetime2(3) NOT NULL CONSTRAINT DF_ServiceRequestCategories_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_ServiceRequestCategories PRIMARY KEY (ServiceRequestCategoryId),
    CONSTRAINT UQ_ServiceRequestCategories_Tenant_CategoryId UNIQUE (TenantId, ServiceRequestCategoryId),
    CONSTRAINT UQ_ServiceRequestCategories_Tenant_Code UNIQUE (TenantId, CategoryCode),
    CONSTRAINT CK_ServiceRequestCategories_Priority CHECK (DefaultPriority IN (1, 2, 3, 4))
);
GO

CREATE TABLE crm.ServiceRequests
(
    ServiceRequestId       uniqueidentifier NOT NULL,
    TenantId               uniqueidentifier NOT NULL,
    RequestNumber          nvarchar(32) NOT NULL,
    BranchId               uniqueidentifier NULL,
    CustomerId             uniqueidentifier NOT NULL,
    ServiceRequestCategoryId uniqueidentifier NOT NULL,
    RelatedConversationId  uniqueidentifier NULL,
    Title                  nvarchar(160) NOT NULL,
    Description            nvarchar(3000) NOT NULL,
    Priority               tinyint NOT NULL CONSTRAINT DF_ServiceRequests_Priority DEFAULT (2),
    Status                 tinyint NOT NULL CONSTRAINT DF_ServiceRequests_Status DEFAULT (1),
    AssignedToStaffProfileId uniqueidentifier NULL,
    CreatedByIdentityUserId uniqueidentifier NOT NULL,
    CreatedAtUtc           datetime2(3) NOT NULL CONSTRAINT DF_ServiceRequests_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
    UpdatedAtUtc           datetime2(3) NULL,
    ResolvedAtUtc          datetime2(3) NULL,
    ClosedAtUtc            datetime2(3) NULL,
    RowVersion             rowversion NOT NULL,

    CONSTRAINT PK_ServiceRequests PRIMARY KEY (ServiceRequestId),
    CONSTRAINT UQ_ServiceRequests_Tenant_RequestId UNIQUE (TenantId, ServiceRequestId),
    CONSTRAINT UQ_ServiceRequests_Tenant_RequestNumber UNIQUE (TenantId, RequestNumber),
    CONSTRAINT FK_ServiceRequests_Customer FOREIGN KEY (TenantId, CustomerId)
        REFERENCES crm.CustomerProfiles (TenantId, CustomerId),
    CONSTRAINT FK_ServiceRequests_Category FOREIGN KEY (TenantId, ServiceRequestCategoryId)
        REFERENCES crm.ServiceRequestCategories (TenantId, ServiceRequestCategoryId),
    CONSTRAINT FK_ServiceRequests_Conversation FOREIGN KEY (TenantId, RelatedConversationId)
        REFERENCES crm.Conversations (TenantId, ConversationId),
    CONSTRAINT FK_ServiceRequests_AssignedStaff FOREIGN KEY (TenantId, AssignedToStaffProfileId)
        REFERENCES crm.StaffProfiles (TenantId, StaffProfileId),
    CONSTRAINT CK_ServiceRequests_Priority CHECK (Priority IN (1, 2, 3, 4)),
    CONSTRAINT CK_ServiceRequests_Status CHECK (Status IN (1, 2, 3, 4, 5, 6, 7)),
    CONSTRAINT CK_ServiceRequests_Title CHECK (LEN(LTRIM(RTRIM(Title))) > 0),
    CONSTRAINT CK_ServiceRequests_Description CHECK (LEN(LTRIM(RTRIM(Description))) > 0)
);
GO

CREATE INDEX IX_ServiceRequests_Tenant_Status_Created
    ON crm.ServiceRequests (TenantId, Status, CreatedAtUtc DESC)
    INCLUDE (RequestNumber, CustomerId, Priority, AssignedToStaffProfileId, BranchId);
GO

CREATE INDEX IX_ServiceRequests_Tenant_Customer_Created
    ON crm.ServiceRequests (TenantId, CustomerId, CreatedAtUtc DESC);
GO

CREATE INDEX IX_ServiceRequests_Tenant_Assignee_Status
    ON crm.ServiceRequests (TenantId, AssignedToStaffProfileId, Status, CreatedAtUtc DESC)
    WHERE AssignedToStaffProfileId IS NOT NULL;
GO

CREATE TABLE crm.ServiceRequestEvents
(
    ServiceRequestEventId uniqueidentifier NOT NULL,
    TenantId             uniqueidentifier NOT NULL,
    ServiceRequestId     uniqueidentifier NOT NULL,
    EventType            nvarchar(24) NOT NULL,
    OldStatus            tinyint NULL,
    NewStatus            tinyint NULL,
    OldAssigneeStaffProfileId uniqueidentifier NULL,
    NewAssigneeStaffProfileId uniqueidentifier NULL,
    Description          nvarchar(1000) NULL,
    ActorIdentityUserId  uniqueidentifier NULL,
    OccurredAtUtc        datetime2(3) NOT NULL CONSTRAINT DF_ServiceRequestEvents_OccurredAtUtc DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_ServiceRequestEvents PRIMARY KEY (ServiceRequestEventId),
    CONSTRAINT FK_ServiceRequestEvents_Request FOREIGN KEY (TenantId, ServiceRequestId)
        REFERENCES crm.ServiceRequests (TenantId, ServiceRequestId),
    CONSTRAINT FK_ServiceRequestEvents_OldAssignee FOREIGN KEY (TenantId, OldAssigneeStaffProfileId)
        REFERENCES crm.StaffProfiles (TenantId, StaffProfileId),
    CONSTRAINT FK_ServiceRequestEvents_NewAssignee FOREIGN KEY (TenantId, NewAssigneeStaffProfileId)
        REFERENCES crm.StaffProfiles (TenantId, StaffProfileId),
    CONSTRAINT CK_ServiceRequestEvents_Type CHECK
    (
        EventType IN (N'Created', N'StatusChanged', N'Assigned', N'Reassigned', N'Reopened', N'Resolved', N'Closed')
    ),
    CONSTRAINT CK_ServiceRequestEvents_OldStatus CHECK (OldStatus IS NULL OR OldStatus IN (1, 2, 3, 4, 5, 6, 7)),
    CONSTRAINT CK_ServiceRequestEvents_NewStatus CHECK (NewStatus IS NULL OR NewStatus IN (1, 2, 3, 4, 5, 6, 7))
);
GO

CREATE INDEX IX_ServiceRequestEvents_Tenant_Request_Occurred
    ON crm.ServiceRequestEvents (TenantId, ServiceRequestId, OccurredAtUtc DESC);
GO

CREATE TABLE crm.ServiceRequestComments
(
    ServiceRequestCommentId uniqueidentifier NOT NULL,
    TenantId               uniqueidentifier NOT NULL,
    ServiceRequestId       uniqueidentifier NOT NULL,
    CommentText            nvarchar(2000) NOT NULL,
    IsInternal             bit NOT NULL CONSTRAINT DF_ServiceRequestComments_IsInternal DEFAULT (0),
    CreatedByIdentityUserId uniqueidentifier NOT NULL,
    CreatedAtUtc           datetime2(3) NOT NULL CONSTRAINT DF_ServiceRequestComments_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_ServiceRequestComments PRIMARY KEY (ServiceRequestCommentId),
    CONSTRAINT FK_ServiceRequestComments_Request FOREIGN KEY (TenantId, ServiceRequestId)
        REFERENCES crm.ServiceRequests (TenantId, ServiceRequestId),
    CONSTRAINT CK_ServiceRequestComments_Text CHECK (LEN(LTRIM(RTRIM(CommentText))) > 0)
);
GO

CREATE INDEX IX_ServiceRequestComments_Tenant_Request_Created
    ON crm.ServiceRequestComments (TenantId, ServiceRequestId, CreatedAtUtc);
GO

/* ================================================================
   7. CRM AUDIT LOG
   Append-only by application policy. Do not store passwords, tokens,
   full payment-card data, or unnecessary copies of sensitive PII here.
   ================================================================ */
CREATE TABLE crm.CrmAuditEntries
(
    CrmAuditEntryId      uniqueidentifier NOT NULL,
    TenantId             uniqueidentifier NOT NULL,
    ActorIdentityUserId  uniqueidentifier NULL,
    ActionCode           nvarchar(64) NOT NULL,
    EntityType           nvarchar(64) NOT NULL,
    EntityId             uniqueidentifier NULL,
    Outcome              nvarchar(16) NOT NULL CONSTRAINT DF_CrmAuditEntries_Outcome DEFAULT (N'Success'),
    CorrelationId        uniqueidentifier NULL,
    Source               nvarchar(24) NULL,
    OccurredAtUtc        datetime2(3) NOT NULL CONSTRAINT DF_CrmAuditEntries_OccurredAtUtc DEFAULT (SYSUTCDATETIME()),
    MetadataJson         nvarchar(max) NULL,

    CONSTRAINT PK_CrmAuditEntries PRIMARY KEY (CrmAuditEntryId),
    CONSTRAINT CK_CrmAuditEntries_Outcome CHECK (Outcome IN (N'Success', N'Failure', N'Denied')),
    CONSTRAINT CK_CrmAuditEntries_MetadataJson CHECK (MetadataJson IS NULL OR ISJSON(MetadataJson) = 1)
);
GO

CREATE INDEX IX_CrmAuditEntries_Tenant_Entity_Occurred
    ON crm.CrmAuditEntries (TenantId, EntityType, EntityId, OccurredAtUtc DESC);
GO

CREATE INDEX IX_CrmAuditEntries_Tenant_Actor_Occurred
    ON crm.CrmAuditEntries (TenantId, ActorIdentityUserId, OccurredAtUtc DESC);
GO
