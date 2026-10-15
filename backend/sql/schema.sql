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
