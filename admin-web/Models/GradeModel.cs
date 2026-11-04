using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;

namespace MyfschoolWeb.Models
{
    /// <summary>One row of dbo.Grade (a single score).</summary>
    public class GradeEntry
    {
        public int Id { get; set; }
        public string Type { get; set; }      // Miệng | 15 phút | 1 tiết | Giữa kỳ | Cuối kỳ
        public int Weight { get; set; }       // 1 | 1 | 2 | 2 | 3
        public decimal Score { get; set; }    // 0..10
        public DateTime? Date { get; set; }
        [JsonIgnore] public string ScoreText { get { return Score.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture); } }
        [JsonIgnore] public string DateText { get { return Date.HasValue ? Date.Value.ToString("dd/MM/yyyy") : ""; } }
    }

    /// <summary>
    /// Student x subject x term view that aggregates the dbo.Grade rows (plus the GradeRemark of the teacher).
    /// Identified by StudentId + Subject + Term. Average = weighted mean by each row's weight, rounded to 2 decimals
    /// (same formula as backend/controllers/GradeController.js).
    /// </summary>
    public class GradeModel
    {
        public int StudentId { get; set; }
        public string StudentName { get; set; }
        public string ClassName { get; set; }
        public string Subject { get; set; }
        public string Term { get; set; }
        public List<GradeEntry> Entries { get; set; } = new List<GradeEntry>();
        public string Comment { get; set; }
        public int? TeacherId { get; set; }
        public string TeacherName { get; set; }

        /// <summary>Weighted mean (2 decimals) or null when there are no scores.</summary>
        public decimal? Average { get { return Services.GradeService.Weighted(Entries); } }
        public string Evaluation { get { return Services.GradeService.Evaluate(Average); } }
        [JsonIgnore] public string BadgeClass { get { return Services.GradeService.BadgeFor(Evaluation); } }
        [JsonIgnore] public string AverageText { get { return Average.HasValue ? Average.Value.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture) : "-"; } }

        /// <summary>Regular scores: Miệng, 15 phút, 1 tiết (ordered by date).</summary>
        [JsonIgnore]
        public List<GradeEntry> Regular
        {
            get { return Entries.Where(e => e.Type == "Miệng" || e.Type == "15 phút" || e.Type == "1 tiết").ToList(); }
        }
        public decimal? Midterm { get { return Mean("Giữa kỳ"); } }
        public decimal? Final { get { return Mean("Cuối kỳ"); } }

        [JsonIgnore] public string RegularText { get { var r = Regular; return r.Count == 0 ? "-" : string.Join("; ", r.Select(e => Fmt(e.Score))); } }
        [JsonIgnore] public string MidtermText { get { return Fmt(Midterm); } }
        [JsonIgnore] public string FinalText { get { return Fmt(Final); } }

        private decimal? Mean(string type)
        {
            var l = Entries.Where(e => e.Type == type).ToList();
            if (l.Count == 0) return null;
            return Math.Round(l.Sum(e => e.Score) / l.Count, 2, MidpointRounding.AwayFromZero);
        }

        public static string Fmt(decimal? d) { return d.HasValue ? d.Value.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture) : "-"; }
    }
}
