using System;

namespace MyfschoolWeb.Models
{
    /// <summary>A lesson = one row of dbo.Schedule. DayOfWeek 1..7 (1 = Thứ Hai ... 7 = Chủ nhật), Period 1..8.</summary>
    public class ScheduleModel
    {
        public int Id { get; set; }
        public int TeacherId { get; set; }
        public string TeacherName { get; set; }
        public string ClassName { get; set; }
        public string Subject { get; set; }
        public int DayOfWeek { get; set; }
        public int Period { get; set; }
        /// <summary>"HH:mm"</summary>
        public string StartTime { get; set; }
        /// <summary>"HH:mm"</summary>
        public string EndTime { get; set; }
        public string Room { get; set; }
        public string Mode { get; set; }
        public string Content { get; set; }
        public string Prep { get; set; }
        public string Note { get; set; }

        public string DayName { get { return Services.ScheduleService.DayName(DayOfWeek); } }
    }
}
