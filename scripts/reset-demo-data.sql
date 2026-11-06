-- Puts FSchoolDB back to the demo state: empties every table and restarts the ids at 1.
-- Afterwards `npm run db:init` (backend/) recreates the 6 demo users and the demo data (seed.sql).
-- Used by scripts\demo.ps1 -Reset. Deletes EVERYTHING in FSchoolDB, including accounts made on the web.
SET NOCOUNT ON;
DELETE FROM dbo.ClubMembers;
DELETE FROM dbo.Clubs;
DELETE FROM dbo.Requests;
DELETE FROM dbo.GradeRemark;
DELETE FROM dbo.TermSummary;
DELETE FROM dbo.Grade;
DELETE FROM dbo.Schedule;
DELETE FROM dbo.ParentStudent;
DELETE FROM dbo.Users;
DBCC CHECKIDENT ('dbo.Clubs', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Requests', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Grade', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Schedule', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Users', RESEED, 0) WITH NO_INFOMSGS;
PRINT 'FSchoolDB emptied.';
