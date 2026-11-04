-- Idempotent schema for FSchoolDB. Batches separated by GO lines.
IF OBJECT_ID('dbo.Users', 'U') IS NULL
CREATE TABLE dbo.Users (
  id           INT IDENTITY(1,1) PRIMARY KEY,
  name         NVARCHAR(100) NOT NULL,
  email        NVARCHAR(150) NULL,
  phone        VARCHAR(20)   NULL,
  passwordHash NVARCHAR(100) NOT NULL,
  role         VARCHAR(10)   NOT NULL,
  createdAt    DATETIME2     NOT NULL CONSTRAINT DF_Users_createdAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_Users_role CHECK (role IN ('GV','Manager','PH','HS'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Users_email' AND object_id = OBJECT_ID('dbo.Users'))
CREATE UNIQUE INDEX UX_Users_email ON dbo.Users(email) WHERE email IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Users_phone' AND object_id = OBJECT_ID('dbo.Users'))
CREATE UNIQUE INDEX UX_Users_phone ON dbo.Users(phone) WHERE phone IS NOT NULL;
GO
IF OBJECT_ID('dbo.Schedule', 'U') IS NULL
CREATE TABLE dbo.Schedule (
  id         INT IDENTITY(1,1) PRIMARY KEY,
  teacherId  INT NOT NULL CONSTRAINT FK_Schedule_Teacher REFERENCES dbo.Users(id),
  className  NVARCHAR(50)  NOT NULL,
  subject    NVARCHAR(100) NOT NULL,
  dayOfWeek  TINYINT NOT NULL CHECK (dayOfWeek BETWEEN 1 AND 7),
  startTime  TIME NOT NULL,
  endTime    TIME NOT NULL,
  room       NVARCHAR(30) NULL
);
GO
IF OBJECT_ID('dbo.Grade', 'U') IS NULL
CREATE TABLE dbo.Grade (
  id        INT IDENTITY(1,1) PRIMARY KEY,
  studentId INT NOT NULL CONSTRAINT FK_Grade_Student REFERENCES dbo.Users(id),
  subject   NVARCHAR(100) NOT NULL,
  score     DECIMAL(4,2) NOT NULL CHECK (score BETWEEN 0 AND 10),
  term      NVARCHAR(20) NULL,
  createdAt DATETIME2 NOT NULL CONSTRAINT DF_Grade_createdAt DEFAULT SYSUTCDATETIME()
);
GO
-- ===== Phase 2: classes, parents, schedule/grade details, requests, clubs =====
IF COL_LENGTH('dbo.Users', 'className') IS NULL ALTER TABLE dbo.Users ADD className NVARCHAR(20) NULL;
GO
IF OBJECT_ID('dbo.ParentStudent', 'U') IS NULL
CREATE TABLE dbo.ParentStudent (
  parentId  INT NOT NULL CONSTRAINT FK_PS_Parent REFERENCES dbo.Users(id),
  studentId INT NOT NULL CONSTRAINT FK_PS_Student REFERENCES dbo.Users(id),
  CONSTRAINT PK_ParentStudent PRIMARY KEY (parentId, studentId)
);
GO
IF COL_LENGTH('dbo.Schedule', 'period') IS NULL ALTER TABLE dbo.Schedule ADD period TINYINT NOT NULL CONSTRAINT DF_Schedule_period DEFAULT 1;
GO
IF COL_LENGTH('dbo.Schedule', 'mode') IS NULL ALTER TABLE dbo.Schedule ADD mode NVARCHAR(30) NULL;
GO
IF COL_LENGTH('dbo.Schedule', 'content') IS NULL ALTER TABLE dbo.Schedule ADD content NVARCHAR(200) NULL;
GO
IF COL_LENGTH('dbo.Schedule', 'prep') IS NULL ALTER TABLE dbo.Schedule ADD prep NVARCHAR(200) NULL;
GO
IF COL_LENGTH('dbo.Schedule', 'note') IS NULL ALTER TABLE dbo.Schedule ADD note NVARCHAR(300) NULL;
GO
IF COL_LENGTH('dbo.Grade', 'type') IS NULL ALTER TABLE dbo.Grade ADD type NVARCHAR(20) NOT NULL CONSTRAINT DF_Grade_type DEFAULT N'15 phút';
GO
IF COL_LENGTH('dbo.Grade', 'weight') IS NULL ALTER TABLE dbo.Grade ADD weight TINYINT NOT NULL CONSTRAINT DF_Grade_weight DEFAULT 1;
GO
IF COL_LENGTH('dbo.Grade', 'gradeDate') IS NULL ALTER TABLE dbo.Grade ADD gradeDate DATE NULL;
GO
IF OBJECT_ID('dbo.GradeRemark', 'U') IS NULL
CREATE TABLE dbo.GradeRemark (
  studentId INT NOT NULL CONSTRAINT FK_GR_Student REFERENCES dbo.Users(id),
  subject   NVARCHAR(100) NOT NULL,
  term      NVARCHAR(20)  NOT NULL,
  teacherId INT NOT NULL CONSTRAINT FK_GR_Teacher REFERENCES dbo.Users(id),
  comment   NVARCHAR(300) NULL,
  CONSTRAINT PK_GradeRemark PRIMARY KEY (studentId, subject, term)
);
GO
IF OBJECT_ID('dbo.TermSummary', 'U') IS NULL
CREATE TABLE dbo.TermSummary (
  studentId INT NOT NULL CONSTRAINT FK_TS_Student REFERENCES dbo.Users(id),
  term      NVARCHAR(20) NOT NULL,
  conduct   NVARCHAR(20) NULL,
  CONSTRAINT PK_TermSummary PRIMARY KEY (studentId, term)
);
GO
IF OBJECT_ID('dbo.Requests', 'U') IS NULL
CREATE TABLE dbo.Requests (
  id             INT IDENTITY(1,1) PRIMARY KEY,
  studentId      INT NOT NULL CONSTRAINT FK_Req_Student REFERENCES dbo.Users(id),
  createdBy      INT NOT NULL CONSTRAINT FK_Req_Creator REFERENCES dbo.Users(id),
  type           NVARCHAR(30)  NOT NULL,
  fromDate       DATE NULL,
  toDate         DATE NULL,
  reason         NVARCHAR(500) NOT NULL,
  status         VARCHAR(10)   NOT NULL CONSTRAINT DF_Req_status DEFAULT 'pending',
  teacherComment NVARCHAR(500) NULL,
  handledBy      INT NULL CONSTRAINT FK_Req_Handler REFERENCES dbo.Users(id),
  handledAt      DATETIME2 NULL,
  createdAt      DATETIME2 NOT NULL CONSTRAINT DF_Req_createdAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_Req_status CHECK (status IN ('pending','approved','rejected'))
);
GO
IF OBJECT_ID('dbo.Clubs', 'U') IS NULL
CREATE TABLE dbo.Clubs (
  id          INT IDENTITY(1,1) PRIMARY KEY,
  name        NVARCHAR(100) NOT NULL,
  icon        NVARCHAR(10)  NULL,
  description NVARCHAR(500) NULL,
  meeting     NVARCHAR(100) NULL,
  location    NVARCHAR(100) NULL,
  advisor     NVARCHAR(100) NULL,
  president   NVARCHAR(100) NULL,
  baseMembers INT NOT NULL CONSTRAINT DF_Club_base DEFAULT 0
);
GO
IF OBJECT_ID('dbo.ClubMembers', 'U') IS NULL
CREATE TABLE dbo.ClubMembers (
  clubId   INT NOT NULL CONSTRAINT FK_CM_Club REFERENCES dbo.Clubs(id),
  userId   INT NOT NULL CONSTRAINT FK_CM_User REFERENCES dbo.Users(id),
  status   VARCHAR(10) NOT NULL CONSTRAINT DF_CM_status DEFAULT 'pending',
  joinedAt DATETIME2 NOT NULL CONSTRAINT DF_CM_joined DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_ClubMembers PRIMARY KEY (clubId, userId),
  CONSTRAINT CK_CM_status CHECK (status IN ('pending','approved'))
);
GO
