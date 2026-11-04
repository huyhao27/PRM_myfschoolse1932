using System.Collections.Generic;

namespace MyfschoolWeb.Models
{
    public class ImportResultModel
    {
        public bool Success { get; set; } = true;
        public string Message { get; set; }
        public int TotalProcessed { get; set; }
        public int InsertedCount { get; set; }
        public int UpdatedCount { get; set; }
        public int FailedCount { get; set; }
        public List<string> ErrorDetails { get; set; } = new List<string>();
        public List<string> ImportedItems { get; set; } = new List<string>();
    }
}
